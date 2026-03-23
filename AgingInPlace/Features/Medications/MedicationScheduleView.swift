import SwiftUI
import SwiftData

/// Form to create a recurring medication schedule.
/// On save: creates MedicationSchedule, then schedules recurring reminder and missed-dose alert.
/// Checks notification authorization first — shows NotificationPermissionView if needed.
struct MedicationScheduleView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("notificationPermissionRequested") private var permissionRequested: Bool = false

    @Query private var profiles: [UserProfile]
    @Query private var allMembers: [CareTeamMember]

    private var currentMemberID: UUID {
        guard let profile = profiles.first,
              let member = allMembers.first(where: { $0.iCloudRecordID == profile.iCloudRecordID })
        else { return UUID() }
        return member.id
    }

    @State private var drugName: String = ""
    @State private var dose: String = ""
    @State private var selectedTime: Date = {
        // Default to 8:00 AM today
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    @State private var missedWindowMinutes: Int = 30
    @State private var showingPermissionView = false
    @State private var saveError: Error?
    @State private var showingError = false

    private let windowOptions: [Int] = [15, 30, 45, 60]

    private var canSave: Bool {
        !drugName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dose.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Drug name", text: $drugName)
                        .frame(minHeight: A11y.minTouchTarget)
                        .accessibilityLabel("Drug name")

                    TextField("Dose (e.g. 500mg)", text: $dose)
                        .frame(minHeight: A11y.minTouchTarget)
                        .accessibilityLabel("Dose")
                }

                Section("Schedule") {
                    DatePicker(
                        "Time",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .frame(minHeight: A11y.minTouchTarget)
                    .accessibilityLabel("Daily reminder time")

                    Picker("Alert window", selection: $missedWindowMinutes) {
                        ForEach(windowOptions, id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .frame(minHeight: A11y.minTouchTarget)
                    .accessibilityLabel("Alert if dose missed after")
                }
            }
            .navigationTitle("New Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minHeight: A11y.minTouchTarget)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSchedule() }
                        .disabled(!canSave)
                        .frame(minHeight: A11y.minTouchTarget)
                }
            }
            .sheet(isPresented: $showingPermissionView) {
                NotificationPermissionView()
                    .presentationDetents([.medium])
            }
            .alert("Save Failed", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError?.localizedDescription ?? "An unexpected error occurred.")
            }
        }
    }

    // MARK: - Save

    private func saveSchedule() {
        let authorMemberID = currentMemberID

        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let hour = components.hour ?? 8
        let minute = components.minute ?? 0

        do {
            let newSchedule = MedicationSchedule(
                drugName: drugName.trimmingCharacters(in: .whitespaces),
                dose: dose.trimmingCharacters(in: .whitespaces),
                hour: hour,
                minute: minute,
                missedWindowMinutes: missedWindowMinutes,
                createdByMemberID: authorMemberID
            )
            context.insert(newSchedule)
            try context.save()

            // Request notification authorization if not yet asked
            if !permissionRequested {
                showingPermissionView = true
            }

            // Schedule notifications asynchronously
            Task {
                try? await NotificationService.scheduleMedicationReminder(for: newSchedule)
                try? await NotificationService.scheduleMissedDoseAlert(for: newSchedule, onDate: Date())
            }

            dismiss()
        } catch {
            saveError = error
            showingError = true
        }
    }
}

#Preview {
    MedicationScheduleView()
        .modelContainer(for: MedicationSchedule.self, inMemory: true)
}
