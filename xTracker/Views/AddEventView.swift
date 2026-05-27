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

    @State private var date: Date
    @State private var selectedActivities: Set<ActivityType>
    @State private var protection: Bool
    @State private var femaleOrgasm: Bool
    @State private var usesToys: Bool
    @State private var selectedToys: Set<ToyType>
    @State private var finish: FinishType
    @State private var notes: String
    @State private var isSaving = false

    private var isEditMode: Bool { eventToEdit != nil }

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
        _usesToys = State(initialValue: !(eventToEdit?.toys.isEmpty ?? true))
        _selectedToys = State(initialValue: Set(eventToEdit?.toys ?? []))
        _finish = State(initialValue: eventToEdit?.finish ?? .condom)
        _notes = State(initialValue: eventToEdit?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.cardSpacing) {
                    dateTimeSection
                    activitiesSection
                    protectionSection
                    femaleOrgasmSection
                    toysSection
                    finishSection
                    notesSection
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 12)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.background)
            .navigationTitle(isEditMode ? "Редактировать" : "Новое событие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundColor(.gray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveAndDismiss) {
                        Image(systemName: "checkmark")
                            .foregroundColor(saveButtonTextColor)
                            .animation(.easeInOut(duration: 0.2), value: selectedActivities.isEmpty)
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var dateTimeSection: some View {
        FormSection(title: "Дата и время") {
            DatePicker(
                "",
                selection: $date,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .colorScheme(.dark)
            .tint(AppTheme.accent)
            .environment(\.locale, Locale(identifier: "ru_RU"))
        }
    }

    private var activitiesSection: some View {
        FormSection(title: "Активности") {
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
    }

    private var protectionSection: some View {
        ToggleRowCard {
            Toggle(isOn: $protection) {
                Text("Использовалась защита")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.primaryText)
            }
            .tint(AppTheme.accent)
        }
    }

    private var femaleOrgasmSection: some View {
        ToggleRowCard {
            Toggle(isOn: $femaleOrgasm) {
                Text("Она кончила 💫")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.primaryText)
            }
            .tint(AppTheme.accent)
        }
    }

    private var toysSection: some View {
        ToggleRowCard {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $usesToys) {
                    Text("Использовались игрушки?")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.primaryText)
                }
                .tint(AppTheme.accent)
                .onChange(of: usesToys) { isOn in
                    if !isOn {
                        selectedToys.removeAll()
                    }
                }

                if usesToys {
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
            }
        }
    }

    private var finishSection: some View {
        FormSection(title: "Окончание") {
            FlowLayout(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(FinishType.allCases) { option in
                    FinishPill(
                        title: option.title,
                        isSelected: finish == option
                    ) {
                        finish = option
                    }
                    .fixedSize()
                }
            }
        }
    }

    private var notesSection: some View {
        FormSection(title: "Заметки") {
            VStack(alignment: .trailing, spacing: 6) {
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
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !selectedActivities.isEmpty && !isSaving
    }

    private var saveButtonTextColor: Color {
        selectedActivities.isEmpty ? .gray : AppTheme.accent
    }

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
        let toys = usesToys ? Array(selectedToys) : []
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

private struct FormSection<Content: View>: View {
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

private struct ToggleRowCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSectionCard()
    }
}

private enum AddEventCardStyle {
    static let unselectedBackground = Color.white.opacity(0.07)
    static let unselectedLabel = Color(hex: "#C0C0C0")
}

private struct SelectableCard: View {
    let emoji: String
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
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 32, weight: .regular, design: .default))

                Text(title)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundStyle(isSelected ? AppTheme.primaryText : AddEventCardStyle.unselectedLabel)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius)
                    .fill(isSelected ? AppTheme.accent : AddEventCardStyle.unselectedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius)
                    .stroke(isSelected ? AppTheme.accent : AppTheme.cardBorder, lineWidth: AppTheme.cardBorderWidth)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

private struct FinishPill: View {
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
                .foregroundStyle(isSelected ? AppTheme.primaryText : AddEventCardStyle.unselectedLabel)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isSelected ? AppTheme.accent : AddEventCardStyle.unselectedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isSelected ? AppTheme.accent : AppTheme.cardBorder, lineWidth: AppTheme.cardBorderWidth)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
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
