//
//  StatisticsView.swift
//  xTracker
//

import SwiftUI
import UIKit

struct StatisticsView: View {
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var userService: UserService
    @EnvironmentObject private var activityCatalog: ActivityCatalogStore
    @State private var segmentedPeriod: SegmentedStatisticsPeriod = .allTime
    @State private var selectedPeriod: StatisticsPeriod = .allTime
    @State private var customPeriodActive = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showPeriodOptionsSheet = false
    @State private var showFemaleOrgasmActivitiesSheet = false
    @State private var femaleOrgasmActivityFilter: Set<String> = SettingsStore.femaleOrgasmActivityFilter
    private static let statsCardsSpacing: CGFloat = StatsLayout.cardsSpacing

    private var resolvedFemaleOrgasmActivityFilter: Set<String> {
        let stored = femaleOrgasmActivityFilter
        if stored.isEmpty {
            return activityCatalog.selectableActivityIDs
        }
        return stored
    }

    private var completedEvents: [Event] {
        store.events.filter { $0.status == .completed }
    }

    private var calculator: StatisticsCalculator {
        StatisticsCalculator(
            events: completedEvents,
            period: customPeriodActive ? .custom : selectedPeriod,
            femaleOrgasmActivityFilter: resolvedFemaleOrgasmActivityFilter,
            customStartDate: customPeriodActive ? customStartDate : nil,
            customEndDate: customPeriodActive ? customEndDate : nil
        )
    }

    private var hasEventsInSelectedPeriod: Bool {
        !calculator.periodEvents.isEmpty
    }

    private var chartDataPoints: [(label: String, count: Int)] {
        let period = customPeriodActive ? StatisticsPeriod.custom : selectedPeriod
        switch period {
        case .allTime:
            return allTimeMonthlyChartData
        case .week:
            return weekDailyChartData
        case .month:
            return monthWeeklyChartData
        case .custom:
            return customPeriodChartData
        case .threeMonths, .year:
            return filteredMonthlyChartData
        }
    }

    private var chartPointDates: [Date]? {
        let calendar = Calendar.current
        let period = customPeriodActive ? StatisticsPeriod.custom : selectedPeriod

        switch period {
        case .allTime:
            return allTimeMonthlyChartDates(calendar: calendar)
        case .threeMonths, .year:
            return filteredMonthlyChartDates(calendar: calendar)
        case .custom:
            guard let startDay = calculator.periodStartDay,
                  let endDay = calculator.periodEndDay,
                  let daySpan = calculator.periodDaySpan,
                  daySpan > 45 else {
                return nil
            }
            return chartMonthsInRangeDates(from: startDay, through: endDay, calendar: calendar)
        case .week, .month:
            return nil
        }
    }

    private func allTimeMonthlyChartDates(calendar: Calendar) -> [Date] {
        let eventsByMonth = Dictionary(grouping: completedEvents) { event in
            calendar.date(from: calendar.dateComponents([.year, .month], from: event.date))
                ?? calendar.startOfDay(for: event.date)
        }
        return eventsByMonth.keys.sorted()
    }

    private func filteredMonthlyChartDates(calendar: Calendar) -> [Date] {
        let filtered = calculator.periodEvents
        let eventsByMonth = Dictionary(grouping: filtered) { event in
            calendar.date(from: calendar.dateComponents([.year, .month], from: event.date))
                ?? calendar.startOfDay(for: event.date)
        }
        return eventsByMonth.keys.sorted()
    }

    private func chartMonthsInRangeDates(
        from startDay: Date,
        through endDay: Date,
        calendar: Calendar
    ) -> [Date] {
        guard var monthCursor = calendar.date(from: calendar.dateComponents([.year, .month], from: startDay)) else {
            return []
        }

        var dates: [Date] = []

        while monthCursor <= endDay {
            dates.append(monthCursor)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor) else { break }
            monthCursor = nextMonth
        }

