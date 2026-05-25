//
//  Event.swift
//  xTracker
//

import Foundation

struct Event: Identifiable, Codable {
    var id: String
    var date: Date
    var duration: Int
    var activities: [ActivityType]
    var protection: Bool
    var femaleOrgasm: Bool = false
    var finish: FinishType
    var toys: [ToyType]
    var notes: String
    var createdBy: String
}
