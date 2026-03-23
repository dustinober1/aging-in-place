import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]
    private var currentProfile: UserProfile? { profiles.first }

    var body: some View {
        Group {
            if let profile = currentProfile {
                switch profile.role {
                case .senior:
                    SeniorHomeView()
                case .caregiver:
                    CaregiverHomeView()
                }
            } else {
                OnboardingContainerView()
            }
        }
    }
}
