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
    @EnvironmentObject private var activityCatalog: ActivityCatalogStore
    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var monthPageIndex = 1
    @State private var monthRecenterTask: Task<Void, Never>?
    @State private var selectedDate = CalendarView.initialSelectedDate
    @State private var showAddEvent = false
    @State private var selectedEvent: Event?
    @State private var eventToDelete: Event?
    @State private var showDeleteAlert = false
    @State private var swipingEventID: String?
    @State private var selectedActivityFilters: Set<String> = []
    @State private var showNotifications = false

    private var hasActiveActivityFilter: Bool {
        !selectedActivityFilters.isEmpty
    }

    private let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.firstWeekday = 2
        return calendar
    }()

    private static var initialSelectedDate: Date {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.firstWeekday = 2
        return calendar.startOfDay(for: Date())
    }

    private var visibleStoreEvents: [Event] {
        store.events
    }

    private var selectedDayEvents: [Event] {
        let dayStart = calendar.startOfDay(for: selectedDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        var events = visibleStoreEvents
            .filter { $0.date >= dayStart && $0.date < dayEnd }
            .filter(\.isVisibleOnCalendar)
            .sorted { $0.date > $1.date }

        guard hasActiveActivityFilter else { return events }

        return events
            .filter { $0.status == .completed }
            .filter(eventMatchesFilter)
    }

    private var currentMonthYearString: String {
        CalendarFormatters.monthYear(from: visibleMonth)
    }

    private var visibleMonth: Date {
        switch monthPageIndex {
        case 0:
            calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        case 2:
            calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        default:
            displayedMonth
        }
    }

    private var plannerNotificationsBinding: Binding<Bool> {
        Binding(
            get: { AppFeatures.eventPlannerEnabled && showNotifications },
            set: { showNotifications = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    calendarSection

                    monthlySummarySection

                    eventsSection
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.bottom, AppTheme.floatingTabBarScrollClearance)

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle(currentMonthYearString)
            .navigationBarTitleDisplayMode(.large)

            .toolbar {
                if AppFeatures.eventPlannerEnabled {
                    ToolbarItem(placement: .topBarTrailing) {
                        notificationsButton
                    }
                }
            }
            .navigationDestination(isPresented: plannerNotificationsBinding) {
                NotificationsView()
            }
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView(prefilledDate: selectedDate)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(eventID: event.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Удалить событие?", isPresented: $showDeleteAlert, presenting: eventToDelete) { event in
            Button("Удалить", role: .destructive) {
                store.deleteEvent(event)
                eventToDelete = nil
            }
            Button("Отмена", role: .cancel) {
                eventToDelete = nil
            }
        } message: { _ in
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

            TabView(selection: $monthPageIndex) {
                monthGrid(monthOffset: -1)
                    .padding(.horizontal, 6)
                    .tag(0)

                monthGrid(monthOffset: 0)
                    .padding(.horizontal, 6)
                    .tag(1)

                monthGrid(monthOffset: 1)
                    .padding(.horizontal, 6)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: Self.calendarGridHeight)
            .onChange(of: monthPageIndex) { newIndex in
                scheduleMonthRecenter(for: newIndex)
            }
        }
    }

    private static let monthPageTransitionDuration: Duration = .milliseconds(350)

    private func scheduleMonthRecenter(for pageIndex: Int) {
        guard pageIndex != 1 else { return }

        let delta = pageIndex == 0 ? -1 : 1
        monthRecenterTask?.cancel()
        monthRecenterTask = Task { @MainActor in
            try? await Task.sleep(for: Self.monthPageTransitionDuration)
            guard !Task.isCancelled else { return }
            guard monthPageIndex == pageIndex else { return }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
                    displayedMonth = newMonth
                }
                monthPageIndex = 1
            }
        }
    }

    // 6 rows × 49pt cells + 5 × 4pt grid spacing
    private static let calendarGridHeight: CGFloat = 294

    private var weekdayHeader: some View {
        LazyVGrid(columns: Self.gridColumns, spacing: 2) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(AppFont.font(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthGrid(monthOffset: Int) -> some View {
        let month = calendar.date(byAdding: .month, value: monthOffset, to: displayedMonth) ?? displayedMonth

        return CalendarMonthGrid(
            month: month,
            days: monthDays(for: month),
            indicatorsByDay: indicatorsByDay(in: month),
            selectedDate: selectedDate,
            calendar: calendar,
            blocksFutureDates: blocksFutureDates,
            onSelectDay: selectDay
        )
    }

    // MARK: - Monthly summary

    private var monthlySummarySection: some View {
        Group {
            if !monthlyActivityCounts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(monthlyActivityCounts, id: \.activity.id) { item in
                            FilterChip(
                                isSelected: selectedActivityFilters.contains(item.activity.id)
                            ) {
                                toggleActivityFilter(item.activity.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(item.activity.emoji)
                                        .font(ChipMetrics.chipTitle)

                                    Text("\(item.count)")
                                        .font(ChipMetrics.chipTitle)
                                        .foregroundColor(
                                            selectedActivityFilters.contains(item.activity.id)
                                                ? AppTheme.background
                                                : AppTheme.primaryText
                                        )
                                }
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
        .padding(.top, 4)
        .id(displayedMonth)
    }

    private var monthlyActivityCounts: [(activity: UserActivity, count: Int)] {
        let monthEvents = eventsInMonth(displayedMonth).filter { $0.status == .completed }
        var counts: [String: Int] = [:]
        for event in monthEvents {
            for activityID in event.activities {
                counts[activityID, default: 0] += 1
            }
        }

        return counts.compactMap { activityID, count -> (UserActivity, Int)? in
            count > 0 ? (activityCatalog.displayActivity(for: activityID), count) : nil
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            let lhsOrder = activityCatalog.colorIndex(for: lhs.activity.id)
            let rhsOrder = activityCatalog.colorIndex(for: rhs.activity.id)
            return lhsOrder < rhsOrder
        }
    }

    // MARK: - Events (bottom)

    private var eventsSection: some View {
        VStack(spacing: 0) {
            selectedDayHeader
                .padding(.top, 12)
                .padding(.bottom, 4)
                .padding(.horizontal, AppTheme.screenHorizontalPadding)

            if !selectedDayEvents.isEmpty {
                eventsList
                    .id(selectedDate)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedDate)
    }

    private var selectedDayHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(CalendarFormatters.selectedDayHeader(for: selectedDate, calendar: calendar))
                .font(AppFont.font(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            addEventButton
        }
    }

    private var addEventButton: some View {
        ChipButton(icon: "plus", title: "Добавить") {
            showAddEvent = true
        }
    }

    private var eventsList: some View {
        List {
            ForEach(selectedDayEvents) { event in
                CalendarEventRow(
                    event: event,
                    creatorProfile: creatorProfile(for: event)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .eventCardChrome(isVisible: swipingEventID == event.id)
                .background {
                    SwipeInteractionObserver(isSwiping: swipeBinding(for: event.id))
                }
                .onTapGesture {
                    selectedEvent = event
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        eventToDelete = event
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(.init())
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .applyListHorizontalContentMarginsZero()
        .applyListScrollClipDisabled()
        .frame(height: CGFloat(selectedDayEvents.count) * Self.eventRowEstimatedHeight)
        .padding(.top, 8)
    }

    private func swipeBinding(for eventID: String) -> Binding<Bool> {
        Binding(
            get: { swipingEventID == eventID },
            set: { isSwiping in
                if isSwiping {
                    swipingEventID = eventID
                } else if swipingEventID == eventID {
                    swipingEventID = nil
                }
            }
        )
    }

    private static let eventRowEstimatedHeight: CGFloat = 84

    // MARK: - Helpers

    private let weekdaySymbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private func indicatorsByDay(in month: Date) -> [Date: [CalendarDayIndicator]] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [:] }

        var eventsByDay: [Date: [Event]] = [:]
        for event in visibleStoreEvents where event.isVisibleOnCalendar && interval.contains(event.date) {
            let day = calendar.startOfDay(for: event.date)
            eventsByDay[day, default: []].append(event)
        }

        var indicatorsByDay: [Date: [CalendarDayIndicator]] = [:]
        indicatorsByDay.reserveCapacity(eventsByDay.count)

        for (day, events) in eventsByDay {
            let visibleEvents: [Event]
            if hasActiveActivityFilter {
                visibleEvents = events
                    .filter { $0.status == .completed }
                    .filter(eventMatchesFilter)
            } else {
                visibleEvents = events
            }

            let indicators = makeIndicators(from: visibleEvents)
            if !indicators.isEmpty {
                indicatorsByDay[day] = indicators
            }
        }

        return indicatorsByDay
    }

    private func makeIndicators(from events: [Event]) -> [CalendarDayIndicator] {
        var indicators: [CalendarDayIndicator] = []

        let completed = events.filter { $0.status == .completed }
        if completed.count >= 3 {
            indicators.append(.fire)
        } else {
            indicators.append(contentsOf: Array(repeating: .completed, count: completed.count))
        }

        if AppFeatures.eventPlannerEnabled {
            if events.contains(where: { $0.status == .confirmed }) {
                indicators.append(.confirmed)
            }
            if events.contains(where: { $0.status == .planned }) {
                indicators.append(.planned)
            }
        }

        return Array(indicators.prefix(3))
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
                days.append(calendar.startOfDay(for: date))
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func eventsInMonth(_ month: Date) -> [Event] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        return visibleStoreEvents.filter { interval.contains($0.date) }
    }

    private var hasPartnerPlannedNotifications: Bool {
        store.hasPartnerPlannedEvents(
            currentUserID: authService.userID,
            partnerID: authService.partnerID
        )
    }

    private var notificationsButton: some View {
        Button {
            showNotifications = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: hasPartnerPlannedNotifications ? "bell.badge" : "bell")
                    .font(AppFont.font(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                if hasPartnerPlannedNotifications {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Уведомления")
    }

    private func eventMatchesFilter(_ event: Event) -> Bool {
        guard hasActiveActivityFilter else { return true }
        return selectedActivityFilters.isSubset(of: Set(event.activities))
    }

    private var blocksFutureDates: Bool {
        !AppFeatures.eventPlannerEnabled
    }

    private func isFutureDate(_ day: Date) -> Bool {
        calendar.startOfDay(for: day) > calendar.startOfDay(for: Date())
    }

    private func toggleActivityFilter(_ activityID: String) {
        if selectedActivityFilters.contains(activityID) {
            selectedActivityFilters.remove(activityID)
        } else {
            selectedActivityFilters.insert(activityID)
        }
    }

    private func selectDay(_ day: Date) {
        guard !blocksFutureDates || !isFutureDate(day) else { return }
        selectedDate = calendar.startOfDay(for: day)
    }

    private func creatorProfile(for event: Event) -> UserAvatarProfile {
        EventProfileResolver.creatorProfile(
            for: event,
            currentUserID: authService.userID,
            currentPartnerID: authService.partnerID,
            ownName: userService.ownName,
            ownAvatarBase64: userService.ownAvatarBase64,
            ownAvatarURL: userService.ownAvatarURL,
            partnerName: userService.partnerName,
            partnerAvatarBase64: userService.partnerAvatarBase64,
            partnerAvatarURL: userService.partnerAvatarURL
        )
    }
}

// MARK: - Month Grid

private struct CalendarMonthGrid: View {
    let month: Date
    let days: [Date?]
    let indicatorsByDay: [Date: [CalendarDayIndicator]]
    let selectedDate: Date
    let calendar: Calendar
    let blocksFutureDates: Bool
    let onSelectDay: (Date) -> Void

    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        LazyVGrid(columns: Self.gridColumns, spacing: 4) {
            ForEach(days.indices, id: \.self) { index in
                if let day = days[index] {
                    CalendarDayCell(
                        day: day,
                        selectedDate: selectedDate,
                        calendar: calendar,
                        isCurrentMonth: calendar.isDate(day, equalTo: month, toGranularity: .month),
                        isFutureDay: blocksFutureDates && isFutureDate(day),
                        dayIndicators: indicatorsByDay[day] ?? [],
                        onTap: { onSelectDay(day) }
                    )
                } else {
                    Color.clear
                        .frame(height: 49)
                }
            }
        }
    }

    private func isFutureDate(_ day: Date) -> Bool {
        calendar.startOfDay(for: day) > calendar.startOfDay(for: Date())
    }
}

// MARK: - Day Cell

private enum CalendarDayIndicator: Equatable {
    case completed
    case planned
    case confirmed
    case fire
}

private struct CalendarDayCell: View {
    let day: Date
    let selectedDate: Date
    let calendar: Calendar
    let isCurrentMonth: Bool
    let isFutureDay: Bool
    let dayIndicators: [CalendarDayIndicator]
    let onTap: () -> Void

    private static let statusHeartColor = Color(hex: "#611D2F")

    private var isToday: Bool {
        calendar.isDateInToday(day)
    }

    private var isSelected: Bool {
        calendar.isDate(day, inSameDayAs: selectedDate)
    }

    private var visualState: DayVisualState {
        if isSelected && isToday { return .selectedToday }
        if isSelected { return .selected }
        if isToday { return .today }
        return .normal
    }

    private enum DayVisualState: Equatable {
        case normal
        case today
        case selected
        case selectedToday
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(dayCircleFill)

                    Text("\(calendar.component(.day, from: day))")
                        .font(AppFont.font(size: 15, weight: dayNumberWeight))
                        .foregroundStyle(dayNumberColor)
                }
                .frame(width: 32, height: 32)
                .animation(nil, value: visualState)

                eventIndicator
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.heartOuterSize)
                    .animation(nil, value: dayIndicators)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(height: 49, alignment: .top)
        }
        .buttonStyle(.plain)
        .disabled(isFutureDay)
        .opacity(isFutureDay ? 0.55 : 1)
    }

    private var dayCircleFill: Color {
        switch visualState {
        case .selectedToday:
            return AppTheme.accent
        case .selected:
            return Color.white
        case .today, .normal:
            return .clear
        }
    }

    private var dayNumberWeight: Font.Weight {
        if isSelected || isToday {
            return Font.Weight.semibold
        }
        return Font.Weight.semibold
    }

    private var dayNumberColor: Color {
        switch visualState {
        case .selectedToday:
            return AppTheme.primaryText
        case .selected:
            return Color.black
        case .today, .normal:
            if isFutureDay {
                return AppTheme.mutedDay
            }
            if !isCurrentMonth {
                return AppTheme.mutedDay
            }
            if isToday {
                return AppTheme.accent
            }
            return AppTheme.primaryText
        }
    }

    private static let heartSize: CGFloat = 9
    private static let heartBorderPadding: CGFloat = 2.5
    private static let heartOuterSize: CGFloat = heartSize + heartBorderPadding * 2
    private static let heartStackOffset: CGFloat = 6

    @ViewBuilder
    private var eventIndicator: some View {
        if dayIndicators.isEmpty {
            Color.clear
        } else if dayIndicators.count == 1, let indicator = dayIndicators.first {
            indicatorView(for: indicator)
        } else {
            let width = stackedHeartsWidth(for: dayIndicators.count)

            ZStack {
                ForEach(Array(dayIndicators.enumerated()), id: \.offset) { index, indicator in
                    let startX = -width / 2 + Self.heartOuterSize / 2

                    indicatorView(for: indicator)
                        .offset(x: startX + CGFloat(index) * Self.heartStackOffset)
                        .zIndex(Double(index))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func stackedHeartsWidth(for count: Int) -> CGFloat {
        Self.heartOuterSize + CGFloat(max(count - 1, 0)) * Self.heartStackOffset
    }

    @ViewBuilder
    private func indicatorView(for indicator: CalendarDayIndicator) -> some View {
        switch indicator {
        case .completed:
            completedHeart
        case .planned:
            plannedHeart
        case .confirmed:
            confirmedHeart
        case .fire:
            Text("🔥")
                .font(.system(size: 9))
                .frame(width: Self.heartOuterSize, height: Self.heartOuterSize)
        }
    }

    private var completedHeart: some View {
        ZStack {
            Image("heart_fill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(AppTheme.background)
                .frame(width: Self.heartOuterSize, height: Self.heartOuterSize)

            Image("heart_fill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(AppTheme.accent)
                .frame(width: Self.heartSize, height: Self.heartSize)
        }
        .frame(width: Self.heartOuterSize, height: Self.heartOuterSize)
    }

    private var plannedHeart: some View {
        ZStack {
            Image("heart_fill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(AppTheme.background)
                .frame(width: Self.heartOuterSize, height: Self.heartOuterSize)

            Image("heart_dashed")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(Self.statusHeartColor)
                .frame(width: Self.heartSize, height: Self.heartSize)
        }
        .frame(width: Self.heartOuterSize, height: Self.heartOuterSize)
    }

    private var confirmedHeart: some View {
        ZStack {
            Image("heart_fill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(AppTheme.background)
                .frame(width: Self.heartOuterSize, height: Self.heartOuterSize)

            Image("heart_fill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(Self.statusHeartColor)
                .frame(width: Self.heartSize, height: Self.heartSize)
        }
        .frame(width: Self.heartOuterSize, height: Self.heartOuterSize)
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
                HStack(alignment: .center, spacing: 8) {
                    Text(Self.timeFormatter.string(from: event.date))
                        .font(AppFont.font(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    if event.showsFutureStatusBadge {
                        EventStatusBadge(status: event.status, style: .compact)
                    }

                    Spacer(minLength: 0)

                    if event.hasNotes {
                        EventNotesIndicator()
                    }
                }

                EventActivitiesSummaryLine(activityIDs: event.activities)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(AppFont.font(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, AppTheme.screenHorizontalPadding)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
        if calendar.isDateInToday(date) || calendar.isDateInYesterday(date) {
            return EventDateFormatting.pillLabel(for: date, calendar: calendar)
        }
        return dayMonthFormatter.string(from: date)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

private extension View {
    @ViewBuilder
    func applyListHorizontalContentMarginsZero() -> some View {
        if #available(iOS 17.0, *) {
            contentMargins(.horizontal, 0, for: .scrollContent)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyListScrollClipDisabled() -> some View {
        if #available(iOS 17.0, *) {
            scrollClipDisabled()
        } else {
            self
        }
    }
}

#Preview {
    CalendarView()
        .environmentObject(EventStore())
        .environmentObject(AuthService())
        .environmentObject(UserService())
        .environmentObject(ActivityCatalogStore())
}
