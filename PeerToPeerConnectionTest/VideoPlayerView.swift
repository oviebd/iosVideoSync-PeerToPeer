internal import SwiftUI
import AVKit
import Combine
import UIKit

// MARK: - Video-Only Player View (no native controls)

struct VideoOnlyPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

class PlayerUIView: UIView {
    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }
    
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = bounds
    }
}

//
//// MARK: - SyncedVideoPlayer
//
class SyncedVideoPlayer: ObservableObject, VideoSyncDelegate {
    @Published var player: AVPlayer
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isSeeking: Bool = false
    @Published var isReady: Bool = false
    @Published var isRemoteSeeking: Bool = false  // True when master is seeking (for slave UI)
    @Published var currentVideoName: String? = nil  // Name of currently loaded video
    
    private var timeObserver: Any?
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var statusObserver: NSKeyValueObservation?
    private var seekCompletionTimer: Timer?  // For delayed play after seek
    private var currentSecurityScopedURL: URL?  // Track security-scoped resource
    
    weak var service: MultipeerService?
    
    let syncInterval: TimeInterval
    
    init(syncInterval: TimeInterval = 2.0) {
        self.syncInterval = syncInterval
        
        // Initialize with empty player (no video loaded)
        self.player = AVPlayer()
        
        // Set audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Audio session error: \(error)")
        }
        
