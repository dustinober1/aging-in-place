import CloudKit
import Combine
import CoreData
import Foundation

enum SyncState: Equatable {
    case notStarted
    case syncing
    case synced
    case error(Error)
    case notAvailable

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted): return true
        case (.syncing, .syncing): return true
        case (.synced, .synced): return true
        case (.error, .error): return true
        case (.notAvailable, .notAvailable): return true
        default: return false
        }
    }
}

@MainActor
@Observable
final class CloudKitSyncMonitor {
    private(set) var syncState: SyncState = .notStarted
    private var eventSubscription: AnyCancellable?

    var displayText: String {
        switch syncState {
        case .notStarted: return ""
        case .syncing: return "Syncing..."
        case .synced: return "Up to date"
        case .error: return "Sync error"
        case .notAvailable: return "iCloud unavailable"
        }
    }

    var isError: Bool {
        if case .error = syncState { return true }
        return false
    }

    init() {}

    func updateState(_ newState: SyncState) {
        syncState = newState
    }

    func startMonitoring() {
        eventSubscription = NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let event = notification.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event else { return }

                if event.endDate == nil {
                    self?.syncState = .syncing
                } else if event.error != nil {
                    self?.syncState = .error(event.error!)
                } else {
                    self?.syncState = .synced
                }
            }
    }

    func stopMonitoring() {
        eventSubscription?.cancel()
        eventSubscription = nil
    }
}
