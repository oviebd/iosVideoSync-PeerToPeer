//
//  FullScreenControlsView.swift
//  PeerToPeerConnectionTest
//

import Combine
internal import SwiftUI

// MARK: - ClosePressHandler

private final class ClosePressHandler: ObservableObject {
    private let subject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?

    static let requiredPresses = 5
    static let debounceInterval: TimeInterval = 2

    @Published private(set) var count = 0
    @Published private(set) var lastPressTime: Date?

    var remainingSeconds: Double {
        guard let last = lastPressTime else { return 0 }
        return max(0, Self.debounceInterval - Date().timeIntervalSince(last))
    }

    var showCloseHint: Bool { count > 0 }

    init() {
        subject
            .debounce(for: .seconds(Self.debounceInterval), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.resetCount()
            }
            .store(in: &cancellables)
    }

    private func resetCount() {
        count = 0
        lastPressTime = nil
        timer?.invalidate()
        timer = nil
    }

    func press(onDismiss: @escaping () -> Void) {
        count += 1
        lastPressTime = Date()
        subject.send(())

        if count >= Self.requiredPresses {
            onDismiss()
            resetCount()
        } else if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                RunLoop.main.perform { self?.objectWillChange.send() }
            }
            RunLoop.main.add(timer!, forMode: .common)
        }
    }
}

// MARK: - FullScreenControlsView

struct FullScreenControlsView: View {
    @ObservedObject var viewModel: VideoPlayerVM
    let role: PlayerRole
    @ObservedObject var visibilityManager: ControlsVisibilityManager
    var onDismiss: () -> Void

    @StateObject private var closePressHandler = ClosePressHandler()

    var body: some View {
        Group {
            if visibilityManager.isVisible {
                controlsOverlay
                    .transition(.opacity)
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        visibilityManager.toggle()
                    }
            }
        }
        .onAppear {
            visibilityManager.scheduleHide()
        }
        .onChange(of: viewModel.isSeeking) { _, isSeeking in
            if role == .master, isSeeking { visibilityManager.keepVisible() }
        }
        .onChange(of: viewModel.isRemoteSeeking) { _, isRemoteSeeking in
            if role == .slave, isRemoteSeeking { visibilityManager.keepVisible() }
        }
        .onDisappear {
            visibilityManager.cancel()
        }
    }

    private var controlsOverlay: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { visibilityManager.toggle() }

            LinearGradient(
                colors: [.black.opacity(0.4), .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top strip - Title at top left
                topRow
                    .padding(.top, 40) // Space for notch/status bar in full screen

                Spacer()

                // Center row — playback controls (white)
                centerRow

                Spacer()

                // Bottom row — Seekbar and times (always shown; slave is read-only)
                bottomBar
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)

            // Close hint popup — shows remaining time, auto-dismisses when count resets
            if role == .master, closePressHandler.showCloseHint {
                closeHintPopup
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            // Select video hint — when play pressed with no video selected (50pt below center)
            if role == .master, viewModel.showSelectVideoHint {
                Text("Please select a video/playlist to play video.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: 50)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentVideoName ?? "No video selected")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if role == .slave {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.isRemoteSeeking ? AppColors.warning : AppColors.accent)
                            .frame(width: 6, height: 6)
                        Text(viewModel.isRemoteSeeking ? "Master seeking…" : "Synced with master")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            Spacer()
        }
    }

    private var centerRow: some View {
        HStack(spacing: 64) {
            if role == .master {
                Button(action: { viewModel.masterBackward(10) }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white)
                }

                Button(action: {
                    if viewModel.isPlaying {
                        viewModel.masterPause()
                    } else {
                        viewModel.masterPlay()
                    }
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.white)
                }

                Button(action: { viewModel.masterForward(10) }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            // Elapsed Time
            Text(formatTime(viewModel.currentTime))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 50, alignment: .leading)

            // Seekbar (read-only for slave, interactive for master)
            Group {
                if role == .master {
                    VideoSeekbar(
                        value: Binding(
                            get: { viewModel.currentTime },
                            set: { viewModel.masterSeek(to: $0) }
                        ),
                        range: 0...max(viewModel.duration, 1),
                        onEditingChanged: { isEditing in
                            viewModel.isSeeking = isEditing
                        }
                    )
                } else {
                    VideoSeekbar(
                        value: Binding(
                            get: { viewModel.currentTime },
                            set: { _ in }
                        ),
                        range: 0...max(viewModel.duration, 1)
                    )
                    .allowsHitTesting(false)
                }
            }

            // Total Time
            Text(formatTime(viewModel.duration))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 50, alignment: .trailing)

            // Close (Dismiss) Button — master only; requires 5 presses within 2 seconds (debounce resets count)
            if role == .master {
                Button(action: { closePressHandler.press(onDismiss: onDismiss) }) {
                    Image(systemName: "multiply")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                }
            }
        }
    }

    private var closeHintPopup: some View {
        let x = ClosePressHandler.requiredPresses - closePressHandler.count
        return Text("Press \(x) times within 2 seconds to close the full screen")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
