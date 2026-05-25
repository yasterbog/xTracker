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
        let userID = activeUserID.isEmpty
            ? UserDefaults.standard.string(forKey: Keys.savedUserID) ?? Auth.auth().currentUser?.uid
            : activeUserID
        guard let userID, !userID.isEmpty, !pairID.isEmpty else { return }

        Task {
            do {
                var payload: [String: Any] = [
                    "name": name,
                    "updatedAt": FieldValue.serverTimestamp(),
                ]
                var encodedAvatarBase64: String?

                if let avatarData {
                    uploadingAvatar = true
                    print("📸 Starting avatar base64 save for userID: \(userID)")
                    print("📸 Avatar data size: \(avatarData.count) bytes")
                    let base64 = try encodeAvatarBase64(from: avatarData)
                    payload["avatarBase64"] = base64
                    ownAvatarBase64 = base64
                    ownAvatarURL = nil
                    encodedAvatarBase64 = base64
                    print("✅ Avatar encoded successfully, base64 length: \(base64.count)")
                }

                try await database
                    .collection("pairs")
                    .document(pairID)
                    .collection("users")
                    .document(userID)
                    .setData(payload, merge: true)
                print("UserService: profile saved for user \(userID)")
                if encodedAvatarBase64 != nil {
                    print("✅ Avatar base64 saved to Firestore")
                }
            } catch {
                print("❌ Avatar base64 save failed: \(error)")
                print("UserService: profile/avatar save failed: \(error.localizedDescription)")
            }

            if avatarData != nil {
                uploadingAvatar = false
            }
        }
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
            }
        }
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
                let name = data["name"] as? String ?? SettingsStore.userName
                let avatarURL = data["avatarURL"] as? String
                let avatarBase64 = data["avatarBase64"] as? String

                Task { @MainActor in
                    self?.ownName = name
                    self?.ownAvatarURL = avatarURL
                    self?.ownAvatarBase64 = avatarBase64
                    SettingsStore.userName = name
                    print("UserService: own profile listener update name=\(name), avatarBase64=\(avatarBase64 == nil ? "nil" : "present"), avatarURL=\(avatarURL ?? "nil")")
                }
            }
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
                let name = data["name"] as? String ?? "Партнёр"
                let avatarURL = data["avatarURL"] as? String
                let avatarBase64 = data["avatarBase64"] as? String

                Task { @MainActor in
                    self?.partnerName = name
                    self?.partnerAvatarURL = avatarURL
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
                let avatarURL = data["avatarURL"] as? String

                Task { @MainActor in
                    self?.partnerAvatarBase64 = avatarBase64
                    self?.partnerAvatarURL = avatarURL
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
