//
//  CalendarView.swift
//  xTracker
//

import SwiftUI
import UIKit

struct CalendarView: View {
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var userService: UserService

    @State private var anchorMonth = Calendar.current.startOfMonth(for: Date())
    @State private var monthOffset = 0
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showAddEvent = false
    @State private var selectedEvent: Event?
    @State private var eventPendingDeletion: Event?
    @State private var showDeleteConfirmation = false
    @State private var selectedActivityFilters: Set<ActivityType> = []

    private var hasActiveActivityFilter: Bool {
        !selectedActivityFilters.isEmpty
    }

    private let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.firstWeekday = 2
        return calendar
    }()

    private var selectedDayEvents: [Event] {
        let events = store.events(on: selectedDate)
        guard hasActiveActivityFilter else { return events }
        return events.filter(eventMatchesFilter)
    }

    private var displayedMonth: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: anchorMonth) ?? anchorMonth
    }

    private var currentMonthYearString: String {
        CalendarFormatters.monthYear(from: displayedMonth)
    }

    private static let monthPageRange = Array(-60...60)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                calendarSection

                monthlySummarySection

                eventsSection
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background)
            .navigationTitle(currentMonthYearString)
            .appLargeNavigationTitle()
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView(prefilledDate: selectedDate)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(eventID: event.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Удалить событие?", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                deletePendingEvent()
            }
            Button("Отмена", role: .cancel) {
                eventPendingDeletion = nil
            }
        } message: {
            Text("Это действие нельзя отменить.")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Calendar (top)

    private var calendarSection: some View {
        VStack(spacing: 0) {
            weekdayHeader
                .padding(.horizontal, 6)
                .padding(.top, 16)
                .padding(.bottom, 2)

            TabView(selection: $monthOffset) {
                ForEach(Self.monthPageRange, id: \.self) { offset in
                    calendarGrid(for: monthDate(forOffset: offset))
                        .padding(.horizontal, 6)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: Self.calendarGridHeight)
        }
    }

    // 6 rows × 49pt cells + 5 × 4pt grid spacing
    private static let calendarGridHeight: CGFloat = 294

    private var weekdayHeader: some View {
        LazyVGrid(columns: Self.gridColumns, spacing: 2) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func calendarGrid(for month: Date) -> some View {
        LazyVGrid(columns: Self.gridColumns, spacing: 4) {
            ForEach(monthDays(for: month), id: \.self) { day in
                if let day {
                    CalendarDayCell(
                        day: day,
                        isCurrentMonth: calendar.isDate(day, equalTo: month, toGranularity: .month),
                        isToday: calendar.isDateInToday(day),
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                        isFuture: isFutureDate(day),
                        eventCount: displayEventCount(on: day)
                    ) {
                        selectDay(day)
                    }
                } else {
                    Color.clear
                        .frame(height: 40)
                }
            }
        }
    }

    // MARK: - Monthly summary

    private var monthlySummarySection: some View {
        Group {
            if !monthlyActivityCounts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(monthlyActivityCounts, id: \.activity.id) { item in
                            MonthlyActivityChip(
                                activity: item.activity,
                                count: item.count,
                                isSelected: selectedActivityFilters.contains(item.activity)
                            ) {
                                toggleActivityFilter(item.activity)
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 16)
                }
                .chipScrollAllowsOverflow()
                .padding(.bottom, 10)
            }
        }
        .padding(.top, 0)
        .id(displayedMonth)
    }

    private var monthlyActivityCounts: [(activity: ActivityType, count: Int)] {
        let monthEvents = eventsInMonth(displayedMonth)
        return ActivityType.allCases.compactMap { activity in
            let count = monthEvents.filter { $0.activities.contains(activity) }.count
            return count > 0 ? (activity, count) : nil
        }
    }

    // MARK: - Events (bottom)

    private var eventsSection: some View {
        VStack(spacing: 0) {
            selectedDayHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()
                .overlay(AppTheme.secondaryText.opacity(0.25))

            if selectedDayEvents.isEmpty {
                emptyEventsState
                    .id(selectedDate)
                    .transition(.opacity)
            } else {
                eventsList
                    .id(selectedDate)
                    .transition(.opacity)
            }
        }
        .background(AppTheme.background)
        .frame(maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: selectedDate)
    }

    private var selectedDayHeader: some View {
        HStack {
            Text(CalendarFormatters.selectedDayHeader(for: selectedDate, calendar: calendar))
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            if !isFutureDate(selectedDate) {
                Button {
                    showAddEvent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .regular, design: .default))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyEventsState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("❤️")
                .font(.system(size: 22, weight: .regular, design: .default))
            Text("Нет событий")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var eventsList: some View {
        List {
            ForEach(selectedDayEvents) { event in
                Button {
                    selectedEvent = event
                } label: {
                    CalendarEventRow(
                        event: event,
                        creatorProfile: creatorProfile(for: event)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        eventPendingDeletion = event
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, 11)
    }

    // MARK: - Helpers

    private let weekdaySymbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    private func monthDate(forOffset offset: Int) -> Date {
        calendar.date(byAdding: .month, value: offset, to: anchorMonth) ?? anchorMonth
    }

    private func monthDays(for month: Date) -> [Date?] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month),
            let daysInMonth = calendar.range(of: .day, in: .month, for: month)
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmpty = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)

        for day in daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func eventsInMonth(_ month: Date) -> [Event] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        return store.events.filter { interval.contains($0.date) }
    }

    private func eventMatchesFilter(_ event: Event) -> Bool {
        guard hasActiveActivityFilter else { return true }
        return selectedActivityFilters.isSubset(of: Set(event.activities))
    }

    private func displayEventCount(on date: Date) -> Int {
        if hasActiveActivityFilter {
            return store.events(on: date).filter(eventMatchesFilter).count
        }
        return store.eventCount(on: date)
    }

    private func toggleActivityFilter(_ activity: ActivityType) {
        if selectedActivityFilters.contains(activity) {
            selectedActivityFilters.remove(activity)
        } else {
            selectedActivityFilters.insert(activity)
        }
    }

    private func selectDay(_ day: Date) {
        guard !isFutureDate(day) else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            selectedDate = calendar.startOfDay(for: day)
        }
    }

    private func isFutureDate(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
    }

    private func deletePendingEvent() {
        guard let event = eventPendingDeletion else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        store.deleteEvent(event)
        eventPendingDeletion = nil
    }

    private func creatorProfile(for event: Event) -> UserAvatarProfile {
        if event.createdBy == authService.userID || authService.userID.isEmpty {
            return UserAvatarProfile(
                userID: authService.userID,
                name: userService.ownName.isEmpty ? SettingsStore.defaultUserName : userService.ownName,
                avatarBase64: userService.ownAvatarBase64,
                avatarURL: userService.ownAvatarURL
            )
        }

        if event.createdBy == authService.partnerID {
            return UserAvatarProfile(
                userID: authService.partnerID,
                name: userService.partnerName.isEmpty ? "Партнёр" : userService.partnerName,
                avatarBase64: userService.partnerAvatarBase64,
                avatarURL: userService.partnerAvatarURL
            )
        }

        return UserAvatarProfile(userID: event.createdBy, name: "Участник", avatarBase64: nil, avatarURL: nil)
    }

    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
}

// MARK: - Monthly Chip

private struct MonthlyActivityChip: View {
    let activity: ActivityType
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                onTap()
            }
        } label: {
            HStack(spacing: 6) {
                Text(activity.emoji)
                    .font(.system(size: 14, weight: .regular, design: .default))

                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(isSelected ? Color.white : AppTheme.primaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? AppTheme.accent : AppTheme.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? AppTheme.accent : AppTheme.cardBorder, lineWidth: AppTheme.cardBorderWidth)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Day Cell

private struct CalendarDayCell: View {
    let day: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let isFuture: Bool
    let eventCount: Int
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                ZStack {
                    dayBackground
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(size: 15, weight: dayNumberWeight, design: .default))
                        .foregroundStyle(dayNumberColor)
                }
                .frame(width: 32, height: 32)

                eventIndicator
                    .frame(height: 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 49)
            .opacity(isFuture ? 0.3 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    @ViewBuilder
    private var dayBackground: some View {
        if isSelected && isToday {
            Circle()
                .fill(AppTheme.accent)
        } else if isSelected {
            Circle()
                .fill(Color.white)
        } else if isToday {
            Circle()
                .fill(Color.clear)
                .overlay(
                    Circle()
                        .inset(by: 1)
                        .stroke(Color(hex: "#FF3B6F"), lineWidth: 2)
                )
        }
    }

    private var dayNumberWeight: Font.Weight {
        if isSelected || isToday {
            return Font.Weight.semibold
        }
        return Font.Weight.regular
    }

    private var dayNumberColor: Color {
        if isSelected && isToday {
            return AppTheme.primaryText
        }
        if isSelected {
            return Color.black
        }
        if !isCurrentMonth {
            return AppTheme.mutedDay
        }
        if isToday {
            return AppTheme.accent
        }
        return AppTheme.primaryText
    }

    @ViewBuilder
    private var eventIndicator: some View {
        switch eventCount {
        case 0:
            Color.clear
        case 1, 2:
            Image("heart_fill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(Color(hex: "#FF3B6F"))
                .frame(width: 10, height: 10)
        default:
            Text("🔥")
                .font(.system(size: 9, weight: .regular, design: .default))
        }
    }
}

// MARK: - Event Row

private struct CalendarEventRow: View {
    let event: Event
    let creatorProfile: UserAvatarProfile

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            UserAvatarView(
                avatarBase64: creatorProfile.avatarBase64,
                avatarURL: creatorProfile.avatarURL,
                name: creatorProfile.name,
                size: 48
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(Self.timeFormatter.string(from: event.date))
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(AppTheme.primaryText)

                HStack(spacing: 4) {
                    ForEach(event.activities) { activity in
                        Text(activity.emoji)
                            .font(.system(size: 24, weight: .regular, design: .default))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.cardBorder, lineWidth: AppTheme.cardBorderWidth)
        )
    }
}

// MARK: - Formatters

private enum CalendarFormatters {
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    static func monthYear(from date: Date) -> String {
        monthYearFormatter.string(from: date).capitalized
    }

    static func selectedDayHeader(for date: Date, calendar: Calendar) -> String {
        let dayMonth = dayMonthFormatter.string(from: date)
        if calendar.isDateInToday(date) {
            return "Сегодня, \(dayMonth)"
        }
        if calendar.isDateInYesterday(date) {
            return "Вчера, \(dayMonth)"
        }
        return dayMonth
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    CalendarView()
        .environmentObject(EventStore())
        .environmentObject(AuthService())
        .environmentObject(UserService())
}
