//
//  ActivityCatalogStore.swift
//  xTracker
//

import Combine
import Foundation

@MainActor
final class ActivityCatalogStore: ObservableObject {
    @Published private(set) var activities: [UserActivity] = []

    var selectableActivities: [UserActivity] {
        activities.filter { !$0.isArchived }
    }

    var selectableActivityIDs: Set<String> {
        Set(selectableActivities.map(\.id))
    }

    init() {
        load()
    }

    func load() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let decoded = try? JSONDecoder().decode([UserActivity].self, from: data),
            !decoded.isEmpty
        else {
            activities = DefaultUserActivities.seed
            save()
            return
        }

        activities = decoded
    }

    func resetToDefaults() {
        activities = DefaultUserActivities.seed
        save()
    }

    func activity(for id: String) -> UserActivity? {
        activities.first { $0.id == id }
    }

    func displayActivity(for id: String) -> UserActivity {
        if let activity = activity(for: id) {
            return activity
        }

        return UserActivity(id: id, title: "Активность", emoji: "✨", isArchived: true)
    }

    func displayEmoji(for id: String) -> String {
        displayActivity(for: id).emoji
    }

    func colorIndex(for activityID: String) -> Int {
        selectableActivities.firstIndex { $0.id == activityID }
            ?? activities.firstIndex { $0.id == activityID }
            ?? 0
    }

    func addActivity(title: String, emoji: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedEmoji.isEmpty else { return }

        let activity = UserActivity(
            id: UUID().uuidString,
            title: trimmedTitle,
            emoji: String(trimmedEmoji.prefix(1))
        )
        activities.append(activity)
        save()
    }

    func updateActivity(id: String, title: String, emoji: String) {
        guard let index = activities.firstIndex(where: { $0.id == id }) else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedEmoji.isEmpty else { return }

        activities[index].title = trimmedTitle
        activities[index].emoji = String(trimmedEmoji.prefix(1))
        save()
    }

    func archiveActivity(id: String) {
        guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
        activities[index].isArchived = true
        save()
    }

    func moveActivities(from source: IndexSet, to destination: Int) {
        var visible = selectableActivities
        visible = Self.reordered(visible, fromOffsets: source, toOffset: destination)

        let archived = activities.filter(\.isArchived)
        activities = visible + archived
        save()
    }

    private static func reordered<T>(
        _ items: [T],
        fromOffsets: IndexSet,
        toOffset: Int
    ) -> [T] {
        guard !fromOffsets.isEmpty else { return items }

        var result = items
        let movingItems = fromOffsets.sorted().map { result[$0] }

        for index in fromOffsets.sorted(by: >) {
            result.remove(at: index)
        }

        let insertIndex = toOffset - fromOffsets.filter { $0 < toOffset }.count
        result.insert(contentsOf: movingItems, at: min(max(insertIndex, 0), result.count))
        return result
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(activities) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static let storageKey = "settings.userActivities"
}
