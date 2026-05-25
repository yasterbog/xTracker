//
//  AuthService.swift
//  xTracker
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class AuthService: ObservableObject {
    @Published var userID: String = ""
    @Published var partnerID: String = ""
    @Published var pairCode: String = ""
    @Published var pairID: String = ""
    @Published var isConnecting = false
    @Published var connectionError: String?
    @Published var connectionSuccessMessage: String?

    private lazy var database = Firestore.firestore()

    private enum Keys {
        static let savedUserID = "savedUserID"
        static let savedPairID = "savedPairID"
        static let legacyUserID = "auth.userID"
        static let legacyPairID = "auth.pairID"
        static let partnerID = "auth.partnerID"
        static let pairCode = "auth.pairCode"
    }

    init() {
        loadFromUserDefaults()
    }

    func bootstrap() async {
        do {
            try await signInAnonymously()
            try await restoreSavedPairIfNeeded()
            await refreshPairStatus()

            if pairID.isEmpty && pairCode.isEmpty {
                _ = try await generatePairCode()
            }
        } catch {
            connectionError = error.localizedDescription
        }
    }

    func signInAnonymously() async throws {
        let savedUserID = persistedUserID()

        if let currentUser = Auth.auth().currentUser {
            if let savedUserID, !savedUserID.isEmpty {
                userID = savedUserID
            } else {
                userID = currentUser.uid
                persistUserID(userID)
            }
            return
        }

        let result = try await Auth.auth().signInAnonymously()

        if let savedUserID, !savedUserID.isEmpty {
            userID = savedUserID
        } else {
            userID = result.user.uid
            persistUserID(userID)
        }
    }

    @discardableResult
    func generatePairCode() async throws -> String {
        try await signInAnonymously()

        let code = try await createUniquePairCode()
        let record = PairRecord(pairID: code, hostUserID: userID, guestUserID: nil)

        try database.collection("pairs").document(code).setData(from: record)

        pairCode = code
        pairID = code
        partnerID = ""
        persistPairState()

        return code
    }

    func joinPair(code: String) async throws {
        isConnecting = true
        connectionError = nil
        connectionSuccessMessage = nil

        defer { isConnecting = false }

        try await signInAnonymously()

        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalizedCode.count == 6 else {
            throw AuthServiceError.invalidCode
        }

        let document = database.collection("pairs").document(normalizedCode)
        let snapshot = try await document.getDocument()

        guard snapshot.exists, var record = try? snapshot.data(as: PairRecord.self) else {
            throw AuthServiceError.codeNotFound
        }

        if record.hostUserID == userID {
            throw AuthServiceError.cannotJoinOwnPair
        }

        if let guestUserID = record.guestUserID, guestUserID != userID {
            throw AuthServiceError.pairAlreadyFull
        }

        record.guestUserID = userID
        try document.setData(from: record)

        pairCode = normalizedCode
        pairID = record.pairID
        partnerID = record.hostUserID
        persistPairState()

        connectionSuccessMessage = "Партнёр успешно подключён!"
    }

    func refreshPairStatus() async {
        let activePairID = pairCode.isEmpty ? pairID : pairCode
        guard !activePairID.isEmpty else { return }

        do {
            let snapshot = try await database.collection("pairs").document(activePairID).getDocument()
            guard let record = try? snapshot.data(as: PairRecord.self) else { return }

            applyPairRecord(record, documentID: snapshot.documentID)
            partnerID = record.partnerUserID(excluding: userID) ?? ""
            persistPairState()
        } catch {
            connectionError = error.localizedDescription
        }
    }

    var isPartnerConnected: Bool {
        !partnerID.isEmpty
    }

    func clearConnectionState() {
        partnerID = ""
        pairID = ""
        pairCode = ""
        UserDefaults.standard.removeObject(forKey: Keys.partnerID)
        UserDefaults.standard.removeObject(forKey: Keys.savedPairID)
        UserDefaults.standard.removeObject(forKey: Keys.legacyPairID)
        UserDefaults.standard.removeObject(forKey: Keys.pairCode)
    }

    private func loadFromUserDefaults() {
        userID = persistedUserID() ?? ""
        partnerID = UserDefaults.standard.string(forKey: Keys.partnerID) ?? ""
        pairID = UserDefaults.standard.string(forKey: Keys.savedPairID)
            ?? UserDefaults.standard.string(forKey: Keys.legacyPairID)
            ?? ""
        pairCode = UserDefaults.standard.string(forKey: Keys.pairCode) ?? ""

        if userID.isEmpty, let currentUser = Auth.auth().currentUser {
            userID = currentUser.uid
            persistUserID(userID)
        }
    }

    private func persistPairState() {
        UserDefaults.standard.set(partnerID, forKey: Keys.partnerID)
        UserDefaults.standard.set(pairID, forKey: Keys.savedPairID)
        UserDefaults.standard.set(pairID, forKey: Keys.legacyPairID)
        UserDefaults.standard.set(pairCode, forKey: Keys.pairCode)
    }

    private func persistUserID(_ userID: String) {
        UserDefaults.standard.set(userID, forKey: Keys.savedUserID)
        UserDefaults.standard.set(userID, forKey: Keys.legacyUserID)
    }

    private func persistedUserID() -> String? {
        UserDefaults.standard.string(forKey: Keys.savedUserID)
            ?? UserDefaults.standard.string(forKey: Keys.legacyUserID)
    }

    private func restoreSavedPairIfNeeded() async throws {
        if !pairID.isEmpty || !pairCode.isEmpty {
            return
        }

        guard let savedUserID = persistedUserID(), !savedUserID.isEmpty else {
            return
        }

        if let record = try await findPairRecord(field: "hostUserID", equals: savedUserID) {
            applyPairRecord(record.record, documentID: record.documentID)
            persistPairState()
            return
        }

        if let record = try await findPairRecord(field: "guestUserID", equals: savedUserID) {
            applyPairRecord(record.record, documentID: record.documentID)
            persistPairState()
        }
    }

    private func findPairRecord(field: String, equals userID: String) async throws -> (record: PairRecord, documentID: String)? {
        let snapshot = try await database
            .collection("pairs")
            .whereField(field, isEqualTo: userID)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first,
              let record = try? document.data(as: PairRecord.self) else {
            return nil
        }

        return (record, document.documentID)
    }

    private func applyPairRecord(_ record: PairRecord, documentID: String) {
        let restoredPairID = record.pairID.isEmpty ? documentID : record.pairID
        pairID = restoredPairID
        pairCode = restoredPairID
        partnerID = record.partnerUserID(excluding: userID) ?? ""
    }

    private func createUniquePairCode() async throws -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

        for _ in 0..<12 {
            let code = String((0..<6).map { _ in characters.randomElement()! })
            let snapshot = try await database.collection("pairs").document(code).getDocument()
            if !snapshot.exists {
                return code
            }
        }

        throw AuthServiceError.codeGenerationFailed
    }
}

private struct PairRecord: Codable {
    var pairID: String
    var hostUserID: String
    var guestUserID: String?

    func partnerUserID(excluding userID: String) -> String? {
        if hostUserID == userID {
            return guestUserID
        }
        if guestUserID == userID {
            return hostUserID
        }
        if hostUserID != userID {
            return hostUserID
        }
        return guestUserID
    }
}

enum AuthServiceError: LocalizedError {
    case invalidCode
    case codeNotFound
    case cannotJoinOwnPair
    case pairAlreadyFull
    case codeGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Код должен содержать 6 символов."
        case .codeNotFound:
            return "Код не найден. Проверьте ввод."
        case .cannotJoinOwnPair:
            return "Нельзя подключиться к своему коду."
        case .pairAlreadyFull:
            return "Эта пара уже подключена к другому пользователю."
        case .codeGenerationFailed:
            return "Не удалось создать код. Попробуйте снова."
        }
    }
}
