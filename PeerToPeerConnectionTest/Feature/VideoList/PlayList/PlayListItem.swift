//
//  PlayListItem.swift
//  PeerToPeerConnectionTest
//
//  Created by Antigravity on 2026-02-28.
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
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.text)
                    .lineLimit(1)
                
                Text("\(playlist.videoIds.count) videos")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? AppTheme.accent.opacity(0.7) : AppTheme.textDim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? AppTheme.accentDim.opacity(0.2) : AppTheme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.accent : AppTheme.border, lineWidth: 1)
            )
        }
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
