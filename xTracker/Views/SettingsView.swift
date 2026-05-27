//
//  SettingsView.swift
//  xTracker
//

import PhotosUI
import SwiftUI
import UIKit

struct SettingsView: View {
    static let profileAvatarSize: CGFloat = 96

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var userService: UserService
    let gradientStart: UnitPoint
    let gradientEnd: UnitPoint

    @State private var nameDraft: String = SettingsStore.userName
    @State private var isEditingName = false
    @State private var showProfileEditor = false

    @State private var showPartnerSheet = false
    @State private var partnerCodeInput = ""
    @State private var showPartnerSuccessAlert = false

    @State private var avatarImage: UIImage? = SettingsStore.avatarImage
    @State private var selectedPhotoItem: PhotosPickerItem?

    @State private var showDeleteConfirmation = false
    @State private var didCopyCode = false

    private var hasUnsavedNameChanges: Bool {
        trimmed(nameDraft) != trimmed(userService.ownName) && !trimmed(nameDraft).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    profileHeader
                        .padding(.top, 16)
                    partnerCard

                    deleteAllDataButton
                        .padding(.top, 24)
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .ambientMainScreen(gradientStart: gradientStart, gradientEnd: gradientEnd)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showPartnerSheet) {
            PartnerConnectSheet(partnerCodeInput: $partnerCodeInput) {
                await connectPartner()
            }
            .environmentObject(authService)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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
        .alert("Готово", isPresented: $showPartnerSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authService.connectionSuccessMessage ?? "Партнёр успешно подключён!")
        }
        .task {
            await refreshPairCodeIfNeeded()
            await authService.refreshPairStatus()
            if !authService.pairID.isEmpty {
                store.setPairID(authService.pairID)
            }
            startProfileListeners()
        }
        .onChange(of: authService.pairCode) { newCode in
            if !newCode.isEmpty {
                didCopyCode = false
            }
        }
        .onChange(of: authService.partnerID) { _ in
            startProfileListeners()
        }
        .onChange(of: authService.pairID) { _ in
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
            Text("Все локальные настройки и данные будут сброшены. Это действие нельзя отменить.")
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

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    EditableAvatarView(
                        image: avatarImage,
                        avatarBase64: avatarBase64,
                        avatarURL: avatarURL,
                        name: displayName,
                        size: Self.profileAvatarSize,
                        isLoading: uploading,
                        showsCameraOverlay: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(uploading)

                Spacer(minLength: 0)

                Button {
                    showProfileEditor = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .regular, design: .default))
                        .foregroundStyle(Color.gray)
                }
                .buttonStyle(.plain)
            }

            Text(displayName)
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

            Divider()
                .overlay(AppTheme.separator)
                .padding(.top, 24)
                .padding(.bottom, 24)
        }
    }

    private var partnerCard: some View {
        SettingsGroup {
            VStack(spacing: 0) {
                HStack {
                    Text("Мой код")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.primaryText)

                    Spacer()

                    Text(authService.pairCode.isEmpty ? "…" : authService.pairCode)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(AppTheme.primaryText)
                        .monospaced()

                    Button {
                        UIPasteboard.general.string = authService.pairCode
                        withAnimation(.easeInOut(duration: 0.15)) {
                            didCopyCode = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { didCopyCode = false }
                        }
                    } label: {
                        Image(systemName: didCopyCode ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundStyle(didCopyCode ? .green : AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }

                SettingsCardDivider()

                if authService.isPartnerConnected {
                    PartnerProfileRow(
                        name: userService.partnerName.isEmpty ? "Партнёр" : userService.partnerName,
                        avatarBase64: userService.partnerAvatarBase64,
                        avatarURL: userService.partnerAvatarURL
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Button {
                        partnerCodeInput = ""
                        showPartnerSheet = true
                    } label: {
                        HStack {
                            Text("Подключить партнёра")
                                .font(AppTheme.bodyFont)
                                .foregroundStyle(AppTheme.primaryText)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authService.isPartnerConnected)
    }

    private var deleteAllDataButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            Text("Удалить все данные")
                .font(AppTheme.bodyFont)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func commitNameIfNeeded() {
        let trimmedName = trimmed(nameDraft)
        guard !trimmedName.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            nameDraft = trimmedName
            SettingsStore.userName = trimmedName
            isEditingName = false
        }

        userService.ownName = trimmedName
        saveProfile(name: trimmedName, avatarData: nil)
    }

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
        if authService.pairCode.isEmpty {
            _ = try? await authService.generatePairCode()
        }
    }

    private func connectPartner() async {
        authService.connectionError = nil
        authService.connectionSuccessMessage = nil

        do {
            try await authService.joinPair(code: partnerCodeInput)
            store.setPairID(authService.pairID)
            saveProfile(name: userService.ownName, avatarData: avatarImage?.jpegData(compressionQuality: 0.85))
            startProfileListeners()
            showPartnerSuccessAlert = true
        } catch {
            authService.connectionError = error.localizedDescription
        }
    }

    private func deleteAllData() {
        SettingsStore.deleteAllData()
        userService.stopListening()
        authService.clearConnectionState()
        store.resetToLocalMockData()

        withAnimation(.easeInOut(duration: 0.25)) {
            userService.ownName = SettingsStore.defaultUserName
            nameDraft = SettingsStore.defaultUserName
            avatarImage = nil
            isEditingName = false
            partnerCodeInput = ""
        }

        Task {
            _ = try? await authService.generatePairCode()
        }
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

// MARK: - Components

private struct ProfileEditSheet: View {
    let avatarBase64: String?
    let avatarURL: String?
    let uploadingAvatar: Bool
    let onSave: (String, Data?, UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
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

    private var saveButtonColor: Color {
        canSave ? Color(hex: "#FF3B6F") : .gray
    }

    var body: some View {
        NavigationStack {
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

                ClearableTextField(
                    placeholder: "Имя",
                    text: $nameDraft,
                    isFocused: $isNameFocused
                )

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.background)
            .navigationTitle("Редактировать профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundColor(.gray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        guard canSave else { return }
                        onSave(trimmedName, selectedAvatarData, selectedImage)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundColor(saveButtonColor)
                    }
                    .disabled(!canSave)
                }
            }
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

private struct ClearableTextField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.primaryText)
                .textInputAutocapitalization(.words)
                .focused(isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .regular, design: .default))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct SheetPrimaryButton: View {
    let title: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDisabled ? Color.gray.opacity(0.35) : AppTheme.accent)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct EditableAvatarView: View {
    let image: UIImage?
    let avatarBase64: String?
    let avatarURL: String?
    let name: String
    let size: CGFloat
    let isLoading: Bool
    var showsCameraOverlay = true

    private var cameraBadgeSize: CGFloat { size * 28 / 88 }
    private var cameraIconSize: CGFloat { size * 13 / 88 }
    private var cameraOffset: CGFloat { size * 2 / 88 }
    private var outerPadding: CGFloat { size * 8 / 88 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let image {
                    AvatarView(image: image, initials: SettingsStore.initials(from: name), size: size)
                } else {
                    UserAvatarView(
                        avatarBase64: avatarBase64,
                        avatarURL: avatarURL,
                        name: name,
                        size: size
                    )
                }

                if isLoading {
                    Circle()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: size, height: size)
                    ProgressView()
                        .tint(AppTheme.primaryText)
                }
            }

            if showsCameraOverlay {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: cameraBadgeSize, height: cameraBadgeSize)
                        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)

                    Image(systemName: "camera.fill")
                        .font(.system(size: cameraIconSize, weight: .semibold, design: .default))
                        .foregroundStyle(Color.black)
                }
                .offset(x: cameraOffset, y: cameraOffset)
            }
        }
        .frame(
            width: showsCameraOverlay ? size + outerPadding : size,
            height: showsCameraOverlay ? size + outerPadding : size
        )
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                AppTheme.sectionHeader(title)
            }

            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCardSurface(cornerRadius: 20)
        }
    }
}

private struct SettingsCardDivider: View {
    var body: some View {
        Divider()
            .overlay(AppTheme.separator)
            .padding(.vertical, 12)
    }
}


private struct AvatarView: View {
    let image: UIImage?
    let initials: String
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            if image == nil {
                AppTheme.accent
            }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initials)
                    .font(.system(size: size * 0.32, weight: .bold, design: .default))
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct PartnerProfileRow: View {
    let name: String
    let avatarBase64: String?
    let avatarURL: String?

    var body: some View {
        HStack(spacing: 12) {
            UserAvatarView(
                avatarBase64: avatarBase64,
                avatarURL: avatarURL,
                name: name,
                size: 40
            )

            Text(name)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.primaryText)

            Spacer()
        }
    }
}

#Preview {
    SettingsView(gradientStart: .top, gradientEnd: .bottomTrailing)
        .environmentObject(AuthService())
        .environmentObject(UserService())
        .environmentObject(EventStore())
}

