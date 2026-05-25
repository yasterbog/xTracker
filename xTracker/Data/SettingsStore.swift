//
//  SettingsStore.swift
//  xTracker
//

import Foundation
import UIKit

enum SettingsStore {
    enum Keys {
        static let userName = "settings.userName"
        static let calendarName = "settings.calendarName"
        static let myPartnerCode = "settings.myPartnerCode"
        static let partnerConnected = "settings.partnerConnected"
        static let avatarImageData = "settings.avatarImageData"
    }

    static let defaultUserName = "Моё имя"
    static let defaultCalendarName = "Наш календарь"

    static var userName: String {
        get { UserDefaults.standard.string(forKey: Keys.userName) ?? defaultUserName }
        set { UserDefaults.standard.set(newValue, forKey: Keys.userName) }
    }

    static var calendarName: String {
        get { UserDefaults.standard.string(forKey: Keys.calendarName) ?? defaultCalendarName }
        set { UserDefaults.standard.set(newValue, forKey: Keys.calendarName) }
    }

    static var myPartnerCode: String {
        if let code = UserDefaults.standard.string(forKey: Keys.myPartnerCode) {
            return code
        }
        let code = generatePartnerCode()
        UserDefaults.standard.set(code, forKey: Keys.myPartnerCode)
        return code
    }

    static var isPartnerConnected: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.partnerConnected) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.partnerConnected) }
    }

    static var avatarImage: UIImage? {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.avatarImageData) else { return nil }
            return UIImage(data: data)
        }
        set {
            if let newValue, let data = newValue.jpegData(compressionQuality: 0.85) {
                UserDefaults.standard.set(data, forKey: Keys.avatarImageData)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.avatarImageData)
            }
        }
    }

    static func initials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }

        let parts = trimmed.split(separator: " ")
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let second = parts[1].prefix(1)
            return "\(first)\(second)".uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    static func deleteAllData() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.userName)
        defaults.removeObject(forKey: Keys.calendarName)
        defaults.removeObject(forKey: Keys.myPartnerCode)
        defaults.removeObject(forKey: Keys.partnerConnected)
        defaults.removeObject(forKey: Keys.avatarImageData)
    }

    private static func generatePartnerCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

enum MockPartner {
    static let name = "Анна"
    static let initials = "АН"
}