        setupPlayerObservers()
        observePlayerStatus()
    }
    
    // Load video from URL
    func loadVideo(url: URL, videoName: String? = nil) {
        // Stop current playback
        player.pause()
        
        // Release previous security-scoped resource
        if let previousURL = currentSecurityScopedURL {
            previousURL.stopAccessingSecurityScopedResource()
            currentSecurityScopedURL = nil
        }
        
        // Store new URL for cleanup
        currentSecurityScopedURL = url
        
        print("📹 Loading video from: \(url)")
        print("   Video name: \(videoName ?? "unknown")")
        
        // Create new player item
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        
        // Update video name
        currentVideoName = videoName
        
        // Reset ready state
        isReady = false
        
        // Re-observe status for new item
        observePlayerStatus()
    }
    
    private func observePlayerStatus() {
        // Observe player item status
        statusObserver = player.observe(\.currentItem?.status, options: [.new]) { [weak self] player, change in
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
        // Observe playback time
        let interval = CMTime(seconds: 0.05, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            
            // Update duration
            if let duration = self.player.currentItem?.duration.seconds, duration.isFinite {
                self.duration = duration
            }
        }
        
        // Observe play/pause state
        player.publisher(for: \.rate)
            .sink { [weak self] rate in
                self?.isPlaying = rate > 0
            }
            .store(in: &cancellables)
    }
    
    deinit {
        // Release security-scoped resource
        if let url = currentSecurityScopedURL {
            url.stopAccessingSecurityScopedResource()
        }
        
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        statusObserver?.invalidate()
        syncTimer?.invalidate()
        seekCompletionTimer?.invalidate()
    }
    
    // MARK: - Master Controls
    
    func masterPlay() {
        player.play()
        service?.sendPlayCommand(position: currentTime)
        startSyncTimer()
    }
    
    func masterPause() {
        player.pause()
        service?.sendPauseCommand(position: currentTime)
        stopSyncTimer()
    }
    
    func masterSeek(to position: Double) {
        // Cancel any pending seek completion
        seekCompletionTimer?.invalidate()
        
        isSeeking = true
        
        // Step 1: Tell slaves to pause and show "seeking..."
        service?.sendSeekingStartedCommand()
        
        // Step 2: Pause master video
        player.pause()
        
        // Step 3: Seek
        let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time) { [weak self] finished in
            guard let self = self, finished else { return }
            
            self.isSeeking = false
            
            // Step 4: Send the new position to slaves
            self.service?.sendSeekCommand(to: position)
            
            // Step 5: Wait 1 second, then play
            self.seekCompletionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                print("🎬 Seek completed, resuming playback")
                self.player.play()
                // Send play with the current position after seek
                self.service?.sendPlayCommand(position: self.currentTime)
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
    
    // MARK: - Sync Timer (Master only)
    
    private func startSyncTimer() {
        stopSyncTimer()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.service?.sendSyncCommand(position: self.currentTime, isPlaying: self.isPlaying)
        }
    }
    
    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    /// Call when leaving room so master stops broadcasting sync; prevents stale timer on re-enter.
    func stopBroadcasting() {
        stopSyncTimer()
        seekCompletionTimer?.invalidate()
        seekCompletionTimer = nil
    }
    
    // MARK: - VideoSyncDelegate
    
    func didReceiveLoadVideoCommand(videoName: String) {
        // This is handled by VideoSyncDelegateWrapper in RoomView
        // This method exists to satisfy the protocol but shouldn't be called directly
        print("⚠️ SyncedVideoPlayer.didReceiveLoadVideoCommand called directly (should go through wrapper)")
    }
    
    func didReceiveVideoInfoResponse(videoName: String, position: Double, isPlaying: Bool) {
        // Handled by VideoSyncDelegateWrapper in RoomView
        print("⚠️ SyncedVideoPlayer.didReceiveVideoInfoResponse called directly (should go through wrapper)")
    }
    
    func didReceiveVideoCommand(_ command: VideoCommand) {
        print("🎬 Executing video command: \(command)")
        print("   Player ready: \(isReady)")
        print("   Current time: \(currentTime)s")
        print("   Is playing: \(isPlaying)")
        
        // Also log to service command log
        service?.addCommandLog("🎬 EXECUTING: \(command)")
        
        switch command {
        case .play(let position):
            print("  → Playing video at position \(position)s")
            if !isReady {
                print("  ⚠️ Warning: Player not ready yet, attempting to play anyway")
                service?.addCommandLog("⚠️ Player not ready!")
            }
            
            // First, sync to the exact position
            let diff = abs(currentTime - position)
            if diff > 0.1 {  // Sync if off by more than 0.1 seconds
                print("  → Syncing position first (diff: \(diff)s)")
                let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                    if finished {
                        print("  → Position synced, now playing")
                        self?.player.play()
                    }
                }
            } else {
                player.play()
            }
            
            isRemoteSeeking = false  // Clear seeking indicator
            service?.addCommandLog("✅ Called player.play()")
            
        case .pause(let position):
            print("  → Pausing video at position \(position)s")
            isRemoteSeeking = false
            
            // First, sync to the exact position
            let diff = abs(currentTime - position)
            if diff > 0.1 {  // Sync if off by more than 0.1 seconds
                print("  → Syncing position first (diff: \(diff)s)")
                let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                    if finished {
                        print("  → Position synced, now pausing")
                        self?.player.pause()
                    }
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
            
        case .sync(let position, let isPlaying):
            let diff = abs(currentTime - position)
            print("  → Sync: position=\(position)s, isPlaying=\(isPlaying), currentTime=\(currentTime)s, diff=\(diff)s")
            
            let applyPlayState = { [weak self] in
                guard let self = self else { return }
                self.isRemoteSeeking = false
                if isPlaying && !self.isPlaying {
                    print("    → Starting playback")
                    if !self.isReady { print("    ⚠️ Warning: Player not ready yet") }
                    self.player.play()
                    self.service?.addCommandLog("✅ Synced play state")
                } else if !isPlaying && self.isPlaying {
                    print("    → Stopping playback")
                    self.player.pause()
                    self.service?.addCommandLog("✅ Synced pause state")
                }
            }
            
            // Seek first if position is off, then apply play/pause in completion so we don't play from wrong frame (smooth, no stuck frame)
            if diff > 0.1 {
                print("    → Correcting position (diff > 0.1s)")
                let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                    if finished { applyPlayState() }
                    else { applyPlayState() } // still apply play state even if seek reported not finished
                }
                service?.addCommandLog("✅ Synced position")
            } else {
                applyPlayState()
            }
        case .loadVideo(videoName: let videoName):
            return
        case .requestVideoInfo:
            // This should be handled by MultipeerService, not here
            return
        case .videoInfoResponse(videoName: _, position: _, isPlaying: _):
            // This should be handled by VideoSyncDelegateWrapper, not here
            return
        }
    }
}

// MARK: - VideoRoomView

struct VideoRoomView: View {
    @EnvironmentObject var service: MultipeerService
    @ObservedObject var videoPlayer: SyncedVideoPlayer
    @State private var showLog: Bool = false
    var onSelectVideo: (() -> Void)? = nil  // Callback for master to show video selection
    
