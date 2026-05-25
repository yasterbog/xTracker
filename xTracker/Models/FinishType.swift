//
//  FinishType.swift
//  xTracker
//

import Foundation

enum FinishType: String, CaseIterable, Codable, Identifiable {
    case condom
    case inside
    case inMouthSwallow
    case inMouthSpit
    case onFace
    case onChest
    case onBelly
    case onBack
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .condom: "В презерватив"
        case .inside: "Внутрь"
        case .inMouthSwallow: "В рот (проглотить)"
        case .inMouthSpit: "В рот (выплюнуть)"
        case .onFace: "На лицо"
        case .onChest: "На грудь"
        case .onBelly: "На живот"
        case .onBack: "На спину"
        case .none: "Не было"
        }
     }
}
