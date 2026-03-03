//
//  AppComponents.swift
//  PeerToPeerConnectionTest
//
//  Reusable UI components for consistent layout and empty/loading states.
//

internal import SwiftUI

// MARK: - Action Card (Home buttons, etc.)

struct ActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let accentBorder: Bool
    let action: () -> Void

    init(
        icon: String,
        iconColor: Color = AppColors.accent,
        title: String,
        subtitle: String,
        accentBorder: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.accentBorder = accentBorder
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(accentBorder ? AppColors.accentDim : AppColors.surface)
                        .frame(width: AppLayout.minTapTarget, height: AppLayout.minTapTarget)
                    Image(systemName: icon)
                        .font(.app.iconMedium)
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(.app.bodySemibold)
                        .foregroundColor(AppColors.text)
                    Text(subtitle)
                        .font(.app.body)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.app.small)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(AppPadding.lg)
            .background(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(accentBorder ? AppColors.accent.opacity(0.3) : AppColors.border, lineWidth: 1)
            )
            .cornerRadius(AppRadius.lg)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let message: String
    var iconFont: Font = .app.iconLarge

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(iconFont)
                .foregroundColor(AppColors.textSecondary)
            Text(message)
                .font(.app.bodyLarge)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xxl)
    }
}

// MARK: - Status Badge (role, connected count)

struct StatusBadge: View {
    let text: String
    let isAccent: Bool

    init(_ text: String, isAccent: Bool = true) {
        self.text = text
        self.isAccent = isAccent
    }

    var body: some View {
        Text(text)
            .font(.app.labelSmall)
            .tracking(2)
            .foregroundColor(isAccent ? AppColors.background : AppColors.warning)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(isAccent ? AppColors.accent : AppColors.warning.opacity(0.15))
            .overlay(
                Capsule().stroke(isAccent ? Color.clear : AppColors.warning.opacity(0.4))
            )
            .clipShape(Capsule())
    }
}
