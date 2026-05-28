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
                .sheetInlineHeader("Событие")
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
                creatorProfile: creatorProfile(for: event),
                onEditTapped: { showEditSheet = true },
                onDeleteTapped: { showDeleteConfirmation = true }
            )
        } else {
            emptyStateView
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
    let onEditTapped: () -> Void
    let onDeleteTapped: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                creatorSection
                dateTimeSection
                activitiesSection
                protectionSection
                toysSection
                finishSection
                femaleOrgasmSection
                notesSection
                editButton
                deleteButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
    }

    private var creatorSection: some View {
        DetailCard(title: "Добавил(а)") {
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

                Spacer()
            }
        }
    }

    private var dateTimeSection: some View {
        DetailCard(title: "Дата и время") {
            VStack(alignment: .leading, spacing: 6) {
                Text(EventDetailFormatters.date.string(from: event.date))
                Text(EventDetailFormatters.time.string(from: event.date))
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(AppTheme.accent)
            }
            .font(AppTheme.bodyFont)
            .foregroundStyle(AppTheme.primaryText)
        }
    }

    @ViewBuilder
    private var activitiesSection: some View {
        DetailCard(title: "Активности") {
            if event.activities.isEmpty {
                Text("Не указаны")
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                activitiesGrid
            }
        }
    }

    private var activitiesGrid: some View {
        LazyVGrid(columns: EventDetailFormatters.twoColumns, spacing: 10) {
            ForEach(event.activities) { activity in
                ActivityDisplayCard(activity: activity)
            }
        }
    }

    private var protectionSection: some View {
        DetailCard(title: "Защита") {
            BoolRow(label: "Использовалась защита", value: event.protection)
        }
    }

    @ViewBuilder
    private var toysSection: some View {
        DetailCard(title: "Игрушки") {
            if event.toys.isEmpty {
                Text("Не использовались")
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                toysGrid
            }
        }
    }

    private var toysGrid: some View {
        LazyVGrid(columns: EventDetailFormatters.twoColumns, spacing: 10) {
            ForEach(event.toys) { toy in
                ToyDisplayCard(toy: toy)
            }
        }
    }

    private var finishSection: some View {
        DetailCard(title: "Окончание") {
            Text(event.finish.title)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private var femaleOrgasmSection: some View {
        DetailCard(title: "Она кончила") {
            Text(event.femaleOrgasm ? "Да 💫" : "Нет")
                .foregroundStyle(event.femaleOrgasm ? AppTheme.accent : AppTheme.primaryText)
        }
    }

    private var notesSection: some View {
        DetailCard(title: "Заметки") {
            Text(event.notes.isEmpty ? "—" : event.notes)
                .foregroundStyle(event.notes.isEmpty ? AppTheme.secondaryText : AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var editButton: some View {
        PrimaryActionButton(title: "Редактировать", action: onEditTapped)
            .padding(.top, 8)
    }

    private var deleteButton: some View {
        DestructionActionButton(title: "Удалить событие", action: onDeleteTapped)
            .padding(.top, 8)
    }
}

// MARK: - Formatters

private enum EventDetailFormatters {
    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let twoColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]
}

// MARK: - Components

private struct DetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionHeader(title)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSectionCard()
    }
}

private struct BoolRow: View {
    let label: String
    let value: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Text(value ? "Да" : "Нет")
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(value ? AppTheme.accent : AppTheme.secondaryText)
        }
    }
}

private struct ActivityDisplayCard: View {
    let activity: ActivityType

    var body: some View {
        VStack(spacing: 6) {
            Text(activity.emoji)
                .font(.system(size: 22, weight: .regular, design: .default))
            Text(activity.title)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.accent.opacity(0.2))
        )
    }
}

private struct ToyDisplayCard: View {
    let toy: ToyType

    var body: some View {
        VStack(spacing: 6) {
            Text(toy.emoji)
                .font(.system(size: 22, weight: .regular, design: .default))
            Text(toy.title)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }
}

#Preview {
    EventDetailView(eventID: MockEventData.allEvents[0].id)
        .environmentObject(EventStore())
        .environmentObject(AuthService())
        .environmentObject(UserService())
}
