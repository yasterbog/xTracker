//
//  AppTheme.swift
//  xTracker
//

import SwiftUI
import UIKit

enum AppTheme {
    static let background = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.gray.opacity(0.5)
    static let sectionHeaderText = Color(hex: "#8A8A8E")
    static let cardBackground = Color(hex: "#121212")
    static let cardBorder = Color(hex: "#1F1F1F")
    static let cardBorderWidth: CGFloat = 1
    static let separator = Color.white.opacity(0.06)
    static let accent = Color(red: 255 / 255, green: 59 / 255, blue: 111 / 255)
    static let eventDot = Color(red: 0.35, green: 0.55, blue: 1.0)
    static let mutedDay = Color.white.opacity(0.25)

    static let screenTitleFont = Font.system(size: 28, weight: .bold, design: .default)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .default)
    static let captionFont = Font.system(size: 13, weight: .regular, design: .default)
    static let statsNumberFont = Font.system(size: 36, weight: .bold, design: .default)
    static let sectionHeaderFont = Font.system(size: 11, weight: .semibold, design: .default)
    static let cardCornerRadius: CGFloat = 20
    static let compactCardCornerRadius: CGFloat = 16
    static let screenHorizontalPadding: CGFloat = 20
    static let cardPadding: CGFloat = 20
    static let cardSpacing: CGFloat = 12

    static func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(sectionHeaderFont)
            .fontWeight(.semibold)
            .kerning(-0.3)
            .foregroundStyle(sectionHeaderText)
    }

    static func applyLargeNavigationTitleAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .black),
            .kern: -0.5,
            .foregroundColor: UIColor.white,
        ]
        UINavigationBar.appearance().largeTitleTextAttributes = appearance.largeTitleTextAttributes
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch sanitized.count {
        case 8:
            red = Double((value & 0xFF00_0000) >> 24) / 255
            green = Double((value & 0x00FF_0000) >> 16) / 255
            blue = Double((value & 0x0000_FF00) >> 8) / 255
            alpha = Double(value & 0x0000_00FF) / 255
        default:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct AmbientGlowBackground: View {
    var startPoint: UnitPoint = .top
    var endPoint: UnitPoint = .bottomTrailing

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(hex: "#FF3B6F").opacity(0.16),
                    Color(hex: "#FF3B6F").opacity(0.04),
                    Color.clear,
                ],
                startPoint: startPoint,
                endPoint: endPoint
            )
            .ignoresSafeArea()
        }
    }
}

extension View {
    func ambientMainScreen(
        gradientStart: UnitPoint = .top,
        gradientEnd: UnitPoint = .bottomTrailing
    ) -> some View {
        ZStack {
            AmbientGlowBackground(startPoint: gradientStart, endPoint: gradientEnd)
            self
        }
    }

  @ViewBuilder
  func appLargeNavigationTitle() -> some View {
    Group {
      if #available(iOS 17.0, *) {
        self.toolbarTitleDisplayMode(.large)
      } else {
        self.navigationBarTitleDisplayMode(.large)
      }
    }
    .onAppear {
      AppTheme.applyLargeNavigationTitleAppearance()
    }
  }

  @ViewBuilder
  func chipScrollAllowsOverflow() -> some View {
    if #available(iOS 17.0, *) {
      scrollClipDisabled()
    } else {
      self
    }
  }

  func appCardSurface(cornerRadius: CGFloat) -> some View {
    background(
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(AppTheme.cardBackground)
    )
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(AppTheme.cardBorder, lineWidth: AppTheme.cardBorderWidth)
    )
  }

  func glassCardSurface(cornerRadius: CGFloat = 20) -> some View {
    background(Color.white.opacity(0.07))
      .cornerRadius(cornerRadius)
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(
            LinearGradient(
              colors: [
                Color.white.opacity(0.18),
                Color.white.opacity(0.03),
                Color.white.opacity(0.08),
                Color.white.opacity(0.03),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      )
  }
}
