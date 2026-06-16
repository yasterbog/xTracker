//
//  NotificationService.swift
//  xTracker
//
//  Event planner push flow — inactive when AppFeatures.eventPlannerEnabled == false.
//

import FirebaseFirestore
import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private lazy var database = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var deliveredNotificationIDs: Set<String> = []
    private var hasReceivedInitialSnapshot = false

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .notDetermined else { return }

        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func sendPushToPartner(toUserId: String, title: String, body: String) async {
        guard !toUserId.isEmpty else { return }

        let record = FirestoreNotificationRecord(
            toUserId: toUserId,
            title: title,
            body: body,
            createdAt: Date(),
            read: false
        )

        do {
            try database.collection("notifications").addDocument(from: record)
        } catch {
            #if DEBUG
            print("[NotificationService] Failed to queue push: \(error.localizedDescription)")
            #endif
        }
    }

    func startListening(forUserID userID: String) {
        stopListening()

        guard !userID.isEmpty else { return }

        hasReceivedInitialSnapshot = false
        deliveredNotificationIDs.removeAll()

        listener = database
            .collection("notifications")
            .whereField("toUserId", isEqualTo: userID)
            .whereField("read", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                Task { @MainActor in
                    guard error == nil, let snapshot else { return }

                    if !self.hasReceivedInitialSnapshot {
                        self.hasReceivedInitialSnapshot = true
                        snapshot.documents.forEach {
                            self.deliveredNotificationIDs.insert($0.documentID)
                        }
                        return
                    }

                    for change in snapshot.documentChanges where change.type == .added {
                        let documentID = change.document.documentID
                        guard !self.deliveredNotificationIDs.contains(documentID) else { continue }
                        self.deliveredNotificationIDs.insert(documentID)

                        guard let record = try? change.document.data(as: FirestoreNotificationRecord.self) else {
                            continue
                        }

                        self.presentLocalNotification(title: record.title, body: record.body)
                    }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        hasReceivedInitialSnapshot = false
        deliveredNotificationIDs.removeAll()
    }

    private func presentLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

private struct FirestoreNotificationRecord: Codable {
    var toUserId: String
    var title: String
    var body: String
    var createdAt: Date
    var read: Bool
}
