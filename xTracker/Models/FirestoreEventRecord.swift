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

    init(from event: Event) {
        id = event.id
        date = event.date
        duration = 0
        activities = event.activities.map(\.rawValue)
        protection = event.protection
        femaleOrgasm = event.femaleOrgasm
        finish = event.finish.rawValue
        toys = event.toys.map(\.rawValue)
        notes = event.notes
        createdBy = event.createdBy
    }

    func toEvent() -> Event? {
        guard let finishType = FinishType(rawValue: finish) else { return nil }

        let activityTypes = activities.compactMap { ActivityType(rawValue: $0) }
        let toyTypes = toys.compactMap { ToyType(rawValue: $0) }

        return Event(
            id: id,
            date: date,
            duration: 0,
            activities: activityTypes,
            protection: protection,
            femaleOrgasm: femaleOrgasm,
            finish: finishType,
            toys: toyTypes,
            notes: notes,
            createdBy: createdBy
        )
    }
}
