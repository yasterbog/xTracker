//
//  StatisticsView.swift
//  xTracker
//

import SwiftUI
import UIKit

struct StatisticsView: View {
    @EnvironmentObject private var store: EventStore

    @State private var selectedPeriod: StatisticsPeriod = .allTime
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    @State private var appliedCustomStartDate: Date?
    @State private var appliedCustomEndDate: Date?
    @State private var showCustomPeriodSheet = false

    private var calculator: StatisticsCalculator {
        StatisticsCalculator(
            events: store.events,
            period: selectedPeriod,
            activityFilter: nil,
            customStartDate: selectedPeriod == .custom ? appliedCustomStartDate : nil,
            customEndDate: selectedPeriod == .custom ? appliedCustomEndDate : nil
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.cardSpacing) {
                    if store.events.isEmpty {
                        statisticsEmptyState
                            .padding(.top, 16)
                    } else {
                        periodFilterBar
                            .padding(.top, 16)

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
            .background(AppTheme.background)
            .navigationTitle("Статистика")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showCustomPeriodSheet) {
            CustomPeriodSheet(
                startDate: $customStartDate,
                endDate: $customEndDate,
                onApply: {
                    appliedCustomStartDate = customStartDate
                    appliedCustomEndDate = customEndDate
                    selectedPeriod = .custom
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(.dark)
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
        .background(AppTheme.background)
    }

    // MARK: - Filter

    private var periodFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(StatisticsPeriod.filterOrder.enumerated()), id: \.element.id) { index, period in
                    FilterPill(
                        title: period.rawValue,
                        isSelected: selectedPeriod == period
                    ) {
                        if period == .custom {
                            if let appliedCustomStartDate {
                                customStartDate = appliedCustomStartDate
                            }
                            if let appliedCustomEndDate {
                                customEndDate = appliedCustomEndDate
                            }
                            showCustomPeriodSheet = true
                        } else {
                            selectedPeriod = period
                        }
                    }
                    .padding(.leading, index == 0 ? 20 : 0)
                    .padding(.trailing, index == StatisticsPeriod.filterOrder.count - 1 ? 20 : 0)
                }
            }
            .padding(.horizontal, 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    private var generalSection: some View {
        StatsSectionCard(title: "Общее") {
            LazyVGrid(columns: Self.twoColumns, spacing: 12) {
                StatCard(title: "Всего событий", value: "\(calculator.totalEvents)")
                StatCard(
                    title: "С последнего события",
                    value: calculator.daysSinceLastEvent.map { "\($0) дн." } ?? "—"
                )
                StatCard(title: "Максимальный перерыв", value: "\(calculator.maxGapDays) дн.")
                StatCard(
                    title: "Она кончила",
                    value: "\(calculator.femaleOrgasmCount)",
                    trailingEmoji: "💫"
                )
            }
        }
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
                        .frame(width: 120, height: 120)
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
        let index = FinishType.allCases.firstIndex(of: finish) ?? 0
        let colors: [Color] = [
            AppTheme.accent,
            Color(red: 0.95, green: 0.4, blue: 0.55),
            Color(red: 0.55, green: 0.45, blue: 0.95),
            Color(red: 0.4, green: 0.75, blue: 0.95),
            Color(red: 0.95, green: 0.7, blue: 0.35),
            Color(red: 0.5, green: 0.85, blue: 0.65),
            Color(red: 0.85, green: 0.5, blue: 0.4),
            Color(red: 0.65, green: 0.65, blue: 0.75),
        ]
        return colors[index % colors.count]
    }

    private static let twoColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]
}

// MARK: - Custom Period Sheet

private struct CustomPeriodSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
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

                Spacer(minLength: 0)

                Button {
                    onApply()
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
            .navigationTitle("Свой период")
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

// MARK: - Components

private enum StatsCardStyle {
    static let sectionBackground = AppTheme.cardBackground
    static let statTileBackground = Color(red: 0.17, green: 0.17, blue: 0.18)
}

private struct StatsSectionCard<Content: View>: View {
    let title: String
    var background: Color
    @ViewBuilder let content: Content

    init(
        title: String,
        background: Color = StatsCardStyle.sectionBackground,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.background = background
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppTheme.sectionHeader(title)

            content
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(background)
        )
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
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            valueRow
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius)
                .fill(StatsCardStyle.statTileBackground)
        )
    }
}

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                action()
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isSelected ? AppTheme.accent : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
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
                        .fill(AppTheme.accent)
                        .frame(width: maxCount > 0 ? geometry.size.width * CGFloat(count) / CGFloat(maxCount) : 0)
                }
            }
            .frame(height: 8)
        }
    }
}

private struct DonutChartView: View {
    let slices: [(fraction: Double, color: Color)]

    var body: some View {
        ZStack {
            ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                let start = slices.prefix(index).map(\.fraction).reduce(0, +)
                Circle()
                    .trim(from: start, to: start + slice.fraction)
                    .stroke(slice.color, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            Circle()
                .fill(AppTheme.background)
                .padding(18)
        }
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
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(isHighlighted ? AppTheme.accent : AppTheme.secondaryText)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? AppTheme.accent : Color.white.opacity(0.15))
                    .frame(width: barWidth, height: barHeight)
            }
            .frame(height: 120, alignment: .bottom)

            Text(label)
                .font(.system(size: 11, weight: .regular, design: .default))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.primaryText)

            Text(range)
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(width: barWidth)
    }

    private var barHeight: CGFloat {
        guard maxCount > 0 else { return 8 }
        return max(12, CGFloat(count) / CGFloat(maxCount) * 120)
    }
}

#Preview {
    StatisticsView()
        .environmentObject(EventStore())
}
