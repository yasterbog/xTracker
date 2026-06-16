//
//  EventStatus.swift
//  xTracker
//

import Foundation

enum EventStatus: String, Codable, CaseIterable {
    case planned
    case confirmed
    case declined
    case completed
}

extension Event {
    /// Whether the event should appear on the calendar grid and day list.
    var isVisibleOnCalendar: Bool {
        guard AppFeatures.eventPlannerEnabled else {
            return status == .completed
        }

        switch status {
        case .declined:
            return false
        case .planned:
            return date >= Date()
        case .confirmed, .completed:
            return true
        }
    }
}
