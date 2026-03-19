import SwiftUI

/// Pre-prompt shown before the system notification permission dialog.
/// Explains why notifications are needed, then calls NotificationService.requestAuthorization().
/// Shown once — tracked via @AppStorage("notificationPermissionRequested").
struct NotificationPermissionView: View {
    @AppStorage("notificationPermissionRequested") private var permissionRequested: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("Medication Reminders")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text("Allow notifications so you receive reminders when medications are due and alerts when a dose is missed.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 8)

            Spacer()

            VStack(spacing: 12) {
                Button("Enable Notifications") {
                    permissionRequested = true
                    Task {
                        _ = try? await NotificationService.requestAuthorization()
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: A11y.minTouchTarget)
                .accessibilityLabel("Enable Notifications")

                Button("Not Now") {
                    permissionRequested = true
                    dismiss()
                }
                .foregroundStyle(Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: A11y.minTouchTarget)
                .accessibilityLabel("Not Now — enable notifications later in Settings")
            }
        }
        .padding(24)
    }
}

#Preview {
    NotificationPermissionView()
}
