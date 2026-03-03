//
//  AppStyles.swift
//  PeerToPeerConnectionTest
//
//  Reusable ViewModifiers, button styles, and common text styles.
//

internal import SwiftUI

// MARK: - Button Styles

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app.bodySemibold)
            .foregroundColor(AppColors.Raw.background)
            .padding(AppPadding.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.Raw.accent)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.Raw.accent.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(AppRadius.lg)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app.bodySemibold)
            .foregroundColor(AppColors.Raw.text)
            .padding(AppPadding.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.Raw.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.Raw.border, lineWidth: 1)
            )
            .cornerRadius(AppRadius.lg)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct AppDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app.bodySemibold)
            .foregroundColor(AppColors.Raw.danger)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.Raw.danger.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.Raw.danger.opacity(0.3))
            )
            .cornerRadius(AppRadius.md)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

// MARK: - Card Style

struct AppCardStyle: ViewModifier {
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(AppPadding.lg)
            .background(isSelected ? AppColors.Raw.accentDim.opacity(0.1) : AppColors.Raw.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(isSelected ? AppColors.Raw.accent.opacity(0.3) : AppColors.Raw.border, lineWidth: 1)
            )
            .cornerRadius(AppRadius.lg)
    }
}

// MARK: - Text Styles (ViewModifiers)

struct AppTitleTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.app.title)
            .foregroundColor(AppColors.Raw.text)
    }
}

struct AppBodyTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.app.body)
            .foregroundColor(AppColors.Raw.text)
    }
}

struct AppCaptionTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.app.caption)
            .foregroundColor(AppColors.Raw.textSecondary)
    }
}

struct AppAccentTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.app.bodySemibold)
            .foregroundColor(AppColors.Raw.accent)
    }
}

// MARK: - View Extensions for Styles

extension View {

    func appCardStyle(isSelected: Bool = false) -> some View {
        modifier(AppCardStyle(isSelected: isSelected))
    }

    func appTitleStyle() -> some View {
        modifier(AppTitleTextStyle())
    }

    func appBodyStyle() -> some View {
        modifier(AppBodyTextStyle())
    }

    func appCaptionStyle() -> some View {
        modifier(AppCaptionTextStyle())
    }

    func appAccentStyle() -> some View {
        modifier(AppAccentTextStyle())
    }
}
