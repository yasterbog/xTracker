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
        try database
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

    func updateEvent(_ event: Event, pairID: String) async throws {
        try await saveEvent(event, pairID: pairID)
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
                guard error == nil, let snapshot else {
                    completion([], [])
                    return
                }

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
