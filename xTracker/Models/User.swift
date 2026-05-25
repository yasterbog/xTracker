//
//  User.swift
//  xTracker
//

import Foundation

struct User: Identifiable, Codable {
    var id: String
    var name: String
    var avatarURL: String
    var calendarName: String
    var partnerID: String
}
