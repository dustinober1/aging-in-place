import SwiftUI
import SwiftData

struct LogMoodView: View {
    let authorType: MoodAuthorType

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("caregiverMemberID") private var caregiverMemberIDString: String = ""
    @AppStorage("seniorMemberID") private var seniorMemberIDString: String = ""
    @AppStorage("seniorName") private var seniorName: String = "them"

    @State private var selectedMood: Int = 3
    @State private var notes: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private var authorMemberID: UUID {
        switch authorType {
        case .senior:
            return UUID(uuidString: seniorMemberIDString) ?? UUID()
        case .caregiver:
            return UUID(uuidString: caregiverMemberIDString) ?? UUID()
        }
    }

    private var navigationTitle: String {
        switch authorType {
        case .senior:
            return "How are you feeling?"
        case .caregiver:
            return "How is \(seniorName) feeling?"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mood") {
                    MoodPickerView(selectedMood: $selectedMood)
                        .padding(.vertical, 8)
                }

                Section("Notes (optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .accessibilityLabel("Notes")
                        .overlay(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Add a note...")
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
            .navigationTitle(navigationTitle)
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
                        saveMood()
                    }
                    .disabled(isSaving)
                    .frame(minWidth: A11y.minTouchTarget, minHeight: A11y.minTouchTarget)
                }
            }
        }
    }

    // MARK: - Save

    private func saveMood() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        do {
            var encryptedNotes: Data?
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNotes.isEmpty {
                let notesData = trimmedNotes.data(using: .utf8)!
                encryptedNotes = try EncryptionService.seal(notesData, for: .mood)
            }

            let log = MoodLog(
                moodValue: selectedMood,
                authorMemberID: authorMemberID,
                authorType: authorType,
                notes: encryptedNotes
            )
            context.insert(log)
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save mood. Please try again."
            isSaving = false
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(
        for: Schema(AgingInPlaceSchemaV3.models),
        migrationPlan: AgingInPlaceMigrationPlan.self,
        configurations: [config]
    )
    return LogMoodView(authorType: .senior)
        .modelContainer(container)
}
