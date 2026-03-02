//
//  VideoRoomView.swift
//  PeerToPeerConnectionTest
//

internal import AVFoundation
internal import SwiftUI

// MARK: - VideoRoomView

struct VideoRoomView: View {
    @EnvironmentObject var service: MultipeerService
    @ObservedObject var videoPlayer: VideoPlayerVM
    var activePlaylistName: String? = nil
    var onShowPlaylistQueue: (() -> Void)? = nil
    @State private var showLog: Bool = false

    var body: some View {
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

            if showLog {
                commandLogView
                    .frame(height: 180)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            VideoPlayerView(
                viewModel: videoPlayer,
                role: service.role == .master ? .master : .slave
            )
            .aspectRatio(16/9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.black)

            statusBar

            Spacer()
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            if let name = activePlaylistName, let onShow = onShowPlaylistQueue {
                Button(action: onShow) {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 12))
                        Text(name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentDim)
                    .cornerRadius(8)
                }
            } else {
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
            }

            Spacer()

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

    // MARK: - Command Log View

    private var commandLogView: some View {
        VStack(alignment: .leading, spacing: 0) {
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
}
