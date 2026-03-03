//
//  AppColors.swift
//  PeerToPeerConnectionTest
//
//  Centralized color definitions with light/dark mode support.
//  Use AppColors or AppColors.Raw for semantic colors.
//

internal import SwiftUI

// MARK: - App Color Palette

enum AppColors {

    // MARK: Semantic Colors
    // Resolve to Raw for dark theme. Extend with @Environment(\.colorScheme) for light/dark variants.

    static var background: Color { Raw.background }
    static var surface: Color { Raw.surface }
    static var border: Color { Raw.border }
    static var text: Color { Raw.text }
    static var textSecondary: Color { Raw.textSecondary }
    static var accent: Color { Raw.accent }
    static var accentDim: Color { Raw.accentDim }
    static var danger: Color { Raw.danger }
    static var warning: Color { Raw.warning }

    // MARK: Raw Palette (fixed hex values)

    enum Raw {
        static let background = Color(hex: "#0A0C10")
        static let surface = Color(hex: "#141720")
        static let border = Color(hex: "#252A35")
        static let accent = Color(hex: "#4FFFB0")
        static let accentDim = Color(hex: "#1A5C3E")
        static let text = Color(hex: "#E8EAF0")
        static let textSecondary = Color(hex: "#5A6070")
        static let danger = Color(hex: "#FF4D6A")
        static let warning = Color(hex: "#FFB547")
    }
}

// MARK: - Color Extension

extension Color {

    static var app: AppColors.Type { AppColors.self }

    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)
        let r = Double((hexNumber & 0xff0000) >> 16) / 255
        let g = Double((hexNumber & 0x00ff00) >> 8) / 255
        let b = Double(hexNumber & 0x0000ff) / 255
        self.init(red: r, green: g, blue: b)
    }
}
