import SwiftUI

struct ProfileSetupView: View {
    @Binding var displayName: String
    let iCloudRecordID: String
    let onContinue: () -> Void
    var body: some View { Text("Profile Setup — placeholder") }
}
