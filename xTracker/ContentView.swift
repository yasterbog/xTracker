 //
//  ContentView.swift
//  xTracker
//

import SwiftUI
import UIKit

struct ContentView: View {
    private enum MainTab: Hashable {
        case calendar
        case statistics
        case settings
    }

    @State private var selectedTab: MainTab = .calendar
    @State private var gradientStart: UnitPoint = .top
    @State private var gradientEnd: UnitPoint = .bottomTrailing

    private func animateGradient() {
        let starts: [UnitPoint] = [.topLeading, .topTrailing, .top]
        let ends: [UnitPoint] = [.bottomLeading, .bottomTrailing, .bottom, .leading, .trailing]

        withAnimation(.easeInOut(duration: 2.0)) {
            gradientStart = starts.randomElement() ?? .top
            gradientEnd = ends.randomElement() ?? .bottomTrailing
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView(
                gradientStart: gradientStart,
                gradientEnd: gradientEnd
            )
                .tag(MainTab.calendar)
                .tabItem {
                    Image("icon_calendar")
                        .renderingMode(.template)
                }

            StatisticsView(
                gradientStart: gradientStart,
                gradientEnd: gradientEnd,
                onAnimateGradient: animateGradient
            )
                .tag(MainTab.statistics)
                .tabItem {
                    Image("icon_stats")
                        .renderingMode(.template)
                }

            SettingsView(
                gradientStart: gradientStart,
                gradientEnd: gradientEnd
            )
                .tag(MainTab.settings)
                .tabItem {
                    Image("icon_settings")
                        .renderingMode(.template)
                }
        }
        .tint(AppTheme.accent)
        .onChange(of: selectedTab) { _ in
            animateGradient()
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            let accentUIColor = UIColor(red: 255 / 255, green: 59 / 255, blue: 111 / 255, alpha: 1)
            appearance.configureWithDefaultBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            appearance.backgroundColor = UIColor.black.withAlphaComponent(0.35)
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray.withAlphaComponent(0.4)
            appearance.stackedLayoutAppearance.selected.iconColor = accentUIColor
            appearance.inlineLayoutAppearance.normal.iconColor = UIColor.gray.withAlphaComponent(0.4)
            appearance.inlineLayoutAppearance.selected.iconColor = accentUIColor
            appearance.compactInlineLayoutAppearance.normal.iconColor = UIColor.gray.withAlphaComponent(0.4)
            appearance.compactInlineLayoutAppearance.selected.iconColor = accentUIColor

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().unselectedItemTintColor = UIColor.gray.withAlphaComponent(0.4)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(EventStore())
        .environmentObject(AuthService())
        .environmentObject(UserService())
}
