//
//  VideoListItemView.swift
//  PeerToPeerConnectionTest
//
//  Sample view demonstrating Core design system usage:
//  AppColors, AppFonts, AppSpacing, AppText, AppStyles.
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
        HStack(spacing: AppSpacing.md) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
                    .font(.app.iconMedium)
                    .onTapGesture { onToggleSelection() }
            }

            Image(systemName: "play.circle.fill")
                .foregroundColor(AppColors.accent)
                .font(.app.iconLarge)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(video.name)
                    .font(.app.bodyLargeMedium)
                    .foregroundColor(AppColors.text)
            }

            Spacer()

            if !isSelectionMode {
                Button(action: onEdit) {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(AppColors.textSecondary)
                        .padding(AppSpacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.md)
        .appCardStyle(isSelected: isSelected && isSelectionMode)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection()
            } else {
                debugPrint("Tap video: \(video.name)")
            }
        }
        .onLongPressGesture {
            if !isSelectionMode { onLongPress() }
        }
    }
}
