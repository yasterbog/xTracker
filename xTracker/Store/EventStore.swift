//
//  EventStore.swift
//  xTracker
//

import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var events: [Event] = []
    @Published var pairID: String = ""

    private let firestoreService: FirestoreService
    private var eventsListener: ListenerRegistration?

    private enum Keys {
        static let savedPairID = "savedPairID"
        static let legacyPairID = "auth.pairID"
    }

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
        self.pairID = UserDefaults.standard.string(forKey: Keys.savedPairID)
            ?? UserDefaults.standard.string(forKey: Keys.legacyPairID)
            ?? ""

        if pairID.isEmpty {
            events = MockEventData.allEvents
        } else {
            startListening()
        }
    }

    func setPairID(_ newPairID: String) {
        guard pairID != newPairID else { return }
        pairID = newPairID
        UserDefaults.standard.set(newPairID, forKey: Keys.savedPairID)
        UserDefaults.standard.set(newPairID, forKey: Keys.legacyPairID)

        if newPairID.isEmpty {
            stopListening()
            events = MockEventData.allEvents
        } else {
            startListening()
        }
    }

    func addEvent(_ event: Event) {
        if pairID.isEmpty {
            events.append(event)
            sortEvents()
            return
        }

        Task {
            do {
                try await firestoreService.saveEvent(event, pairID: pairID)
            } catch {
                print("Failed to save event: \(error.localizedDescription)")
            }
        }
    }

    func addEventAndWaitForUploads(_ event: Event) async {
        if pairID.isEmpty {
            events.append(event)
            sortEvents()
            return
        }

        do {
            try await firestoreService.saveEvent(event, pairID: pairID)
        } catch {
            print("Failed to save event: \(error.localizedDescription)")
        }
    }

    func deleteEvent(_ event: Event) {
        if pairID.isEmpty {
            events.removeAll { $0.id == event.id }
            return
        }

        Task {
            do {
                try await firestoreService.deleteEvent(event, pairID: pairID)
            } catch {
                print("Failed to delete event: \(error.localizedDescription)")
            }
        }
    }

    func updateEvent(_ event: Event) {
        if pairID.isEmpty {
            guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
            events[index] = event
            sortEvents()
            return
        }

        Task {
            do {
                try await firestoreService.updateEvent(event, pairID: pairID)
            } catch {
                print("Failed to update event: \(error.localizedDescription)")
            }
        }
    }

    func updateEventAndWaitForUploads(_ event: Event) async {
        if pairID.isEmpty {
            guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
            events[index] = event
            sortEvents()
            return
        }

        do {
            try await firestoreService.updateEvent(event, pairID: pairID)
        } catch {
            print("Failed to update event: \(error.localizedDescription)")
        }
    }

    func events(on date: Date) -> [Event] {
        let calendar = Calendar.current
        return events
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    func eventCount(on date: Date) -> Int {
        events(on: date).count
    }

    func resetToLocalMockData() {
        stopListening()
        pairID = ""
        UserDefaults.standard.removeObject(forKey: Keys.savedPairID)
        UserDefaults.standard.removeObject(forKey: Keys.legacyPairID)
        events = MockEventData.allEvents
    }

    private func startListening() {
        stopListening()
        guard !pairID.isEmpty else { return }

        eventsListener = firestoreService.listenToEvents(pairID: pairID) { [weak self] firestoreEvents in
            Task { @MainActor in
                self?.events = firestoreEvents
            }
        }
    }

    private func stopListening() {
        eventsListener?.remove()
        eventsListener = nil
    }

    private func sortEvents() {
        events.sort { $0.date < $1.date }
    }

    deinit {
        eventsListener?.remove()
    }
}
