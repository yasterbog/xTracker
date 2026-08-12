//
//  FirestoreEventRecord.swift
//  xTracker
//

import Foundation

/// Firestore-serializable event payload.
struct FirestoreEventRecord: Codable {
    var id: String
    var date: Date
    var duration: Int
    var activities: [String]
    var protection: Bool
    var femaleOrgasm: Bool
    var finish: String
    var toys: [String]
    var notes: String
    var createdBy: String
    var createdAt: Date
    var status: String?

    init(from event: Event) {
        id = event.id
        date = event.date
        duration = 0
        activities = event.activities
        protection = event.protection
        femaleOrgasm = event.femaleOrgasm
        finish = event.finish.rawValue
        toys = event.toys.map(\.rawValue)
        notes = event.notes
        createdBy = event.createdBy
        createdAt = event.createdAt
        status = event.status.rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        duration = try container.decode(Int.self, forKey: .duration)
        activities = try container.decode([String].self, forKey: .activities)
        protection = try container.decode(Bool.self, forKey: .protection)
        femaleOrgasm = try container.decodeIfPresent(Bool.self, forKey: .femaleOrgasm) ?? false
        finish = try container.decode(String.self, forKey: .finish)
        toys = try container.decode([String].self, forKey: .toys)
        notes = try container.decode(String.self, forKey: .notes)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? date
        status = try container.decodeIfPresent(String.self, forKey: .status)
    }

    func toEvent() -> Event? {
        guard let finishType = FinishType(rawValue: finish) else { return nil }

        let toyTypes = toys.compactMap { ToyType(rawValue: $0) }
        let eventStatus = EventStatus(rawValue: status ?? "") ?? .completed

        return Event(
            id: id,
            date: date,
            duration: 0,
            activities: activities,
            protection: protection,
            femaleOrgasm: femaleOrgasm,
            finish: finishType,
            toys: toyTypes,
            notes: notes,
            createdBy: createdBy,
            createdAt: createdAt,
            status: eventStatus
        )
    }
}
