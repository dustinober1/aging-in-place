import SwiftUI

struct WelcomeView: View {
    @Binding var iCloudRecordID: String
    let onContinue: () -> Void
    @State private var isCheckingiCloud = false
    @State private var iCloudError: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)
                Text("AgingInPlace")
                    .font(.largeTitle).fontWeight(.bold)
                Text("Coordinate care for your loved ones, together.")
                    .font(.title3).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 16) {
                if let error = iCloudError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.subheadline).foregroundStyle(.orange).padding(.horizontal)
                }
                Button {
                    checkiCloudAndContinue()
                } label: {
                    if isCheckingiCloud {
                        ProgressView().frame(maxWidth: .infinity).frame(minHeight: A11y.minTouchTarget)
                    } else {
                        Text("Continue with iCloud").font(.headline)
                            .frame(maxWidth: .infinity).frame(minHeight: A11y.minTouchTarget)
                    }
                }
                .buttonStyle(.borderedProminent).disabled(isCheckingiCloud).padding(.horizontal, 32)

                Button("Continue without iCloud") {
                    iCloudRecordID = ""
                    onContinue()
                }
                .font(.subheadline).foregroundStyle(.secondary).frame(minHeight: A11y.minTouchTarget)
            }
            Spacer()
        }
        .navigationBarBackButtonHidden()
    }

    private func checkiCloudAndContinue() {
        isCheckingiCloud = true
        iCloudError = nil
        Task {
            let status = await CloudKitAvailability.checkAccountStatus()
            if status == .available {
                if let recordID = await iCloudIdentityService.fetchRecordID() {
                    iCloudRecordID = recordID
                } else { iCloudRecordID = "" }
                onContinue()
            } else {
                iCloudError = "iCloud is not available. Sign in to iCloud in Settings, or continue without it."
            }
            isCheckingiCloud = false
        }
    }
}
