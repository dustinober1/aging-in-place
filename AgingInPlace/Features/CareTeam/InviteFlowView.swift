import SwiftUI
import SwiftData
import CloudKit

struct InviteFlowView: View {
    @Environment(\.modelContext) private var context
    @Query private var circles: [CareCircle]

    @State private var showShareSheet = false
    @State private var iCloudAvailable = true
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

                    Text(iCloudAvailable
                         ? "Share a link to invite someone to your care team."
                         : "Share this code with the person you want to add to your care team.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if iCloudAvailable {
                    cloudKitShareSection
                } else {
                    localCodeFallbackSection
                }

                Spacer()
            }
            .navigationTitle("Invite Caregiver")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                let status = await CloudKitAvailability.checkAccountStatus()
                iCloudAvailable = (status == .available)
                if !iCloudAvailable && currentCode.isEmpty {
                    generateNewCode()
                }
            }
        }
    }

    // MARK: - CloudKit Share

    private var cloudKitShareSection: some View {
        Button {
            showShareSheet = true
        } label: {
            Label("Share Invite Link", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .frame(minHeight: A11y.minTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .sheet(isPresented: $showShareSheet) {
            if let circle,
               let ckContainer = SharingService.persistentCloudKitContainer(from: context),
               let store = ckContainer.persistentStoreCoordinator.persistentStores.first {
                CloudSharingControllerRepresentable(
                    controller: SharingService.makeSharingController(
                        for: circle,
                        persistentStore: store,
                        container: ckContainer
                    )
                )
            } else {
                ContentUnavailableView(
                    "Sharing Unavailable",
                    systemImage: "icloud.slash",
                    description: Text("Could not connect to iCloud. Try again later.")
                )
            }
        }
    }

    // MARK: - Local Code Fallback

    private var localCodeFallbackSection: some View {
        VStack(spacing: 16) {
            Text(currentCode)
                .font(.system(.title, design: .monospaced, weight: .bold))
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

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

            ShareLink(item: "Join my care circle with code: \(currentCode)") {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: A11y.minTouchTarget)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Button("Generate New Code") {
                generateNewCode()
            }
            .font(.subheadline)
            .frame(minHeight: A11y.minTouchTarget)
            .padding(.horizontal)
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
