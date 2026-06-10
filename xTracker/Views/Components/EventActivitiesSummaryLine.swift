//
//  EventActivitiesSummaryLine.swift
//  xTracker
//

import SwiftUI
import UIKit

enum EventActivitiesSummaryStyle {
    static let overflowTextColor = Color(hex: "#B3B3B3")
    static let overflowFont = AppFont.font(size: 15, weight: .semibold)
    static let overflowUIFont = AppFont.uiFont(size: 15, weight: .semibold)
    static let emojiFont = AppFont.font(size: 15, weight: .semibold)
    static let emojiUIFont = AppFont.uiFont(size: 15, weight: .semibold)
    static let emojiSpacing: CGFloat = 4
}

enum EventActivitiesSummaryFormatting {
    struct Layout {
        let visibleCount: Int
        let remainingCount: Int
    }

    static func layout(for activities: [ActivityType], maxWidth: CGFloat) -> Layout {
        guard !activities.isEmpty else {
            return Layout(visibleCount: 0, remainingCount: 0)
        }

        guard maxWidth > 0 else {
            return Layout(visibleCount: activities.count, remainingCount: 0)
        }

        if rowWidth(activities: activities, visibleCount: activities.count, remainingCount: 0) <= maxWidth {
            return Layout(visibleCount: activities.count, remainingCount: 0)
        }

        for visibleCount in stride(from: activities.count - 1, through: 0, by: -1) {
            let remainingCount = activities.count - visibleCount
            if rowWidth(activities: activities, visibleCount: visibleCount, remainingCount: remainingCount) <= maxWidth {
                return Layout(visibleCount: visibleCount, remainingCount: remainingCount)
            }
        }

        return Layout(visibleCount: 0, remainingCount: activities.count)
    }

    private static func rowWidth(activities: [ActivityType], visibleCount: Int, remainingCount: Int) -> CGFloat {
        var width: CGFloat = 0

        for index in 0..<visibleCount {
            if index > 0 {
                width += EventActivitiesSummaryStyle.emojiSpacing
            }
            width += emojiWidth(activities[index].emoji)
        }

        if remainingCount > 0 {
            if visibleCount > 0 {
                width += EventActivitiesSummaryStyle.emojiSpacing
            }
            width += overflowWidth(for: remainingCount)
        }

        return width
    }

    private static func emojiWidth(_ emoji: String) -> CGFloat {
        ceil((emoji as NSString).size(withAttributes: [.font: EventActivitiesSummaryStyle.emojiUIFont]).width)
    }

    private static func overflowWidth(for count: Int) -> CGFloat {
        let text = "+\(count)"
        return ceil((text as NSString).size(withAttributes: [.font: EventActivitiesSummaryStyle.overflowUIFont]).width)
    }
}

private struct AvailableWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct EventActivitiesSummaryLine: View {
    let activities: [ActivityType]

    @State private var availableWidth: CGFloat = 0

    private var layout: EventActivitiesSummaryFormatting.Layout {
        EventActivitiesSummaryFormatting.layout(for: activities, maxWidth: availableWidth)
    }

    var body: some View {
        HStack(spacing: EventActivitiesSummaryStyle.emojiSpacing) {
            ForEach(Array(activities.prefix(layout.visibleCount))) { activity in
                Text(activity.emoji)
                    .font(EventActivitiesSummaryStyle.emojiFont)
            }

            if layout.remainingCount > 0 {
                Text("+\(layout.remainingCount)")
                    .font(EventActivitiesSummaryStyle.overflowFont)
                    .foregroundColor(EventActivitiesSummaryStyle.overflowTextColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: AvailableWidthPreferenceKey.self, value: geometry.size.width)
            }
        )
        .onPreferenceChange(AvailableWidthPreferenceKey.self) { width in
            if width > 0, abs(width - availableWidth) > 0.5 {
                availableWidth = width
            }
        }
    }
}
