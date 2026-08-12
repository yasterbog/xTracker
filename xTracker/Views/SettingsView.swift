//
//  SettingsView.swift
//  xTracker
//

import PhotosUI
import SwiftUI
import UIKit

struct SettingsView: View {
    static let profileAvatarSize: CGFloat = 96
    static let profileHeaderAvatarSize: CGFloat = 64

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var userService: UserService
    @EnvironmentObject private var activityCatalog: ActivityCatalogStore

    @State private var nameDraft: String = SettingsStore.userName
    @State private var isEditingName = false
    @State private var showProfileEditor = false
    @State private var settingsPath = NavigationPath()

    @State private var avatarImage: UIImage? = SettingsStore.avatarImage
    @State private var selectedPhotoItem: PhotosPickerItem?

    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack(path: $settingsPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    profileHeader
                        .padding(.top, 16)

                    settingsMenu

                    deleteAllDataButton
                        .padding(.top, 8)
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.bottom, AppTheme.floatingTabBarScrollClearance)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .appScreenBackground()
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .pair:
                    PairSettingsView()
                case .activities:
                    MyActivitiesView()
                }
            }
        }
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditSheet(
                initialName: userService.ownName.isEmpty ? SettingsStore.defaultUserName : userService.ownName,
                avatarBase64: userService.ownAvatarBase64,
                avatarURL: userService.ownAvatarURL,
                initialImage: avatarImage,
                uploadingAvatar: userService.uploadingAvatar,
                onSave: { name, avatarData, image in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        nameDraft = name
                        userService.ownName = name
                        SettingsStore.userName = name
                        if let image {
                            avatarImage = image
                            SettingsStore.avatarImage = image
                        }
                    }
                    saveProfile(name: name, avatarData: avatarData)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            await refreshPairCodeIfNeeded()
            await authService.refreshPairStatus()
            await ensureOwnProfileOnSyncPairIfNeeded()
            if !authService.pairID.isEmpty {
                store.setPairID(authService.pairID)
            }
            startProfileListeners()
        }
        .onChange(of: authService.pairID) { _ in
            startProfileListeners()
        }
        .onChange(of: authService.partnerID) { _ in
            startProfileListeners()
        }
        .onChange(of: userService.ownName) { newName in
            guard !trimmed(newName).isEmpty else { return }
            SettingsStore.userName = trimmed(newName)
            if !isEditingName {
                nameDraft = trimmed(newName)
            }
        }
        .onChange(of: userService.ownAvatarBase64) { newValue in
            if newValue != nil {
                avatarImage = nil
            }
        }
        .alert("Удалить все данные?", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                deleteAllData()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Будут удалены только ваши события, имя и аватарка. События партнёра сохранятся. Личный код будет создан заново.")
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedPhotoItem) { newItem in
            loadPhoto(from: newItem)
        }
    }

    // MARK: - Sections

    private var profileHeader: some View {
        let avatarBase64 = userService.ownAvatarBase64
        let avatarURL = userService.ownAvatarURL
        let name = userService.ownName
        let uploading = userService.uploadingAvatar
        let displayName = name.isEmpty ? SettingsStore.defaultUserName : name
        let partnerDisplayName = userService.partnerName.isEmpty ? "Партнёр" : userService.partnerName

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    EditableAvatarView(
                        image: avatarImage,
                        avatarBase64: avatarBase64,
                        avatarURL: avatarURL,
                        name: displayName,
                        size: Self.profileHeaderAvatarSize,
                        isLoading: uploading,
                        showsCameraOverlay: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(uploading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(AppFont.font(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)

                    if authService.isPartnerConnected {
                        Text("В паре с \(partnerDisplayName)")
                            .font(AppFont.font(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                    } else {
                        Text("Соло • Без пары")
                            .font(AppFont.font(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                Spacer(minLength: 8)

                ChipButton(title: "Изменить") {
                    showProfileEditor = true
                }
            }
        }
    }

    private var settingsMenu: some View {
        SettingsMenuGroup {
            Button {
                settingsPath.append(SettingsDestination.pair)
            } label: {
                SettingsMenuRow(iconAsset: "lovely", title: "Пара")
            }
            .buttonStyle(.plain)

            SettingsMenuDivider()

            Button {
                settingsPath.append(SettingsDestination.activities)
            } label: {
                SettingsMenuRow(iconAsset: "folder-favorite", title: "Мои активности")
            }
            .buttonStyle(.plain)
        }
    }

    private var deleteAllDataButton: some View {
        DestructionActionButton(title: "Удалить все данные") {
            showDeleteConfirmation = true
        }
    }

    // MARK: - Actions

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        avatarImage = image
                        SettingsStore.avatarImage = image
                    }
                    saveProfile(name: userService.ownName, avatarData: data)
                }
            }
        }
    }

    private func refreshPairCodeIfNeeded() async {
        if authService.resolvedPairCode.isEmpty {
            _ = try? await authService.generatePairCode()
        }
    }

    private func deleteAllData() {
        Task {
            SettingsStore.deleteAllData()
            activityCatalog.resetToDefaults()
            userService.stopListening()
            userService.resetOwnProfileLocally()
            store.stopListeningForDeletion()

            withAnimation(.easeInOut(duration: 0.25)) {
                nameDraft = SettingsStore.defaultUserName
                avatarImage = nil
                isEditingName = false
            }

            do {
                try await authService.deleteAllData()
            } catch {
                authService.connectionError = authService.formatConnectionError(error)
                if authService.resolvedPairCode.isEmpty {
                    _ = try? await authService.generatePairCode()
                }
            }

            store.resetAfterDataDeletion()
            store.setPairID(authService.pairID, force: true)

            userService.startListeners(
                pairID: authService.pairID,
                userID: authService.userID,
                partnerID: authService.partnerID
            )
        }
    }

    private func ensureOwnProfileOnSyncPairIfNeeded() async {
        guard authService.isPartnerConnected else { return }
        guard authService.pairID != authService.pairCode else { return }

        try? await userService.ensureProfileOnSyncPair(
            from: authService.pairCode,
            to: authService.pairID,
            userID: authService.userID,
            fallbackName: SettingsStore.userName,
            avatarData: SettingsStore.avatarImage?.jpegData(compressionQuality: 0.85)
        )
    }

    private func saveProfile(name: String, avatarData: Data?) {
        let pairID = authService.pairID
        guard !pairID.isEmpty else { return }
        userService.saveProfile(
            name: trimmed(name.isEmpty ? SettingsStore.defaultUserName : name),
            avatarData: avatarData,
            pairID: pairID
        )
    }

    private func startProfileListeners() {
        userService.startListeners(
            pairID: authService.pairID,
            userID: authService.userID,
            partnerID: authService.partnerID
        )
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Profile Edit Sheet

private struct ProfileEditSheet: View {
    let avatarBase64: String?
    let avatarURL: String?
    let uploadingAvatar: Bool
    let onSave: (String, Data?, UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nameDraft: String
    @State private var selectedImage: UIImage?
    @State private var selectedAvatarData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(
        initialName: String,
        avatarBase64: String?,
        avatarURL: String?,
        initialImage: UIImage?,
        uploadingAvatar: Bool,
        onSave: @escaping (String, Data?, UIImage?) -> Void
    ) {
        self.avatarBase64 = avatarBase64
        self.avatarURL = avatarURL
        self.uploadingAvatar = uploadingAvatar
        self.onSave = onSave
        _nameDraft = State(initialValue: initialName)
        _selectedImage = State(initialValue: initialImage)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        EditableAvatarView(
                            image: selectedImage,
                            avatarBase64: avatarBase64,
                            avatarURL: avatarURL,
                            name: trimmedName.isEmpty ? SettingsStore.defaultUserName : trimmedName,
                            size: SettingsView.profileAvatarSize,
                            isLoading: uploadingAvatar,
                            showsCameraOverlay: false
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)

                    FloatingLabelTextField(
                        label: "Имя",
                        text: $nameDraft
                    )

                    PrimaryActionButton(title: "Сохранить", isEnabled: canSave) {
                        onSave(trimmedName, selectedAvatarData, selectedImage)
                        dismiss()
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.vertical, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .background(AppTheme.background)
            .sheetInlineHeader("Редактировать профиль")
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedPhotoItem) { newItem in
            loadPhoto(from: newItem)
        }
    }

    private var trimmedName: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedAvatarData = data
                    selectedImage = image
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService())
        .environmentObject(UserService())
        .environmentObject(EventStore())
        .environmentObject(ActivityCatalogStore())
}
