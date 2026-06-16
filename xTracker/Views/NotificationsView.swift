//
//  NotificationsView.swift
//  xTracker
//
//  Event planner UI — inactive when AppFeatures.eventPlannerEnabled == false.
//

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var authService: AuthService

    private var partnerPlannedEvents: [Event] {
        store.partnerPlannedEvents(currentUserID: authService.userID, partnerID: authService.partnerID)
    }

    private let ruCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        return calendar
    }()

    var body: some View {
        ScrollView {
            if partnerPlannedEvents.isEmpty {
                emptyState
                    .padding(.top, 48)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(partnerPlannedEvents) { event in
                        NotificationEventRow(
                            event: event,
                            calendar: ruCalendar,
                            onAccept: { accept(event) },
                            onDecline: { decline(event) }
                        )
                    }
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, AppTheme.floatingTabBarScrollClearance)
            }
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.secondaryText)

            Text("Нет новых предложений")
                .font(AppFont.font(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            Text("Когда партнёр предложит встречу, она появится здесь")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }

    private func accept(_ event: Event) {
        var updated = event
        updated.status = .confirmed
        store.updateEvent(updated)
        UXFeedback.mediumImpact()

        let formattedDate = Self.formattedEventDate(event.date, calendar: ruCalendar)
        Task {
            await NotificationService.shared.sendPushToPartner(
                toUserId: event.createdBy,
                title: "Партнёр принял 🩷",
                body: "Ваше предложение на \(formattedDate) принято"
            )
        }
    }

    private func decline(_ event: Event) {
        var updated = event
        updated.status = .declined
        store.updateEvent(updated)
        UXFeedback.mediumImpact()

        let formattedDate = Self.formattedEventDate(event.date, calendar: ruCalendar)
        Task {
            await NotificationService.shared.sendPushToPartner(
                toUserId: event.createdBy,
                title: "Партнёр отклонил",
                body: "Ваше предложение на \(formattedDate) отклонено"
            )
        }
    }

    private static func formattedEventDate(_ date: Date, calendar: Calendar) -> String {
        "\(EventDateFormatting.pillLabel(for: date, calendar: calendar)) · \(timeFormatter.string(from: date))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct NotificationEventRow: View {
    let event: Event
    let calendar: Calendar
    let onAccept: () -> Void
    let onDecline: () -> Void

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "\(EventDateFormatting.pillLabel(for: event.date, calendar: calendar)) · \(Self.timeFormatter.string(from: event.date))"
                )
                .font(AppFont.font(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

                Text("Партнёр предлагает встречу")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(spacing: 10) {
                Button(action: onAccept) {
                    Text("Принять")
                        .font(AppFont.font(size: 15, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onDecline) {
                    Text("Отклонить")
                        .font(AppFont.font(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.subtleSurfaceBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.subtleSurfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(EventStore())
            .environmentObject(AuthService())
    }
    .preferredColorScheme(.dark)
}
