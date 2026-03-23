import SwiftUI
import SwiftData

struct JoinCircleView: View {
    @Environment(\.modelContext) private var context
    @Query private var circles: [CareCircle]

    @State private var enteredCode = ""
    @State private var displayName = ""
    @State private var selectedRole: MemberRole = .family
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var didJoin = false
    @State private var iCloudAvailable = true

    private var circle: CareCircle? { circles.first }

    var body: some View {
        NavigationStack {
            if didJoin {
                joinedConfirmationView
            } else {
                formView
            }
        }
        .task {
            let status = await CloudKitAvailability.checkAccountStatus()
            iCloudAvailable = (status == .available)
        }
    }

    // MARK: - Form

    private var formView: some View {
        Form {
            if iCloudAvailable {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "link.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentColor)
                        Text("Open the invite link sent by your senior to join their care circle automatically.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Join via Link")
                }
            }

            Section(iCloudAvailable ? "Or Enter Code Manually" : "Invite Code") {
                TextField("CARE-XXXX-XXXX", text: $enteredCode)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .onChange(of: enteredCode) { _, newValue in
                        enteredCode = newValue.uppercased()
                        errorMessage = nil
                    }
            }

            Section("Your Details") {
                TextField("Your name", text: $displayName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)

                Picker("Role", selection: $selectedRole) {
                    ForEach(MemberRole.allCases, id: \.self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    requestToJoin()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Request to Join")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: A11y.minTouchTarget)
                    }
                }
                .disabled(enteredCode.isEmpty || displayName.isEmpty || isLoading)
            }
        }
        .navigationTitle("Join Care Circle")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Joined confirmation

    private var joinedConfirmationView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("Request Sent!")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Wait for the senior to approve your request.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .navigationTitle("Request Sent")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Join logic

    private func requestToJoin() {
        isLoading = true
        errorMessage = nil

        let trimmedCode = enteredCode.trimmingCharacters(in: .whitespaces)
        let fetchDesc = FetchDescriptor<InviteCode>(predicate: #Predicate { $0.code == trimmedCode })

        do {
            let matching = try context.fetch(fetchDesc)

            guard let invite = matching.first else {
                errorMessage = "Invalid code. Please check and try again."
                isLoading = false
                return
            }

            guard !invite.isUsed else {
                errorMessage = "This code has already been used."
                isLoading = false
                return
            }

            guard let circle = invite.circle ?? circles.first else {
                errorMessage = "No care circle found for this code."
                isLoading = false
                return
            }

            let member = CareTeamMember(
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                role: selectedRole,
                circle: circle
            )
            circle.members.append(member)
            context.insert(member)
            invite.isUsed = true
            try context.save()

            didJoin = true
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isLoading = false
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
    let code = InviteCodeGenerator.generate()
    let invite = InviteCode(code: code, circle: circle)
    circle.pendingInvites.append(invite)
    ctx.insert(circle)
    ctx.insert(invite)
    try? ctx.save()

    return JoinCircleView()
        .modelContainer(container)
}