    var body: some View {
        GeometryReader { geometry in
            let videoHeight = geometry.size.height * 0.35
            VStack(spacing: 0) {
                // Command Log toggle button
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring()) {
                            showLog.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showLog ? "terminal.fill" : "terminal")
                            Text(showLog ? "Hide Log" : "Show Log")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(showLog ? AppTheme.accent : AppTheme.textDim)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.surface)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(showLog ? AppTheme.accent.opacity(0.3) : AppTheme.border, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                
                // Command Log (conditionally visible)
                if showLog {
                    commandLogView
                        .frame(height: 180)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Video name label
                videoNameLabel
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                
                // Video Player - custom view only (no native in-player controls)
                ZStack {
                    VideoOnlyPlayerView(player: videoPlayer.player)
                        .frame(height: videoHeight)
                        .background(Color.black)
                    
                    // Seeking indicator overlay (slave only)
                    if service.role == .slave && videoPlayer.isRemoteSeeking {
                        ZStack {
                            Color.black.opacity(0.7)
                            
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
                                    .scaleEffect(1.5)
                                
                                Text("SEEKING...")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.accent)
                                    .tracking(3)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .frame(height: videoHeight)
                
                // Status bar below video
                statusBar
                
                // Controls/info area
                Spacer()
                
                if service.role == .master {
                    masterControls
                } else {
                    slaveIndicator
                }
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }
    
    // MARK: Video Name Label
    
    private var videoNameLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "film")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textDim)
            Text(videoPlayer.currentVideoName ?? "No video selected")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(AppTheme.textDim)
            Spacer()
            
            // Select Video button (master only)
            if service.role == .master, let onSelectVideo = onSelectVideo {
                Button(action: onSelectVideo) {
                    HStack(spacing: 4) {
                        Image(systemName: "film")
                            .font(.system(size: 11))
                        Text("Select Video")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.accentDim.opacity(0.3))
                    .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: Status Bar (below video)
    
    private var statusBar: some View {
        HStack(spacing: 12) {
            Button(action: { service.leaveRoom() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Leave")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(AppTheme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.surface)
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Seeking indicator (master)
            if service.role == .master && videoPlayer.isSeeking {
                HStack(spacing: 4) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
                        .scaleEffect(0.8)
                    Text("SEEKING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.accentDim)
                .cornerRadius(6)
            }
            
            // Player ready indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(videoPlayer.isReady ? AppTheme.accent : AppTheme.warning)
                    .frame(width: 5, height: 5)
                Text(videoPlayer.isReady ? "READY" : "LOAD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
            }
            .foregroundColor(AppTheme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.surface)
            .cornerRadius(6)
            
            // Role badge
            HStack(spacing: 4) {
                Circle()
                    .fill(service.role == .master ? AppTheme.accent : AppTheme.warning)
                    .frame(width: 5, height: 5)
                Text(service.role == .master ? "MASTER" : "SLAVE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
            }
            .foregroundColor(AppTheme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.surface)
            .cornerRadius(6)
            
            // Connected count
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 9))
                Text("\(service.connectedPeers.count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(AppTheme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.surface)
            .cornerRadius(6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.bg)
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1), alignment: .bottom)
    }
    
    // MARK: Command Log View
    
    private var commandLogView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("COMMAND LOG")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.accent)
                    .tracking(2)
                Spacer()
                Button(action: { service.commandLog.removeAll() }) {
                    Text("CLEAR")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.textDim)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.surface)
            
            Divider().background(AppTheme.border)
            
            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if service.commandLog.isEmpty {
                            Text("Waiting for commands...")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppTheme.textDim)
                                .padding(8)
                        } else {
                            ForEach(Array(service.commandLog.enumerated()), id: \.offset) { index, log in
                                Text(log)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(log.contains("❌") ? AppTheme.danger :
                                                   log.contains("📤") ? AppTheme.accent :
                                                   log.contains("📥") ? AppTheme.warning :
                                                   AppTheme.text)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .id(index)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                .onChange(of: service.commandLog.count) { oldValue, newValue in
                    if let lastIndex = service.commandLog.indices.last {
                        withAnimation {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(AppTheme.bg)
        }
        .background(AppTheme.bg)
        .overlay(
            Rectangle()
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
    
    // MARK: Top Bar
    
    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: { service.leaveRoom() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Leave")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }
            
            Spacer()
            
            // Player ready indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(videoPlayer.isReady ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(videoPlayer.isReady ? "READY" : "LOADING")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            
            // Role badge
            HStack(spacing: 6) {
                Circle()
                    .fill(service.role == .master ? AppTheme.accent : AppTheme.warning)
                    .frame(width: 6, height: 6)
                Text(service.role == .master ? "MASTER" : "SLAVE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            
            // Connected count
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                Text("\(service.connectedPeers.count)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
    
    // MARK: Master Controls
    
    private var masterControls: some View {
        VStack(spacing: 12) {
            // Progress bar
            VStack(spacing: 6) {
                Slider(value: Binding(
                    get: { videoPlayer.currentTime },
                    set: { videoPlayer.masterSeek(to: $0) }
                ), in: 0...max(videoPlayer.duration, 1))
                .tint(AppTheme.accent)
                
                HStack {
                    Text(formatTime(videoPlayer.currentTime))
                        .font(.system(size: 11, design: .monospaced))
                    Spacer()
                    Text(formatTime(videoPlayer.duration))
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundColor(AppTheme.text)
            }
            
            // Control buttons
            HStack(spacing: 24) {
                Button(action: { videoPlayer.masterBackward(10) }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.text)
                }
                
                Button(action: {
                    print("🎯 Play/Pause button tapped!")
                    print("   Current isPlaying state: \(videoPlayer.isPlaying)")
                    if videoPlayer.isPlaying {
                        print("   → Calling masterPause()")
                        videoPlayer.masterPause()
                    } else {
                        print("   → Calling masterPlay()")
                        videoPlayer.masterPlay()
                    }
                }) {
                    Image(systemName: videoPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.accent)
                }
                
                Button(action: { videoPlayer.masterForward(10) }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.text)
                }
            }
            
            // Sync info
            Text("Broadcasting • Sync every \(Int(videoPlayer.syncInterval))s")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(AppTheme.textDim)
                .tracking(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppTheme.surface)
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1), alignment: .top)
    }
    
    // MARK: Slave Indicator
    
    private var slaveIndicator: some View {
        VStack(spacing: 10) {
            // Main status
            HStack(spacing: 8) {
                Image(systemName: videoPlayer.isRemoteSeeking ? "hourglass" : "lock.fill")
                    .font(.system(size: 11))
                Text(videoPlayer.isRemoteSeeking ? "Master seeking..." : "Synced with master")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(videoPlayer.isRemoteSeeking ? AppTheme.warning : AppTheme.text)
            
            // Time display
            Text(formatTime(videoPlayer.currentTime) + " / " + formatTime(videoPlayer.duration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppTheme.textDim)
            
            Divider().background(AppTheme.border)
            
            // Get Video Info button (only show when connected to master)
            if !service.connectedPeers.isEmpty {
                Button(action: {
                    print("📹 Requesting video info from master")
                    service.sendRequestVideoInfoCommand()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12))
                        Text("Get Video Info")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.bg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.accent)
                    .cornerRadius(8)
                }
                .padding(.vertical, 4)
            }
            
            Divider().background(AppTheme.border)
            
            // Diagnostic info
            VStack(spacing: 6) {
                HStack {
                    Text("Rate:")
                    Spacer()
                    Text(String(format: "%.2f", videoPlayer.player.rate))
                        .foregroundColor(videoPlayer.player.rate > 0 ? AppTheme.accent : AppTheme.textDim)
                }
                HStack {
                    Text("Ready:")
                    Spacer()
                    Text(videoPlayer.isReady ? "✓" : "✗")
                        .foregroundColor(videoPlayer.isReady ? AppTheme.accent : AppTheme.danger)
                }
                HStack {
                    Text("Delegate:")
                    Spacer()
                    Text(service.videoDelegate != nil ? "✓" : "✗")
                        .foregroundColor(service.videoDelegate != nil ? AppTheme.accent : AppTheme.danger)
                }
                HStack {
                    Text("Seeking:")
                    Spacer()
                    Text(videoPlayer.isRemoteSeeking ? "YES" : "NO")
                        .foregroundColor(videoPlayer.isRemoteSeeking ? AppTheme.warning : AppTheme.textDim)
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(AppTheme.text)
            

        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppTheme.surface)
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1), alignment: .top)
    }
    
    // MARK: Helpers
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - RoundedCorner Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}


