import SwiftUI
import SwiftData

/// Senior-facing care team list with role labels, invite, and swipe-to-delete with confirmation.
struct CareTeamListView: View {
    @Environment(\.modelContext) private var context
    @Query private var members: [CareTeamMember]

    @State private var showInviteFlow = false
    @State private var memberToDelete: CareTeamMember? = nil
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if members.isEmpty {
                    emptyStateView
                } else {
                    memberListView
                }
            }
            .navigationTitle("Care Team")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showInviteFlow = true
                    } label: {
                        Label("Invite Caregiver", systemImage: "person.badge.plus")
                    }
                    .frame(minHeight: A11y.minTouchTarget)
                }
            }
            .sheet(isPresented: $showInviteFlow) {
                InviteFlowView()
            }
            .confirmationDialog(
                deleteDialogTitle,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove Member", role: .destructive) {
                    if let member = memberToDelete {
                        removeMember(member)
                    }
                }
                Button("Cancel", role: .cancel) {
                    memberToDelete = nil
                }
            } message: {
                Text("This member will be removed from your care team. You can re-invite them later.")
            }
        }
    }

    // MARK: - List view

    private var memberListView: some View {
        List {
            ForEach(members) { member in
                NavigationLink {
                    // Placeholder — MemberDetailView is created in Plan 03.
                    // Will be replaced with MemberDetailView(member: member) during Plan 05 integration.
                    Text("Member Detail")
                        .navigationTitle(member.displayName)
                } label: {
                    memberRow(member)
                }
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    memberToDelete = members[index]
                    showDeleteConfirmation = true
                }
            }
        }
    }

    // MARK: - Row

    private func memberRow(_ member: CareTeamMember) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(member.displayName) — \(member.role.displayName)")
                    .font(.body)
                    .fontWeight(.medium)

                if member.isProxy {
                    Text("Proxy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .frame(minHeight: A11y.minCardHeight)
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Care Team Members", systemImage: "person.3")
        } description: {
            Text("Invite a caregiver to get started.")
        } actions: {
            Button("Invite Caregiver") {
                showInviteFlow = true
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: A11y.minTouchTarget)
        }
    }

    // MARK: - Computed properties

    private var deleteDialogTitle: String {
        if let member = memberToDelete {
            return "Remove \(member.displayName)?"
        }
        return "Remove Member?"
    }

    // MARK: - Actions

    private func removeMember(_ member: CareTeamMember) {
        // Delete the member from SwiftData (cascade handled by relationship)
        context.delete(member)
        try? context.save()

        // Note: key rotation for ALL categories is triggered after member removal.
        // The EncryptionService.rotateKey calls will be integrated in Plan 05
        // when the full permission revocation flow is wired up end-to-end.
        memberToDelete = nil
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: CareCircle.self, CareTeamMember.self, CareRecord.self,
        InviteCode.self, EmergencyContact.self,
        configurations: config
    )
    let ctx = ModelContext(container)
    let circle = CareCircle(seniorName: "Margaret")
    let sarah = CareTeamMember(displayName: "Sarah", role: .family, circle: circle)
    let maria = CareTeamMember(displayName: "Maria", role: .paidAide, circle: circle)
    circle.members.append(contentsOf: [sarah, maria])
    ctx.insert(circle)
    ctx.insert(sarah)
    ctx.insert(maria)
    try? ctx.save()

    return CareTeamListView()
        .modelContainer(container)
}
