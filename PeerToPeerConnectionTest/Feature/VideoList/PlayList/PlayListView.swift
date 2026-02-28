//
//  PlayListView.swift
//  PeerToPeerConnectionTest
//
//  Created by Antigravity on 2026-02-28.
//

internal import SwiftUI

struct PlayListView: View {
    let playlists: [PlaylistModelData]
    let selectedPlaylistId: String?
    let onSelect: (PlaylistModelData?) -> Void
    let onDelete: (PlaylistModelData) -> Void
    let onCreate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Create Playlist Button
                    Button(action: onCreate) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                    }
                    
                    // "All" Playlist Item
                    Button(action: { onSelect(nil) }) {
                        Text("All")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedPlaylistId == nil ? AppTheme.accent : AppTheme.text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(selectedPlaylistId == nil ? AppTheme.accentDim.opacity(0.2) : AppTheme.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedPlaylistId == nil ? AppTheme.accent : AppTheme.border, lineWidth: 1)
                            )
                    }
                    
                    ForEach(playlists) { playlist in
                        PlayListItem(
                            playlist: playlist,
                            isSelected: selectedPlaylistId == playlist.id,
                            onSelect: {
                                onSelect(playlist)
                            },
                            onDelete: {
                                onDelete(playlist)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }
}
