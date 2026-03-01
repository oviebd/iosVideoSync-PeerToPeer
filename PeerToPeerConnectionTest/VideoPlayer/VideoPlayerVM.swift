//
//  VideoPlayerVM.swift
//  PeerToPeerConnectionTest
//

internal import AVFoundation
import Combine
import Foundation

// MARK: - VideoPlayerVM

class VideoPlayerVM: ObservableObject, VideoSyncDelegate {
    @Published var player: AVPlayer
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isSeeking: Bool = false
    @Published var isReady: Bool = false
    @Published var isRemoteSeeking: Bool = false
    @Published var currentVideoName: String?

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var statusObserver: NSKeyValueObservation?
    private var seekCompletionTimer: Timer?
    private var currentSecurityScopedURL: URL?

    /// When true, do not broadcast rate/seek changes (we're applying our own masterPlay/masterPause/masterSeek)
    private var suppressNativeControlBroadcast: Bool = false
    private var lastObservedPosition: Double = 0
    private var lastPositionObservedAt: CFTimeInterval = 0
    private var lastKnownRate: Float = 0

    weak var service: MultipeerService?

    init() {
        self.player = AVPlayer()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Audio session error: \(error)")
        }

        setupPlayerObservers()
        observePlayerStatus()
    }

    // MARK: - Load Video

    func loadVideo(url: URL, videoName: String? = nil) {
        player.pause()

        if let previousURL = currentSecurityScopedURL {
            previousURL.stopAccessingSecurityScopedResource()
            currentSecurityScopedURL = nil
        }

        currentSecurityScopedURL = url

        print("📹 Loading video from: \(url)")
        print("   Video name: \(videoName ?? "unknown")")

        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)

        currentVideoName = videoName
        isReady = false

        observePlayerStatus()
    }

    private func observePlayerStatus() {
        statusObserver = player.observe(\.currentItem?.status, options: [.new]) { [weak self] player, _ in
            guard let self = self else { return }

            if let status = player.currentItem?.status {
                DispatchQueue.main.async {
                    switch status {
                    case .readyToPlay:
                        self.isReady = true
                        print("✅ Video is ready to play")
                        if let duration = player.currentItem?.duration.seconds, duration.isFinite {
                            self.duration = duration
                            print("   Duration: \(duration)s")
                        }
                    case .failed:
                        print("❌ Video failed to load: \(player.currentItem?.error?.localizedDescription ?? "unknown")")
                    case .unknown:
                        print("⏳ Video status: unknown")
                    @unknown default:
                        break
                    }
                }
            }
        }
    }

    private func setupPlayerObservers() {
        let interval = CMTime(seconds: 0.05, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let newPosition = time.seconds
            self.currentTime = newPosition

            if let duration = self.player.currentItem?.duration.seconds, duration.isFinite {
                self.duration = duration
            }

            // Detect seek from native controls (position jump > expected from playback)
            self.detectNativeSeekAndBroadcast(newPosition: newPosition)
            self.lastObservedPosition = newPosition
            self.lastPositionObservedAt = CACurrentMediaTime()
        }

        player.publisher(for: \.rate)
            .sink { [weak self] rate in
                guard let self = self else { return }
                self.lastKnownRate = Float(rate)
                self.isPlaying = rate > 0
                self.broadcastPlayPauseIfFromNativeControls(rate: Double(rate))
            }
            .store(in: &cancellables)
    }

    private func broadcastPlayPauseIfFromNativeControls(rate: Double) {
        guard !suppressNativeControlBroadcast else { return }
        guard let svc = service, svc.role == .master else { return }

        if rate > 0 {
            svc.sendPlayCommand(position: currentTime)
        } else {
            svc.sendPauseCommand(position: currentTime)
        }
    }

    private func detectNativeSeekAndBroadcast(newPosition: Double) {
        guard !suppressNativeControlBroadcast else { return }
        guard let svc = service, svc.role == .master else { return }
        guard lastPositionObservedAt > 0 else { return }

        let elapsed = CACurrentMediaTime() - lastPositionObservedAt
        let expectedDelta = elapsed * Double(player.rate)
        let actualDelta = abs(newPosition - lastObservedPosition)

        // Position jump > 0.5s beyond normal playback = user seeked via native scrubber
        if actualDelta > 0.5 + abs(expectedDelta) {
            suppressNativeControlBroadcast = true
            isSeeking = true

            player.pause()
            svc.sendSeekingStartedCommand()
            svc.sendSeekCommand(to: newPosition)

            let wasPlaying = lastKnownRate > 0
            seekCompletionTimer?.invalidate()
            seekCompletionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.suppressNativeControlBroadcast = false
                self.isSeeking = false
                if wasPlaying {
                    self.player.play()
                    self.service?.sendPlayCommand(position: self.currentTime)
                } else {
                    self.service?.sendPauseCommand(position: self.currentTime)
                }
            }
        }
    }

    deinit {
        if let url = currentSecurityScopedURL {
            url.stopAccessingSecurityScopedResource()
        }

        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        statusObserver?.invalidate()
        seekCompletionTimer?.invalidate()
    }

    // MARK: - Master Controls

    func masterPlay() {
        suppressNativeControlBroadcast = true
        player.play()
        service?.sendPlayCommand(position: currentTime)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.suppressNativeControlBroadcast = false
        }
    }

    func masterPause() {
        suppressNativeControlBroadcast = true
        player.pause()
        service?.sendPauseCommand(position: currentTime)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.suppressNativeControlBroadcast = false
        }
    }

    func masterSeek(to position: Double) {
        seekCompletionTimer?.invalidate()
        suppressNativeControlBroadcast = true
        isSeeking = true

        service?.sendSeekingStartedCommand()

        player.pause()

        let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time) { [weak self] finished in
            guard let self = self, finished else { return }

            self.isSeeking = false

            self.service?.sendSeekCommand(to: position)

            self.seekCompletionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                print("🎬 Seek completed, resuming playback")
                self.player.play()
                self.service?.sendPlayCommand(position: self.currentTime)
                self.suppressNativeControlBroadcast = false
            }
        }
    }

    func masterForward(_ seconds: Double) {
        let newPosition = min(currentTime + seconds, duration)
        masterSeek(to: newPosition)
    }

    func masterBackward(_ seconds: Double) {
        let newPosition = max(currentTime - seconds, 0)
        masterSeek(to: newPosition)
    }

    func stopBroadcasting() {
        seekCompletionTimer?.invalidate()
        seekCompletionTimer = nil
    }

    // MARK: - VideoSyncDelegate

    func didReceiveLoadVideoCommand(videoName: String) {
        print("⚠️ VideoPlayerVM.didReceiveLoadVideoCommand called directly (should go through wrapper)")
    }

    func didReceiveVideoInfoResponse(videoName: String, position: Double, isPlaying: Bool) {
        print("⚠️ VideoPlayerVM.didReceiveVideoInfoResponse called directly (should go through wrapper)")
    }

    func didReceiveVideoCommand(_ command: VideoCommand) {
        print("🎬 Executing video command: \(command)")
        print("   Player ready: \(isReady)")
        print("   Current time: \(currentTime)s")
        print("   Is playing: \(isPlaying)")

        service?.addCommandLog("🎬 EXECUTING: \(command)")

        switch command {
        case .play(let position):
            print("  → Playing video at position \(position)s")
            if !isReady {
                print("  ⚠️ Warning: Player not ready yet, attempting to play anyway")
                service?.addCommandLog("⚠️ Player not ready!")
            }

            let diff = abs(currentTime - position)
            if diff > 0.1 {
                print("  → Syncing position first (diff: \(diff)s)")
                let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                    print("  → Position sync finished: \(finished), playing")
                    // Always call play() - slave must resume even if seek reports unfinished (e.g. when seek was superseded)
                    self?.player.play()
                }
            } else {
                player.play()
            }

            isRemoteSeeking = false
            service?.addCommandLog("✅ Called player.play()")

        case .pause(let position):
            print("  → Pausing video at position \(position)s")
            isRemoteSeeking = false

            let diff = abs(currentTime - position)
            if diff > 0.1 {
                print("  → Syncing position first (diff: \(diff)s)")
                let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    self?.player.pause()
                }
            } else {
                player.pause()
            }

            service?.addCommandLog("✅ Called player.pause()")

        case .seekingStarted:
            print("  → Master started seeking, pausing and showing indicator")
            isRemoteSeeking = true
            player.pause()
            service?.addCommandLog("⏸️ Master seeking...")

        case .seek(let position):
            print("  → Seeking to \(position)s")
            let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                print("    → Seek finished: \(finished)")
                self?.isRemoteSeeking = false
            }
            service?.addCommandLog("✅ Called player.seek()")

        case .loadVideo(videoName: _):
            return
        case .requestVideoInfo:
            return
        case .videoInfoResponse(videoName: _, position: _, isPlaying: _):
            return
        }
    }
}
