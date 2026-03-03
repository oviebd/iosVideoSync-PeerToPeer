//
//  BackgroundKeepAliveService.swift
//  PeerToPeerConnectionTest
//
//  Keeps MultipeerConnectivity session alive when app is backgrounded by playing
//  a silent looping audio track. Only active when in a room. Uses .mixWithOthers
//  so it does not interrupt video playback or the user's music.
//

internal import AVFoundation
import Combine
internal import UIKit

final class BackgroundKeepAliveService: ObservableObject {

    private var silentPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var isInBackground = false
    private var shouldKeepAlive = false

    private weak var multipeerService: MultipeerService?

    init(multipeerService: MultipeerService) {
        self.multipeerService = multipeerService

        setupLifecycleObservers()
        observeRoomState()
    }

    private func setupLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.appDidEnterBackground()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.appWillEnterForeground()
            }
            .store(in: &cancellables)
    }

    private func observeRoomState() {
        multipeerService?.$isInRoom
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isInRoom in
                self?.roomStateDidChange(isInRoom: isInRoom)
            }
            .store(in: &cancellables)
    }

    private func appDidEnterBackground() {
        isInBackground = true
        updateKeepAliveState()
    }

    private func appWillEnterForeground() {
        isInBackground = false
        stopSilentAudio()
    }

    private func roomStateDidChange(isInRoom: Bool) {
        shouldKeepAlive = isInRoom
        if !isInRoom {
            stopSilentAudio()
        } else if isInBackground {
            startSilentAudio()
        }
    }

    private func updateKeepAliveState() {
        if shouldKeepAlive && isInBackground {
            startSilentAudio()
        } else {
            stopSilentAudio()
        }
    }

    private func startSilentAudio() {
        guard shouldKeepAlive, isInBackground else { return }
        guard silentPlayer == nil else { return }

        guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
            print("⚠️ [BackgroundKeepAlive] silence.wav not found in bundle")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])

            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            player.play()

            if player.play() {
                silentPlayer = player
                print("✅ [BackgroundKeepAlive] Silent audio started (room active, app backgrounded)")
            } else {
                print("⚠️ [BackgroundKeepAlive] Failed to start silent playback")
            }
        } catch {
            print("⚠️ [BackgroundKeepAlive] Failed to activate audio session: \(error.localizedDescription)")
        }
    }

    private func stopSilentAudio() {
        guard let player = silentPlayer else { return }

        player.stop()
        silentPlayer = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            print("⚠️ [BackgroundKeepAlive] Failed to restore video playback session: \(error.localizedDescription)")
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("⚠️ [BackgroundKeepAlive] Failed to deactivate audio session: \(error.localizedDescription)")
            }
        }

        print("✅ [BackgroundKeepAlive] Silent audio stopped, session restored for video")
    }
}
