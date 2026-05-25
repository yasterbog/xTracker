//
//  MockEventData.swift
//  xTracker
//

import Foundation

enum MockEventData {
    static let allEvents: [Event] = buildEvents()

    private static func buildEvents() -> [Event] {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return []
        }

        func makeDate(day: Int, hour: Int, minute: Int = 0) -> Date {
            var components = calendar.dateComponents([.year, .month], from: monthStart)
            components.day = day
            components.hour = hour
            components.minute = minute
            return calendar.date(from: components) ?? now
        }

        return [
            Event(
                id: "mock-1",
                date: makeDate(day: 3, hour: 21, minute: 30),
                duration: 0,
                activities: [.sex, .cunnilingus],
                protection: true,
                finish: .inside,
                toys: [.vibrator],
                notes: "",
                createdBy: "user-1"
            ),
            Event(
                id: "mock-2",
                date: makeDate(day: 8, hour: 23, minute: 0),
                duration: 0,
                activities: [.blowjob],
                protection: false,
                finish: .inMouthSwallow,
                toys: [],
                notes: "",
                createdBy: "user-1"
            ),
            Event(
                id: "mock-3",
                date: makeDate(day: 12, hour: 20, minute: 15),
                duration: 0,
                activities: [.sex, .anal],
                protection: true,
                finish: .condom,
                toys: [.plugAnal],
                notes: "",
                createdBy: "user-2"
            ),
            Event(
                id: "mock-4",
                date: makeDate(day: 15, hour: 19, minute: 0),
                duration: 0,
                activities: [.handjob, .masturbation],
                protection: false,
                finish: .onBelly,
                toys: [],
                notes: "",
                createdBy: "user-1"
            ),
            Event(
                id: "mock-5",
                date: makeDate(day: 15, hour: 22, minute: 45),
                duration: 0,
                activities: [.sex],
                protection: true,
                finish: .inside,
                toys: [.handcuffs],
                notes: "",
                createdBy: "user-2"
            ),
            Event(
                id: "mock-6",
                date: makeDate(day: 20, hour: 21, minute: 10),
                duration: 0,
                activities: [.cunnilingus, .sex],
                protection: false,
                finish: .onFace,
                toys: [.blindfold],
                notes: "",
                createdBy: "user-1"
            ),
        ]
    }

    static func events(on date: Date, in allEvents: [Event] = allEvents) -> [Event] {
        let calendar = Calendar.current
        return allEvents
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    static func eventCount(on date: Date, in allEvents: [Event] = allEvents) -> Int {
        events(on: date, in: allEvents).count
    }
}
