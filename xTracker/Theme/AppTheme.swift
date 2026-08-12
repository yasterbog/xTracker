//
//  AppTheme.swift
//  xTracker
//

import SwiftUI
import UIKit

enum AppTheme {
    static let background = Color(hex: "#0D0C0C")
    /// Unified surface for cards/chips/controls.
    static let surfaceFill = Color(hex: "#1D1B1B").opacity(0.5)
    static let primaryText = Color.white
    static let appWhite = Color.white
    static let secondaryText = Color(hex: "#787878")
    static let sectionHeaderText = Color(hex: "#787878")
    static let sectionTitleText = primaryText
    static let cardBackground = Color(hex: "#121212")
    static let subtleSurfaceBackground = surfaceFill
    static let pairFieldBackground = Color(hex: "#111111")
    static let successGreen = Color(hex: "#34C759")
    static let cardBorder = Color(hex: "#1F1F1F")
    static let cardBorderWidth: CGFloat = 1
    static let separator = Color.white.opacity(0.06)
    static let accent = Color(hex: "#E82757")
    static let eventDot = Color(red: 0.35, green: 0.55, blue: 1.0)
    static let mutedDay = Color.white.opacity(0.50)

    static let screenTitleFont = AppFont.font(size: 28, weight: .bold)
    static let bodyFont = AppFont.font(size: 16, weight: .semibold)
    static let captionFont = AppFont.font(size: 13, weight: .semibold)
    static let statsNumberFont = AppFont.font(size: 36, weight: .bold)
    static let sectionHeaderFont = AppFont.font(size: 11, weight: .semibold)
    static let sectionTitleFont = AppFont.font(size: 15, weight: .semibold)
    static let cardCornerRadius: CGFloat = 20
    static let compactCardCornerRadius: CGFloat = 24
    static let screenHorizontalPadding: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let cardSpacing: CGFloat = 12
    /// Bottom scroll padding so content can pass under the floating tab bar (~56pt bar + 12pt offset + home indicator).
    static let floatingTabBarScrollClearance: CGFloat = 88

    static var scrollBackdropHeight: CGFloat {
        UIScreen.main.bounds.height
    }

    static func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(sectionHeaderFont)
            .kerning(0)
            .foregroundStyle(sectionHeaderText)
    }

    static func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(sectionTitleFont)
            .kerning(0)
            .foregroundStyle(sectionTitleText)
    }

    static func applyLargeNavigationTitleAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.largeTitleTextAttributes = [
            .font: AppFont.uiFont(size: 34, weight: .bold),
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

extension View {
    /// Ambient layer that scrolls with the screen content (not pinned to the viewport).
    func ambientScrollBackdrop(
        gradientStart: UnitPoint = .top,
        gradientEnd: UnitPoint = .bottom
    ) -> some View {
        frame(maxWidth: .infinity, minHeight: AppTheme.scrollBackdropHeight, alignment: .top)
            .background {
                ZStack(alignment: .top) {
                    AppTheme.background
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    AmbientBackground(startPoint: gradientStart, endPoint: gradientEnd)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppTheme.scrollBackdropHeight)
                        .allowsHitTesting(false)
                }
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

  func appScreenBackground() -> some View {
    background(AppTheme.background.ignoresSafeArea())
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
