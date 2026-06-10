//
//  DayHeartColorStore.swift
//  xTracker
//

import Combine
import Foundation
import SwiftUI

/// Persists calendar heart colors per day. Assigned when the first event is added to a day.
@MainActor
final class DayHeartColorStore: ObservableObject {
    static let palette: [Color] = [
        AppTheme.accent,
        Color(hex: "#5EF7A0"),
        Color(hex: "#FFD33D"),
        Color(hex: "#FF8A38"),
        Color(hex: "#8B5CFF"),
        Color(hex: "#38D8FF"),
    ]

    @Published private var indicesByDayKey: [String: [Int]] = [:]

    private let defaults: UserDefaults
    private let storageKey = "calendar.dayHeartColorIndices"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.dictionary(forKey: storageKey) as? [String: [Int]] {
            indicesByDayKey = saved
        }
    }

    func colors(for day: Date, calendar: Calendar = .current) -> [Color] {
        guard let indices = indicesByDayKey[dayKey(for: day, calendar: calendar)] else { return [] }
        return indices.compactMap { index in
            guard Self.palette.indices.contains(index) else { return nil }
            return Self.palette[index]
        }
    }

    func syncDay(_ day: Date, eventCount: Int, calendar: Calendar = .current) {
        let normalizedDay = calendar.startOfDay(for: day)
        let key = dayKey(for: normalizedDay, calendar: calendar)
        let needed = Self.heartCount(for: eventCount)

        if needed == 0 {
            guard indicesByDayKey[key] != nil else { return }
            indicesByDayKey.removeValue(forKey: key)
            persist()
            return
        }

        var indices = indicesByDayKey[key] ?? []

        if indices.count > needed {
            indicesByDayKey[key] = Array(indices.prefix(needed))
            persist()
            return
        }

        if indices.count == needed {
            return
        }

        while indices.count < needed {
            let neighborIndices = neighborColorIndices(for: normalizedDay, calendar: calendar)
            let excluded = Set(neighborIndices + indices)
            let allIndices = Array(Self.palette.indices)
            let available = allIndices.filter { !excluded.contains($0) }
            let pool = available.isEmpty ? allIndices : available
            guard let picked = pool.randomElement() else { break }
            indices.append(picked)
        }

        indicesByDayKey[key] = indices
        persist()
    }

    func clearAll() {
        guard !indicesByDayKey.isEmpty else { return }
        indicesByDayKey.removeAll()
        persist()
    }

    func reconcile(with events: [Event], calendar: Calendar = .current) {
        let eventsByDay = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
        let activeKeys = Set(eventsByDay.keys.map { dayKey(for: $0, calendar: calendar) })

        for key in indicesByDayKey.keys where !activeKeys.contains(key) {
            indicesByDayKey.removeValue(forKey: key)
        }

        for day in eventsByDay.keys.sorted() {
            syncDay(day, eventCount: eventsByDay[day]?.count ?? 0, calendar: calendar)
        }

        persist()
    }

    private func neighborColorIndices(for day: Date, calendar: Calendar) -> [Int] {
        let offsets = [-1, 1, -7, 7]
        return offsets.compactMap { offset -> [Int]? in
            guard let neighbor = calendar.date(byAdding: .day, value: offset, to: day) else { return nil }
            return indicesByDayKey[dayKey(for: neighbor, calendar: calendar)]
        }
        .flatMap { $0 }
    }

    private func persist() {
        defaults.set(indicesByDayKey, forKey: storageKey)
    }

    private func dayKey(for day: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let dayValue = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, dayValue)
    }

    /// One shared color per day, regardless of how many events occurred.
    private static func heartCount(for eventCount: Int) -> Int {
        eventCount > 0 ? 1 : 0
    }
}
