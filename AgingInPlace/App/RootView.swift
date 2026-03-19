import SwiftUI

struct RootView: View {
    @AppStorage("userRole") private var userRole: String = ""

    var body: some View {
        Group {
            if userRole == "senior" {
                SeniorHomeView()
            } else if userRole == "caregiver" {
                CaregiverHomeView()
            } else {
                RoleSelectionView(userRole: $userRole)
            }
        }
    }
}

private struct RoleSelectionView: View {
    @Binding var userRole: String

    var body: some View {
        VStack(spacing: 32) {
            Text("AgingInPlace")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("How will you use this app?")
                .font(.title3)
                .foregroundStyle(Color.secondary)

            VStack(spacing: 16) {
                Button {
                    userRole = "senior"
                } label: {
                    Text("I am the senior")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: A11y.minTouchTarget)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    userRole = "caregiver"
                } label: {
                    Text("I am a caregiver")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: A11y.minTouchTarget)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
}
