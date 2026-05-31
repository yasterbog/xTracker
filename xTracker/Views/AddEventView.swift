//
//  AddEventView.swift
//  xTracker
//

import SwiftUI
import UIKit

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var authService: AuthService

    private let eventToEdit: Event?
    private let notesLimit = 500
    private let sectionSpacing: CGFloat = 40

    @State private var date: Date
    @State private var selectedActivities: Set<ActivityType>
    @State private var protection: Bool
    @State private var femaleOrgasm: Bool
    @State private var selectedToys: Set<ToyType>
    @State private var finish: FinishType
    @State private var notes: String
    @State private var isSaving = false
    @State private var isDatePickerExpanded = false
    @State private var isTimePickerExpanded = false

    private var isEditMode: Bool { eventToEdit != nil }

    private var ruCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        return calendar
    }

    init(eventToEdit: Event? = nil, prefilledDate: Date? = nil) {
        self.eventToEdit = eventToEdit

        let initialDate: Date
        if let eventToEdit {
            initialDate = eventToEdit.date
        } else if let prefilledDate {
            initialDate = Self.date(fromDay: prefilledDate, keepingTimeFrom: Date())
        } else {
            initialDate = Date()
        }

        _date = State(initialValue: initialDate)
        _selectedActivities = State(initialValue: Set(eventToEdit?.activities ?? [.sex]))
        _protection = State(initialValue: eventToEdit?.protection ?? false)
        _femaleOrgasm = State(initialValue: eventToEdit?.femaleOrgasm ?? false)
        _selectedToys = State(initialValue: Set(eventToEdit?.toys ?? []))
        _finish = State(initialValue: eventToEdit?.finish ?? .condom)
        _notes = State(initialValue: eventToEdit?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: sectionSpacing) {
                        dateTimeSection
                        activitiesSection
                        detailsSection
                        finishSection
                        toysSection
                        notesSection
                    }
                    .padding(.horizontal, AppTheme.screenHorizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 88)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)

                floatingSaveButton
            }
            .background(AppTheme.background)
            .sheetInlineHeader(isEditMode ? "Редактировать" : "Новое событие")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionHeader("Дата и время")

            HStack(spacing: 10) {
                PickerChip(
                    date: $date,
                    mode: .date,
                    chipTitle: EventDateFormatting.pillLabel(for: date, calendar: ruCalendar),
                    isExpanded: $isDatePickerExpanded,
                    maximumDate: Date()
                )
                .onChange(of: isDatePickerExpanded) { expanded in
                    if expanded { isTimePickerExpanded = false }
                }

                PickerChip(
                    date: $date,
                    mode: .time,
                    chipTitle: Self.timeFormatter.string(from: date),
                    isExpanded: $isTimePickerExpanded,
                    maximumDate: Date()
                )
                .onChange(of: isTimePickerExpanded) { expanded in
                    if expanded { isDatePickerExpanded = false }
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionHeader("Активности")

            LazyVGrid(columns: Self.twoColumns, spacing: 12) {
                ForEach(ActivityType.allCases) { activity in
                    SelectableCard(
                        emoji: activity.emoji,
                        title: activity.title,
                        isSelected: selectedActivities.contains(activity)
                    ) {
                        toggle(activity, in: &selectedActivities)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionHeader("Детали")

            VStack(spacing: 12) {
                AddEventDetailCheckboxRow(
                    title: "Использовалась защита",
                    isOn: $protection
                )

                AddEventDetailCheckboxRow(
                    title: "Она кончила 💫",
                    isOn: $femaleOrgasm
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var toysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionHeader("Игрушки")

            LazyVGrid(columns: Self.twoColumns, spacing: 12) {
                ForEach(ToyType.allCases) { toy in
                    SelectableCard(
                        emoji: toy.emoji,
                        title: toy.title,
                        isSelected: selectedToys.contains(toy)
                    ) {
                        toggle(toy, in: &selectedToys)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var finishSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionHeader("Окончание")

            FlowLayout(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(FinishType.allCases) { option in
                    FilterChip(
                        title: option.title,
                        isSelected: finish == option
                    ) {
                        finish = option
                    }
                    .fixedSize()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionHeader("Заметки")

            VStack(alignment: .trailing, spacing: 8) {
                TextField("Заметки...", text: $notes, axis: .vertical)
                    .lineLimit(4...8)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.primaryText)
                    .onChange(of: notes) { newValue in
                        if newValue.count > notesLimit {
                            notes = String(newValue.prefix(notesLimit))
                        }
                    }

                Text("\(notes.count)/\(notesLimit)")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(notes.count >= notesLimit ? AppTheme.accent : AppTheme.secondaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EventFormStyle.unselectedSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var floatingSaveButton: some View {
        createButton
            .primaryActionButtonFloatingShadow()
            .padding(.trailing, AppTheme.screenHorizontalPadding)
            .padding(.bottom, 12)
    }

    private var createButton: some View {
        PrimaryActionButton(
            title: isEditMode ? "Сохранить" : "Создать",
            isEnabled: canSave,
            isLoading: isSaving,
            expandsHorizontally: false,
            action: saveAndDismiss
        )
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !selectedActivities.isEmpty && !isSaving
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func date(fromDay day: Date, keepingTimeFrom timeSource: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        let time = calendar.dateComponents([.hour, .minute], from: timeSource)
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components) ?? day
    }

    private func saveAndDismiss() {
        saveEvent()
    }

    private func saveEvent() {
        guard canSave else { return }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let toys = Array(selectedToys)
        UXFeedback.mediumImpact()
        isSaving = true

        if let eventToEdit {
            let updated = Event(
                id: eventToEdit.id,
                date: date,
                duration: 0,
                activities: Array(selectedActivities),
                protection: protection,
                femaleOrgasm: femaleOrgasm,
                finish: finish,
                toys: toys,
                notes: trimmedNotes,
                createdBy: eventToEdit.createdBy
            )
            Task {
                await store.updateEventAndWaitForUploads(updated)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            }
        } else {
            let event = Event(
                id: UUID().uuidString,
                date: date,
                duration: 0,
                activities: Array(selectedActivities),
                protection: protection,
                femaleOrgasm: femaleOrgasm,
                finish: finish,
                toys: toys,
                notes: trimmedNotes,
                createdBy: authService.userID.isEmpty ? "local-user" : authService.userID
            )
            Task {
                await store.addEventAndWaitForUploads(event)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            }
        }
    }

    private func toggle<T: Hashable>(_ item: T, in set: inout Set<T>) {
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
    }

    private static let twoColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]
}

// MARK: - Subviews

private struct AddEventDetailCheckboxRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(isOn ? EventFormStyle.selectedLabel : EventFormStyle.unselectedLabel)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                EventFormCheckbox(isOn: isOn)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
                    .fill(isOn ? EventFormStyle.selectedTintBackground : EventFormStyle.surfaceBackground)
            )
            .overlay {
                if isOn {
                    RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
                        .strokeBorder(EventFormStyle.selectedBorderColor, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SelectableCard: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                action()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Text(emoji)
                        .font(.system(size: 32, weight: .regular, design: .default))

                    Text(title)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? EventFormStyle.selectedLabel : EventFormStyle.unselectedLabel)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .padding(.horizontal, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
                                .fill(EventFormStyle.selectedTintBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
                                        .strokeBorder(EventFormStyle.selectedBorderColor, lineWidth: 1)
                                )
                        } else {
                            EventFormStyle.unselectedSurface
                        }
                    }
                )

                EventFormCheckbox(isOn: isSelected)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(x: isSelected ? 1.03 : 1.0, y: isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
    }
}

private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 10
    var verticalSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let resolved = proposal.replacingUnspecifiedDimensions()
        return arrange(
            maxWidth: resolved.width,
            subviews: subviews,
            in: .zero,
            placeSubviews: false
        ).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        _ = arrange(
            maxWidth: bounds.width,
            subviews: subviews,
            in: bounds,
            placeSubviews: true
        )
    }

    private func arrange(
        maxWidth: CGFloat,
        subviews: Subviews,
        in bounds: CGRect,
        placeSubviews: Bool
    ) -> (size: CGSize, positions: [CGPoint]) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX > bounds.minX, currentX + size.width > bounds.minX + maxWidth {
                currentX = bounds.minX
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            if placeSubviews {
                subview.place(
                    at: CGPoint(x: currentX, y: currentY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            usedWidth = max(usedWidth, currentX + size.width - bounds.minX)
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        let totalHeight = max(0, currentY + rowHeight - bounds.minY)
        return (CGSize(width: usedWidth, height: totalHeight), positions)
    }
}

#Preview {
    AddEventView()
        .environmentObject(EventStore())
        .environmentObject(AuthService())
}
