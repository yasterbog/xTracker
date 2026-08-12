//
//  PairSettingsView.swift
//  xTracker
//

import SwiftUI
import UIKit

struct PairSettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var userService: UserService

    @State private var showPartnerSheet = false
    @State private var partnerCodeInput = ""
    @State private var showPartnerSuccessAlert = false
    @State private var didCopyCode = false
    @State private var showDisconnectPartnerAlert = false
    @State private var isDisconnectingPartner = false
    @State private var avatarImage: UIImage? = SettingsStore.avatarImage

    var body: some View {
        ScrollView {
            SettingsStatsCard {
                VStack(alignment: .leading, spacing: 20) {
                    PairConnectionDiagram(
                        isPartnerConnected: authService.isPartnerConnected,
                        ownAvatarImage: avatarImage,
                        ownAvatarBase64: userService.ownAvatarBase64,
                        ownAvatarURL: userService.ownAvatarURL,
                        ownName: userService.ownName.isEmpty ? SettingsStore.defaultUserName : userService.ownName,
                        partnerAvatarBase64: userService.partnerAvatarBase64,
                        partnerAvatarURL: userService.partnerAvatarURL,
                        partnerName: userService.partnerName.isEmpty ? "Партнёр" : userService.partnerName,
                        onAddPartnerTap: openPartnerSheet
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        if !authService.isPartnerConnected {
                            FloatingLabelReadOnlyField(
                                label: "Мой код",
                                value: authService.resolvedPairCode.isEmpty ? "…" : authService.resolvedPairCode,
                                fieldBackgroundColor: AppTheme.pairFieldBackground,
                                trailingIconAsset: "copy",
                                trailingIconSuccessAsset: "copy-success",
                                isTrailingIconSuccess: didCopyCode,
                                trailingIconColor: AppTheme.appWhite,
                                trailingIconSuccessColor: AppTheme.successGreen,
                                onTrailingTap: copyPairCode
                            )
                        }

                        if authService.isPartnerConnected {
                            DestructionActionButton(
                                title: "Отключить партнёра",
                                isEnabled: !isDisconnectingPartner,
                                titleColor: AppTheme.secondaryText
                            ) {
                                showDisconnectPartnerAlert = true
                            }
                        } else {
                            PrimaryActionButton(title: "Подключить партнёра") {
                                openPartnerSheet()
                            }
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: authService.isPartnerConnected)
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.top, 28)
            .padding(.bottom, AppTheme.floatingTabBarScrollClearance)
        }
        .scrollIndicators(.hidden)
        .appScreenBackground()
        .sheetInlineHeader("Пара")
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPartnerSheet) {
            PartnerConnectSheet(partnerCodeInput: $partnerCodeInput) {
                await connectPartner()
            }
            .environmentObject(authService)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Готово", isPresented: $showPartnerSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authService.connectionSuccessMessage ?? "Партнёр успешно подключён!")
        }
        .alert("Отключить партнёра?", isPresented: $showDisconnectPartnerAlert) {
            Button("Отключить", role: .destructive) {
                Task { await disconnectPartner() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы точно хотите отключить партнёра? Вся ваша совместная история событий сотрётся без возможности восстановления.")
        }
        .onChange(of: authService.pairCode) { _ in
            didCopyCode = false
        }
        .onChange(of: authService.pairID) { _ in
            didCopyCode = false
        }
    }

    private func openPartnerSheet() {
        partnerCodeInput = ""
        showPartnerSheet = true
    }

    private func copyPairCode() {
        guard !authService.resolvedPairCode.isEmpty else { return }
        UIPasteboard.general.string = authService.resolvedPairCode
        withAnimation(.easeOut(duration: 0.08)) {
            didCopyCode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.08)) {
                didCopyCode = false
            }
        }
    }

    private func disconnectPartner() async {
        isDisconnectingPartner = true
        defer { isDisconnectingPartner = false }

        do {
            try await authService.disconnectPartner()
            store.setPairID(authService.pairID, force: true)
            userService.stopListeningToPartner()
            userService.startListeners(
                pairID: authService.pairID,
                userID: authService.userID,
                partnerID: authService.partnerID
            )
        } catch {
            authService.connectionError = authService.formatConnectionError(error)
        }
    }

    private func connectPartner() async {
        authService.connectionError = nil
        authService.connectionSuccessMessage = nil

        do {
            try await authService.joinPair(code: partnerCodeInput)
            store.setPairID(authService.pairID, force: true)
            try await userService.ensureProfileOnSyncPair(
                from: authService.pairCode,
                to: authService.pairID,
                userID: authService.userID,
                fallbackName: SettingsStore.userName,
                avatarData: avatarImage?.jpegData(compressionQuality: 0.85) ?? SettingsStore.avatarImage?.jpegData(compressionQuality: 0.85)
            )
            try await userService.saveProfileAndWait(
                name: userService.ownName,
                avatarData: avatarImage?.jpegData(compressionQuality: 0.85) ?? SettingsStore.avatarImage?.jpegData(compressionQuality: 0.85),
                pairID: authService.pairID
            )
            await userService.prefetchPartnerProfile(
                partnerID: authService.partnerID,
                syncPairID: authService.pairID
            )
            userService.startListeners(
                pairID: authService.pairID,
                userID: authService.userID,
                partnerID: authService.partnerID
            )
            showPartnerSuccessAlert = true
        } catch {
            authService.connectionError = authService.formatConnectionError(error)
        }
    }
}
