import CloudKit
import CoreData
import SwiftData
import UIKit

struct SharingService {
    static func shareTitle(for circle: CareCircle) -> String {
        if circle.seniorName.isEmpty {
            return "Care Circle"
        }
        return "\(circle.seniorName)'s Care Circle"
    }

    /// Attempts to surface the underlying NSPersistentCloudKitContainer from a SwiftData ModelContext.
    /// This relies on a private SwiftData↔CoreData bridge that is not guaranteed by Apple's API;
    /// it is accepted as a known fragility for the 1.0 ship.
    static func persistentCloudKitContainer(
        from modelContext: ModelContext
    ) -> NSPersistentCloudKitContainer? {
        // The `managedObjectContext` bridge is not publicly available in this SDK version.
        // Callers that need an NSPersistentCloudKitContainer should pass one directly
        // via makeSharingController(for:persistentStore:container:).
        return nil
    }

    @MainActor
    static func makeSharingController(
        for circle: CareCircle,
        persistentStore: NSPersistentStore,
        container: NSPersistentCloudKitContainer
    ) -> UICloudSharingController {
        let controller = UICloudSharingController { _, prepareCompletionHandler in
            let share = CKShare(rootRecord: CKRecord(recordType: "CD_CareCircle"))
            share[CKShare.SystemFieldKey.title] = shareTitle(for: circle)
            container.persistUpdatedShare(share, in: persistentStore) { share, error in
                prepareCompletionHandler(share, CKContainer.default(), error)
            }
        }
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    static func acceptShare(
        metadata: CKShare.Metadata,
        persistentStore: NSPersistentStore,
        container: NSPersistentCloudKitContainer
    ) async throws {
        try await container.acceptShareInvitations(
            from: [metadata],
            into: persistentStore
        )
    }
}
