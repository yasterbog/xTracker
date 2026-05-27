//
//  StatisticsView.swift
//  xTracker
//

import SwiftUI
import UIKit

struct StatisticsView: View {
    @EnvironmentObject private var store: EventStore
    let gradientStart: UnitPoint
    let gradientEnd: UnitPoint
    let onAnimateGradient: () -> Void

    @State private var segmentedPeriod: SegmentedStatisticsPeriod = .allTime
    @State private var selectedPeriod: StatisticsPeriod = .allTime
    @State private var customPeriodActive = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showPeriodOptionsSheet = false

    private var calculator: StatisticsCalculator {
        StatisticsCalculator(
            events: store.events,
            period: customPeriodActive ? .custom : selectedPeriod,
            activityFilter: nil,
            customStartDate: customPeriodActive ? customStartDate : nil,
            customEndDate: customPeriodActive ? customEndDate : nil
        )
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
        case .threeMonths, .year, .custom:
            return filteredMonthlyChartData
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.cardSpacing) {
                        if store.events.isEmpty {
                            statisticsEmptyState
                                .padding(.top, 16)
                        } else {
                            periodFilterBar
                                .padding(.top, 16)

                            monthlyChartSection

                            VStack(alignment: .leading, spacing: AppTheme.cardSpacing) {
                                generalSection
                                activitiesSection
                                femaleOrgasmSection
                                finishSection
                                toysSection
                                timeOfDaySection
                            }
                            .padding(.horizontal, AppTheme.screenHorizontalPadding)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .ambientMainScreen(gradientStart: gradientStart, gradientEnd: gradientEnd)
            .navigationTitle("Статистика")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if !customPeriodActive {
                            customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                            customEndDate = Date()
                        }
                        showPeriodOptionsSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .foregroundColor(customPeriodActive ? Color(hex: "#FF3B6F") : .white)
                    }
                }
            }
        }
        .sheet(isPresented: $showPeriodOptionsSheet) {
            PeriodOptionsSheet(
                startDate: $customStartDate,
                endDate: $customEndDate,
                onApplyCustom: {
                    customPeriodActive = true
                    selectedPeriod = .custom
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedPeriod) { _ in
            onAnimateGradient()
        }
    }

    private var statisticsEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.fill")
                .font(.system(size: 54, weight: .regular, design: .default))
                .foregroundStyle(AppTheme.accent)

            Text("Нет событий")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.primaryText)

            Text("Добавьте первое событие в календаре")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filter

    private var periodFilterBar: some View {
        Group {
            if customPeriodActive {
                HStack(spacing: 8) {
                    Text(customPeriodLabel)
                        .font(.system(size: 15))
                        .foregroundColor(.white)

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            customPeriodActive = false
                            segmentedPeriod = .allTime
                            selectedPeriod = .allTime
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            } else {
                Picker("", selection: $segmentedPeriod) {
                    ForEach(SegmentedStatisticsPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
                .onChange(of: segmentedPeriod) { newPeriod in
                    selectedPeriod = newPeriod.statisticsPeriod
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: customPeriodActive)
    }

    private var customPeriodLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        let start = formatter.string(from: customStartDate)
        let end = formatter.string(from: customEndDate)
        return "\(start) — \(end)"
    }

    // MARK: - Sections

    private var generalSection: some View {
        LazyVGrid(columns: Self.twoColumns, spacing: 12) {
            StatCard(title: "Всего событий", value: "\(calculator.totalEvents)")
            StatCard(
                title: "Она кончила",
                value: "\(calculator.femaleOrgasmCount)",
                trailingEmoji: "💫"
            )
            StatCard(title: "Максимальный перерыв", value: "\(calculator.maxGapDays) дн.")
            StatCard(
                title: "С последнего события",
                value: calculator.daysSinceLastEvent.map { "\($0) дн." } ?? "—"
            )
        }
    }

    private var monthlyChartSection: some View {
        MonthlyEventsLineChart(
            dataPoints: chartDataPoints
        )
        .padding(.top, 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var allTimeMonthlyChartData: [(label: String, count: Int)] {
        let calendar = Calendar.current
        let eventsByMonth = Dictionary(grouping: store.events) { event in
            calendar.date(from: calendar.dateComponents([.year, .month], from: event.date)) ?? calendar.startOfDay(for: event.date)
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
        var days: [Date] = []
        var day = startOfMonday

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

    private var filteredMonthlyChartData: [(label: String, count: Int)] {
        let calendar = Calendar.current
        let filtered = calculator.periodEvents
        let eventsByMonth = Dictionary(grouping: filtered) { event in
            calendar.date(from: calendar.dateComponents([.year, .month], from: event.date)) ?? calendar.startOfDay(for: event.date)
        }
        let sortedMonths = eventsByMonth.keys.sorted()

        return sortedMonths.map { monthStart in
            (label: Self.monthLabel(from: monthStart), count: eventsByMonth[monthStart]?.count ?? 0)
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
            let counts = calculator.activityCounts()
            let maxCount = max(counts.map(\.count).max() ?? 1, 1)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(counts, id: \.activity.id) { item in
                    HorizontalBarRow(
                        leading: "\(item.activity.emoji) \(item.activity.title)",
                        count: item.count,
                        maxCount: maxCount
                    )
                }
            }
        }
    }

    private var femaleOrgasmSection: some View {
        StatsSectionCard(title: "Она кончила 💫") {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(calculator.femaleOrgasmPercentage)%")
                    .font(AppTheme.statsNumberFont)
                    .foregroundStyle(AppTheme.accent)

                Text("в \(calculator.femaleOrgasmCount) из \(calculator.totalEvents) событий")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var finishSection: some View {
        StatsSectionCard(title: "Окончания") {
            let slices = calculator.finishSlices()
            if slices.isEmpty {
                Text("Нет данных за период")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.top, 16)
            } else {
                VStack(spacing: 16) {
                    DonutChartView(slices: slices.map { ($0.fraction, finishColor($0.finish)) })
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(slices.enumerated()), id: \.offset) { _, slice in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(finishColor(slice.finish))
                                    .frame(width: 10, height: 10)

                                Text(slice.finish.title)
                                    .font(AppTheme.captionFont)
                                    .foregroundStyle(AppTheme.primaryText)

                                Spacer()

                                Text("\(slice.count)")
                                    .font(.system(size: 13, weight: .bold, design: .default))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text("\(Int((slice.fraction * 100).rounded()))%")
                                    .font(.system(size: 13, weight: .semibold, design: .default))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(.top, 16)
            }
        }
    }

    private var toysSection: some View {
        StatsSectionCard(title: "Игрушки") {
            let counts = calculator.toyCounts()
            let maxCount = max(counts.map(\.count).max() ?? 1, 1)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(counts, id: \.toy.id) { item in
                    HorizontalBarRow(
                        leading: "\(item.toy.emoji) \(item.toy.title)",
                        count: item.count,
                        maxCount: maxCount
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

    private func finishColor(_ finish: FinishType) -> Color {
        switch finish {
        case .condom:
            Color(hex: "#FF3B6F")
        case .inside:
            Color(hex: "#5E5CE6")
        case .inMouthSwallow:
            Color(hex: "#30D158")
        case .inMouthSpit:
            Color(hex: "#0A84FF")
        case .onFace:
            Color(hex: "#FFD60A")
        case .onChest:
            Color(hex: "#FF6B35")
        case .onBelly:
            Color(hex: "#BF5AF2")
        case .onBack:
            Color(hex: "#00C7BE")
        case .none:
            Color.gray
        }
    }

    private static let twoColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
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
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(AppTheme.primaryText)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Начало")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.secondaryText)

                        DatePicker("", selection: $startDate, in: ...endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .tint(AppTheme.accent)
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Конец")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.secondaryText)

                        DatePicker("", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .tint(AppTheme.accent)
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                    }
                }

                Spacer(minLength: 0)

                Button {
                    onApplyCustom()
                    dismiss()
                } label: {
                    Text("Применить")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.accent)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.background)
            .navigationTitle("Период")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Monthly Line Chart

private struct MonthlyEventsLineChart: View {
    let dataPoints: [(label: String, count: Int)]

    private let lineColor = Color(hex: "#FF3B6F")
    private let chartHeight: CGFloat = 160
    private let chartVerticalPadding: CGFloat = 16
    private let gridLineCount = 4

    private var hasData: Bool {
        dataPoints.contains { $0.count > 0 }
    }

    private var maxCount: Int {
        max(dataPoints.map(\.count).max() ?? 1, 1)
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
                chartCanvas
                    .frame(height: chartHeight)
            }

            xAxisLabels
        }
    }

    private var xAxisLabels: some View {
        GeometryReader { geometry in
            let labelWidth = dataPoints.isEmpty ? 0 : geometry.size.width / CGFloat(dataPoints.count)

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(dataPoints.enumerated()), id: \.offset) { index, point in
                    Text(xAxisLabel(for: index, label: point.label))
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: labelWidth)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(height: 14)
    }

    private func xAxisLabel(for index: Int, label: String) -> String {
        if dataPoints.count > 8, !index.isMultiple(of: 2) {
            return ""
        }
        return label
    }

    private var chartCanvas: some View {
        Canvas { context, size in
            guard !dataPoints.isEmpty else { return }

            let points = chartPoints(in: size)
            guard !points.isEmpty else { return }

            drawGridLines(context: &context, size: size)

            let linePath = smoothLinePath(points: points)
            var areaPath = linePath
            areaPath.addLine(to: CGPoint(x: points[points.count - 1].x, y: size.height))
            areaPath.addLine(to: CGPoint(x: points[0].x, y: size.height))
            areaPath.closeSubpath()

            context.fill(
                areaPath,
                with: .linearGradient(
                    Gradient(colors: [lineColor.opacity(0.3), Color.clear]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)
                )
            )

            context.stroke(
                linePath,
                with: .color(lineColor),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func chartPlotHeight(for size: CGSize) -> CGFloat {
        max(size.height - chartVerticalPadding * 2, 0)
    }

    private func drawGridLines(context: inout GraphicsContext, size: CGSize) {
        let dashStyle = StrokeStyle(lineWidth: 1, lineCap: .round, dash: [5, 5])
        let gridColor = Color.white.opacity(0.08)
        let plotHeight = chartPlotHeight(for: size)

        for lineIndex in 0..<gridLineCount {
            let y = chartVerticalPadding + plotHeight * CGFloat(lineIndex) / CGFloat(gridLineCount - 1)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), style: dashStyle)
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

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !dataPoints.isEmpty else { return [] }

        let plotHeight = chartPlotHeight(for: size)
        let horizontalStep = dataPoints.count > 1 ? size.width / CGFloat(dataPoints.count - 1) : 0

        return dataPoints.enumerated().map { index, point in
            let x = dataPoints.count > 1 ? CGFloat(index) * horizontalStep : size.width / 2
            let normalized = CGFloat(point.count) / CGFloat(maxCount)
            let y = chartVerticalPadding + plotHeight * (1 - normalized)
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Components

private enum StatsCardStyle {
    static let cornerRadius: CGFloat = 24
}

private extension View {
    func statsGlassCardStyle() -> some View {
        let shape = RoundedRectangle(cornerRadius: StatsCardStyle.cornerRadius, style: .continuous)

        return background(Color.white.opacity(0.07))
            .clipShape(shape)
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.03),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
    }
}

private struct StatsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppTheme.sectionHeader(title)

            content
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .statsGlassCardStyle()
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    var trailingEmoji: String?

    @ViewBuilder
    private var valueRow: some View {
        if let trailingEmoji {
            HStack(alignment: .center, spacing: 0) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text(trailingEmoji)
                    .font(.system(size: 14))
                    .baselineOffset(-2)
                    .padding(.leading, 4)
            }
        } else {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            AppTheme.sectionHeader(title)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            valueRow
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100, alignment: .leading)
        .statsGlassCardStyle()
    }
}

private struct HorizontalBarRow: View {
    let leading: String
    let count: Int
    let maxCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(leading)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.7))
                        .frame(width: maxCount > 0 ? geometry.size.width * CGFloat(count) / CGFloat(maxCount) : 0)
                }
            }
            .frame(height: 8)
        }
    }
}

private struct DonutChartView: View {
    let slices: [(fraction: Double, color: Color)]

    private let lineWidth: CGFloat = 28

    private var visibleSlices: [(fraction: Double, color: Color)] {
        slices.filter { $0.fraction > 0 }
    }

    var body: some View {
        ZStack {
            ForEach(Array(visibleSlices.enumerated()), id: \.offset) { index, slice in
                let start = visibleSlices.prefix(index).map(\.fraction).reduce(0, +)

                Circle()
                    .trim(from: start, to: start + slice.fraction)
                    .stroke(
                        slice.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: 140, height: 140)
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
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(isHighlighted ? AppTheme.accent : AppTheme.secondaryText)

                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? Color(hex: "#FF3B6F") : Color.white.opacity(0.15))
                    .frame(width: barWidth, height: barHeight)
            }

            Text(label)
                .font(.system(size: 11, weight: .regular, design: .default))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.primaryText)

            Text(range)
                .font(.system(size: 10, weight: .regular, design: .default))
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
    StatisticsView(
        gradientStart: .top,
        gradientEnd: .bottomTrailing,
        onAnimateGradient: {}
    )
        .environmentObject(EventStore())
}
