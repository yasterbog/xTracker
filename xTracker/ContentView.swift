//
//  ContentView.swift
//  xTracker
//

import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        TabView {
            CalendarView()
                .tabItem {
                    Image("icon_calendar")
                        .renderingMode(.template)
                }

            StatisticsView()
                .tabItem {
                    Image("icon_stats")
                        .renderingMode(.template)
                }

            SettingsView()
                .tabItem {
                    Image("icon_settings")
                        .renderingMode(.template)
                }
        }
        .tint(AppTheme.accent)
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
