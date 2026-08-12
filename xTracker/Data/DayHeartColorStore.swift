//
//  DayHeartColorStore.swift
//  xTracker
//

import SwiftUI

enum DayHeartColorStore {
    static let palette: [Color] = [
        AppTheme.accent,
        Color(hex: "#5BB1FC"),
        Color(hex: "#74F09A"),
        Color(hex: "#FDC86C"),
        Color(hex: "#FF8A38"),
        Color(hex: "#8B5CFF"),
        Color(hex: "#FF5E87"),
        Color(hex: "#F2E24C"),
        Color(hex: "#5C7CFF"),
    ]

    static func color(at index: Int) -> Color {
        guard !palette.isEmpty else { return AppTheme.accent }
        if index < palette.count {
            return palette[index]
        }
        return AppTheme.appWhite
    }
}
