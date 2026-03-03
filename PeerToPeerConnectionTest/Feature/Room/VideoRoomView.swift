//
//  VideoRoomView.swift
//  PeerToPeerConnectionTest
//
//  Redesigned with Core design system.
//

internal import AVFoundation
internal import SwiftUI

struct VideoRoomView: View {
    @EnvironmentObject var service: MultipeerService
    @ObservedObject var videoPlayer: VideoPlayerVM
    var currentPlaylistInfo: PlaylistInfo? = nil
    var onShowPlaylistQueue: (() -> Void)? = nil
    @State private var showLog: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring()) { showLog.toggle() }
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: showLog ? "terminal.fill" : "terminal")
                        Text(showLog ? "Hide Log" : "Show Log")
                            .font(.app.smallSemibold)
                    }
                    .foregroundColor(showLog ? AppColors.accent : AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .stroke(showLog ? AppColors.accent.opacity(0.3) : AppColors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }

            if showLog {
                commandLogView
                    .frame(height: 180)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack(alignment: .center) {
                VideoPlayerView(
                    viewModel: videoPlayer,
                    role: service.role == .master ? .master : .slave
                )
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.black)

                // Slave waiting overlay when master disconnected (e.g. background/lock)
                if service.role == .slave && service.connectedPeers.isEmpty {
                    Color.black.opacity(0.7)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    VStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                            .scaleEffect(1.2)
                        Text(AppText.Room.waitingForMaster)
                            .font(.app.bodyMedium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            statusBar

            Spacer()
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    // MARK: Status Bar

    private var statusBar: some View {
        HStack(spacing: AppSpacing.md) {
            if let info = currentPlaylistInfo, let onShow = onShowPlaylistQueue {
                Button(action: onShow) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "music.note.list")
                            .font(.app.body)
                        Text(info.playlistName)
                            .font(.app.bodyMedium)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.down")
                            .font(.app.label)
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.accentDim)
                    .cornerRadius(AppRadius.md)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { service.leaveRoom() }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "chevron.left")
                            .font(.app.bodySemibold)
                        Text(AppText.General.leave)
                            .font(.app.bodyMedium)
                    }
                    .foregroundColor(AppColors.text)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.md)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if service.role == .master && videoPlayer.isSeeking {
                HStack(spacing: AppSpacing.xs) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        .scaleEffect(0.8)
                    Text("SEEKING")
                        .font(.app.labelSmall)
                        .tracking(1)
                }
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.accentDim)
                .cornerRadius(AppRadius.sm)
            }

            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(videoPlayer.isReady ? AppColors.accent : AppColors.warning)
                    .frame(width: 5, height: 5)
                Text(videoPlayer.isReady ? "READY" : "LOAD")
                    .font(.app.labelSmall)
                    .tracking(1)
            }
            .foregroundColor(AppColors.text)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.sm)

            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(service.role == .master ? AppColors.accent : AppColors.warning)
                    .frame(width: 5, height: 5)
                Text(service.role == .master ? AppText.Room.master : AppText.Room.slave)
                    .font(.app.labelSmall)
                    .tracking(1)
            }
            .foregroundColor(AppColors.text)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.sm)

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "person.2.fill")
                    .font(.app.labelSmall)
                Text("\(service.connectedPeers.count)")
                    .font(.app.smallSemibold)
            }
            .foregroundColor(AppColors.text)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.sm)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.background)
        .overlay(Rectangle().stroke(AppColors.border, lineWidth: 1), alignment: .bottom)
    }

    // MARK: Command Log

    private var commandLogView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("COMMAND LOG")
                    .font(.app.smallSemibold)
                    .foregroundColor(AppColors.accent)
                    .tracking(2)
                Spacer()
                Button(action: { service.commandLog.removeAll() }) {
                    Text("CLEAR")
                        .font(.app.labelSmall)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.surface)

            Divider().background(AppColors.border)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.xs) {
                        if service.commandLog.isEmpty {
                            Text("Waiting for commands...")
                                .font(.app.label)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(AppSpacing.sm)
                        } else {
                            ForEach(Array(service.commandLog.enumerated()), id: \.offset) { index, log in
                                Text(log)
                                    .font(.app.captionRegular)
                                    .foregroundColor(log.contains("❌") ? AppColors.danger :
                                                     log.contains("📤") ? AppColors.accent :
                                                     log.contains("📥") ? AppColors.warning :
                                                     AppColors.text)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, AppSpacing.xs)
                                    .id(index)
                            }
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
                .onChange(of: service.commandLog.count) { _, _ in
                    if let lastIndex = service.commandLog.indices.last {
                        withAnimation { proxy.scrollTo(lastIndex, anchor: .bottom) }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(AppColors.background)
        }
        .background(AppColors.background)
        .overlay(Rectangle().stroke(AppColors.border, lineWidth: 1))
    }
}
