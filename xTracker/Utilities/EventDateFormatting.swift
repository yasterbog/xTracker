//
//  EventDateFormatting.swift
//  xTracker
//

import Foundation

enum EventDateFormatting {
    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    static func pillLabel(for date: Date, calendar: Calendar = .current) -> String {
        let dayMonth = dayMonthFormatter.string(from: date)
        if calendar.isDateInToday(date) {
            return "Сегодня, \(dayMonth)"
        }
        if calendar.isDateInYesterday(date) {
            return "Вчера, \(dayMonth)"
        }
        return fullDateFormatter.string(from: date)
    }
}
