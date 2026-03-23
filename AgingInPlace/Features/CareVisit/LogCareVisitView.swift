import SwiftUI
import SwiftData

struct LogCareVisitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("caregiverMemberID") private var caregiverMemberIDString: String = ""

    @State private var visitDate: Date = Date()
    @State private var meals: String = ""
    @State private var mobility: String = ""
    @State private var observations: String = ""
    @State private var concerns: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !meals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !mobility.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !observations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !concerns.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var authorMemberID: UUID {
        UUID(uuidString: caregiverMemberIDString) ?? UUID()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Visit Details") {
                    DatePicker(
                        "Visit Date",
                        selection: $visitDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityLabel("Visit Date")
                }

                Section("Meals") {
                    TextEditor(text: $meals)
                        .frame(minHeight: 80)
                        .accessibilityLabel("Meals")
                        .overlay(alignment: .topLeading) {
                            if meals.isEmpty {
                                Text("What did they eat?")
                                    .foregroundStyle(Color(uiColor: .placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Mobility") {
                    TextEditor(text: $mobility)
                        .frame(minHeight: 80)
                        .accessibilityLabel("Mobility")
                        .overlay(alignment: .topLeading) {
                            if mobility.isEmpty {
                                Text("How was their movement today?")
                                    .foregroundStyle(Color(uiColor: .placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Observations") {
                    TextEditor(text: $observations)
                        .frame(minHeight: 80)
                        .accessibilityLabel("Observations")
                        .overlay(alignment: .topLeading) {
                            if observations.isEmpty {
                                Text("General observations...")
                                    .foregroundStyle(Color(uiColor: .placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Concerns") {
                    TextEditor(text: $concerns)
                        .frame(minHeight: 80)
                        .accessibilityLabel("Concerns")
                        .overlay(alignment: .topLeading) {
                            if concerns.isEmpty {
                                Text("Any concerns to note?")
                                    .foregroundStyle(Color(uiColor: .placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Color.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Log Care Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(minWidth: A11y.minTouchTarget, minHeight: A11y.minTouchTarget)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVisit()
                    }
                    .disabled(!isFormValid || isSaving)
                    .frame(minWidth: A11y.minTouchTarget, minHeight: A11y.minTouchTarget)
                }
            }
        }
    }

    // MARK: - Save

    private func saveVisit() {
        guard isFormValid, !isSaving else { return }
        isSaving = true
        errorMessage = nil

        do {
            let payload = CareVisitPayload(
                meals: meals,
                mobility: mobility,
                observations: observations,
                concerns: concerns
            )
            let jsonData = try JSONEncoder().encode(payload)
            let encryptedPayload = try EncryptionService.seal(jsonData, for: .careVisits)

            let log = CareVisitLog(
                encryptedPayload: encryptedPayload,
                visitDate: visitDate,
                authorMemberID: authorMemberID
            )
            context.insert(log)
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save care visit. Please try again."
            isSaving = false
        }
    }
}

// MARK: - Payload structure

private struct CareVisitPayload: Codable {
    let meals: String
    let mobility: String
    let observations: String
    let concerns: String
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(
        for: Schema(AgingInPlaceSchemaV3.models),
        migrationPlan: AgingInPlaceMigrationPlan.self,
        configurations: [config]
    )
    return LogCareVisitView()
        .modelContainer(container)
}
