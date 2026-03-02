//
//  PlayerControlsOverlay.swift
//  PeerToPeerConnectionTest
//

internal import SwiftUI

// MARK: - PlayerControlsOverlay

struct PlayerControlsOverlay: View {
    @ObservedObject var viewModel: VideoPlayerVM
    let role: PlayerRole
    var onEnterFullScreen: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Gradient scrim so controls stay readable over bright video
            LinearGradient(
                colors: [.black.opacity(0.4), .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top strip - Title at top left
                topStrip
                    .padding(.top, 16)

                Spacer()

                // Center row — playback controls (white)
                centerRow

                Spacer()

                // Bottom row — Unified Seekbar, times, same line
                if role == .master {
                    bottomRow
                        .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Top Strip

    private var topStrip: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentVideoName ?? "No video selected")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if role == .slave {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.isRemoteSeeking ? AppTheme.warning : AppTheme.accent)
                            .frame(width: 6, height: 6)
                        Text(viewModel.isRemoteSeeking ? "Master seeking…" : "Synced with master")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Center Row

    private var centerRow: some View {
        HStack(spacing: 48) {
            if role == .master {
                Button(action: { viewModel.masterBackward(10) }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 28, weight: .light))
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
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                }

                Button(action: { viewModel.masterForward(10) }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Bottom Row

    private var bottomRow: some View {
        HStack(spacing: 12) {
            // Elapsed Time
            Text(formatTime(viewModel.currentTime))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 45, alignment: .leading)

            // Seekbar (Custom VideoSeekbar)
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

            // Total Time
            Text(formatTime(viewModel.duration))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 45, alignment: .trailing)

            // Full Screen Button at bottom right
            if let onEnterFullScreen = onEnterFullScreen {
                Button(action: onEnterFullScreen) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(8)
                }
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
