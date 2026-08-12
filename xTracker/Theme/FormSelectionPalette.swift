//
//  FormSelectionPalette.swift
//  xTracker
//

import SwiftUI

enum FormSelectionPalette {
    static var colors: [Color] { DayHeartColorStore.palette }

    static let toyColors: [Color] = colors

    static func color(at index: Int) -> Color {
        DayHeartColorStore.color(at: index)
    }

    static func color(forActivityID activityID: String, catalog: ActivityCatalogStore) -> Color {
        color(at: catalog.colorIndex(for: activityID))
    }

    static func color(for toy: ToyType) -> Color {
        color(at: ToyType.allCases.firstIndex(of: toy) ?? 0)
    }

    static func selectedBackground(_ color: Color) -> Color {
        color.opacity(0.12)
    }

    static let selectedBorderWidth: CGFloat = 1

    static func selectedBorder(_ color: Color) -> Color {
        color.opacity(0.65)
    }
}
