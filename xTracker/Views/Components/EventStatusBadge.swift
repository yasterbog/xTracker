//
//  EventStatusBadge.swift
//  xTracker
//

import SwiftUI

enum EventStatusBadgeStyle {
    case regular
    case compact
}

struct EventStatusBadge: View {
    let status: EventStatus
    var style: EventStatusBadgeStyle = .regular

    private var title: String? {
        switch status {
        case .planned: "В ожидании"
        case .confirmed: "Принято"
        case .declined, .completed: nil
        }
    }

    private var accentColor: Color? {
        switch status {
        case .planned: EventStatusPalette.waiting
        case .confirmed: EventStatusPalette.accepted
        case .declined, .completed: nil
        }
    }

    var body: some View {
        if let title, let accentColor {
            Text(title)
                .font(style == .compact ? AppFont.font(size: 11, weight: .semibold) : AppTheme.captionFont)
                .foregroundStyle(accentColor)
                .padding(.horizontal, style == .compact ? 8 : 12)
                .padding(.vertical, style == .compact ? 4 : 8)
                .background(accentColor.opacity(0.15), in: Capsule())
        }
    }
}

enum EventStatusPalette {
    static let waiting = Color(hex: "#FDC86C")
    static let accepted = Color(hex: "#74F09A")
}

extension Event {
    var showsFutureStatusBadge: Bool {
        guard AppFeatures.eventPlannerEnabled else { return false }
        return (status == .planned || status == .confirmed) && date >= Date()
    }
}
