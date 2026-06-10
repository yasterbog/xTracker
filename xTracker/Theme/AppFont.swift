//
//  AppFont.swift
//  xTracker
//

import CoreText
import SwiftUI
import UIKit

/// Manrope — maps legacy weights to the closest face (ExtraBold is max for heavier-than-bold).
enum AppFont {
    private static let bundleFontFiles = [
        "Manrope-Regular",
        "Manrope-Medium",
        "Manrope-SemiBold",
        "Manrope-Bold",
        "Manrope-ExtraBold",
    ]

    static let regularPSName = "Manrope-Regular"
    static let mediumPSName = "Manrope-Medium"
    static let semiBoldPSName = "Manrope-SemiBold"
    static let boldPSName = "Manrope-Bold"
    static let blackPSName = "Manrope-ExtraBold"

    /// Manrope is listed in `UIAppFonts` (xTracker-Info.plist) and loads at launch.
    /// Runtime registration is a fallback only when plist loading did not run.
    static func registerBundledFonts() {
        guard UIFont(name: regularPSName, size: 12) == nil else { return }

        for name in bundleFontFiles {
            guard let url = bundledFontURL(named: name) else { continue }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }

    private static func bundledFontURL(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "ttf")
            ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
    }

    // MARK: - SwiftUI

    /// Builds from `UIFont` so SwiftUI does not silently fall back to SF Pro (`Font.custom` often does).
    static func font(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        Font(uiFont(size: size, swiftWeight: weight))
    }

    static var isLoaded: Bool {
        UIFont(name: semiBoldPSName, size: 12) != nil
    }

    static func postScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .black, .heavy:
            return blackPSName
        case .bold:
            return boldPSName
        case .semibold:
            return semiBoldPSName
        case .medium:
            return mediumPSName
        case .regular:
            return semiBoldPSName
        default:
            return semiBoldPSName
        }
    }

    // MARK: - UIKit

    static func uiFont(size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
        let name = postScriptName(for: weight)
        return UIFont(name: name, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: weight)
    }

    static func uiFont(size: CGFloat, swiftWeight: Font.Weight) -> UIFont {
        uiFont(size: size, weight: uiWeight(from: swiftWeight))
    }

    static func postScriptName(for weight: UIFont.Weight) -> String {
        switch weight {
        case .black, .heavy:
            return blackPSName
        case .bold:
            return boldPSName
        case .semibold:
            return semiBoldPSName
        case .medium:
            return mediumPSName
        case .regular:
            return semiBoldPSName
        default:
            return semiBoldPSName
        }
    }

    static func uiWeight(from weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .black, .heavy:
            return .black
        case .bold:
            return .bold
        case .semibold, .regular:
            return .semibold
        case .medium:
            return .medium
        default:
            return .semibold
        }
    }
}
