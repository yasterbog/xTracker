//
//  AppTheme.swift
//  xTracker
//

import SwiftUI

enum AppTheme {
    static let background = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.gray.opacity(0.5)
    static let sectionHeaderText = Color.gray.opacity(0.6)
    static let cardBackground = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let separator = Color.white.opacity(0.06)
    static let accent = Color(red: 255 / 255, green: 59 / 255, blue: 111 / 255)
    static let eventDot = Color(red: 0.35, green: 0.55, blue: 1.0)
    static let mutedDay = Color.white.opacity(0.25)

    static let screenTitleFont = Font.system(size: 28, weight: .bold, design: .default)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .default)
    static let captionFont = Font.system(size: 13, weight: .regular, design: .default)
    static let statsNumberFont = Font.system(size: 36, weight: .bold, design: .default)
    static let sectionHeaderFont = Font.system(size: 11, weight: .semibold, design: .default)
    static let cardCornerRadius: CGFloat = 20
    static let compactCardCornerRadius: CGFloat = 16
    static let screenHorizontalPadding: CGFloat = 20
    static let cardPadding: CGFloat = 20
    static let cardSpacing: CGFloat = 12

    static func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(sectionHeaderFont)
            .tracking(1.5)
            .foregroundStyle(sectionHeaderText)
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch sanitized.count {
        case 8:
            red = Double((value & 0xFF00_0000) >> 24) / 255
            green = Double((value & 0x00FF_0000) >> 16) / 255
            blue = Double((value & 0x0000_FF00) >> 8) / 255
            alpha = Double(value & 0x0000_00FF) / 255
        default:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
