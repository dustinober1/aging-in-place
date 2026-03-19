import SwiftUI
import SwiftData

struct EmergencyContactFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Editing an existing contact (nil = creating new)
    var existingContact: EmergencyContact?

    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var relationship: String = ""
    @State private var medicalNotes: String = ""
    @State private var showValidationError = false

    var isEditing: Bool { existingContact != nil }

    init(existingContact: EmergencyContact? = nil) {
        self.existingContact = existingContact
        if let contact = existingContact {
            _name = State(initialValue: contact.name)
            _phone = State(initialValue: contact.phone)
            _relationship = State(initialValue: contact.relationship)
            _medicalNotes = State(initialValue: contact.medicalNotes ?? "")
        }
    }

    var body: some View {
        Form {
            Section("Contact Info") {
                LabeledTextField(label: "Name", text: $name, prompt: "Full name")
                LabeledTextField(label: "Phone", text: $phone, prompt: "Phone number")
                    .keyboardType(.phonePad)
                LabeledTextField(label: "Relationship", text: $relationship, prompt: "e.g. Spouse, Doctor")
            }

            Section("Medical Notes (optional)") {
                TextEditor(text: $medicalNotes)
                    .frame(minHeight: 80)
                    .accessibilityLabel("Medical notes")
            }

            if showValidationError {
                Section {
                    Text("Name and phone number are required.")
                        .foregroundStyle(Color.red)
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Contact" : "Add Contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty, !trimmedPhone.isEmpty else {
            showValidationError = true
            return
        }

        let notes = medicalNotes.trimmingCharacters(in: .whitespaces)

        if let contact = existingContact {
            contact.name = trimmedName
            contact.phone = trimmedPhone
            contact.relationship = relationship.trimmingCharacters(in: .whitespaces)
            contact.medicalNotes = notes.isEmpty ? nil : notes
            contact.lastModified = Date()
        } else {
            let contact = EmergencyContact(
                name: trimmedName,
                phone: trimmedPhone,
                relationship: relationship.trimmingCharacters(in: .whitespaces),
                medicalNotes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(contact)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Helpers

private struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    let prompt: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)
            TextField(prompt, text: $text)
                .frame(minHeight: A11y.minTouchTarget)
                .keyboardType(keyboardType)
        }
    }
}

#Preview {
    NavigationStack {
        EmergencyContactFormView()
            .modelContainer(for: EmergencyContact.self, inMemory: true)
    }
}
