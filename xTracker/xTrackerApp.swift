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
    @StateObject private var activityCatalog = ActivityCatalogStore()

    init() {
        AppFont.registerBundledFonts()
        #if DEBUG
        if !AppFont.isLoaded {
            assertionFailure("[AppFont] Manrope is not available — check UIAppFonts and bundled TTFs.")
        }
        #endif
        FirebaseApp.configure()

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [
            .font: AppFont.uiFont(size: 34, weight: .bold),
            .kern: -0.5,
        ]
        appearance.titleTextAttributes = [
            .font: AppFont.uiFont(size: 17, weight: .semibold),
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
                .environmentObject(activityCatalog)
                .task {
                    if AppFeatures.eventPlannerEnabled {
                        await NotificationService.shared.requestAuthorizationIfNeeded()
                    }
                    await authService.bootstrap()
                    if authService.isPartnerConnected,
                       authService.pairID != authService.pairCode {
                        try? await userService.ensureProfileOnSyncPair(
                            from: authService.pairCode,
                            to: authService.pairID,
                            userID: authService.userID,
                            fallbackName: SettingsStore.userName,
                            avatarData: SettingsStore.avatarImage?.jpegData(compressionQuality: 0.85)
                        )
                    }
                    if !authService.pairID.isEmpty {
                        store.setPairID(authService.pairID)
                    }
                    userService.startListeners(
                        pairID: authService.pairID,
                        userID: authService.userID,
                        partnerID: authService.partnerID
                    )
                    if authService.isPartnerConnected {
                        await userService.prefetchPartnerProfile(
                            partnerID: authService.partnerID,
                            syncPairID: authService.pairID
                        )
                    }
                    if AppFeatures.eventPlannerEnabled {
                        NotificationService.shared.startListening(forUserID: authService.userID)
                    }
                }
                .onChange(of: authService.pairID) { newPairID in
                    Task {
                        let previousPairID = store.pairID
                        store.setPairID(newPairID, force: previousPairID != newPairID)
                        userService.startListeners(
                            pairID: authService.pairID,
                            userID: authService.userID,
                            partnerID: authService.partnerID
                        )
                    }
                }
                .onChange(of: authService.userID) { newUserID in
                    userService.startListeners(
                        pairID: authService.pairID,
                        userID: authService.userID,
                        partnerID: authService.partnerID
                    )
                    if AppFeatures.eventPlannerEnabled {
                        NotificationService.shared.startListening(forUserID: newUserID)
                    }
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
