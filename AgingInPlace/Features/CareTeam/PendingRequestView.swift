import SwiftUI
import SwiftData

/// Senior-facing pending request approval screen.
struct PendingRequestView: View {
    @Environment(\.modelContext) private var context

    let member: CareTeamMember

    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "person.badge.clock")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)

                Text("Pending Request")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text(member.displayName)
                    .font(.title)
                    .fontWeight(.semibold)

                Text(member.role.displayName)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Text("Wants to join your care team")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    approveMember()
                } label: {
                    Label("Approve", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: A11y.minTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal)

                Button(role: .destructive) {
                    rejectMember()
                } label: {
                    Label("Reject", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: A11y.minTouchTarget)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Actions

    private func approveMember() {
        // Grant all 4 default permission categories on approval
        member.grantedCategories = PermissionCategory.allCases
        member.lastModified = Date()
        try? context.save()
        onApprove?()
    }

    private func rejectMember() {
        context.delete(member)
        try? context.save()
        onReject?()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(
        for: CareCircle.self, CareTeamMember.self, CareRecord.self,
        InviteCode.self, EmergencyContact.self,
        configurations: config
    )
    let ctx = ModelContext(container)
    let circle = CareCircle(seniorName: "Margaret")
    let member = CareTeamMember(displayName: "Sarah Johnson", role: .family, circle: circle)
    circle.members?.append(member)
    ctx.insert(circle)
    ctx.insert(member)
    try? ctx.save()

    return PendingRequestView(member: member)
        .modelContainer(container)
}
