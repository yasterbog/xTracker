//
//  ActivityType.swift
//  xTracker
//

import Foundation

enum ActivityType: String, CaseIterable, Codable, Identifiable {
    case sex
    case anal
    case cunnilingus
    case blowjob
    case masturbation
    case handjob

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sex: "Секс"
        case .blowjob: "Минет"
        case .cunnilingus: "Кунилингус"
        case .anal: "Анал"
        case .masturbation: "Мастурбация"
        case .handjob: "Хэндджоб"
        }
    }

    var emoji: String {
        switch self {
        case .sex: "🔥"
        case .blowjob: "💋"
        case .cunnilingus: "👅"
        case .anal: "🍑"
        case .masturbation: "🤚"
        case .handjob: "🖐️"
        }
    }
}
