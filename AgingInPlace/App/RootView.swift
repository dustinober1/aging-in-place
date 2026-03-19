import SwiftUI

struct RootView: View {
    @AppStorage("userRole") private var userRole: String = ""

    var body: some View {
        Group {
            if userRole == "senior" {
                Text("Senior Home")
                    .font(.largeTitle)
            } else if userRole == "caregiver" {
                Text("Caregiver Home")
                    .font(.largeTitle)
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
                        .frame(minHeight: Accessibility.minTouchTarget)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    userRole = "caregiver"
                } label: {
                    Text("I am a caregiver")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Accessibility.minTouchTarget)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
}
