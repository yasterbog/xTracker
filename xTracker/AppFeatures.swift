//
//  AppFeatures.swift
//  xTracker
//

import Foundation

/// Feature flags — flip a switch here to re-enable disabled functionality.
enum AppFeatures {
    // MARK: - Event planner
    //
    // When `false`, disables:
    // - Future day selection on calendar grid
    // - Future date/time in AddEventView pickers (maximumDate: today)
    // - Notifications bell + NotificationsView
    // - Partner accept/decline push flow (NotificationService)
    // - Planned/confirmed calendar hearts and status badges
    // - EventDetail "В ожидании" / "Принято" banners and "Состоялось" button
    //
    // Data model (`EventStatus`, Firestore `status` field) stays intact for easy restore.
    static let eventPlannerEnabled = false
}
