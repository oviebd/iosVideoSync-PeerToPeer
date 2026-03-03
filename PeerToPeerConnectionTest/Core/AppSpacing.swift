//
//  AppSpacing.swift
//  PeerToPeerConnectionTest
//
//  Centralized spacing constants and padding presets.
//

internal import SwiftUI

// MARK: - Spacing Scale

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 28
}

// MARK: - Padding Presets

enum AppPadding {

    static let xs = EdgeInsets(top: AppSpacing.xs, leading: AppSpacing.xs, bottom: AppSpacing.xs, trailing: AppSpacing.xs)
    static let sm = EdgeInsets(top: AppSpacing.sm, leading: AppSpacing.sm, bottom: AppSpacing.sm, trailing: AppSpacing.sm)
    static let md = EdgeInsets(top: AppSpacing.md, leading: AppSpacing.md, bottom: AppSpacing.md, trailing: AppSpacing.md)
    static let lg = EdgeInsets(top: AppSpacing.lg, leading: AppSpacing.lg, bottom: AppSpacing.lg, trailing: AppSpacing.lg)
    static let xl = EdgeInsets(top: AppSpacing.xl, leading: AppSpacing.xl, bottom: AppSpacing.xl, trailing: AppSpacing.xl)

    static let horizontalSm = EdgeInsets(top: 0, leading: AppSpacing.sm, bottom: 0, trailing: AppSpacing.sm)
    static let horizontalMd = EdgeInsets(top: 0, leading: AppSpacing.md, bottom: 0, trailing: AppSpacing.md)
    static let horizontalLg = EdgeInsets(top: 0, leading: AppSpacing.lg, bottom: 0, trailing: AppSpacing.lg)
    static let horizontalXl = EdgeInsets(top: 0, leading: AppSpacing.xl, bottom: 0, trailing: AppSpacing.xl)
    static let horizontalXxl = EdgeInsets(top: 0, leading: AppSpacing.xxl, bottom: 0, trailing: AppSpacing.xxl)

    static let verticalSm = EdgeInsets(top: AppSpacing.sm, leading: 0, bottom: AppSpacing.sm, trailing: 0)
    static let verticalMd = EdgeInsets(top: AppSpacing.md, leading: 0, bottom: AppSpacing.md, trailing: 0)
    static let verticalLg = EdgeInsets(top: AppSpacing.lg, leading: 0, bottom: AppSpacing.lg, trailing: 0)
}

// MARK: - Corner Radius

enum AppRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
}

// MARK: - Layout

enum AppLayout {
    /// Top inset for content below status bar (status bar ~47pt + spacing)
    static let safeAreaTopContent: CGFloat = 60
    /// Bottom inset for tab bar / home indicator
    static let safeAreaBottomContent: CGFloat = 50
    /// Grid pattern opacity
    static let gridPatternOpacity: CGFloat = 0.06
    /// Grid pattern line spacing
    static let gridSpacing: CGFloat = 30
    /// Minimum tap target (HIG: 44pt)
    static let minTapTarget: CGFloat = 44
}
