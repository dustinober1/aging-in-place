import SwiftUI

struct SyncStatusBanner: View {
    @Environment(CloudKitSyncMonitor.self) private var syncMonitor

    var body: some View {
        if !syncMonitor.displayText.isEmpty && syncMonitor.syncState != .synced {
            HStack(spacing: 8) {
                if case .syncing = syncMonitor.syncState {
                    ProgressView()
                        .controlSize(.small)
                } else if syncMonitor.isError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if case .notAvailable = syncMonitor.syncState {
                    Image(systemName: "icloud.slash")
                        .foregroundStyle(.secondary)
                }

                Text(syncMonitor.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
