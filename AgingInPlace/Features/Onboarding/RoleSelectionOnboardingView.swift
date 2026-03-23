import SwiftUI

struct RoleSelectionOnboardingView: View {
    @Binding var selectedRole: UserRole
    let onContinue: () -> Void
    var body: some View { Text("Role Selection — placeholder") }
}
