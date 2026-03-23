import SwiftUI
import SwiftData

struct CareCircleSetupView: View {
    @Environment(\.modelContext) private var context
    let role: UserRole
    let displayName: String
    let iCloudRecordID: String

    var body: some View {
        if role == .senior {
            seniorSetup
        } else {
            caregiverSetup
        }
    }

    private var seniorSetup: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 48)).foregroundStyle(Color.accentColor)
                Text("Create Your Care Circle")
                    .font(.title2).fontWeight(.semibold)
                Text("Your care circle is where caregivers can coordinate your care.")
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            Spacer()
            Button { createSeniorProfile() } label: {
                Text("Create Care Circle").font(.headline)
                    .frame(maxWidth: .infinity).frame(minHeight: A11y.minTouchTarget)
            }
            .buttonStyle(.borderedProminent).padding(.horizontal, 32)
            Spacer()
        }
        .navigationBarBackButtonHidden()
    }

    @State private var inviteCode = ""
    @State private var errorMessage: String?

    private var caregiverSetup: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 48)).foregroundStyle(Color.accentColor)
                Text("Join a Care Circle")
                    .font(.title2).fontWeight(.semibold)
                Text("Ask the senior to share an invite link, or enter an invite code.")
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            VStack(spacing: 16) {
                TextField("CARE-XXXX-XXXX", text: $inviteCode)
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.center).autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: inviteCode) { _, newValue in
                        inviteCode = newValue.uppercased()
                        errorMessage = nil
                    }
                if let error = errorMessage {
                    Text(error).font(.subheadline).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button { joinWithCode() } label: {
                    Text("Join Circle").font(.headline)
                        .frame(maxWidth: .infinity).frame(minHeight: A11y.minTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Skip for now") { createCaregiverProfileOnly() }
                    .font(.subheadline).foregroundStyle(.secondary).frame(minHeight: A11y.minTouchTarget)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .navigationBarBackButtonHidden()
    }

    private func createSeniorProfile() {
        let profile = UserProfile(iCloudRecordID: iCloudRecordID, displayName: displayName, role: .senior)
        context.insert(profile)
        let circle = CareCircle(seniorName: displayName)
        context.insert(circle)
        try? context.save()
    }

    private func joinWithCode() {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespaces)
        let fetchDesc = FetchDescriptor<InviteCode>(predicate: #Predicate { $0.code == trimmed })
        do {
            let matching = try context.fetch(fetchDesc)
            guard let invite = matching.first else {
                errorMessage = "Invalid code. Please check and try again."; return
            }
            guard !invite.isUsed else {
                errorMessage = "This code has already been used."; return
            }
            guard let circle = invite.circle else {
                errorMessage = "No care circle found for this code."; return
            }
            let profile = UserProfile(iCloudRecordID: iCloudRecordID, displayName: displayName, role: .caregiver)
            context.insert(profile)
            let member = CareTeamMember(displayName: displayName, role: .family, circle: circle)
            member.iCloudRecordID = iCloudRecordID
            circle.members?.append(member)
            context.insert(member)
            invite.isUsed = true
            try context.save()
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func createCaregiverProfileOnly() {
        let profile = UserProfile(iCloudRecordID: iCloudRecordID, displayName: displayName, role: .caregiver)
        context.insert(profile)
        try? context.save()
    }
}
