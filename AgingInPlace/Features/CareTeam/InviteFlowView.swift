import SwiftUI
import SwiftData

/// Senior-facing invite screen — displays a generated invite code with Copy and Share options.
struct InviteFlowView: View {
    @Environment(\.modelContext) private var context
    @Query private var circles: [CareCircle]

    @State private var currentCode: String = ""
    @State private var showCopiedFeedback = false

    private var circle: CareCircle? { circles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Invite a Caregiver")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Share this code with the person you want to add to your care team.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Code display
                Text(currentCode)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Copy button
                Button {
                    UIPasteboard.general.string = currentCode
                    showCopiedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopiedFeedback = false
                    }
                } label: {
                    Label(showCopiedFeedback ? "Copied!" : "Copy", systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: A11y.minTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(showCopiedFeedback ? .green : .accentColor)
                .padding(.horizontal)

                // Share button
                ShareLink(item: "Join my care circle with code: \(currentCode)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: A11y.minTouchTarget)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                // Generate new code button
                Button("Generate New Code") {
                    generateNewCode()
                }
                .font(.subheadline)
                .frame(minHeight: A11y.minTouchTarget)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Invite Caregiver")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if currentCode.isEmpty {
                    generateNewCode()
                }
            }
        }
    }

    private func generateNewCode() {
        let code = InviteCodeGenerator.generate()
        currentCode = code

        guard let circle else { return }
        let invite = InviteCode(code: code, circle: circle)
        circle.pendingInvites.append(invite)
        context.insert(invite)
        try? context.save()
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
    ctx.insert(circle)
    try? ctx.save()

    return InviteFlowView()
        .modelContainer(container)
}
