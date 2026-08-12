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
    /// Personal invite code — always the user's own pair document ID.
    @Published var pairCode: String = ""
    /// Pair document used for shared events/profile sync.
    @Published var pairID: String = ""
    @Published var userID: String = ""
    @Published var partnerID: String = ""
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
            reconcilePersistedPairState()
            await ensurePersonalPairCodeFromFirestore()

            if pairCode.isEmpty {
                _ = try await generatePairCode()
            } else {
                try await ensurePersonalPairDocumentExists()
            }

            await refreshPairStatus()
        } catch {
            connectionError = userFacingErrorMessage(for: error)
            if pairCode.isEmpty {
                try? await generatePairCode()
            }
        }
    }

    var resolvedPairCode: String {
        pairCode
    }

    var syncPairID: String {
        pairID.isEmpty ? pairCode : pairID
    }

    func signInAnonymously() async throws {
        if Auth.auth().currentUser == nil {
            _ = try await Auth.auth().signInAnonymously()
        }

        guard let authUID = Auth.auth().currentUser?.uid, !authUID.isEmpty else {
            throw AuthServiceError.authenticationFailed
        }

        userID = authUID
        persistUserID(authUID)
    }

    @discardableResult
    func generatePairCode() async throws -> String {
        try await signInAnonymously()

        let code = try await createUniquePairCode()
        let record = PairRecord(pairID: code, hostUserID: userID, guestUserID: nil)

        try await database.collection("pairs").document(code).setData(from: record)

        pairCode = code
        pairID = code
        partnerID = ""
        persistPairState()

        return code
    }

    func joinPair(code: String, firestoreService: FirestoreService = FirestoreService()) async throws {
        isConnecting = true
        connectionError = nil
        connectionSuccessMessage = nil

        defer { isConnecting = false }

        try await signInAnonymously()
        await ensurePersonalPairCodeFromFirestore()

        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalizedCode.count == 6 else {
            throw AuthServiceError.invalidCode
        }

        let personalPairID = personalPairCode
        guard !personalPairID.isEmpty else {
            throw AuthServiceError.codeNotFound
        }

        if personalPairID == normalizedCode {
            throw AuthServiceError.cannotJoinOwnPair
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
        if record.connectedAt == nil {
            record.connectedAt = Date()
        }
        record.pairID = normalizedCode
        try await document.setData(from: record)

        // Keep personal code, switch shared sync to the host's pair.
        pairID = normalizedCode
        partnerID = record.hostUserID
        persistPairState()

        try await firestoreService.migrateEventsCreatedBy(
            userID: userID,
            from: personalPairID,
            to: normalizedCode
        )

        connectionSuccessMessage = "Партнёр успешно подключён!"
    }

    func refreshPairStatus(firestoreService: FirestoreService = FirestoreService()) async {
        guard !pairCode.isEmpty else { return }

        do {
            if try await applyHostConnectionIfNeeded() {
                persistPairState()
                return
            }

            if try await applyGuestConnectionIfNeeded() {
                persistPairState()
                return
            }

            partnerID = ""
            pairID = pairCode
            persistPairState()
        } catch {
            connectionError = userFacingErrorMessage(for: error)
        }
    }

    var isPartnerConnected: Bool {
        !partnerID.isEmpty
    }

    func disconnectPartner(firestoreService: FirestoreService = FirestoreService()) async throws {
        let personalPairID = personalPairCode
        guard !personalPairID.isEmpty else { return }

        try await signInAnonymously()

        let sharedPairID = pairID.isEmpty ? personalPairID : pairID
        if !partnerID.isEmpty {
            try await firestoreService.deleteAllEvents(pairID: sharedPairID)
        }

        var clearedPaths = Set<String>()

        let personalDoc = database.collection("pairs").document(personalPairID)
        let personalSnapshot = try await personalDoc.getDocument()

        if let record = try? personalSnapshot.data(as: PairRecord.self),
           record.hostUserID == userID,
           record.guestUserID != nil {
            try await clearGuestConnection(on: personalDoc)
            clearedPaths.insert(personalDoc.path)
        }

        if sharedPairID != personalPairID {
            let syncDoc = database.collection("pairs").document(sharedPairID)
            let syncSnapshot = try await syncDoc.getDocument()
            if let record = try? syncSnapshot.data(as: PairRecord.self),
               record.guestUserID == userID {
                try await clearGuestConnection(on: syncDoc)
                clearedPaths.insert(syncDoc.path)
            }
        }

        let guestPairs = try await database
            .collection("pairs")
            .whereField("guestUserID", isEqualTo: userID)
            .getDocuments()

        for document in guestPairs.documents where !clearedPaths.contains(document.reference.path) {
            try await clearGuestConnection(on: document.reference)
        }

        partnerID = ""
        pairID = personalPairID
        persistPairState()
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

    func deleteAllData(firestoreService: FirestoreService = FirestoreService()) async throws {
        try await signInAnonymously()

        let oldPairID = syncPairID
        if !oldPairID.isEmpty {
            do {
                try await removeOwnDataFromPair(oldPairID: oldPairID, firestoreService: firestoreService)
            } catch {
                print("AuthService: cloud cleanup failed: \(error.localizedDescription)")
            }
        }

        partnerID = ""

        clearConnectionState()
        _ = try await generatePairCode()

        do {
            try await resetProfileInCurrentPair()
        } catch {
            print("AuthService: profile reset failed: \(error.localizedDescription)")
        }
    }

    func formatConnectionError(_ error: Error) -> String {
        userFacingErrorMessage(for: error)
    }

    private var personalPairCode: String {
        if !pairCode.isEmpty { return pairCode }
        return pairID
    }

    private func applyHostConnectionIfNeeded() async throws -> Bool {
        let snapshot = try await database.collection("pairs").document(pairCode).getDocument()
        guard let record = try? snapshot.data(as: PairRecord.self), snapshot.exists else {
            return false
        }

        guard record.hostUserID == userID, let guestID = record.guestUserID, !guestID.isEmpty else {
            return false
        }

        partnerID = guestID
        pairID = pairCode
        return true
    }

    private func applyGuestConnectionIfNeeded() async throws -> Bool {
        guard let guestPair = try await findPairRecord(field: "guestUserID", equals: userID) else {
            return false
        }

        let record = guestPair.record
        guard record.hostUserID != userID else { return false }

        partnerID = record.hostUserID
        pairID = guestPair.documentID
        return true
    }

    private func removeOwnDataFromPair(
        oldPairID: String,
        firestoreService: FirestoreService
    ) async throws {
        let document = database.collection("pairs").document(oldPairID)
        let snapshot = try await document.getDocument()

        try await firestoreService.deleteEventsCreatedBy(userID: userID, pairID: oldPairID)
        try await firestoreService.deleteUserProfile(pairID: oldPairID, userID: userID)

        guard snapshot.exists, var record = try? snapshot.data(as: PairRecord.self) else {
            return
        }

        let partnerUserID = record.partnerUserID(excluding: userID)
        let isHost = record.hostUserID == userID
        let isGuest = record.guestUserID == userID

        if isHost, let partnerUserID {
            record.hostUserID = partnerUserID
            record.guestUserID = nil
            record.connectedAt = nil
            try await document.setData(from: record)
        } else if isGuest {
            try await clearGuestConnection(on: document)
        } else if isHost {
            try await firestoreService.deletePairDocument(pairID: oldPairID)
        }
    }

    private func clearGuestConnection(on reference: DocumentReference) async throws {
        try await reference.setData([
            "guestUserID": NSNull(),
            "connectedAt": NSNull(),
        ], merge: true)
    }

    private func reconcilePersistedPairState() {
        if pairID.isEmpty && !pairCode.isEmpty {
            pairID = pairCode
        }
    }

    private func ensurePersonalPairCodeFromFirestore() async {
        guard !userID.isEmpty else { return }

        do {
            if let personal = try await findPairRecord(field: "hostUserID", equals: userID) {
                pairCode = personal.documentID
                persistPairState()
            }
        } catch {
            print("AuthService: failed to restore personal pair code: \(error.localizedDescription)")
        }
    }

    private func ensurePersonalPairDocumentExists() async throws {
        let snapshot = try await database.collection("pairs").document(pairCode).getDocument()
        guard snapshot.exists else {
            _ = try await generatePairCode()
            return
        }

        guard let record = try? snapshot.data(as: PairRecord.self), record.hostUserID == userID else {
            _ = try await generatePairCode()
            return
        }
    }

    private func resetProfileInCurrentPair() async throws {
        let targetPairID = syncPairID
        guard !targetPairID.isEmpty, !userID.isEmpty else { return }

        try await database
            .collection("pairs")
            .document(targetPairID)
            .collection("users")
            .document(userID)
            .setData([
                "name": SettingsStore.defaultUserName,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
    }

    private func loadFromUserDefaults() {
        userID = persistedUserID() ?? ""
        partnerID = UserDefaults.standard.string(forKey: Keys.partnerID) ?? ""
        pairCode = UserDefaults.standard.string(forKey: Keys.pairCode) ?? ""
        pairID = UserDefaults.standard.string(forKey: Keys.savedPairID)
            ?? UserDefaults.standard.string(forKey: Keys.legacyPairID)
            ?? ""

        if pairCode.isEmpty, !pairID.isEmpty {
            pairCode = pairID
        }

        if userID.isEmpty, let currentUser = Auth.auth().currentUser {
            userID = currentUser.uid
            persistUserID(userID)
        }
    }

    private func persistPairState() {
        UserDefaults.standard.set(partnerID, forKey: Keys.partnerID)
        UserDefaults.standard.set(pairCode, forKey: Keys.pairCode)
        UserDefaults.standard.set(pairID, forKey: Keys.savedPairID)
        UserDefaults.standard.set(pairID, forKey: Keys.legacyPairID)
    }

    private func persistUserID(_ userID: String) {
        UserDefaults.standard.set(userID, forKey: Keys.savedUserID)
        UserDefaults.standard.set(userID, forKey: Keys.legacyUserID)
    }

    private func persistedUserID() -> String? {
        UserDefaults.standard.string(forKey: Keys.savedUserID)
            ?? UserDefaults.standard.string(forKey: Keys.legacyUserID)
    }

    private func restorePersonalPairIfNeeded() async throws {
        await ensurePersonalPairCodeFromFirestore()
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

    private func createUniquePairCode() async throws -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

        for _ in 0..<24 {
            let code = String((0..<6).map { _ in characters.randomElement()! })
            do {
                let snapshot = try await database.collection("pairs").document(code).getDocument()
                if !snapshot.exists {
                    return code
                }
            } catch {
                continue
            }
        }

        throw AuthServiceError.codeGenerationFailed
    }

    private func userFacingErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain,
           nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
            return "Нет доступа к серверу. Обновите правила Firestore и попробуйте снова."
        }
        if let authError = error as? AuthServiceError {
            return authError.localizedDescription
        }
        return error.localizedDescription
    }
}

private struct PairRecord: Codable {
    var pairID: String
    var hostUserID: String
    var guestUserID: String?
    var connectedAt: Date?

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
    case authenticationFailed

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
        case .authenticationFailed:
            return "Не удалось войти в аккаунт. Попробуйте снова."
        }
    }
}
