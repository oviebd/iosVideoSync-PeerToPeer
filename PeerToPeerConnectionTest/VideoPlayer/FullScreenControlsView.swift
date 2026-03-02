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

                // Bottom row — Unified Seekbar, times, same line
                if role == .master {
                    bottomBar
                        .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 24)
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
                            .fill(viewModel.isRemoteSeeking ? AppTheme.warning : AppTheme.accent)
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
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 50, alignment: .trailing)

            // Close (Dismiss) Button at bottom right
            Button(action: onDismiss) {
                Image(systemName: "multiply")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
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
