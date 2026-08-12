//
//  Event.swift
//  xTracker
//

import Foundation

struct Event: Identifiable, Codable {
    var id: String
    var date: Date
    var duration: Int
    var activities: [String]
    var protection: Bool
    var femaleOrgasm: Bool = false
    var finish: FinishType
    var toys: [ToyType]
    var notes: String
    var createdBy: String
    var createdAt: Date
    var status: EventStatus = .completed

    var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        id: String,
        date: Date,
        duration: Int,
        activities: [String],
        protection: Bool,
        femaleOrgasm: Bool = false,
        finish: FinishType,
        toys: [ToyType],
        notes: String,
        createdBy: String,
        createdAt: Date = Date(),
        status: EventStatus = .completed
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.activities = activities
        self.protection = protection
        self.femaleOrgasm = femaleOrgasm
        self.finish = finish
        self.toys = toys
        self.notes = notes
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        duration = try container.decode(Int.self, forKey: .duration)

        if let activityIDs = try? container.decode([String].self, forKey: .activities) {
            activities = activityIDs
        } else {
            activities = []
        }

        protection = try container.decode(Bool.self, forKey: .protection)
        femaleOrgasm = try container.decodeIfPresent(Bool.self, forKey: .femaleOrgasm) ?? false
        finish = try container.decode(FinishType.self, forKey: .finish)
        toys = try container.decode([ToyType].self, forKey: .toys)
        notes = try container.decode(String.self, forKey: .notes)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? date
        status = (try? container.decode(EventStatus.self, forKey: .status)) ?? .completed
    }
}
