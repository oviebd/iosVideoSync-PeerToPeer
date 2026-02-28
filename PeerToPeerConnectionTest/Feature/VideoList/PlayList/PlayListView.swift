//
//  PlayListView.swift
//  PeerToPeerConnectionTest
//
//  Created by Antigravity on 2026-02-28.
//

internal import SwiftUI

struct PlayListView: View {
    let playlists: [PlaylistModelData]
    let onSelect: (PlaylistModelData) -> Void
    let onDelete: (PlaylistModelData) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playlists")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.text)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(playlists) { playlist in
                        PlayListItem(
                            playlist: playlist,
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
