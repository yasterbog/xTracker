//
//  SettingsView.swift
//  xTracker
//

import PhotosUI
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var userService: UserService

    @State private var nameDraft: String = SettingsStore.userName
    @State private var isEditingName = false
    @State private var showProfileEditor = false

    @State private var isEditingCalendarName = false
    @State private var calendarNameDraft: String = SettingsStore.calendarName
    @State private var showCalendarNameEditor = false

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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    profileHeader
                    calendarCard
                    partnerCard
                    accountCard
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
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
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCalendarNameEditor) {
            CalendarNameEditSheet(
                initialName: userService.calendarName.isEmpty ? SettingsStore.defaultCalendarName : userService.calendarName,
                onSave: { name in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        calendarNameDraft = name
                        userService.calendarName = name
                        SettingsStore.calendarName = name
                    }
                    userService.saveCalendarName(name, pairID: authService.pairID)
                }
            )
            .presentationDetents([.height(320), .medium])
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
        .onChange(of: userService.calendarName) { newName in
            guard !trimmed(newName).isEmpty else { return }
            SettingsStore.calendarName = trimmed(newName)
            if !isEditingCalendarName {
                calendarNameDraft = trimmed(newName)
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
        VStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                EditableAvatarView(
                    image: avatarImage,
                    avatarBase64: userService.ownAvatarBase64,
                    avatarURL: userService.ownAvatarURL,
                    name: userService.ownName.isEmpty ? SettingsStore.defaultUserName : userService.ownName,
                    size: 88,
                    isLoading: userService.uploadingAvatar
                )
            }
            .buttonStyle(.plain)
            .disabled(userService.uploadingAvatar)

            Text(userService.ownName.isEmpty ? SettingsStore.defaultUserName : userService.ownName)
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.center)

            Button {
                showProfileEditor = true
            } label: {
                Text("Изменить")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var calendarCard: some View {
        SettingsGroup(title: "КАЛЕНДАРЬ") {
            Button {
                showCalendarNameEditor = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 22)

                    Text("Название календаря")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.primaryText)

                    Spacer(minLength: 8)

                    Text(userService.calendarName.isEmpty ? SettingsStore.defaultCalendarName : userService.calendarName)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var partnerCard: some View {
        SettingsGroup(title: "ПАРТНЁР") {
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

    private var accountCard: some View {
        SettingsGroup(title: "АККАУНТ") {
            VStack(spacing: 0) {
                HStack {
                    Text("Версия приложения")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.primaryText)

                    Spacer()

                    Text("1.0.0")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                SettingsCardDivider()

                Button {} label: {
                    HStack {
                        Text("Написать нам")
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)

                SettingsCardDivider()

                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Text("Удалить все данные")
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(.red)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
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

    private func confirmCalendarRename() {
        let trimmedName = trimmed(calendarNameDraft)
        guard !trimmedName.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            SettingsStore.calendarName = trimmedName
            isEditingCalendarName = false
        }

        userService.saveCalendarName(trimmedName, pairID: authService.pairID)
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
            userService.saveCalendarName(userService.calendarName, pairID: authService.pairID)
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
            userService.calendarName = SettingsStore.defaultCalendarName
            calendarNameDraft = SettingsStore.defaultCalendarName
            avatarImage = nil
            isEditingName = false
            isEditingCalendarName = false
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

    var body: some View {
        VStack(spacing: 20) {
            Text("Изменить профиль")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                EditableAvatarView(
                    image: selectedImage,
                    avatarBase64: avatarBase64,
                    avatarURL: avatarURL,
                    name: trimmedName.isEmpty ? SettingsStore.defaultUserName : trimmedName,
                    size: 96,
                    isLoading: uploadingAvatar
                )
            }
            .buttonStyle(.plain)

            ClearableTextField(
                placeholder: "Имя",
                text: $nameDraft,
                isFocused: $isNameFocused
            )

            Spacer(minLength: 0)

            SheetPrimaryButton(title: "Сохранить", isDisabled: trimmedName.isEmpty) {
                guard !trimmedName.isEmpty else { return }
                onSave(trimmedName, selectedAvatarData, selectedImage)
                dismiss()
            }

            Button {
                dismiss()
            } label: {
                Text("Отмена")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isNameFocused = true
            }
        }
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

private struct CalendarNameEditSheet: View {
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @State private var nameDraft: String

    init(initialName: String, onSave: @escaping (String) -> Void) {
        self.onSave = onSave
        _nameDraft = State(initialValue: initialName)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Название календаря")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            ClearableTextField(
                placeholder: "Название календаря",
                text: $nameDraft,
                isFocused: $isNameFocused
            )

            Text("Название будет обновлено у обоих партнёров")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            SheetPrimaryButton(title: "Сохранить", isDisabled: trimmedName.isEmpty) {
                guard !trimmedName.isEmpty else { return }
                onSave(trimmedName)
                dismiss()
            }

            Button {
                dismiss()
            } label: {
                Text("Отмена")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isNameFocused = true
            }
        }
    }

    private var trimmedName: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
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

            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)

                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(Color.black)
            }
            .offset(x: 2, y: 2)
        }
        .frame(width: size + 8, height: size + 8)
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppTheme.sectionHeader(title)

            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.cardBackground)
                )
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
    SettingsView()
        .environmentObject(AuthService())
        .environmentObject(UserService())
        .environmentObject(EventStore())
}

