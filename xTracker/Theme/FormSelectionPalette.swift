//
//  FormSelectionPalette.swift
//  xTracker
//

import SwiftUI

enum FormSelectionPalette {
    static var colors: [Color] { DayHeartColorStore.palette }

    static let toyColors: [Color] = colors + [
        Color(hex: "#29F0D0"),
        Color(hex: "#C85DFF"),
    ]

    static func color(for activity: ActivityType) -> Color {
        color(in: colors, at: ActivityType.allCases.firstIndex(of: activity) ?? 0)
    }

    static func color(for toy: ToyType) -> Color {
        color(in: toyColors, at: ToyType.allCases.firstIndex(of: toy) ?? 0)
    }

    static func selectedBackground(_ color: Color) -> Color {
        color.opacity(0.12)
    }

    static let selectedBorderWidth: CGFloat = 2

    static func selectedBorder(_ color: Color) -> Color {
        color.opacity(0.65)
    }

    private static func color(in palette: [Color], at index: Int) -> Color {
        guard !palette.isEmpty else { return AppTheme.accent }
        return palette[index % palette.count]
    }
}
