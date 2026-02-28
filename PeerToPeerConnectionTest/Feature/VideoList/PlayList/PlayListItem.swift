//
//  PlayListItem.swift
//  PeerToPeerConnectionTest
//
//  Created by Antigravity on 2026-02-28.
//

internal import SwiftUI

struct PlayListItem: View {
    let playlist: PlaylistModelData
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.accentDim.opacity(0.3))
                    
                    Image(systemName: "folder.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.accent)
                }
                .frame(width: 60, height: 60)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.text)
                        .lineLimit(1)
                    
                    Text("\(playlist.videoIds.count) videos")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textDim)
                }
            }
            .padding(12)
            .background(AppTheme.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .frame(width: 120)
        .contextMenu {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Playlist", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(playlist.name)'? This action cannot be undone.")
        }
    }
}
