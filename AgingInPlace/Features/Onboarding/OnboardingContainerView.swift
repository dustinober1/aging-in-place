import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var context
    @State private var step: OnboardingStep = .welcome
    @State private var selectedRole: UserRole = .senior
    @State private var displayName: String = ""
    @State private var iCloudRecordID: String = ""

    enum OnboardingStep {
        case welcome, roleSelection, profileSetup, careCircleSetup
    }

    var body: some View {
        NavigationStack {
            switch step {
            case .welcome:
                WelcomeView(iCloudRecordID: $iCloudRecordID, onContinue: { step = .roleSelection })
            case .roleSelection:
                RoleSelectionOnboardingView(selectedRole: $selectedRole, onContinue: { step = .profileSetup })
            case .profileSetup:
                ProfileSetupView(displayName: $displayName, iCloudRecordID: iCloudRecordID, onContinue: { step = .careCircleSetup })
            case .careCircleSetup:
                CareCircleSetupView(role: selectedRole, displayName: displayName, iCloudRecordID: iCloudRecordID)
            }
        }
    }
}
