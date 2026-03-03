//
//  AppFonts.swift
//  PeerToPeerConnectionTest
//
//  Centralized typography system with reusable font styles.
//

internal import SwiftUI

// MARK: - Font Sizes

enum AppFontSize {
    static let caption: CGFloat = 10
    static let small: CGFloat = 11
    static let body: CGFloat = 14
    static let bodyLarge: CGFloat = 16
    static let subtitle: CGFloat = 18
    static let title: CGFloat = 20
    static let titleLarge: CGFloat = 22
    static let display: CGFloat = 42
    static let iconSmall: CGFloat = 18
    static let iconMedium: CGFloat = 20
    static let iconLarge: CGFloat = 24
    static let iconXLarge: CGFloat = 32
}

// MARK: - Font Weights

enum AppFontWeight {
    static let regular = Font.Weight.regular
    static let medium = Font.Weight.medium
    static let semibold = Font.Weight.semibold
    static let bold = Font.Weight.bold
    static let black = Font.Weight.black
    static let thin = Font.Weight.thin
}

// MARK: - Font Styles

enum AppFonts {

    static var caption: Font {
        .system(size: AppFontSize.caption, weight: AppFontWeight.medium, design: .monospaced)
    }

    static var captionRegular: Font {
        .system(size: AppFontSize.caption, weight: AppFontWeight.regular)
    }

    static var small: Font {
        .system(size: AppFontSize.small, weight: AppFontWeight.medium)
    }

    static var smallSemibold: Font {
        .system(size: AppFontSize.small, weight: AppFontWeight.semibold, design: .monospaced)
    }

    static var body: Font {
        .system(size: AppFontSize.body, weight: AppFontWeight.regular)
    }

    static var bodyMedium: Font {
        .system(size: AppFontSize.body, weight: AppFontWeight.medium)
    }

    static var bodySemibold: Font {
        .system(size: AppFontSize.body, weight: AppFontWeight.semibold)
    }

    static var bodyLarge: Font {
        .system(size: AppFontSize.bodyLarge, weight: AppFontWeight.regular)
    }

    static var bodyLargeMedium: Font {
        .system(size: AppFontSize.bodyLarge, weight: AppFontWeight.medium)
    }

    static var subtitle: Font {
        .system(size: AppFontSize.subtitle, weight: AppFontWeight.semibold)
    }

    static var title: Font {
        .system(size: AppFontSize.title, weight: AppFontWeight.bold)
    }

    static var titleLarge: Font {
        .system(size: AppFontSize.titleLarge, weight: AppFontWeight.bold)
    }

    static var display: Font {
        .system(size: AppFontSize.display, weight: AppFontWeight.black)
    }

    static var label: Font {
        .system(size: AppFontSize.small, weight: AppFontWeight.medium, design: .monospaced)
    }

    static var labelSmall: Font {
        .system(size: AppFontSize.caption, weight: AppFontWeight.medium, design: .monospaced)
    }

    static var iconSmall: Font {
        .system(size: AppFontSize.iconSmall)
    }

    static var iconMedium: Font {
        .system(size: AppFontSize.iconMedium)
    }

    static var iconLarge: Font {
        .system(size: AppFontSize.iconLarge)
    }

    static var iconXLarge: Font {
        .system(size: AppFontSize.iconXLarge, weight: AppFontWeight.thin)
    }
}

// MARK: - Font Extension

extension Font {
    static var app: AppFonts.Type { AppFonts.self }
}
