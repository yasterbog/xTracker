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
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.gray)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("Нет событий")
                .foregroundColor(.gray)
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
}

// MARK: - Scroll Content

private struct EventDetailScrollContent: View {
    let event: Event
    let creatorProfile: UserAvatarProfile

    private let sectionSpacing: CGFloat = 40

    private var ruCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        return calendar
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
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
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
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
                    .font(.system(size: 16, weight: .semibold, design: .default))
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
                    ForEach(event.activities) { activity in
                        EventDetailDisplayCard(emoji: activity.emoji, title: activity.title)
                    }
                }
            }
        }
    }

    private var protectionSection: some View {
        EventFormSection(title: "Использовалась защита") {
            Text(event.protection ? "Да" : "Нет")
                .font(AppTheme.bodyFont)
                .foregroundStyle(event.protection ? AppTheme.primaryText : EventFormStyle.unselectedLabel)
        }
    }

    private var femaleOrgasmSection: some View {
        EventFormSection(title: "Она кончила 💫") {
            Text(event.femaleOrgasm ? "Да" : "Нет")
                .font(AppTheme.bodyFont)
                .foregroundStyle(event.femaleOrgasm ? AppTheme.primaryText : EventFormStyle.unselectedLabel)
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
                        EventDetailDisplayCard(emoji: toy.emoji, title: toy.title)
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

    var body: some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 32, weight: .regular, design: .default))

            Text(title)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(EventFormStyle.selectedLabel)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
                .fill(EventFormStyle.selectedTintBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
                        .strokeBorder(EventFormStyle.selectedBorderColor, lineWidth: 1)
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
}
