//
//  FirestoreService.swift
//  xTracker
//

import FirebaseFirestore
import Foundation

struct FirestoreEventChange {
    let event: Event
    let type: DocumentChangeType
}

final class FirestoreService {
    private lazy var database = Firestore.firestore()

    func saveEvent(_ event: Event, pairID: String) async throws {
        let record = FirestoreEventRecord(from: event)
        try await database
            .collection("pairs")
            .document(pairID)
            .collection("events")
            .document(event.id)
            .setData(from: record)
    }

    func deleteEvent(_ event: Event, pairID: String) async throws {
        try await database
            .collection("pairs")
            .document(pairID)
            .collection("events")
            .document(event.id)
            .delete()
    }

    func deleteAllEvents(pairID: String) async throws {
        try await deleteAllDocuments(
            in: database
                .collection("pairs")
                .document(pairID)
                .collection("events")
        )
    }

    func deleteAllUsers(pairID: String) async throws {
        try await deleteAllDocuments(
            in: database
                .collection("pairs")
                .document(pairID)
                .collection("users")
        )
    }

    func deleteEventsCreatedBy(userID: String, pairID: String) async throws {
        let eventsCollection = database
            .collection("pairs")
            .document(pairID)
            .collection("events")

        let queriedSnapshot = try await eventsCollection
            .whereField("createdBy", isEqualTo: userID)
            .getDocuments()

        var deletedIDs = Set<String>()
        for document in queriedSnapshot.documents {
            try await document.reference.delete()
            deletedIDs.insert(document.documentID)
        }

        // Fallback for legacy events saved before auth synced user IDs.
        let allSnapshot = try await eventsCollection.getDocuments()
        for document in allSnapshot.documents {
            guard !deletedIDs.contains(document.documentID) else { continue }
            guard let record = try? document.data(as: FirestoreEventRecord.self) else { continue }
            if record.createdBy == userID || record.createdBy == "local-user" {
                try await document.reference.delete()
            }
        }
    }

    func deleteUserProfile(pairID: String, userID: String) async throws {
        try await database
            .collection("pairs")
            .document(pairID)
            .collection("users")
            .document(userID)
            .delete()
    }

    func deletePairDocument(pairID: String) async throws {
        try await database.collection("pairs").document(pairID).delete()
    }

    func migrateEventsCreatedBy(
        userID: String,
        from sourcePairID: String,
        to destinationPairID: String
    ) async throws {
        guard !userID.isEmpty, !sourcePairID.isEmpty, !destinationPairID.isEmpty else { return }
        guard sourcePairID != destinationPairID else { return }

        let eventsCollection = database
            .collection("pairs")
            .document(sourcePairID)
            .collection("events")

        let snapshot = try await eventsCollection.getDocuments()

        for document in snapshot.documents {
            guard var record = try? document.data(as: FirestoreEventRecord.self),
                  let event = record.toEvent()
            else {
                continue
            }

            let isOwnedByUser = record.createdBy == userID || record.createdBy == "local-user"
            guard isOwnedByUser else { continue }

            var migratedEvent = event
            if record.createdBy == "local-user" {
                migratedEvent.createdBy = userID
            }

            try await saveEvent(migratedEvent, pairID: destinationPairID)
            try await document.reference.delete()
        }
    }

    private func deleteAllDocuments(in collection: CollectionReference) async throws {
        let snapshot = try await collection.getDocuments()
        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }

    func updateEvent(_ event: Event, pairID: String) async throws {
        try await saveEvent(event, pairID: pairID)
    }

    func fetchUserProfileSnapshot(
        pairID: String,
        userID: String
    ) async throws -> UserAvatarProfile? {
        guard !pairID.isEmpty, !userID.isEmpty else { return nil }

        let snapshot = try await database
            .collection("pairs")
            .document(pairID)
            .collection("users")
            .document(userID)
            .getDocument()

        guard let data = snapshot.data() else { return nil }

        let rawName = data["name"] as? String
        let name = rawName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? rawName!.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        guard let name else { return nil }

        return UserAvatarProfile(
            userID: userID,
            name: name,
            avatarBase64: data["avatarBase64"] as? String,
            avatarURL: data["avatarURL"] as? String
        )
    }

    func findPersonalPairID(for userID: String) async throws -> String? {
        let snapshot = try await database
            .collection("pairs")
            .whereField("hostUserID", isEqualTo: userID)
            .limit(to: 1)
            .getDocuments()

        return snapshot.documents.first?.documentID
    }

    @discardableResult
    func listenToEvents(
        pairID: String,
        completion: @escaping ([Event]) -> Void
    ) -> ListenerRegistration {
        listenToEvents(pairID: pairID) { events, _ in
            completion(events)
        }
    }

    @discardableResult
    func listenToEvents(
        pairID: String,
        completion: @escaping ([Event], [FirestoreEventChange]) -> Void
    ) -> ListenerRegistration {
        database
            .collection("pairs")
            .document(pairID)
            .collection("events")
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("Firestore events listener error: \(error.localizedDescription)")
                    return
                }
                guard let snapshot else { return }

                let events = snapshot.documents.compactMap { document -> Event? in
                    guard let record = try? document.data(as: FirestoreEventRecord.self) else {
                        return nil
                    }
                    return record.toEvent()
                }
                .sorted { $0.date < $1.date }

                let changes = snapshot.documentChanges.compactMap { change -> FirestoreEventChange? in
                    guard let record = try? change.document.data(as: FirestoreEventRecord.self),
                          let event = record.toEvent()
                    else {
                        return nil
                    }
                    return FirestoreEventChange(event: event, type: change.type)
                }

                completion(events, changes)
            }
    }
}
