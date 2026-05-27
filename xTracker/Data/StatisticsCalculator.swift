//
//  StatisticsCalculator.swift
//  xTracker
//

import Foundation

enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case allTime = "Всё время"
    case week = "Неделя"
    case month = "Месяц"
    case threeMonths = "3 месяца"
    case year = "Год"
    case custom = "Свой период"

    var id: String { rawValue }

    static var filterOrder: [StatisticsPeriod] {
        [.allTime, .week, .month, .threeMonths, .year, .custom]
    }
}

enum SegmentedStatisticsPeriod: String, CaseIterable, Identifiable {
    case allTime = "Всё время"
    case week = "Неделя"
    case month = "Месяц"

    var id: String { rawValue }

    var statisticsPeriod: StatisticsPeriod {
        switch self {
        case .allTime: .allTime
        case .week: .week
        case .month: .month
        }
    }

    init?(statisticsPeriod: StatisticsPeriod) {
        switch statisticsPeriod {
        case .allTime: self = .allTime
        case .week: self = .week
        case .month: self = .month
        case .threeMonths, .year, .custom: return nil
        }
    }
}

enum TimeOfDayPeriod: String, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: "Утро"
        case .afternoon: "День"
        case .evening: "Вечер"
        case .night: "Ночь"
        }
    }

    var emoji: String {
        switch self {
        case .morning: "🌅"
        case .afternoon: "☀️"
        case .evening: "🌆"
        case .night: "🌙"
        }
    }

    var hourRangeLabel: String {
        switch self {
        case .morning: "6–12"
        case .afternoon: "12–18"
        case .evening: "18–23"
        case .night: "23–6"
        }
    }

    func contains(hour: Int) -> Bool {
        switch self {
        case .morning: (6..<12).contains(hour)
        case .afternoon: (12..<18).contains(hour)
        case .evening: (18..<23).contains(hour)
        case .night: hour >= 23 || hour < 6
        }
    }
}

struct StatisticsCalculator {
    let events: [Event]
    let period: StatisticsPeriod
    let activityFilter: ActivityType?
    let customStartDate: Date?
    let customEndDate: Date?
    let referenceDate: Date
    let calendar: Calendar

    init(
        events: [Event],
        period: StatisticsPeriod,
        activityFilter: ActivityType? = nil,
        customStartDate: Date? = nil,
        customEndDate: Date? = nil,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.events = events
        self.period = period
        self.activityFilter = activityFilter
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
        self.referenceDate = referenceDate
        self.calendar = calendar
    }

    var periodEvents: [Event] {
        events
            .filter { event in
                if let start = periodStartDate, event.date < start {
                    return false
                }
                if let end = periodEndDate, event.date > end {
                    return false
                }
                return true
            }
            .sorted { $0.date < $1.date }
    }

    var displayEvents: [Event] {
        guard let activityFilter else { return periodEvents }
        return periodEvents.filter { $0.activities.contains(activityFilter) }
    }

    var totalEvents: Int { periodEvents.count }

    var daysSinceLastEvent: Int? {
        guard let last = periodEvents.last else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: last.date), to: calendar.startOfDay(for: referenceDate)).day
    }

    var maxGapDays: Int {
        let sorted = periodEvents.map(\.date)
        guard sorted.count >= 2 else { return 0 }

        var maxGap = 0
        for index in 1..<sorted.count {
            let dayGap = calendar.dateComponents([.day], from: calendar.startOfDay(for: sorted[index - 1]), to: calendar.startOfDay(for: sorted[index])).day ?? 0
            maxGap = max(maxGap, dayGap)
        }
        return maxGap
    }

    var femaleOrgasmCount: Int {
        periodEvents.filter(\.femaleOrgasm).count
    }

    var femaleOrgasmPercentage: Int {
        guard !periodEvents.isEmpty else { return 0 }
        return Int((Double(femaleOrgasmCount) / Double(periodEvents.count) * 100).rounded())
    }

    func activityCounts() -> [(activity: ActivityType, count: Int)] {
        ActivityType.allCases
            .map { activity in
                let count = periodEvents.filter { $0.activities.contains(activity) }.count
                return (activity, count)
            }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    func finishSlices() -> [(finish: FinishType, count: Int, fraction: Double)] {
        guard !periodEvents.isEmpty else { return [] }
        let grouped = Dictionary(grouping: periodEvents, by: \.finish)
        return FinishType.allCases.compactMap { finish in
            let count = grouped[finish]?.count ?? 0
            guard count > 0 else { return nil }
            return (finish, count, Double(count) / Double(periodEvents.count))
        }
        .sorted { $0.count > $1.count }
    }

    var eventsWithToysCount: Int {
        periodEvents.filter { !$0.toys.isEmpty }.count
    }

    func toyCounts() -> [(toy: ToyType, count: Int)] {
        ToyType.allCases
            .map { toy in
                let count = periodEvents.filter { $0.toys.contains(toy) }.count
                return (toy, count)
            }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    func timeOfDayCounts() -> [(period: TimeOfDayPeriod, count: Int)] {
        TimeOfDayPeriod.allCases.map { period in
            let count = periodEvents.filter { period.contains(hour: calendar.component(.hour, from: $0.date)) }.count
            return (period, count)
        }
    }

    func monthlyEventCounts(lastMonths: Int = 12) -> [(label: String, count: Int)] {
        var localeCalendar = calendar
        localeCalendar.locale = Locale(identifier: "ru_RU")

        let formatter = DateFormatter()
        formatter.locale = localeCalendar.locale
        formatter.dateFormat = "LLL"

        guard
            let currentMonthStart = localeCalendar.date(
                from: localeCalendar.dateComponents([.year, .month], from: referenceDate)
            )
        else {
            return []
        }

        return (0..<lastMonths).reversed().compactMap { monthOffset -> (label: String, count: Int)? in
            guard
                let monthStart = localeCalendar.date(byAdding: .month, value: -monthOffset, to: currentMonthStart),
                let nextMonth = localeCalendar.date(byAdding: .month, value: 1, to: monthStart),
                let monthEnd = localeCalendar.date(byAdding: .second, value: -1, to: nextMonth)
            else {
                return nil
            }

            let count = events.filter { $0.date >= monthStart && $0.date <= monthEnd }.count
            let rawLabel = formatter.string(from: monthStart)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .trimmingCharacters(in: .whitespaces)
            let label = rawLabel.prefix(1).uppercased() + rawLabel.dropFirst()
            return (label, count)
        }
    }

    private var periodStartDate: Date? {
        switch period {
        case .allTime:
            return nil
        case .week:
            let today = calendar.startOfDay(for: referenceDate)
            let weekday = calendar.component(.weekday, from: today)
            let daysFromMonday = (weekday + 5) % 7
            guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
                return nil
            }
            return calendar.startOfDay(for: monday)
        case .month:
            let today = calendar.startOfDay(for: referenceDate)
            let components = calendar.dateComponents([.year, .month], from: today)
            return calendar.date(from: components)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: referenceDate)
        case .year:
            return calendar.date(from: calendar.dateComponents([.year], from: referenceDate))
        case .custom:
            guard let customStartDate else { return nil }
            return calendar.startOfDay(for: customStartDate)
        }
    }

    private var periodEndDate: Date? {
        switch period {
        case .allTime:
            return nil
        case .custom:
            guard let customEndDate else { return endOfDay(referenceDate) }
            return endOfDay(customEndDate)
        default:
            return endOfDay(referenceDate)
        }
    }

    private func endOfDay(_ date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components) ?? date
    }
}
