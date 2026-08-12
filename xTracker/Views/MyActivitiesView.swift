//
//  MyActivitiesView.swift
//  xTracker
//

import SwiftUI

struct MyActivitiesView: View {
    @EnvironmentObject private var activityCatalog: ActivityCatalogStore

    @State private var activityToEdit: UserActivity?
    @State private var showCreateSheet = false
    @State private var swipingActivityID: String?

    var body: some View {
        List {
            ForEach(activityCatalog.selectableActivities) { activity in
                ActivityManagementRow(activity: activity)
                    .contentShape(RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous))
                    .eventCardChrome(isVisible: swipingActivityID == activity.id)
                    .background {
                        SwipeInteractionObserver(isSwiping: swipeBinding(for: activity.id))
                    }
                    .onTapGesture {
                        activityToEdit = activity
                    }
                    .draggable(activity.id)
                    .dropDestination(for: String.self) { items, _ in
                        guard let draggedID = items.first else { return false }
                        reorderActivities(draggedID: draggedID, before: activity.id)
                        return true
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            activityCatalog.archiveActivity(id: activity.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(
                        EdgeInsets(
                            top: 5,
                            leading: AppTheme.screenHorizontalPadding,
                            bottom: 5,
                            trailing: AppTheme.screenHorizontalPadding
                        )
                    )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, 12)
        .appScreenBackground()
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppTheme.floatingTabBarScrollClearance)
        }
        .sheetInlineHeader("Мои активности") {
            Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $activityToEdit) { activity in
            ActivityEditorSheet(
                mode: .edit(activity),
                onSave: { title, emoji in
                    activityCatalog.updateActivity(id: activity.id, title: title, emoji: emoji)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCreateSheet) {
            ActivityEditorSheet(
                mode: .create,
                onSave: { title, emoji in
                    activityCatalog.addActivity(title: title, emoji: emoji)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func reorderActivities(draggedID: String, before targetID: String) {
        let activities = activityCatalog.selectableActivities
        guard let fromIndex = activities.firstIndex(where: { $0.id == draggedID }),
              let toIndex = activities.firstIndex(where: { $0.id == targetID }),
              fromIndex != toIndex else { return }

        let destination = toIndex > fromIndex ? toIndex + 1 : toIndex
        activityCatalog.moveActivities(from: IndexSet(integer: fromIndex), to: destination)
    }

    private func swipeBinding(for activityID: String) -> Binding<Bool> {
        Binding(
            get: { swipingActivityID == activityID },
            set: { isSwiping in
                if isSwiping {
                    swipingActivityID = activityID
                } else if swipingActivityID == activityID {
                    swipingActivityID = nil
                }
            }
        )
    }
}

private struct ActivityManagementRow: View {
    let activity: UserActivity

    var body: some View {
        HStack(spacing: 12) {
            Text(activity.emoji)
                .font(AppFont.font(size: 24, weight: .semibold))
                .frame(width: 32, alignment: .center)

            Text(activity.title)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.compactCardCornerRadius, style: .continuous)
                .fill(EventFormStyle.surfaceBackground)
        )
    }
}

private struct ActivityEditorSheet: View {
    enum Mode {
        case create
        case edit(UserActivity)
    }

    let mode: Mode
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var titleDraft: String
    @State private var emojiDraft: String

    init(mode: Mode, onSave: @escaping (String, String) -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .create:
            _titleDraft = State(initialValue: "")
            _emojiDraft = State(initialValue: "")
        case .edit(let activity):
            _titleDraft = State(initialValue: activity.title)
            _emojiDraft = State(initialValue: activity.emoji)
        }
    }

    private var sheetTitle: String {
        switch mode {
        case .create: "Новая активность"
        case .edit: "Редактировать"
        }
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !trimmedEmoji.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                FloatingLabelTextField(label: "Название", text: $titleDraft)

                FloatingLabelTextField(
                    label: "Символ",
                    text: $emojiDraft,
                    textInputAutocapitalization: .never
                )
                .onChange(of: emojiDraft) { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.count > 1 {
                        emojiDraft = String(trimmed.prefix(1))
                    }
                }

                Spacer(minLength: 0)

                PrimaryActionButton(title: "Сохранить", isEnabled: canSave) {
                    onSave(trimmedTitle, trimmedEmoji)
                    dismiss()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.background)
            .sheetInlineHeader(sheetTitle)
        }
        .preferredColorScheme(.dark)
    }

    private var trimmedTitle: String {
        titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEmoji: String {
        emojiDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
