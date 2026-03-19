import SwiftUI
import SwiftData

struct EmergencyContactListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EmergencyContact.name) private var contacts: [EmergencyContact]
    @State private var showingAddForm = false

    var body: some View {
        Group {
            if contacts.isEmpty {
                emptyState
            } else {
                contactList
            }
        }
        .navigationTitle("Emergency Contacts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Emergency Contact")
            }
        }
        .sheet(isPresented: $showingAddForm) {
            NavigationStack {
                EmergencyContactFormView()
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView(
            "No Emergency Contacts",
            systemImage: "cross.case.fill",
            description: Text("Add emergency contacts so care team members can reach them quickly.")
        )
        .overlay(alignment: .bottom) {
            Button {
                showingAddForm = true
            } label: {
                Text("Add Contact")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: A11y.minTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    private var contactList: some View {
        List {
            ForEach(contacts) { contact in
                ContactRow(contact: contact)
            }
            .onDelete(perform: deleteContacts)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(contacts[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Contact Row

private struct ContactRow: View {
    let contact: EmergencyContact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contact.name)
                .font(.headline)
            Text(contact.relationship)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            if !contact.phone.isEmpty {
                callButton
            }
        }
        .frame(minHeight: A11y.minTouchTarget)
        .accessibilityElement(children: .combine)
    }

    private var callButton: some View {
        Button {
            let digits = contact.phone.filter { $0.isNumber || $0 == "+" }
            if let url = URL(string: "tel:\(digits)") {
                UIApplication.shared.open(url)
            }
        } label: {
            Label(contact.phone, systemImage: "phone.fill")
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Call \(contact.name)")
    }
}

#Preview {
    NavigationStack {
        EmergencyContactListView()
            .modelContainer(for: EmergencyContact.self, inMemory: true)
    }
}
