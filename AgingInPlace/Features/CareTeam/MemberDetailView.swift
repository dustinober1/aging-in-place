import SwiftUI
import SwiftData

struct MemberDetailView: View {
    @Bindable var member: CareTeamMember
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showRemoveConfirmation: Bool = false

    var body: some View {
        List {
            // MARK: - Header section
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(member.displayName)
                            .font(.title2.bold())
                        if member.isProxy {
                            Text("Proxy")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    Text(member.role.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .frame(minHeight: A11y.minTouchTarget)
            }

            // MARK: - Permissions section
            Section(header: Text("Can see:")) {
                ForEach(PermissionCategory.allCases, id: \.self) { category in
                    PermissionToggleRow(category: category, member: member)
                }
            }

            // MARK: - Remove from team section
            Section {
                if member.isProxy {
                    Text("To remove a proxy, designate a new proxy first.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: A11y.minTouchTarget)
                } else {
                    Button(role: .destructive) {
                        showRemoveConfirmation = true
                    } label: {
                        Text("Remove from Team")
                            .frame(maxWidth: .infinity, minHeight: A11y.minTouchTarget)
                    }
                }
            }
        }
        .navigationTitle("Care Team Member")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove \(member.displayName) from the team?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                removeMember()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will revoke all their access and rotate the encryption keys.")
        }
    }

    // MARK: - Remove member action

    private func removeMember() {
        // Capture the categories the member had access to before deletion
        let categoriesToRotate = member.grantedCategories

        // Delete from SwiftData
        modelContext.delete(member)
        try? modelContext.save()

        // Rotate keys for all categories the member had access to
        Task {
            for category in categoriesToRotate {
                try? EncryptionService.rotateKey(for: category)
            }
        }

        dismiss()
    }
}
