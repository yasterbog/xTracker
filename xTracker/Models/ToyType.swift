//
//  ToyType.swift
//  xTracker
//

import Foundation

enum ToyType: String, CaseIterable, Codable, Identifiable {
    case plugAnal
    case dildo
    case vibrator
    case masturbatorEgg
    case handcuffs
    case blindfold
    case gag

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plugAnal: "Анальная пробка"
        case .dildo: "Дилдо"
        case .vibrator: "Вибратор"
        case .masturbatorEgg: "Мастурбатор-яйцо"
        case .handcuffs: "Наручники"
        case .blindfold: "Повязка на глаза"
        case .gag: "Кляп"
        }
    }

    var emoji: String {
        switch self {
        case .plugAnal: "🔌"
        case .dildo: "🍆"
        case .vibrator: "📳"
        case .masturbatorEgg: "🥚"
        case .handcuffs: "⛓️"
        case .blindfold: "🙈"
        case .gag: "👄"
        }
    }
}
