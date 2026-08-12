//
//  UserService.swift
//  xTracker
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation
import UIKit

@MainActor
final class UserService: ObservableObject {
    @Published var ownName: String = SettingsStore.userName
    @Published var ownAvatarURL: String?
    @Published var ownAvatarBase64: String?
    @Published var partnerName: String = ""
    @Published var partnerAvatarURL: String?
    @Published var partnerAvatarBase64: String?
    @Published var uploadingAvatar = false

    private lazy var database = Firestore.firestore()
    private var ownProfileListener: ListenerRegistration?
    private var partnerListener: ListenerRegistration?
    private var partnerAvatarListener: ListenerRegistration?
    private var activePairID = ""
    private var activeUserID = ""
    private var activePartnerID = ""

    private enum Keys {
        static let savedUserID = "savedUserID"
    }

    func saveProfile(name: String, avatarData: Data?, pairID: String) {
        Task {
            try? await saveProfileAndWait(name: name, avatarData: avatarData, pairID: pairID)
        }
    }

    func saveProfileAndWait(name: String, avatarData: Data?, pairID: String) async throws {
        let userID = activeUserID.isEmpty
            ? UserDefaults.standard.string(forKey: Keys.savedUserID) ?? Auth.auth().currentUser?.uid
            : activeUserID
        guard let userID, !userID.isEmpty, !pairID.isEmpty else { return }

        var payload: [String: Any] = [
            "name": name,
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        if let avatarData {
            uploadingAvatar = true
            defer { uploadingAvatar = false }

            let base64 = try encodeAvatarBase64(from: avatarData)
            payload["avatarBase64"] = base64
            ownAvatarBase64 = base64
            ownAvatarURL = nil
        } else if let ownAvatarBase64, !ownAvatarBase64.isEmpty {
            payload["avatarBase64"] = ownAvatarBase64
        }

        try await database
            .collection("pairs")
            .document(pairID)
            .collection("users")
            .document(userID)
            .setData(payload, merge: true)

        ownName = name
        SettingsStore.userName = name
    }

    func ensureProfileOnSyncPair(
        from personalPairID: String,
        to syncPairID: String,
        userID: String,
        fallbackName: String,
        avatarData: Data?
    ) async throws {
        guard !personalPairID.isEmpty, !syncPairID.isEmpty, !userID.isEmpty else { return }
        guard personalPairID != syncPairID else { return }

        let destination = database
            .collection("pairs")
            .document(syncPairID)
            .collection("users")
            .document(userID)

        let destinationSnapshot = try await destination.getDocument()
        let destinationData = destinationSnapshot.data() ?? [:]
        let destinationName = (destinationData["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let destinationHasCustomName = destinationName.map {
            !$0.isEmpty && $0 != SettingsStore.defaultUserName
        } ?? false
        let destinationHasAvatar = (destinationData["avatarBase64"] as? String)?.isEmpty == false
            || (destinationData["avatarURL"] as? String)?.isEmpty == false

        if destinationHasCustomName && destinationHasAvatar {
            ownName = destinationName ?? SettingsStore.userName
            SettingsStore.userName = ownName
            ownAvatarBase64 = destinationData["avatarBase64"] as? String
            ownAvatarURL = destinationData["avatarURL"] as? String
            return
        }

        let sourceSnapshot = try await database
            .collection("pairs")
            .document(personalPairID)
            .collection("users")
            .document(userID)
            .getDocument()

        let sourceData = sourceSnapshot.data() ?? [:]
        let sourceName = (sourceData["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFallback = fallbackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName: String
        if let sourceName, !sourceName.isEmpty {
            resolvedName = sourceName
        } else if !trimmedFallback.isEmpty {
            resolvedName = trimmedFallback
        } else {
            resolvedName = SettingsStore.defaultUserName
        }

        var payload: [String: Any] = [
            "name": resolvedName,
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        if let avatarBase64 = sourceData["avatarBase64"] as? String, !avatarBase64.isEmpty {
            payload["avatarBase64"] = avatarBase64
        } else if let avatarData {
            payload["avatarBase64"] = try encodeAvatarBase64(from: avatarData)
        }

        if let avatarURL = sourceData["avatarURL"] as? String, !avatarURL.isEmpty {
            payload["avatarURL"] = avatarURL
        }

        try await destination.setData(payload, merge: true)

        ownName = resolvedName
        SettingsStore.userName = resolvedName
        ownAvatarBase64 = payload["avatarBase64"] as? String
        ownAvatarURL = payload["avatarURL"] as? String
    }

    func startListeners(pairID: String, userID: String, partnerID: String) {
        guard !pairID.isEmpty, !userID.isEmpty else {
            stopListening()
            return
        }

        let shouldRestartOwn = activePairID != pairID || activeUserID != userID
        let shouldRestartPartner = activePairID != pairID || activePartnerID != partnerID

        activePairID = pairID
        activeUserID = userID
        activePartnerID = partnerID

        if shouldRestartOwn {
            listenToOwnProfile(pairID: pairID, userID: userID)
        }

        if shouldRestartPartner {
            if partnerID.isEmpty {
                stopListeningToPartner()
            } else {
                listenToPartner(pairID: pairID, partnerID: partnerID) { _, _ in }
                listenToPartnerAvatar(pairID: pairID, partnerID: partnerID)
                Task {
                    await prefetchPartnerProfile(partnerID: partnerID, syncPairID: pairID)
                }
            }
        }
    }

    func ownAvatarProfile(userID: String) -> UserAvatarProfile {
        UserAvatarProfile(
            userID: userID,
            name: ownName.isEmpty ? SettingsStore.defaultUserName : ownName,
            avatarBase64: ownAvatarBase64,
            avatarURL: ownAvatarURL
        )
    }

    func partnerAvatarProfile(partnerID: String) -> UserAvatarProfile {
        UserAvatarProfile(
            userID: partnerID,
            name: partnerName.isEmpty ? "Партнёр" : partnerName,
            avatarBase64: partnerAvatarBase64,
            avatarURL: partnerAvatarURL
        )
    }

    func prefetchPartnerProfile(partnerID: String, syncPairID: String) async {
        guard !partnerID.isEmpty, !syncPairID.isEmpty else { return }

        let firestoreService = FirestoreService()

        if let syncProfile = try? await firestoreService.fetchUserProfileSnapshot(
            pairID: syncPairID,
            userID: partnerID
        ), isUsefulPartnerProfile(syncProfile) {
            applyPartnerProfile(syncProfile)
            return
        }

        if let personalPairID = try? await firestoreService.findPersonalPairID(for: partnerID),
           let personalProfile = try? await firestoreService.fetchUserProfileSnapshot(
            pairID: personalPairID,
            userID: partnerID
           ), isUsefulPartnerProfile(personalProfile) {
            applyPartnerProfile(personalProfile)
        }
    }

    private func isUsefulPartnerProfile(_ profile: UserAvatarProfile) -> Bool {
        let trimmed = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "Партнёр" && trimmed != SettingsStore.defaultUserName
            || profile.avatarBase64?.isEmpty == false
            || profile.avatarURL?.isEmpty == false
    }

    private func applyPartnerProfile(_ profile: UserAvatarProfile) {
        partnerName = profile.name
        partnerAvatarBase64 = profile.avatarBase64
        partnerAvatarURL = profile.avatarURL
    }

    func listenToOwnProfile(pairID: String, userID: String) {
        ownProfileListener?.remove()

        guard !pairID.isEmpty, !userID.isEmpty else {
            ownName = SettingsStore.userName
            ownAvatarURL = nil
            ownAvatarBase64 = nil
            return
        }

        ownProfileListener = database
            .collection("pairs")
            .document(pairID)
            .collection("users")
            .document(userID)
            .addSnapshotListener { [weak self] snapshot, _ in
                let data = snapshot?.data() ?? [:]
                let rawName = data["name"] as? String
                let name = Self.resolvedOwnProfileName(
                    rawName: rawName,
                    profileExists: snapshot?.exists == true,
                    currentName: self?.ownName ?? SettingsStore.userName
                )
                let avatarURL = data["avatarURL"] as? String
                let avatarBase64 = data["avatarBase64"] as? String
                    ?? self?.ownAvatarBase64

                Task { @MainActor in
                    self?.ownName = name
                    self?.ownAvatarURL = avatarURL ?? self?.ownAvatarURL
                    self?.ownAvatarBase64 = avatarBase64
                    SettingsStore.userName = name
                    print("UserService: own profile listener update name=\(name), avatarBase64=\(avatarBase64 == nil ? "nil" : "present"), avatarURL=\(avatarURL ?? "nil")")
                }
            }
    }

    private static func resolvedOwnProfileName(
        rawName: String?,
        profileExists: Bool,
        currentName: String
    ) -> String {
        if let rawName {
            let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if !profileExists {
            let trimmedCurrent = currentName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedCurrent.isEmpty, trimmedCurrent != SettingsStore.defaultUserName {
                return trimmedCurrent
            }
        }

        return SettingsStore.defaultUserName
    }

    private static func resolvedPartnerProfileName(
        rawName: String?,
        profileExists: Bool,
        currentName: String
    ) -> String {
        if let rawName {
            let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed != SettingsStore.defaultUserName {
                return trimmed
            }
        }

        if !profileExists {
            let trimmedCurrent = currentName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedCurrent.isEmpty, trimmedCurrent != "Партнёр" {
                return trimmedCurrent
            }
        }

        return "Партнёр"
    }

    func listenToPartner(
        pairID: String,
        partnerID: String,
        completion: @escaping (String, String?) -> Void
    ) {
        partnerListener?.remove()

        guard !pairID.isEmpty, !partnerID.isEmpty else {
            partnerName = ""
            partnerAvatarURL = nil
            partnerAvatarBase64 = nil
            completion("", nil)
            return
        }

        partnerListener = database
            .collection("pairs")
            .document(pairID)
            .collection("users")
            .document(partnerID)
            .addSnapshotListener { [weak self] snapshot, _ in
                let data = snapshot?.data() ?? [:]
                let rawName = data["name"] as? String
                let name = Self.resolvedPartnerProfileName(
                    rawName: rawName,
                    profileExists: snapshot?.exists == true,
                    currentName: self?.partnerName ?? ""
                )
                let avatarURL = data["avatarURL"] as? String
                let avatarBase64 = data["avatarBase64"] as? String
                    ?? self?.partnerAvatarBase64

                Task { @MainActor in
                    self?.partnerName = name
                    self?.partnerAvatarURL = avatarURL ?? self?.partnerAvatarURL
                    self?.partnerAvatarBase64 = avatarBase64
                    print("👀 Partner listener triggered, avatarBase64: \(avatarBase64 == nil ? "nil" : "present")")
                    print("UserService: partner listener triggered name=\(name), avatarBase64=\(avatarBase64 == nil ? "nil" : "present"), avatarURL=\(avatarURL ?? "nil")")
                    completion(name, avatarURL)
                }
            }
    }

    func listenToPartnerAvatar(pairID: String, partnerID: String) {
        partnerAvatarListener?.remove()

        guard !pairID.isEmpty, !partnerID.isEmpty else {
            partnerAvatarURL = nil
            return
        }

        partnerAvatarListener = database
            .collection("pairs")
            .document(pairID)
            .collection("users")
            .document(partnerID)
            .addSnapshotListener { [weak self] snapshot, _ in
                let data = snapshot?.data() ?? [:]
                let avatarBase64 = data["avatarBase64"] as? String
                    ?? self?.partnerAvatarBase64
                let avatarURL = data["avatarURL"] as? String

                Task { @MainActor in
                    self?.partnerAvatarBase64 = avatarBase64
                    self?.partnerAvatarURL = avatarURL ?? self?.partnerAvatarURL
                    print("👀 Partner listener triggered, avatarBase64: \(avatarBase64 == nil ? "nil" : "present")")
                    print("UserService: partner avatar listener triggered avatarBase64=\(avatarBase64 == nil ? "nil" : "present"), avatarURL=\(avatarURL ?? "nil")")
                }
            }
    }

    func stopListeningToPartner() {
        partnerListener?.remove()
        partnerAvatarListener?.remove()
        partnerListener = nil
        partnerAvatarListener = nil
        activePartnerID = ""
        partnerName = ""
        partnerAvatarURL = nil
        partnerAvatarBase64 = nil
    }

    func stopListening() {
        ownProfileListener?.remove()
        partnerListener?.remove()
        partnerAvatarListener?.remove()
        ownProfileListener = nil
        partnerListener = nil
        partnerAvatarListener = nil
        activePairID = ""
        activeUserID = ""
        activePartnerID = ""
        ownName = SettingsStore.userName
        ownAvatarURL = nil
        ownAvatarBase64 = nil
        partnerName = ""
        partnerAvatarURL = nil
        partnerAvatarBase64 = nil
    }

    func resetOwnProfileLocally() {
        ownName = SettingsStore.defaultUserName
        ownAvatarURL = nil
        ownAvatarBase64 = nil
        SettingsStore.userName = SettingsStore.defaultUserName
    }

    private func encodeAvatarBase64(from data: Data) throws -> String {
        guard let image = UIImage(data: data) else {
            throw AvatarEncodingError.invalidImageData
        }

        let resized = image.resizedToFit(maxSize: CGSize(width: 200, height: 200))
        guard let jpegData = resized.jpegData(compressionQuality: 0.3) else {
            throw AvatarEncodingError.jpegEncodingFailed
        }

        print("📸 Compressed avatar size: \(jpegData.count) bytes")
        return jpegData.base64EncodedString()
    }

    deinit {
        ownProfileListener?.remove()
        partnerListener?.remove()
        partnerAvatarListener?.remove()
    }
}

private enum AvatarEncodingError: LocalizedError {
    case invalidImageData
    case jpegEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid avatar image data."
        case .jpegEncodingFailed:
            return "Failed to encode avatar as JPEG."
        }
    }
}

private extension UIImage {
    func resizedToFit(maxSize: CGSize) -> UIImage {
        let widthRatio = maxSize.width / size.width
        let heightRatio = maxSize.height / size.height
        let scale = min(1, widthRatio, heightRatio)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
