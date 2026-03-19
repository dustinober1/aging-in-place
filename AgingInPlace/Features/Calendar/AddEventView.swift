import SwiftUI
import SwiftData

/// Form to create a new calendar event.
/// Encrypts location, notes, and attendees before saving. Schedules a local reminder notification.
struct AddEventView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Appointment fields

    @State private var title = ""
    @State private var eventDate: Date = {
        // Default to tomorrow at 9 AM
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }()

    // MARK: - Details fields

    @State private var location = ""
    @State private var notes = ""
    @State private var attendees = ""

    // MARK: - Reminder offset

    private let reminderOptions: [(label: String, minutes: Int)] = [
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("1 hour", 60),
        ("2 hours", 120),
        ("1 day", 1440)
    ]
    @State private var selectedReminderMinutes = 60

    // MARK: - Error state

    @State private var saveError: String?

    private var isSaveEnabled: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Appointment section
                Section("Appointment") {
                    TextField("Title (required)", text: $title)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Appointment title")

                    DatePicker(
                        "Date & Time",
                        selection: $eventDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .frame(minHeight: 44)
                }

                // MARK: Details section
                Section("Details") {
                    TextField("Location (optional)", text: $location)
                        .frame(minHeight: 44)

                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Notes (optional)")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 88)
                    }

                    TextField("Attendees (comma-separated, optional)", text: $attendees)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Attendees, comma-separated")
                }

                // MARK: Reminder section
                Section("Reminder") {
                    Picker("Remind me", selection: $selectedReminderMinutes) {
                        ForEach(reminderOptions, id: \.minutes) { option in
                            Text(option.label).tag(option.minutes)
                        }
                    }
                    .frame(minHeight: 44)
                }

                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEvent()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(!isSaveEnabled)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Save logic

    private func saveEvent() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        // Build the payload dict
        let attendeeList = attendees
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let payloadDict: [String: Any] = [
            "location": location.trimmingCharacters(in: .whitespacesAndNewlines),
            "notes": notes.trimmingCharacters(in: .whitespacesAndNewlines),
            "attendees": attendeeList
        ]

        let jsonData: Data
        let encryptedPayload: Data

        do {
            jsonData = try JSONSerialization.data(withJSONObject: payloadDict)
            encryptedPayload = try EncryptionService.seal(jsonData, for: .calendar)
        } catch {
            saveError = "Failed to encrypt event details. Please try again."
            return
        }

        // Use a placeholder member ID (real app would use logged-in member ID from AppStorage)
        let memberID = UUID()

        let newEvent = CalendarEvent(
            title: trimmedTitle,
            eventDate: eventDate,
            reminderOffsetMinutes: selectedReminderMinutes,
            encryptedPayload: encryptedPayload,
            createdByMemberID: memberID
        )

        modelContext.insert(newEvent)

        do {
            try modelContext.save()
        } catch {
            saveError = "Failed to save appointment. Please try again."
            modelContext.delete(newEvent)
            return
        }

        // Schedule reminder notification in a Task — non-blocking, fire-and-forget
        Task {
            try? await NotificationService.scheduleAppointmentReminder(for: newEvent)
        }

        dismiss()
    }
}

#Preview {
    AddEventView()
        .modelContainer(for: CalendarEvent.self, inMemory: true)
}
