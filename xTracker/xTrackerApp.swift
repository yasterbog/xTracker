//
//  xTrackerApp.swift
//  xTracker
//
//  Created by Nikita on 22.05.2026.
//

import FirebaseCore
import SwiftUI
import UIKit

@main
struct xTrackerApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var userService = UserService()
    @StateObject private var store = EventStore()

    init() {
        FirebaseApp.configure()

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .black),
            .kern: -0.5,
        ]
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(authService)
                .environmentObject(userService)
                .task {
                    await authService.bootstrap()
                    if !authService.pairID.isEmpty {
                        store.setPairID(authService.pairID)
                    }
                    userService.startListeners(
                        pairID: authService.pairID,
                        userID: authService.userID,
                        partnerID: authService.partnerID
                    )
                }
                .onChange(of: authService.pairID) { newPairID in
                    store.setPairID(newPairID)
                    userService.startListeners(
                        pairID: authService.pairID,
                        userID: authService.userID,
                        partnerID: authService.partnerID
                    )
                }
                .onChange(of: authService.userID) { _ in
                    userService.startListeners(
                        pairID: authService.pairID,
                        userID: authService.userID,
                        partnerID: authService.partnerID
                    )
                }
                .onChange(of: authService.partnerID) { _ in
                    userService.startListeners(
                        pairID: authService.pairID,
                        userID: authService.userID,
                        partnerID: authService.partnerID
                    )
                }
        }
    }
}
