//
//  FullScreenControlsView.swift
//  PeerToPeerConnectionTest
//

internal import SwiftUI

// MARK: - FullScreenControlsView

struct FullScreenControlsView: View {
    @ObservedObject var viewModel: VideoPlayerVM
    let role: PlayerRole
    @ObservedObject var visibilityManager: ControlsVisibilityManager
    var onDismiss: () -> Void

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
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { visibilityManager.toggle() }

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(spacing: 12) {
                Spacer(minLength: 0)

                // Top row
                topRow

                // Center row
                centerRow

                // Bottom bar
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

    private var topRow: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }

            Spacer()

            Text(viewModel.currentVideoName ?? "No video selected")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var centerRow: some View {
        Group {
            if role == .master {
                HStack(spacing: 24) {
                    Button(action: { viewModel.masterBackward(10) }) {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.accent)
                    }

                    Button(action: {
                        if viewModel.isPlaying {
                            viewModel.masterPause()
                        } else {
                            viewModel.masterPlay()
                        }
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(AppTheme.accent)
                    }

                    Button(action: { viewModel.masterForward(10) }) {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.accent)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isRemoteSeeking ? "hourglass" : "lock.fill")
                        .font(.system(size: 14))
                    Text(viewModel.isRemoteSeeking ? "Master seeking…" : "Synced with master")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(viewModel.isRemoteSeeking ? AppTheme.warning : AppTheme.accent)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if role == .master {
                Slider(
                    value: Binding(
                        get: { viewModel.currentTime },
                        set: { viewModel.masterSeek(to: $0) }
                    ),
                    in: 0...max(viewModel.duration, 1)
                )
                .tint(AppTheme.accent)

                HStack {
                    Text(formatTime(viewModel.currentTime))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text(formatTime(viewModel.duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isReady ? AppTheme.accent : AppTheme.warning)
                        .frame(width: 5, height: 5)
                    Text(viewModel.isReady ? "READY" : "LOAD")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(.white)

                HStack(spacing: 4) {
                    Circle()
                        .fill(role == .master ? AppTheme.accent : AppTheme.warning)
                        .frame(width: 5, height: 5)
                    Text(role == .master ? "MASTER" : "SLAVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(.white)

                Spacer()
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
