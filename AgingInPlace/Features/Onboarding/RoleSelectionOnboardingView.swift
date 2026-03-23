import SwiftUI

struct RoleSelectionOnboardingView: View {
    @Binding var selectedRole: UserRole
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Text("How will you use this app?")
                    .font(.title2).fontWeight(.semibold)
                Text("This determines what you see on your home screen.")
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            VStack(spacing: 16) {
                Button {
                    selectedRole = .senior
                    onContinue()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "person.fill").font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I am the senior").font(.headline)
                            Text("Track your health, meds, and appointments")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: A11y.minTouchTarget)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    selectedRole = .caregiver
                    onContinue()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "person.2.fill").font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I am a caregiver").font(.headline)
                            Text("Help coordinate care for someone you love")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: A11y.minTouchTarget)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .navigationBarBackButtonHidden()
    }
}