        return dates
    }

    private var chartDisplayPoints: [ChartDisplayPoint] {
        chartDataPoints.map { point in
            ChartDisplayPoint(label: point.label, count: point.count, isPlaceholder: false)
        }
    }

    private var monthlyChartSection: some View {
        MonthlyEventsLineChart(dataPoints: chartDisplayPoints)
            .animation(nil, value: chartDataSignature)
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.top, 20)
            .padding(.bottom, 24)
    }

    private var chartDataSignature: String {
        chartDataPoints.map { "\($0.label):\($0.count)" }.joined(separator: "|")
    }

    private var allTimeMonthlyChartData: [(label: String, count: Int)] {
        let calendar = Calendar.current
        let eventsByMonth = Dictionary(grouping: completedEvents) { event in
            calendar.date(from: calendar.dateComponents([.year, .month], from: event.date))
                ?? calendar.startOfDay(for: event.date)
        }
        let sortedMonths = eventsByMonth.keys.sorted()

        return sortedMonths.map { monthStart in
            (label: Self.monthLabel(from: monthStart), count: eventsByMonth[monthStart]?.count ?? 0)
        }
    }

    private var weekDailyChartData: [(label: String, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return []
        }

        let startOfMonday = calendar.startOfDay(for: monday)
        let events = calculator.periodEvents
        var day = startOfMonday
        var days: [Date] = []

        while day <= today {
            days.append(day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return days.map { day in
            let count = events.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
            return (label: Self.weekdayLabel(from: day), count: count)
        }
    }

    private var monthWeeklyChartData: [(label: String, count: Int)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }

        let rangeStart = calendar.startOfDay(for: firstOfMonth)
        let events = calculator.periodEvents
        var weekStart = startOfWeek(for: rangeStart, calendar: calendar)
        var points: [(label: String, count: Int)] = []

        while weekStart <= today {
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { break }
            let bucketStart = max(weekStart, rangeStart)
            let bucketEnd = min(weekEnd, today)

            let count = events.filter { event in
                let day = calendar.startOfDay(for: event.date)
                return day >= bucketStart && day <= bucketEnd
            }.count

            points.append((label: Self.weekBucketLabel(from: bucketStart), count: count))
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = nextWeek
        }

        return points
    }

    private var customPeriodChartData: [(label: String, count: Int)] {
        guard let startDay = calculator.periodStartDay,
              let endDay = calculator.periodEndDay,
              let daySpan = calculator.periodDaySpan else {
            return filteredMonthlyChartData
        }

        let calendar = Calendar.current
        let events = calculator.periodEvents

        if daySpan <= 6 {
            return chartDaysInRange(from: startDay, through: endDay, events: events, calendar: calendar)
        }
        if daySpan <= 45 {
            return chartWeeksInRange(from: startDay, through: endDay, events: events, calendar: calendar)
        }
        return chartMonthsInRange(from: startDay, through: endDay, events: events, calendar: calendar)
    }

    private var filteredMonthlyChartData: [(label: String, count: Int)] {
        let calendar = Calendar.current
        let filtered = calculator.periodEvents
        let eventsByMonth = Dictionary(grouping: filtered) { event in
            calendar.date(from: calendar.dateComponents([.year, .month], from: event.date))
                ?? calendar.startOfDay(for: event.date)
        }
        let sortedMonths = eventsByMonth.keys.sorted()

        return sortedMonths.map { monthStart in
            (label: Self.monthLabel(from: monthStart), count: eventsByMonth[monthStart]?.count ?? 0)
        }
    }

    private func chartDaysInRange(
        from startDay: Date,
        through endDay: Date,
        events: [Event],
        calendar: Calendar
    ) -> [(label: String, count: Int)] {
        var day = startDay
        var days: [Date] = []

        while day <= endDay {
            days.append(day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return days.map { day in
            let count = events.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
            return (label: Self.weekdayLabel(from: day), count: count)
        }
    }

    private func chartWeeksInRange(
        from startDay: Date,
        through endDay: Date,
        events: [Event],
        calendar: Calendar
    ) -> [(label: String, count: Int)] {
        var calendar = calendar
        calendar.firstWeekday = 2

        var points: [(label: String, count: Int)] = []
        var weekStart = startOfWeek(for: startDay, calendar: calendar)

        while weekStart <= endDay {
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { break }
            let bucketStart = max(weekStart, startDay)
            let bucketEnd = min(weekEnd, endDay)

            let count = events.filter { event in
                let eventDay = calendar.startOfDay(for: event.date)
                return eventDay >= bucketStart && eventDay <= bucketEnd
            }.count

            points.append((label: Self.weekBucketLabel(from: bucketStart), count: count))

            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = nextWeek
        }

        return points
    }

    private func chartMonthsInRange(
        from startDay: Date,
        through endDay: Date,
        events: [Event],
        calendar: Calendar
    ) -> [(label: String, count: Int)] {
        guard var monthCursor = calendar.date(from: calendar.dateComponents([.year, .month], from: startDay)) else {
            return []
        }

        var points: [(label: String, count: Int)] = []

        while monthCursor <= endDay {
            let count = events.filter { event in
                guard let eventMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: event.date)) else {
                    return false
                }
                return eventMonth == monthCursor
            }.count

            points.append((label: Self.monthLabel(from: monthCursor), count: count))

            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor) else { break }
            monthCursor = nextMonth
        }

        return points
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Self.statsCardsSpacing) {
                    if completedEvents.isEmpty {
                        statisticsEmptyState
                            .padding(.top, 16)
                    } else {
                        periodFilterBar
                            .padding(.top, 16)

                        if hasEventsInSelectedPeriod {
                            monthlyChartSection

                            VStack(alignment: .leading, spacing: Self.statsCardsSpacing) {
                                generalSection
                                detailSections
                            }
                            .padding(.horizontal, AppTheme.screenHorizontalPadding)
                        } else {
                            periodEmptyState
                                .padding(.top, 24)
                                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.bottom, AppTheme.floatingTabBarScrollClearance)

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Статистика")
            .navigationBarTitleDisplayMode(.large)

        }
        .sheet(isPresented: $showPeriodOptionsSheet) {
            CustomPeriodSheet(
                startDate: $customStartDate,
                endDate: $customEndDate,
                onApply: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        customPeriodActive = true
                        selectedPeriod = .custom
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFemaleOrgasmActivitiesSheet) {
            FemaleOrgasmActivitiesFilterSheet(
                selectedActivities: $femaleOrgasmActivityFilter,
                allActivities: activityCatalog.selectableActivities
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: femaleOrgasmActivityFilter) { newValue in
            SettingsStore.femaleOrgasmActivityFilter = newValue
        }
        .preferredColorScheme(.dark)
    }

    private var statisticsEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.fill")
                .font(.system(size: 54))
                .foregroundStyle(AppTheme.accent)

            Text("Нет событий")
                .font(AppFont.font(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text("Добавьте первое событие в календаре")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var periodEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.secondaryText)

            Text("Пока ничего за этот период")
                .font(AppFont.font(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            Text("За выбранный интервал нет событий. Выберите другой период или добавьте запись в календаре.")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var detailSections: some View {
        VStack(alignment: .leading, spacing: Self.statsCardsSpacing) {
            if !calculator.activityCounts(lookup: activityCatalog.displayActivity(for:)).isEmpty {
                activitiesSection
            }

            if calculator.femaleOrgasmFilteredTotalEvents > 0 {
                femaleOrgasmSection
            }

            gapStatsSection

            if !calculator.finishSlices().isEmpty {
                finishSection
            }

            if !calculator.toyCounts().isEmpty {
                toysSection
            }

            if calculator.timeOfDayCounts().contains(where: { $0.count > 0 }) {
                timeOfDaySection
            }
        }
    }

    // MARK: - Filter

    private var customPeriodRangeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        let start = formatter.string(from: customStartDate)
        let end = formatter.string(from: customEndDate)
        return "\(start) — \(end)"
    }

    private var periodFilterBar: some View {
        Group {
            if customPeriodActive {
                HStack(spacing: 8) {
                    Text(customPeriodRangeLabel)
                        .font(AppFont.font(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            customPeriodActive = false
                            selectedPeriod = segmentedPeriod.statisticsPeriod
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .buttonStyle(ScalePressButtonStyle(scale: 0.95))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 8) {
                        ForEach(SegmentedStatisticsPeriod.allCases) { period in
                            FilterChip(
                                chipTitle: period.rawValue,
                                isSelected: segmentedPeriod == period
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    segmentedPeriod = period
                                    selectedPeriod = period.statisticsPeriod
                                    customPeriodActive = false
                                }
                            }
                        }

                        ChipCircleButton(systemName: "ellipsis") {
                            customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                            customEndDate = Date()
                            showPeriodOptionsSheet = true
                        }
                    }
                    .padding(.vertical, 2)
                }
                .chipScrollAllowsOverflow()
            }
        }
        .padding(.horizontal, AppTheme.screenHorizontalPadding)
        .padding(.bottom, 4)
        .animation(.easeInOut(duration: 0.3), value: customPeriodActive)
    }

    // MARK: - Sections

    private var generalSection: some View {
        LazyVGrid(columns: Self.twoColumns, spacing: Self.statsCardsSpacing) {
            StatCard(
                title: "Всего событий",
                value: "\(calculator.totalEvents)",
                iconName: "heart"
            )
            StatCard(
                title: "Она кончила",
                value: "\(calculator.femaleOrgasmCount)",
                iconName: "medal-star"
            )
        }
    }

    private static func monthLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLL"
        let raw = formatter.string(from: date)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .trimmingCharacters(in: .whitespaces)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    private static func weekdayLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEE"
        let raw = formatter.string(from: date)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .trimmingCharacters(in: .whitespaces)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    private static func weekBucketLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysFromMonday = (weekday - 2 + 7) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: day) ?? day
    }

    private var activitiesSection: some View {
        StatsSectionCard(title: "Активности") {
            let counts = calculator.activityCounts(lookup: activityCatalog.displayActivity(for:))
            let totalUsages = counts.map(\.count).reduce(0, +)

            VStack(alignment: .leading, spacing: 15) {
                if totalUsages > 0 {
                    StorageStyleSegmentedBar(
                        segments: counts.enumerated().map { index, item in
                            (
                                fraction: Double(item.count) / Double(totalUsages),
                                color: statsPaletteColor(at: index)
                            )
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(counts.enumerated()), id: \.element.activity.id) { index, item in
                        let fraction = totalUsages > 0 ? Double(item.count) / Double(totalUsages) : 0

                        StatsLegendRow(
                            color: statsPaletteColor(at: index),
                            title: item.activity.title,
                            count: item.count,
                            percentage: Int((fraction * 100).rounded())
                        )
                    }
                }
            }
        }
    }

    private var femaleOrgasmSection: some View {
        StatsSectionCard(
            title: "Она кончила",
            trailing: {
                Button {
                    showFemaleOrgasmActivitiesSheet = true
                } label: {
                    Image("sort")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Учитывать активности")
            }
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(calculator.femaleOrgasmPercentage)%")
                    .font(AppFont.font(size: 52, weight: .black))
                    .foregroundStyle(AppTheme.accent)

                Text(
                    "в \(calculator.femaleOrgasmFilteredOrgasmCount) из \(calculator.femaleOrgasmFilteredTotalEvents) событий"
                )
                    .font(AppFont.font(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var finishSection: some View {
        StatsSectionCard(title: "Окончания") {
            let slices = calculator.finishSlices()

            VStack(spacing: 24) {
                DonutChartView(
                    segments: slices.enumerated().map { index, slice in
                        (
                            value: Double(slice.count),
                            color: statsPaletteColor(at: index)
                        )
                    }
                )
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                        StatsLegendRow(
                            color: statsPaletteColor(at: index),
                            title: slice.finish.title,
                            count: slice.count,
                            percentage: Int((slice.fraction * 100).rounded())
                        )
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var gapStatsSection: some View {
        LazyVGrid(columns: Self.twoColumns, spacing: Self.statsCardsSpacing) {
            GapStatCard(
                title: "Макс. перерыв",
                days: calculator.maxGapDays
            )
            GapStatCard(
                title: "Текущий перерыв",
                days: calculator.daysSinceLastEvent
            )
        }
    }

    private var toysSection: some View {
        StatsSectionCard(title: "Игрушки") {
            let counts = calculator.toyCounts()
            let maxCount = max(counts.map(\.count).max() ?? 1, 1)

            VStack(alignment: .leading, spacing: 15) {
                ForEach(Array(counts.enumerated()), id: \.element.toy.id) { index, item in
                    HorizontalBarRow(
                        leading: item.toy.title,
                        count: item.count,
                        maxCount: maxCount,
                        barColor: index == 0 ? AppTheme.accent : AppTheme.appWhite
                    )
                }
            }
        }
    }

    private var timeOfDaySection: some View {
        StatsSectionCard(title: "Время суток") {
            let counts = calculator.timeOfDayCounts()
            let maxCount = max(counts.map(\.count).max() ?? 1, 1)
            let tallest = counts.map(\.count).max() ?? 0

            GeometryReader { geometry in
                let barCount = CGFloat(counts.count)
                let gap: CGFloat = 6
                let totalGap = gap * max(barCount - 1, 0)
                let barWidth = barCount > 0 ? (geometry.size.width - totalGap) / barCount : 0

                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(counts, id: \.period.id) { item in
                        TimeOfDayBar(
                            label: item.period.title,
                            range: item.period.hourRangeLabel,
                            count: item.count,
                            maxCount: maxCount,
                            barWidth: barWidth,
                            isHighlighted: item.count == tallest && tallest > 0
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 176)
        }
    }

    private func statsPaletteColor(at index: Int) -> Color {
        DayHeartColorStore.color(at: index)
    }

    private static let twoColumns = [
        GridItem(.flexible(), spacing: statsCardsSpacing),
        GridItem(.flexible(), spacing: statsCardsSpacing),
    ]
}

// MARK: - Period Options Sheet

private struct PeriodOptionsSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApplyCustom: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Свой период")
                        .font(AppFont.font(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    VStack(alignment: .leading, spacing: 8) {
                        AppTheme.sectionTitle("Начало")

                        DatePicker("", selection: $startDate, in: ...endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .tint(AppTheme.accent)
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        AppTheme.sectionTitle("Конец")

                        DatePicker("", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .tint(AppTheme.accent)
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                    }
                }

                Spacer(minLength: 0)

                PrimaryActionButton(title: "Применить") {
                    onApplyCustom()
                    dismiss()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.background)
            .sheetInlineHeader("Свой период")
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Female Orgasm Activities Filter Sheet

private struct FemaleOrgasmActivitiesFilterSheet: View {
    @Binding var selectedActivities: Set<String>
    let allActivities: [UserActivity]

    @Environment(\.dismiss) private var dismiss
    @State private var draftSelection: Set<String> = []

    private var canApply: Bool {
        !draftSelection.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(allActivities) { activity in
                            ActivityFilterCheckboxRow(
                                activity: activity,
                                isSelected: draftSelection.contains(activity.id)
                            ) {
                                UXFeedback.lightImpact()
                                if draftSelection.contains(activity.id) {
                                    draftSelection.remove(activity.id)
                                } else {
                                    draftSelection.insert(activity.id)
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)

                PrimaryActionButton(
                    title: "Применить",
                    isEnabled: canApply,
                    animatesEnabledState: false
                ) {
                    selectedActivities = draftSelection
                    SettingsStore.femaleOrgasmActivityFilter = draftSelection
                    dismiss()
                }
                .padding(.top, 20)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.background)
            .sheetInlineHeader("Учитывать активности")
            .animation(nil, value: draftSelection)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            draftSelection = selectedActivities.isEmpty
                ? Set(allActivities.map(\.id))
                : selectedActivities
        }
    }
}

private struct ActivityFilterCheckboxRow: View {
    let activity: UserActivity
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("\(activity.emoji) \(activity.title)")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                StatsActivityCheckbox(isOn: isSelected)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
                    .fill(isSelected ? EventFormStyle.selectedTintBackground : EventFormStyle.surfaceBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? EventFormStyle.selectedBorderColor : Color.clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct StatsActivityCheckbox: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(EventFormStyle.uncheckedCheckboxBorder, lineWidth: 1.5)
                .opacity(isOn ? 0 : 1)

            Circle()
                .fill(EventFormStyle.selectedCheckboxFill)
                .opacity(isOn ? 1 : 0)

            CheckmarkDrawShape()
                .stroke(
                    EventFormStyle.selectedCheckboxCheckmark,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 11, height: 11)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: 22, height: 22)
        .animation(nil, value: isOn)
    }
}

// MARK: - Custom Period Sheet (Variant B)

private struct CustomPeriodSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isStartPickerExpanded = false
    @State private var isEndPickerExpanded = false

    private var ruCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        return calendar
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 12) {
                        AppTheme.sectionTitle("Начало")

                        PickerChip(
                            date: $startDate,
                            mode: .date,
                            chipTitle: EventDateFormatting.pillLabel(for: startDate, calendar: ruCalendar),
                            isExpanded: $isStartPickerExpanded,
                            maximumDate: endDate
                        )
                        .onChange(of: isStartPickerExpanded) { expanded in
                            if expanded { isEndPickerExpanded = false }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        AppTheme.sectionTitle("Конец")

                        PickerChip(
                            date: $endDate,
                            mode: .date,
                            chipTitle: EventDateFormatting.pillLabel(for: endDate, calendar: ruCalendar),
                            isExpanded: $isEndPickerExpanded,
                            minimumDate: startDate,
                            maximumDate: Date()
                        )
                        .onChange(of: isEndPickerExpanded) { expanded in
                            if expanded { isStartPickerExpanded = false }
                        }
                    }
                }

                Spacer(minLength: 0)

                PrimaryActionButton(title: "Применить") {
                    onApply()
                    dismiss()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.background)
            .sheetInlineHeader("Свой период")
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Monthly Line Chart

private struct ChartDisplayPoint {
    let label: String
    let count: Int
    let isPlaceholder: Bool
}

private struct MonthlyEventsLineChart: View {
    let dataPoints: [ChartDisplayPoint]

    private let lineColor = AppTheme.accent
    private let chartHeight: CGFloat = 160
    private let chartVerticalPadding: CGFloat = 16
    private let gridLineCount = 4
    private let yAxisLegendWidth: CGFloat = 28
    private let yAxisLegendSpacing: CGFloat = 8
    private let gridLineColor = Color.white.opacity(0.09)
    private let legendTextColor = AppTheme.secondaryText.opacity(0.72)
    private static let lineEdgeOverflow: CGFloat = 48

    private var hasData: Bool {
        dataPoints.contains { !$0.isPlaceholder && $0.count > 0 }
    }

    private var maxCount: Int {
        let realCounts = dataPoints.filter { !$0.isPlaceholder }.map(\.count)
        return max(realCounts.max() ?? 1, 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            if !hasData {
                Text("Нет данных")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: chartHeight)
            } else {
                GeometryReader { geometry in
                    let fullWidth = geometry.size.width
                    let plotWidth = max(fullWidth - yAxisLegendWidth - yAxisLegendSpacing, 0)
                    let markerData = markerPoints(in: CGSize(width: plotWidth, height: chartHeight))

                    VStack(spacing: 8) {
                        chartArea(
                            fullWidth: fullWidth,
                            plotWidth: plotWidth,
                            markerData: markerData
                        )

                        xAxisLabelsRow(plotWidth: plotWidth)
                            .frame(width: plotWidth, alignment: .leading)
                    }
                    .frame(width: fullWidth, alignment: .leading)
                }
                .frame(height: chartHeight + 8 + 14)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func chartArea(
        fullWidth: CGFloat,
        plotWidth: CGFloat,
        markerData: [(point: CGPoint, count: Int)]
    ) -> some View {
        let overflow = Self.lineEdgeOverflow
        let lineEndPoint = linePoints(
            from: markerData,
            plotWidth: plotWidth,
            overflow: overflow
        ).last

        return ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawGridLines(context: &context, width: fullWidth)
            }
            .frame(width: fullWidth, height: chartHeight)

            HStack(spacing: yAxisLegendSpacing) {
                linePlot(
                    plotWidth: plotWidth,
                    markerData: markerData,
                    overflow: overflow
                )
                .frame(width: plotWidth, height: chartHeight)

                yAxisLegend
            }
            .frame(width: fullWidth, alignment: .leading)

            if let lineEndPoint {
                Circle()
                    .fill(lineColor)
                    .frame(width: 8, height: 8)
                    .position(
                        x: lineEndPoint.x - overflow,
                        y: lineEndPoint.y
                    )
                    .transaction { $0.animation = nil }
            }
        }
        .frame(width: fullWidth, height: chartHeight, alignment: .topLeading)
    }

    private func linePlot(
        plotWidth: CGFloat,
        markerData: [(point: CGPoint, count: Int)],
        overflow: CGFloat
    ) -> some View {
        ZStack(alignment: .leading) {
            lineCanvas(
                size: CGSize(width: plotWidth + overflow * 2, height: chartHeight),
                markerData: markerData,
                plotWidth: plotWidth,
                overflow: overflow
            )
            .offset(x: -overflow)
        }
        .frame(width: plotWidth, height: chartHeight, alignment: .leading)
        .clipped()
    }

    private func xAxisLabelsRow(plotWidth: CGFloat) -> some View {
        let labelWidth = plotWidth / CGFloat(max(dataPoints.count, 1))

        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(dataPoints.enumerated()), id: \.offset) { index, point in
                Text(xAxisLabel(for: index, point: point))
                    .font(AppFont.font(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: labelWidth)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: plotWidth)
    }

    private func xAxisLabel(for index: Int, point: ChartDisplayPoint) -> String {
        if point.isPlaceholder {
            return ""
        }
        if dataPoints.count > 8, !index.isMultiple(of: 2) {
            return ""
        }
        return point.label
    }

    private var yAxisLegend: some View {
        let plotHeight = chartPlotHeight(for: CGSize(width: 1, height: chartHeight))

        return ZStack(alignment: .topLeading) {
            ForEach(0..<gridLineCount, id: \.self) { lineIndex in
                Text("\(gridLineValue(for: lineIndex))")
                    .font(AppFont.font(size: 10, weight: .semibold))
                    .foregroundStyle(legendTextColor)
                    .frame(width: yAxisLegendWidth, alignment: .trailing)
                    .offset(y: gridLineY(for: lineIndex, plotHeight: plotHeight) - 7)
            }
        }
        .frame(width: yAxisLegendWidth, height: chartHeight, alignment: .topLeading)
    }

    private func gridLineY(for lineIndex: Int, plotHeight: CGFloat) -> CGFloat {
        chartVerticalPadding + plotHeight * CGFloat(lineIndex) / CGFloat(max(gridLineCount - 1, 1))
    }

    private func gridLineValue(for lineIndex: Int) -> Int {
        guard gridLineCount > 1 else { return maxCount }
        let fraction = 1 - CGFloat(lineIndex) / CGFloat(gridLineCount - 1)
        return max(0, Int((CGFloat(maxCount) * fraction).rounded()))
    }

    private func lineCanvas(
        size: CGSize,
        markerData: [(point: CGPoint, count: Int)],
        plotWidth: CGFloat,
        overflow: CGFloat
    ) -> some View {
        Canvas { context, size in
            guard !dataPoints.isEmpty else { return }

            let points = linePoints(
                from: markerData,
                plotWidth: plotWidth,
                overflow: overflow
            )
            guard !points.isEmpty else { return }

            let linePath = smoothLinePath(points: points)

            context.stroke(
                linePath,
                with: .color(lineColor),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size.width, height: size.height)
    }

    private func chartPlotHeight(for size: CGSize) -> CGFloat {
        max(size.height - chartVerticalPadding * 2, 0)
    }

    private func drawGridLines(context: inout GraphicsContext, width: CGFloat) {
        let lineStyle = StrokeStyle(lineWidth: 0.5, lineCap: .round)
        let plotHeight = chartPlotHeight(for: CGSize(width: width, height: chartHeight))

        for lineIndex in 0..<gridLineCount {
            let y = chartVerticalPadding + plotHeight * CGFloat(lineIndex) / CGFloat(gridLineCount - 1)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
            context.stroke(path, with: .color(gridLineColor), style: lineStyle)
        }
    }

    private func smoothLinePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else {
            if let first = points.first {
                path.move(to: first)
            }
            return path
        }

        path.move(to: points[0])

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let controlPoint1 = CGPoint(
                x: previous.x + (current.x - previous.x) / 3,
                y: previous.y
            )
            let controlPoint2 = CGPoint(
                x: current.x - (current.x - previous.x) / 3,
                y: current.y
            )
            path.addCurve(to: current, control1: controlPoint1, control2: controlPoint2)
        }

        return path
    }

    private func markerPoints(in size: CGSize) -> [(point: CGPoint, count: Int)] {
        guard !dataPoints.isEmpty else { return [] }

        let plotHeight = chartPlotHeight(for: size)
        let bucketWidth = size.width / CGFloat(dataPoints.count)

        return dataPoints.enumerated().map { index, point in
            let x = bucketWidth * CGFloat(index) + bucketWidth / 2
            let normalized = CGFloat(point.count) / CGFloat(maxCount)
            let y = chartVerticalPadding + plotHeight * (1 - normalized)
            return (CGPoint(x: x, y: y), point.count)
        }
    }

    private func linePoints(
        from markerData: [(point: CGPoint, count: Int)],
        plotWidth: CGFloat,
        overflow: CGFloat
    ) -> [CGPoint] {
        let mapped = markerData.map { item in
            CGPoint(x: item.point.x + overflow, y: item.point.y)
        }
        guard !mapped.isEmpty else { return [] }

        let rightEdge = plotWidth + overflow

        if mapped.count == 1, let point = mapped.first {
            return [
                CGPoint(x: 0, y: point.y),
                CGPoint(x: rightEdge, y: point.y),
            ]
        }

        guard mapped.count >= 2 else { return mapped }

        var points = mapped
        points[0] = CGPoint(x: 0, y: points[0].y)
        points[points.count - 1] = CGPoint(x: rightEdge, y: points[points.count - 1].y)
        return points
    }
}

// MARK: - Components

private enum StatsLayout {
    static let cardsSpacing: CGFloat = 10
    static let cardPadding: CGFloat = 20
    static let sectionCardPadding: CGFloat = 24
}

private enum StatsCardStyle {
    static let cornerRadius: CGFloat = 32
}

private extension View {
    func statsGlassCardStyle() -> some View {
        let shape = RoundedRectangle(cornerRadius: StatsCardStyle.cornerRadius, style: .continuous)

        return background(AppTheme.subtleSurfaceBackground)
            .clipShape(shape)
    }

}

private enum StatsGlowCorner {
    case topLeading
    case topTrailing
}

private struct StatsAccentGlow: View {
    let color: Color
    var corner: StatsGlowCorner = .topLeading

    static let size: CGFloat = 200
    static let blur: CGFloat = 64
    static let opacity: CGFloat = 0.05

    var body: some View {
        Circle()
            .fill(color.opacity(Self.opacity))
            .frame(width: Self.size, height: Self.size)
            .blur(radius: Self.blur)
            .offset(
                x: corner == .topTrailing ? Self.size / 2 : -Self.size / 2,
                y: -Self.size / 2
            )
            .allowsHitTesting(false)
    }
}

private struct StatsSectionCard<Content: View, Trailing: View>: View {
    let title: String
    var glowColor: Color?
    var glowCorner: StatsGlowCorner = .topLeading
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: Content

    init(
        title: String,
        glowColor: Color? = nil,
        glowCorner: StatsGlowCorner = .topLeading,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.glowColor = glowColor
        self.glowCorner = glowCorner
        self.trailing = trailing
        self.content = content()
    }

    private var backgroundAlignment: Alignment {
        glowCorner == .topTrailing ? .topTrailing : .topLeading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppTheme.sectionTitle(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .trailing) {
                    trailing()
                        .offset(y: -2)
                }

            content
        }
        .padding(StatsLayout.sectionCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: backgroundAlignment) {
            ZStack(alignment: backgroundAlignment) {
                AppTheme.subtleSurfaceBackground

                if let glowColor {
                    StatsAccentGlow(color: glowColor, corner: glowCorner)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: StatsCardStyle.cornerRadius, style: .continuous))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let iconName: String

    private static let iconSize: CGFloat = 22
    private static let iconBadgePadding: CGFloat = 10
    private static let iconBadgeCornerRadius: CGFloat = 13
    private static let contentSpacing: CGFloat = 12
    private static let titleValueSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Self.contentSpacing) {
            iconBadge

            VStack(alignment: .leading, spacing: Self.titleValueSpacing) {
                Text(title)
                    .font(AppFont.font(size: 15, weight: .black))
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(value)
                    .font(AppFont.font(size: 28, weight: .black))
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .padding(StatsLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.subtleSurfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: StatsCardStyle.cornerRadius, style: .continuous))
    }

    private var iconBadge: some View {
        Image(iconName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.iconSize, height: Self.iconSize)
            .foregroundStyle(AppTheme.appWhite)
            .padding(Self.iconBadgePadding)
            .background(
                RoundedRectangle(cornerRadius: Self.iconBadgeCornerRadius, style: .continuous)
                    .fill(AppTheme.appWhite.opacity(0.1))
            )
    }
}

private struct GapStatCard: View {
    let title: String
    let days: Int?

    private static let titleValueSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Self.titleValueSpacing) {
            daysValue

            Text(title)
                .font(AppFont.font(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StatsLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.subtleSurfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: StatsCardStyle.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var daysValue: some View {
        if let days {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(days)")
                    .font(AppFont.font(size: 28, weight: .black))
                    .foregroundStyle(AppTheme.primaryText)

                Text("дней")
                    .font(AppFont.font(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
            }
        } else {
            Text("—")
                .font(AppFont.font(size: 28, weight: .black))
                .foregroundStyle(AppTheme.primaryText)
        }
    }
}

private struct StorageStyleSegmentedBar: View {
    let segments: [(fraction: Double, color: Color)]

    private let barHeight: CGFloat = 16
    private let minimumSegmentWidth: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            let visibleSegments = segments.filter { $0.fraction > 0 }
            let gapCount = max(visibleSegments.count - 1, 0)
            let totalGapWidth = CGFloat(gapCount) * SegmentedChartMetrics.segmentSpacing
            let segmentableWidth = max(geometry.size.width - totalGapWidth, 0)

            HStack(spacing: SegmentedChartMetrics.segmentSpacing) {
                ForEach(Array(visibleSegments.enumerated()), id: \.offset) { _, segment in
                    RoundedRectangle(cornerRadius: SegmentedChartMetrics.cornerRadius, style: .continuous)
                        .fill(segment.color)
                        .frame(width: max(segmentableWidth * segment.fraction, minimumSegmentWidth))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: barHeight)
    }
}

private struct StatsLegendRow: View {
    let color: Color
    let title: String
    let count: Int
    let percentage: Int

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(color)
                .frame(width: 3, height: 14)

            Text(title)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            Text("\(count)")
                .font(AppFont.font(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text("\(percentage)%")
                .font(AppFont.font(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}

private struct HorizontalBarRow: View {
    let leading: String
    let count: Int
    let maxCount: Int
    let barColor: Color

    private static let barHeight: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(leading)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(AppFont.font(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.appWhite.opacity(0.04))
                    Capsule()
                        .fill(barColor)
                        .frame(width: maxCount > 0 ? geometry.size.width * CGFloat(count) / CGFloat(maxCount) : 0)
                }
            }
            .frame(height: Self.barHeight)
        }
    }
}

private enum SegmentedChartMetrics {
    static let segmentSpacing: CGFloat = 4
    static let cornerRadius: CGFloat = 8
}

private struct ArcShape: Shape {
    let startValue: CGFloat
    let endValue: CGFloat

    func path(in rect: CGRect) -> Path {
        let startAngle = 360.0 * startValue
        let endAngle = 360.0 * endValue
        let bezier = UIBezierPath(
            arcCenter: CGPoint(x: 0.5, y: 0.5),
            radius: 0.5,
            startAngle: CGFloat(startAngle * .pi / 180),
            endAngle: CGFloat(endAngle * .pi / 180),
            clockwise: true
        )
        let multiplier = min(rect.width, rect.height)
        return Path(bezier.cgPath)
            .applying(CGAffineTransform(scaleX: multiplier, y: multiplier))
            .applying(CGAffineTransform(translationX: rect.midX, y: rect.midY).inverted())
            .applying(CGAffineTransform(rotationAngle: CGFloat(90.0 * .pi / 180)).inverted())
            .applying(CGAffineTransform(translationX: rect.midX, y: rect.midY))
    }
}

private struct DonutChartView: View {
    let segments: [(value: Double, color: Color)]

    private var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    private struct ArcSegment {
        let start: CGFloat
        let end: CGFloat
        let color: Color
    }

    private func buildSegments() -> [ArcSegment] {
        guard total > 0 else { return [] }
        let gap: CGFloat = 0.0444
        let sorted = segments.filter { $0.value > 0 }.sorted { $0.value > $1.value }
        let totalGap = gap * CGFloat(sorted.count)
        let available = 1.0 - totalGap

        var result: [ArcSegment] = []
        var current: CGFloat = 0

        for segment in sorted {
            let fraction = CGFloat(segment.value / total) * available
            let start = current + gap / 2
            let end = start + fraction
            result.append(ArcSegment(start: start, end: end, color: segment.color))
            current += fraction + gap
        }
        return result
    }

    var body: some View {
        ZStack {
            ForEach(Array(buildSegments().enumerated()), id: \.offset) { _, seg in
                ArcShape(startValue: seg.start, endValue: seg.end)
                    .stroke(seg.color, style: StrokeStyle(
                        lineWidth: 16,
                        lineCap: .round,
                        lineJoin: .round
                    ))
            }
        }
        .frame(width: 160, height: 160)
    }
}

private struct TimeOfDayBar: View {
    let label: String
    let range: String
    let count: Int
    let maxCount: Int
    let barWidth: CGFloat
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text("\(count)")
                    .font(AppFont.font(size: 13, weight: .semibold))
                    .foregroundStyle(isHighlighted ? AppTheme.accent : AppTheme.secondaryText)

                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? AppTheme.accent : Color.white.opacity(0.15))
                    .frame(width: barWidth, height: barHeight)
            }

            Text(label)
                .font(AppFont.font(size: 11, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.primaryText)

            Text(range)
                .font(AppFont.font(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(width: barWidth)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var barHeight: CGFloat {
        guard maxCount > 0 else { return 8 }
        return max(12, CGFloat(count) / CGFloat(maxCount) * 120)
    }
}

#Preview {
    StatisticsView()
        .environmentObject(EventStore())
        .environmentObject(AuthService())
        .environmentObject(UserService())
        .environmentObject(ActivityCatalogStore())
}
