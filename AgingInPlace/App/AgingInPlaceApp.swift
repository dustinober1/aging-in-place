import SwiftUI
import SwiftData

@main
struct AgingInPlaceApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(
            for: [
                CareCircle.self,
                CareTeamMember.self,
                CareRecord.self,
                InviteCode.self,
                EmergencyContact.self
            ],
            isAutosaveEnabled: false
        )
    }
}
