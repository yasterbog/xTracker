//
//  DayEventsSheet.swift
//  xTracker
//

import SwiftUI

struct DayEventsSheet: View {
    let date: Date
    let events: [Event]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedEvent: Event?

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    emptyStateView
                } else {
                    List(events) { event in
                        Button {
                            selectedEvent = event
                        } label: {
                            EventRowView(event: event, timeFormatter: Self.timeFormatter)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(AppTheme.background)
                        .listRowSeparatorTint(AppTheme.secondaryText.opacity(0.3))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.background)
            .navigationTitle(Self.dayFormatter.string(from: date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedEvent) { event in
                EventDetailView(eventID: event.id)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("Нет событий")
                .foregroundColor(.gray)
        }
    }
}

private struct EventRowView: View {
    let event: Event
    let timeFormatter: DateFormatter

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeFormatter.string(from: event.date))
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 52, alignment: .leading)

            Text(event.activities.map(\.emoji).joined(separator: " "))
                .font(.system(size: 20, weight: .regular, design: .default))
                .frame(maxWidth: .infinity, alignment: .leading)

            if event.hasNotes {
                EventNotesIndicator()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DayEventsSheet(date: Date(), events: EventStore().events)
}
