import SwiftUI
import SwiftData

/// Shared care calendar view showing all appointments sorted chronologically.
/// Displays upcoming and past sections. Swipe to delete cancels the reminder notification.
struct CareCalendarView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CalendarEvent.eventDate, order: .forward)
    private var allEvents: [CalendarEvent]

    @State private var showAddEvent = false

    private var now: Date { Date() }

    private var upcomingEvents: [CalendarEvent] {
        allEvents.filter { $0.eventDate >= now }
    }

    private var pastEvents: [CalendarEvent] {
        allEvents.filter { $0.eventDate < now }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allEvents.isEmpty {
                    ContentUnavailableView(
                        "No Appointments",
                        systemImage: "calendar",
                        description: Text("Tap + to add an appointment.")
                    )
                } else {
                    List {
                        if !upcomingEvents.isEmpty {
                            Section("Upcoming") {
                                ForEach(upcomingEvents) { event in
                                    CalendarEventRow(event: event)
                                }
                                .onDelete { indexSet in
                                    deleteEvents(upcomingEvents, at: indexSet)
                                }
                            }
                        }

                        if !pastEvents.isEmpty {
                            Section("Past") {
                                ForEach(pastEvents) { event in
                                    CalendarEventRow(event: event)
                                }
                                .onDelete { indexSet in
                                    deleteEvents(pastEvents, at: indexSet)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Care Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Add Appointment")
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventView()
            }
        }
    }

    // MARK: - Delete

    private func deleteEvents(_ events: [CalendarEvent], at indexSet: IndexSet) {
        for index in indexSet {
            let event = events[index]
            NotificationService.cancelAppointmentReminder(for: event)
            modelContext.delete(event)
        }
        try? modelContext.save()
    }
}

// MARK: - Calendar Event Row

/// A single row in the care calendar list.
private struct CalendarEventRow: View {

    let event: CalendarEvent

    private static let eventDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var decryptedLocation: String? {
        guard let payload = try? EncryptionService.open(event.encryptedPayload, for: .calendar),
              let dict = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let location = dict["location"] as? String,
              !location.isEmpty
        else { return nil }
        return location
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.headline)
                .frame(minHeight: 44)

            Text(Self.eventDateFormatter.string(from: event.eventDate))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let location = decryptedLocation {
                Text(location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CareCalendarView()
        .modelContainer(for: CalendarEvent.self, inMemory: true)
}
