import SwiftUI
import SwiftData

/// Form to log a medication dose.
/// If opened from a schedule, pre-fills drug name and dose, and links via scheduleID.
/// On save: encrypts payload via EncryptionService, inserts MedicationLog, cancels missed-dose alert.
struct LogMedicationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Optional schedule — when provided, pre-fills fields and links scheduleID.
    let schedule: MedicationSchedule?

    @Query private var profiles: [UserProfile]
    @Query private var allMembers: [CareTeamMember]

    private var currentMemberID: UUID {
        guard let profile = profiles.first,
              let member = allMembers.first(where: { $0.iCloudRecordID == profile.iCloudRecordID })
        else { return UUID() }
        return member.id
    }

    @State private var drugName: String
    @State private var dose: String
    @State private var administeredAt: Date = Date()
    @State private var notes: String = ""
    @State private var saveError: Error?
    @State private var showingError = false

    init(schedule: MedicationSchedule? = nil) {
        self.schedule = schedule
        _drugName = State(initialValue: schedule?.drugName ?? "")
        _dose = State(initialValue: schedule?.dose ?? "")
    }

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

                Section("Time") {
                    DatePicker(
                        "Administered at",
                        selection: $administeredAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .frame(minHeight: A11y.minTouchTarget)
                }

                Section("Notes (optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .accessibilityLabel("Notes")
                }
            }
            .navigationTitle("Log Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minHeight: A11y.minTouchTarget)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveDose() }
                        .disabled(!canSave)
                        .frame(minHeight: A11y.minTouchTarget)
                }
            }
            .alert("Save Failed", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError?.localizedDescription ?? "An unexpected error occurred.")
            }
        }
    }

    // MARK: - Save

    private func saveDose() {
        let authorMemberID = currentMemberID

        do {
            // JSON-encode the payload
            struct MedPayload: Codable {
                let drugName: String
                let dose: String
                let notes: String
            }
            let payload = MedPayload(
                drugName: drugName.trimmingCharacters(in: .whitespaces),
                dose: dose.trimmingCharacters(in: .whitespaces),
                notes: notes
            )
            let jsonData = try JSONEncoder().encode(payload)
            let encryptedPayload = try EncryptionService.seal(jsonData, for: .medications)

            // Insert MedicationLog
            let log = MedicationLog(
                scheduleID: schedule?.id,
                encryptedPayload: encryptedPayload,
                administeredAt: administeredAt,
                authorMemberID: authorMemberID
            )
            context.insert(log)
            try context.save()

            // Cancel missed-dose alert if this was a scheduled dose
            if let schedule {
                NotificationService.cancelMissedDoseAlert(for: schedule, onDate: administeredAt)
            }

            dismiss()
        } catch {
            saveError = error
            showingError = true
        }
    }
}

#Preview {
    LogMedicationView(schedule: nil)
        .modelContainer(for: MedicationLog.self, inMemory: true)
}
