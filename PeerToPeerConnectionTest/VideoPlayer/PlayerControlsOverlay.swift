//
//  PlayerControlsOverlay.swift
//  PeerToPeerConnectionTest
//

internal import SwiftUI

// MARK: - PlayerControlsOverlay

struct PlayerControlsOverlay: View {
    @ObservedObject var viewModel: VideoPlayerVM
    let role: PlayerRole
    var onSelectVideo: (() -> Void)? = nil
    var onEnterFullScreen: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // Gradient scrim so controls stay readable over bright video
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                Spacer(minLength: 0)

                // Top strip
                topStrip

                // Center row — playback (master) or sync status (slave)
                centerRow

                // Progress / scrubber row (master only)
                if role == .master {
                    progressRow
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Top Strip

    private var topStrip: some View {
        HStack {
            Text(viewModel.currentVideoName ?? "No video selected")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            HStack(spacing: 8) {
                if role == .master, let onSelectVideo = onSelectVideo {
                    Button(action: onSelectVideo) {
                        Text("Select Video")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.accentDim.opacity(0.5))
                            .cornerRadius(6)
                    }
                }

                if let onEnterFullScreen = onEnterFullScreen {
                    Button(action: onEnterFullScreen) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    // MARK: - Center Row

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
                            .font(.system(size: 56))
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

    // MARK: - Progress Row

    private var progressRow: some View {
        VStack(spacing: 6) {
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
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
