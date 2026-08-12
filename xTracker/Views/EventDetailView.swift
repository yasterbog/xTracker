//
//  EventDetailView.swift
//  xTracker
//

import SwiftUI
import UIKit

struct EventDetailView: View {
    let eventID: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var activityCatalog: ActivityCatalogStore
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var userService: UserService

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    private var event: Event? {
        store.events.first { $0.id == eventID }
    }

    private var eventExists: Bool {
        store.events.contains { $0.id == eventID }
    }

    var body: some View {
        NavigationStack {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
                .sheetInlineHeader("Событие", trailing: eventDetailHeaderTrailing)
                .sheet(isPresented: $showEditSheet, content: editSheetContent)
                .alert("Удалить событие?", isPresented: $showDeleteConfirmation) {
                    deleteAlertActions
                } message: {
                    Text("Это действие нельзя отменить.")
                }
                .onChange(of: eventExists) { exists in
                    if !exists {
                        dismiss()
                    }
                }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var detailContent: some View {
        if let event {
            EventDetailScrollContent(
                event: event,
                creatorProfile: creatorProfile(for: event)
            )
        } else {
            emptyStateView
        }
    }

    @ViewBuilder
    private func eventDetailHeaderTrailing() -> some View {
        if event != nil {
            Menu {
                Button("Редактировать") {
                    showEditSheet = true
                }
                Button("Удалить событие", role: .destructive) {
                    showDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(AppFont.font(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.secondaryText)

            Text("Нет событий")
                .foregroundColor(AppTheme.secondaryText)
        }
    }

    @ViewBuilder
    private func editSheetContent() -> some View {
        if let event {
            AddEventView(eventToEdit: event)
        }
    }

    @ViewBuilder
    private var deleteAlertActions: some View {
        Button("Удалить", role: .destructive) {
            deleteEvent()
        }
        Button("Отмена", role: .cancel) {}
    }

    private func deleteEvent() {
        guard let event else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        store.deleteEvent(event)
        dismiss()
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

// MARK: - Scroll Content

private struct EventDetailScrollContent: View {
    let event: Event
    let creatorProfile: UserAvatarProfile

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var activityCatalog: ActivityCatalogStore

    @State private var isMarkingCompleted = false

    private let sectionSpacing: CGFloat = 40

    private var ruCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        return calendar
    }

    private var showsPlannedBanner: Bool {
        AppFeatures.eventPlannerEnabled && event.status == .planned && event.date >= Date()
    }

    private var showsConfirmedFutureBanner: Bool {
        AppFeatures.eventPlannerEnabled && event.status == .confirmed && event.date >= Date()
    }

    private var showsMarkCompletedButton: Bool {
        AppFeatures.eventPlannerEnabled && event.status == .confirmed && event.date < Date()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    if showsPlannedBanner {
                        EventStatusBadge(status: .planned)
                    }

                    if showsConfirmedFutureBanner {
                        EventStatusBadge(status: .confirmed)
                    }

                    creatorSection
                    dateTimeSection
                    activitiesSection
                    protectionSection
                    femaleOrgasmSection
                    finishSection
                    toysSection
                    if !event.notes.isEmpty {
                        notesSection
                    }
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, showsMarkCompletedButton ? 88 : 32)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)

            if showsMarkCompletedButton {
                markCompletedButton
            }
        }
    }

    private var markCompletedButton: some View {
        PrimaryActionButton(
            title: "Состоялось",
            systemImage: "checkmark",
            isLoading: isMarkingCompleted,
            expandsHorizontally: false,
            action: markCompleted
        )
        .primaryActionButtonFloatingShadow()
        .padding(.trailing, AppTheme.screenHorizontalPadding)
        .padding(.bottom, 12)
    }

    private func markCompleted() {
        guard !isMarkingCompleted else { return }

        var updated = event
        updated.status = .completed
        isMarkingCompleted = true
        UXFeedback.mediumImpact()

        Task {
            await store.updateEventAndWaitForUploads(updated)
            await MainActor.run {
                isMarkingCompleted = false
                dismiss()
            }
        }
    }

    private var creatorSection: some View {
        EventFormSection(title: "Добавил(а)") {
            HStack(spacing: 10) {
                UserAvatarView(
                    avatarBase64: creatorProfile.avatarBase64,
                    avatarURL: creatorProfile.avatarURL,
                    name: creatorProfile.name,
                    size: 34
                )

                Text(creatorProfile.name)
                    .font(AppFont.font(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer(minLength: 0)
            }
        }
    }

    private var dateTimeSection: some View {
        EventFormSection(title: "Дата и время") {
            Text(
                "\(EventDateFormatting.pillLabel(for: event.date, calendar: ruCalendar)) · \(EventDetailFormatters.time.string(from: event.date))"
            )
            .font(AppTheme.bodyFont)
            .foregroundStyle(AppTheme.primaryText)
        }
    }

    @ViewBuilder
    private var activitiesSection: some View {
        EventFormSection(title: "Активности") {
            if event.activities.isEmpty {
                Text("Не было")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(EventFormStyle.unselectedLabel)
            } else {
                LazyVGrid(columns: EventDetailFormatters.twoColumns, spacing: 12) {
                    ForEach(event.activities, id: \.self) { activityID in
                        let activity = activityCatalog.displayActivity(for: activityID)
                        EventDetailDisplayCard(
                            emoji: activity.emoji,
                            title: activity.title,
                            accentColor: FormSelectionPalette.color(
                                forActivityID: activityID,
                                catalog: activityCatalog
                            )
                        )
                    }
                }
            }
        }
    }

    private var protectionSection: some View {
        EventFormSection(title: "Использовалась защита") {
            Text(event.protection ? "Да" : "Нет")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private var femaleOrgasmSection: some View {
        EventFormSection(title: "Она кончила 💫") {
            Text(event.femaleOrgasm ? "Да" : "Нет")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private var finishSection: some View {
        EventFormSection(title: "Окончание") {
            Text(event.finish.title)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    @ViewBuilder
    private var toysSection: some View {
        EventFormSection(title: "Игрушки") {
            if event.toys.isEmpty {
                Text("Не использовались")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(EventFormStyle.unselectedLabel)
            } else {
                LazyVGrid(columns: EventDetailFormatters.twoColumns, spacing: 12) {
                    ForEach(event.toys) { toy in
                        EventDetailDisplayCard(
                            emoji: toy.emoji,
                            title: toy.title,
                            accentColor: FormSelectionPalette.color(for: toy)
                        )
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        EventFormSection(title: "Заметки") {
            Text(event.notes)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Display Components

private struct EventDetailDisplayCard: View {
    let emoji: String
    let title: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(AppFont.font(size: 32, weight: .semibold))

            Text(title)
                .font(AppFont.font(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
                .fill(FormSelectionPalette.selectedBackground(AppTheme.accent))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
                        .strokeBorder(
                            FormSelectionPalette.selectedBorder(AppTheme.accent),
                            lineWidth: FormSelectionPalette.selectedBorderWidth
                        )
                )
        )
    }
}

// MARK: - Formatters

private enum EventDetailFormatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let twoColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]
}

#Preview {
    EventDetailView(eventID: MockEventData.allEvents[0].id)
        .environmentObject(EventStore())
        .environmentObject(AuthService())
        .environmentObject(UserService())
        .environmentObject(ActivityCatalogStore())
}
