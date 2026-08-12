//
//  UserActivity.swift
//  xTracker
//

import Foundation

struct UserActivity: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var title: String
    var emoji: String
    var isArchived: Bool

    init(
        id: String,
        title: String,
        emoji: String,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.isArchived = isArchived
    }
}

enum DefaultUserActivities {
    static let seed: [UserActivity] = [
        UserActivity(id: "sex", title: "Секс", emoji: "🔥"),
        UserActivity(id: "blowjob", title: "Минет", emoji: "💋"),
        UserActivity(id: "cunnilingus", title: "Кунилингус", emoji: "👅"),
        UserActivity(id: "anal", title: "Анал", emoji: "🍑"),
        UserActivity(id: "masturbation", title: "Мастурбация", emoji: "🤚"),
        UserActivity(id: "handjob", title: "Дрочка партнеру", emoji: "🤝"),
    ]
}
