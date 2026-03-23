import SwiftUI

struct ProfileSetupView: View {
    @Binding var displayName: String
    let iCloudRecordID: String
    let onContinue: () -> Void
    @State private var isLoadingName = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Text("What's your name?")
                    .font(.title2).fontWeight(.semibold)
                Text("This is how others in the care circle will see you.")
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            VStack(spacing: 16) {
                TextField("Your name", text: $displayName)
                    .font(.title3).multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)
                if isLoadingName {
                    ProgressView("Loading from iCloud...").font(.caption)
                }
            }
            Spacer()
            Button {
                onContinue()
            } label: {
                Text("Continue").font(.headline)
                    .frame(maxWidth: .infinity).frame(minHeight: A11y.minTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 32)
            Spacer()
        }
        .navigationBarBackButtonHidden()
        .task {
            guard !iCloudRecordID.isEmpty, displayName.isEmpty else { return }
            isLoadingName = true
            if let name = await iCloudIdentityService.fetchUserName() {
                displayName = name
            }
            isLoadingName = false
        }
    }
}
