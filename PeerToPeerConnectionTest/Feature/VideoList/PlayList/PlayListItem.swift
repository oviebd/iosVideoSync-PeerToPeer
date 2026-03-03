//
//  PlayListItem.swift
//  PeerToPeerConnectionTest
//
//  Redesigned with Core design system.
//

internal import SwiftUI

struct PlayListItem: View {
    let playlist: PlaylistModelData
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(playlist.name)
                    .font(.app.bodyMedium)
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.text)
                    .lineLimit(1)

                Text(String(format: AppText.Playlist.videosCount, playlist.videoIds.count))
                    .font(.app.small)
                    .foregroundColor(isSelected ? AppColors.accent.opacity(0.7) : AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(isSelected ? AppColors.accentDim.opacity(0.2) : AppColors.surface)
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { showDeleteAlert = true } label: {
                Label(AppText.General.delete, systemImage: "trash")
            }
        }
        .alert(AppText.Alert.deletePlaylist, isPresented: $showDeleteAlert) {
            Button(AppText.General.delete, role: .destructive) { onDelete() }
            Button(AppText.General.cancel, role: .cancel) { }
        } message: {
            Text(String(format: AppText.Alert.deletePlaylistMessage, playlist.name))
        }
    }
}
