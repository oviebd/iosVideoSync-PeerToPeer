//
//  VideoListItemView.swift
//  PeerToPeerConnectionTest
//
//  Created by Antigravity on 2026-02-28.
//

internal import SwiftUI

struct VideoListItemView: View {
    let video: VideoItem
    let isSelectionMode: Bool
    let isSelected: Bool
    let onEdit: () -> Void
    let onLongPress: () -> Void
    let onToggleSelection: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textDim)
                    .font(.system(size: 20))
                    .onTapGesture {
                        onToggleSelection()
                    }
            }
            
            Image(systemName: "play.circle.fill")
                .foregroundColor(AppTheme.accent)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.name)
                    .foregroundColor(AppTheme.text)
                    .font(.system(size: 16, weight: .medium))
                
                // You could add meta info here if available, e.g., duration or size
            }
            
            Spacer()
            
            if !isSelectionMode {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(AppTheme.textDim)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isSelected && isSelectionMode ? AppTheme.accentDim.opacity(0.1) : AppTheme.surface)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection()
            } else {
                // Normal tap action (e.g., play video)
                debugPrint("Tap video: \(video.name)")
            }
        }
        .onLongPressGesture {
            if !isSelectionMode {
                onLongPress()
            }
        }
    }
}
