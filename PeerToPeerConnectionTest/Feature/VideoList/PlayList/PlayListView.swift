//
//  PlayListView.swift
//  PeerToPeerConnectionTest
//
//  Redesigned with Core design system.
//

internal import SwiftUI

struct PlayListView: View {
    let playlists: [PlaylistModelData]
    let selectedPlaylistId: String?
    let onSelect: (PlaylistModelData?) -> Void
    let onDelete: (PlaylistModelData) -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    Button(action: onCreate) {
                        Image(systemName: "plus")
                            .font(.app.title)
                            .foregroundColor(AppColors.accent)
                            .frame(width: 44, height: 44)
                            .background(AppColors.surface)
                            .cornerRadius(AppRadius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.lg)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: { onSelect(nil) }) {
                        Text("All")
                            .font(.app.bodyMedium)
                            .foregroundColor(selectedPlaylistId == nil ? AppColors.accent : AppColors.text)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(selectedPlaylistId == nil ? AppColors.accentDim.opacity(0.2) : AppColors.surface)
                            .cornerRadius(AppRadius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.lg)
                                    .stroke(selectedPlaylistId == nil ? AppColors.accent : AppColors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    ForEach(playlists) { playlist in
                        PlayListItem(
                            playlist: playlist,
                            isSelected: selectedPlaylistId == playlist.id,
                            onSelect: { onSelect(playlist) },
                            onDelete: { onDelete(playlist) }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
        .padding(.vertical, AppSpacing.sm)
    }
}
