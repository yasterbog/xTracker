//
//  TabBarTrackView.swift
//  xTracker
//

import SwiftUI

struct TabBarTrackView: View {
    var pillOffsetX: CGFloat
    var highlightedIndex: Int
    var pillStretch: PillStretchState

    private static let itemWidth: CGFloat = 72
    private static let itemHeight: CGFloat = 48
    private static let itemSpacing: CGFloat = 4
    private static let tabCount = 3

    private static let tabs: [(filled: String, outline: String)] = [
        ("icon_calendar", "icon_calendar_outline"),
        ("icon_stats", "icon_stats_outline"),
        ("icon_settings", "icon_settings_outline"),
    ]

    var body: some View {
        HStack(spacing: Self.itemSpacing) {
            ForEach(0..<Self.tabCount, id: \.self) { index in
                tabIcon(at: index, isActive: index == highlightedIndex)
            }
        }
        .background(alignment: .leading) {
            selectionPill
        }
    }

    private var selectionPill: some View {
        Capsule()
            .fill(Color.white.opacity(0.12))
            .frame(width: Self.itemWidth, height: Self.itemHeight)
            .scaleEffect(x: pillStretch.x, y: pillStretch.y, anchor: pillStretch.anchor)
            .offset(x: pillOffsetX)
            .animation(TabBarPillAnimation.move, value: pillOffsetX)
    }

    private func tabIcon(at index: Int, isActive: Bool) -> some View {
        ZStack {
            Image(Self.tabs[index].outline)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .opacity(isActive ? 0 : 1)

            Image(Self.tabs[index].filled)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .opacity(isActive ? 1 : 0)
        }
        .foregroundStyle(.white)
        .frame(width: 24, height: 24)
        .frame(width: Self.itemWidth, height: Self.itemHeight)
        .animation(TabBarPillAnimation.icon, value: isActive)
    }
}
