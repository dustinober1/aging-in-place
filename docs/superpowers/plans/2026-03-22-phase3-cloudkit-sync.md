# Phase 3: CloudKit + CKShare Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sync the senior's care data to all caregiver devices via CloudKit shared zones, preserving existing AES-GCM encryption.

**Architecture:** SwiftData with `ModelConfiguration` backed by a CloudKit container. The senior owns a `CKShare` on their `CareCircle`; caregivers become share participants. All existing `@Model` classes sync automatically once the CloudKit container is configured. A new `CareCircle` -> `CareRecord` relationship (V3 schema migration) ensures care records live in the shared zone. A `CloudKitSyncMonitor` provides sync state to the UI. A `SharingService` wraps `CKShare` lifecycle.

**Tech Stack:** SwiftUI, SwiftData, CloudKit (CKShare, NSPersistentCloudKitContainer), Swift 6 strict concurrency

**Spec:** `docs/superpowers/specs/2026-03-22-app-store-launch-design.md` (Phase 3 section)

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `AgingInPlace/Models/Schema/AgingInPlaceSchemaV3.swift` | V3 schema with CareRecord-CareCircle relationship |
| Modify | `AgingInPlace/Models/Schema/AgingInPlaceMigrationPlan.swift` | Add V2->V3 lightweight migration stage |
| Modify | `AgingInPlace/Models/CareRecord.swift` | Add `circle: CareCircle?` relationship property |
| Modify | `AgingInPlace/Models/CareCircle.swift` | Add `@Relationship` to `[CareRecord]` |
| Modify | `AgingInPlace/App/AgingInPlaceApp.swift` | Add `cloudKitContainerIdentifier` to `ModelConfiguration` |
| Modify | `AgingInPlace/AgingInPlace.entitlements` | Add CloudKit entitlement + iCloud container |
| Modify | `project.yml` | Add CloudKit capability and iCloud container to target settings |
| Create | `AgingInPlace/CloudKit/CloudKitSyncMonitor.swift` | Observable sync state (syncing, synced, error, notAvailable) |
| Create | `AgingInPlace/CloudKit/SharingService.swift` | CKShare creation, participant management, share acceptance |
| Create | `AgingInPlace/CloudKit/CloudKitAvailability.swift` | Check iCloud account status and container availability |
| Create | `AgingInPlace/CloudKit/CloudSharingControllerRepresentable.swift` | UIViewControllerRepresentable wrapper for UICloudSharingController |
| Modify | `AgingInPlace/Features/CareTeam/InviteFlowView.swift` | Replace invite code generation with CKShare URL creation |
| Modify | `AgingInPlace/Features/CareTeam/JoinCircleView.swift` | Replace code entry with share link acceptance |
| Modify | `AgingInPlace/Features/SeniorHome/SeniorHomeView.swift` | Add sync status indicator |
| Modify | `AgingInPlace/Features/CaregiverHome/CaregiverHomeView.swift` | Add sync status indicator |
| Create | `AgingInPlace/CloudKit/SyncStatusBanner.swift` | Reusable sync status banner view |
| Create | `AgingInPlaceTests/SchemaV3MigrationTests.swift` | V3 migration and CareRecord-CareCircle relationship tests |
| Create | `AgingInPlaceTests/CloudKitSyncMonitorTests.swift` | Sync monitor state machine tests |
| Create | `AgingInPlaceTests/SharingServiceTests.swift` | Sharing service unit tests |

---

### Task 1: Schema V3 — Add CareRecord-CareCircle Relationship

**Files:**
- Create: `AgingInPlace/Models/Schema/AgingInPlaceSchemaV3.swift`
- Modify: `AgingInPlace/Models/Schema/AgingInPlaceMigrationPlan.swift`
- Modify: `AgingInPlace/Models/CareRecord.swift`
- Modify: `AgingInPlace/Models/CareCircle.swift`
- Create: `AgingInPlaceTests/SchemaV3MigrationTests.swift`

- [ ] **Step 1: Write failing test for CareRecord-CareCircle relationship**

```swift
// AgingInPlaceTests/SchemaV3MigrationTests.swift
import XCTest
import SwiftData
@testable import AgingInPlace

final class SchemaV3MigrationTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Schema(AgingInPlaceSchemaV3.models),
            migrationPlan: AgingInPlaceMigrationPlan.self,
            configurations: [config]
        )
    }

    func testContainerOpensWithV3MigrationPlan() throws {
        XCTAssertNoThrow(try makeContainer())
    }

    func testCareRecordLinkedToCareCircle() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let circle = CareCircle(seniorName: "Margaret")
        context.insert(circle)

        let payload = try EncryptionService.seal(
            "{\"note\":\"test\"}".data(using: .utf8)!,
            for: .medications
        )
        let record = CareRecord(
            category: .medications,
            encryptedPayload: payload,
            authorMemberID: UUID(),
            circle: circle
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CareCircle>())
        XCTAssertEqual(fetched.first?.careRecords.count, 1)
        XCTAssertEqual(fetched.first?.careRecords.first?.id, record.id)
    }

    func testCareRecordCascadeDeletesWithCircle() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let circle = CareCircle(seniorName: "Margaret")
        context.insert(circle)

        let payload = try EncryptionService.seal(
            "{\"note\":\"test\"}".data(using: .utf8)!,
            for: .medications
        )
        let record = CareRecord(
            category: .medications,
            encryptedPayload: payload,
            authorMemberID: UUID(),
            circle: circle
        )
        context.insert(record)
        try context.save()

        context.delete(circle)
        try context.save()

        let records = try context.fetch(FetchDescriptor<CareRecord>())
        XCTAssertEqual(records.count, 0)
    }

    func testPhase2ModelsStillInsertableAfterV3Migration() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let schedule = MedicationSchedule(
            drugName: "Metformin", dose: "500mg",
            hour: 8, minute: 0, createdByMemberID: UUID()
        )
        context.insert(schedule)

        let moodLog = MoodLog(moodValue: 3, authorMemberID: UUID(), authorType: .senior)
        context.insert(moodLog)

        try context.save()

        let schedules = try context.fetch(FetchDescriptor<MedicationSchedule>())
        let moods = try context.fetch(FetchDescriptor<MoodLog>())
        XCTAssertEqual(schedules.count, 1)
        XCTAssertEqual(moods.count, 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests/SchemaV3MigrationTests 2>&1 | tail -20`
Expected: FAIL — `AgingInPlaceSchemaV3` does not exist, `CareRecord` init does not accept `circle:` parameter, `CareCircle` has no `careRecords` property.

- [ ] **Step 3: Add `circle` property to CareRecord**

Modify `AgingInPlace/Models/CareRecord.swift`:

```swift
import Foundation
import SwiftData

@Model
final class CareRecord {
    var id: UUID
    var category: PermissionCategory
    /// Stores AES-GCM sealed box bytes — NEVER plaintext
    var encryptedPayload: Data
    var authorMemberID: UUID
    var createdAt: Date
    var lastModified: Date
    var circle: CareCircle?

    init(category: PermissionCategory, encryptedPayload: Data, authorMemberID: UUID, circle: CareCircle? = nil) {
        self.id = UUID()
        self.category = category
        self.encryptedPayload = encryptedPayload
        self.authorMemberID = authorMemberID
        self.createdAt = Date()
        self.lastModified = Date()
        self.circle = circle
    }
}
```

- [ ] **Step 4: Add `careRecords` relationship to CareCircle**

Modify `AgingInPlace/Models/CareCircle.swift`:

```swift
import Foundation
import SwiftData

@Model
final class CareCircle {
    var id: UUID
    var seniorName: String
    var seniorDeviceID: String
    @Relationship(deleteRule: .cascade, inverse: \CareTeamMember.circle)
    var members: [CareTeamMember]
    @Relationship(deleteRule: .cascade, inverse: \InviteCode.circle)
    var pendingInvites: [InviteCode]
    @Relationship(deleteRule: .cascade, inverse: \CareRecord.circle)
    var careRecords: [CareRecord]
    var lastModified: Date

    init(seniorName: String, seniorDeviceID: String = "") {
        self.id = UUID()
        self.seniorName = seniorName
        self.seniorDeviceID = seniorDeviceID
        self.members = []
        self.pendingInvites = []
        self.careRecords = []
        self.lastModified = Date()
    }
}
```

- [ ] **Step 5: Create AgingInPlaceSchemaV3**

```swift
// AgingInPlace/Models/Schema/AgingInPlaceSchemaV3.swift
import SwiftData

enum AgingInPlaceSchemaV3: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CareCircle.self,
            CareTeamMember.self,
            CareRecord.self,
            InviteCode.self,
            EmergencyContact.self,
            MedicationSchedule.self,
            MedicationLog.self,
            CareVisitLog.self,
            MoodLog.self,
            CalendarEvent.self
        ]
    }
}
```

- [ ] **Step 6: Update migration plan for V2->V3**

Modify `AgingInPlace/Models/Schema/AgingInPlaceMigrationPlan.swift`:

```swift
import SwiftData

enum AgingInPlaceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AgingInPlaceSchemaV1.self, AgingInPlaceSchemaV2.self, AgingInPlaceSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    /// Lightweight migration: adding new entities requires no data transformation
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AgingInPlaceSchemaV1.self,
        toVersion: AgingInPlaceSchemaV2.self
    )

    /// Lightweight migration: adding optional relationship (CareRecord.circle) requires no data transformation
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: AgingInPlaceSchemaV2.self,
        toVersion: AgingInPlaceSchemaV3.self
    )
}
```

- [ ] **Step 7: Update AgingInPlaceApp.swift to use V3 schema**

Modify `AgingInPlace/App/AgingInPlaceApp.swift` — change `AgingInPlaceSchemaV2` to `AgingInPlaceSchemaV3`:

```swift
import SwiftUI
import SwiftData

@main
struct AgingInPlaceApp: App {

    let container: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            return try ModelContainer(
                for: Schema(AgingInPlaceSchemaV3.models),
                migrationPlan: AgingInPlaceMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests/SchemaV3MigrationTests 2>&1 | tail -20`
Expected: PASS — all 4 tests green.

- [ ] **Step 9: Run full test suite to verify no regressions**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: All existing tests pass. Some tests that create `CareRecord` without the `circle:` parameter still work because it defaults to `nil`.

- [ ] **Step 10: Commit**

```bash
git add AgingInPlace/Models/Schema/AgingInPlaceSchemaV3.swift \
       AgingInPlace/Models/Schema/AgingInPlaceMigrationPlan.swift \
       AgingInPlace/Models/CareRecord.swift \
       AgingInPlace/Models/CareCircle.swift \
       AgingInPlace/App/AgingInPlaceApp.swift \
       AgingInPlaceTests/SchemaV3MigrationTests.swift
git commit -m "feat(03): schema V3 migration — add CareRecord-CareCircle relationship"
```

---

### Task 2: CloudKit Entitlements and Project Configuration

**Files:**
- Modify: `AgingInPlace/AgingInPlace.entitlements`
- Modify: `project.yml`

- [ ] **Step 1: Add CloudKit entitlements**

Replace `AgingInPlace/AgingInPlace.entitlements` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.usernotifications.time-sensitive</key>
    <true/>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.agingInPlace.app</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Update project.yml to include CloudKit capability**

Add under `targets.AgingInPlace.settings.base`:

```yaml
    ICLOUD_CONTAINER_IDENTIFIER: iCloud.com.agingInPlace.app
```

- [ ] **Step 3: Verify project generates correctly**

Run: `cd /Users/dustinober/Projects/aging-in-place && xcodegen generate 2>&1`
Expected: "Generated project" success message (if using XcodeGen). If project.yml is consumed differently, verify the Xcode project opens without errors.

- [ ] **Step 4: Commit**

```bash
git add AgingInPlace/AgingInPlace.entitlements project.yml
git commit -m "feat(03): add CloudKit entitlements and iCloud container configuration"
```

---

### Task 3: CloudKit Availability Check

**Files:**
- Create: `AgingInPlace/CloudKit/CloudKitAvailability.swift`

- [ ] **Step 1: Create CloudKit directory**

Run: `mkdir -p AgingInPlace/CloudKit`

- [ ] **Step 2: Write CloudKitAvailability**

```swift
// AgingInPlace/CloudKit/CloudKitAvailability.swift
import CloudKit
import Foundation

enum CloudKitAccountStatus: Sendable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
}

struct CloudKitAvailability: Sendable {
    static func checkAccountStatus() async -> CloudKitAccountStatus {
        do {
            let status = try await CKContainer.default().accountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount:
                return .noAccount
            case .restricted:
                return .restricted
            case .couldNotDetermine:
                return .couldNotDetermine
            case .temporarilyUnavailable:
                return .temporarilyUnavailable
            @unknown default:
                return .couldNotDetermine
            }
        } catch {
            return .couldNotDetermine
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add AgingInPlace/CloudKit/CloudKitAvailability.swift
git commit -m "feat(03): add CloudKit account availability check"
```

---

### Task 4: CloudKitSyncMonitor — Observable Sync State

**Files:**
- Create: `AgingInPlace/CloudKit/CloudKitSyncMonitor.swift`
- Create: `AgingInPlaceTests/CloudKitSyncMonitorTests.swift`

- [ ] **Step 1: Write failing tests for sync monitor state machine**

```swift
// AgingInPlaceTests/CloudKitSyncMonitorTests.swift
import XCTest
@testable import AgingInPlace

@MainActor
final class CloudKitSyncMonitorTests: XCTestCase {

    func testInitialStateIsNotStarted() {
        let monitor = CloudKitSyncMonitor()
        XCTAssertEqual(monitor.syncState, .notStarted)
    }

    func testUpdateToSyncing() {
        let monitor = CloudKitSyncMonitor()
        monitor.updateState(.syncing)
        XCTAssertEqual(monitor.syncState, .syncing)
    }

    func testUpdateToSynced() {
        let monitor = CloudKitSyncMonitor()
        monitor.updateState(.synced)
        XCTAssertEqual(monitor.syncState, .synced)
    }

    func testUpdateToError() {
        let monitor = CloudKitSyncMonitor()
        let error = NSError(domain: "test", code: 1)
        monitor.updateState(.error(error))
        if case .error(let e) = monitor.syncState {
            XCTAssertEqual((e as NSError).code, 1)
        } else {
            XCTFail("Expected error state")
        }
    }

    func testUpdateToNotAvailable() {
        let monitor = CloudKitSyncMonitor()
        monitor.updateState(.notAvailable)
        XCTAssertEqual(monitor.syncState, .notAvailable)
    }

    func testSyncStateDisplayText() {
        let monitor = CloudKitSyncMonitor()

        monitor.updateState(.notStarted)
        XCTAssertEqual(monitor.displayText, "")

        monitor.updateState(.syncing)
        XCTAssertEqual(monitor.displayText, "Syncing...")

        monitor.updateState(.synced)
        XCTAssertEqual(monitor.displayText, "Up to date")

        monitor.updateState(.notAvailable)
        XCTAssertEqual(monitor.displayText, "iCloud unavailable")

        let error = NSError(domain: "CKErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        monitor.updateState(.error(error))
        XCTAssertEqual(monitor.displayText, "Sync error")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests/CloudKitSyncMonitorTests 2>&1 | tail -20`
Expected: FAIL — `CloudKitSyncMonitor` does not exist.

- [ ] **Step 3: Implement CloudKitSyncMonitor**

```swift
// AgingInPlace/CloudKit/CloudKitSyncMonitor.swift
import CloudKit
import Combine
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

    /// Start listening to NSPersistentCloudKitContainer event notifications.
    /// Call this once after the ModelContainer is created.
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests/CloudKitSyncMonitorTests 2>&1 | tail -20`
Expected: PASS — all 6 tests green.

- [ ] **Step 5: Commit**

```bash
git add AgingInPlace/CloudKit/CloudKitSyncMonitor.swift \
       AgingInPlaceTests/CloudKitSyncMonitorTests.swift
git commit -m "feat(03): add CloudKitSyncMonitor with observable sync state"
```

---

### Task 5: SharingService — CKShare Lifecycle

**Files:**
- Create: `AgingInPlace/CloudKit/SharingService.swift`
- Create: `AgingInPlaceTests/SharingServiceTests.swift`

- [ ] **Step 1: Write failing tests for SharingService**

```swift
// AgingInPlaceTests/SharingServiceTests.swift
import XCTest
import SwiftData
import CloudKit
@testable import AgingInPlace

final class SharingServiceTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Schema(AgingInPlaceSchemaV3.models),
            migrationPlan: AgingInPlaceMigrationPlan.self,
            configurations: [config]
        )
    }

    func testShareTitleUsesCircleSeniorName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let circle = CareCircle(seniorName: "Margaret")
        context.insert(circle)
        try context.save()

        let title = SharingService.shareTitle(for: circle)
        XCTAssertEqual(title, "Margaret's Care Circle")
    }

    func testShareTitleFallsBackForEmptyName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let circle = CareCircle(seniorName: "")
        context.insert(circle)
        try context.save()

        let title = SharingService.shareTitle(for: circle)
        XCTAssertEqual(title, "Care Circle")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests/SharingServiceTests 2>&1 | tail -20`
Expected: FAIL — `SharingService` does not exist.

- [ ] **Step 3: Implement SharingService**

Note: SwiftData's `ModelContainer` does not expose the underlying `NSPersistentCloudKitContainer` directly. To access Core Data sharing APIs, we use `ModelContext`'s backing `NSManagedObjectContext` to traverse to the `NSPersistentStoreCoordinator` and its container. The `persistentContainer` accessor below uses this bridge.

```swift
// AgingInPlace/CloudKit/SharingService.swift
import CloudKit
import CoreData
import SwiftData
import UIKit

struct SharingService {
    /// Generate the display title for a CKShare based on the care circle.
    static func shareTitle(for circle: CareCircle) -> String {
        if circle.seniorName.isEmpty {
            return "Care Circle"
        }
        return "\(circle.seniorName)'s Care Circle"
    }

    /// Bridge from SwiftData ModelContainer to the underlying NSPersistentCloudKitContainer.
    /// SwiftData internally creates an NSPersistentCloudKitContainer when cloudKitDatabase is set.
    /// We access it via the NSManagedObjectContext's persistent store coordinator.
    static func persistentCloudKitContainer(
        from modelContext: ModelContext
    ) -> NSPersistentCloudKitContainer? {
        // SwiftData's ModelContext wraps an NSManagedObjectContext internally.
        // We access the coordinator, which belongs to the NSPersistentCloudKitContainer.
        guard let coordinator = modelContext.managedObjectContext?.persistentStoreCoordinator else {
            return nil
        }
        // The coordinator's parent container is the NSPersistentCloudKitContainer
        // This relies on SwiftData's internal structure when cloudKitDatabase != .none
        return coordinator.persistentStores.first?.url.map { _ in
            // Create a reference container pointing to the same coordinator
            let container = NSPersistentCloudKitContainer(name: "AgingInPlace")
            container.persistentStoreCoordinator = coordinator
            return container
        } ?? nil
    }

    /// Create a UICloudSharingController for the given CareCircle.
    /// The senior calls this to invite caregivers.
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

    /// Accept a CKShare metadata when the app is opened via a share URL.
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests/SharingServiceTests 2>&1 | tail -20`
Expected: PASS — both tests green.

- [ ] **Step 5: Commit**

```bash
git add AgingInPlace/CloudKit/SharingService.swift \
       AgingInPlaceTests/SharingServiceTests.swift
git commit -m "feat(03): add SharingService for CKShare lifecycle management"
```

---

### Task 6: Wire CloudKit into ModelContainer

**Files:**
- Modify: `AgingInPlace/App/AgingInPlaceApp.swift`

- [ ] **Step 1: Update ModelConfiguration with CloudKit container identifier**

```swift
// AgingInPlace/App/AgingInPlaceApp.swift
import SwiftUI
import SwiftData

@main
struct AgingInPlaceApp: App {

    let container: ModelContainer = {
        do {
            let config = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(
                for: Schema(AgingInPlaceSchemaV3.models),
                migrationPlan: AgingInPlaceMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @State private var syncMonitor = CloudKitSyncMonitor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(syncMonitor)
                .onAppear {
                    syncMonitor.startMonitoring()
                }
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 2: Run full test suite**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: All tests pass. Tests use in-memory containers so CloudKit config doesn't affect them.

- [ ] **Step 3: Commit**

```bash
git add AgingInPlace/App/AgingInPlaceApp.swift
git commit -m "feat(03): wire CloudKit database into ModelContainer with sync monitor"
```

---

### Task 7: Sync Status Banner UI

**Files:**
- Create: `AgingInPlace/CloudKit/SyncStatusBanner.swift`
- Modify: `AgingInPlace/Features/SeniorHome/SeniorHomeView.swift`
- Modify: `AgingInPlace/Features/CaregiverHome/CaregiverHomeView.swift`

- [ ] **Step 1: Create SyncStatusBanner view**

```swift
// AgingInPlace/CloudKit/SyncStatusBanner.swift
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
```

- [ ] **Step 2: Add SyncStatusBanner to SeniorHomeView**

In `AgingInPlace/Features/SeniorHome/SeniorHomeView.swift`, add the banner inside the `VStack` in `body`, right after `greetingHeader`:

```swift
// Inside var body, within the VStack(spacing: 16):
greetingHeader
SyncStatusBanner()
cardList
```

- [ ] **Step 3: Add SyncStatusBanner to CaregiverHomeView**

In `AgingInPlace/Features/CaregiverHome/CaregiverHomeView.swift`, add the banner inside the `VStack` in `body`, right after `greetingHeader`:

```swift
// Inside var body, within the VStack(alignment: .leading, spacing: 24):
greetingHeader
SyncStatusBanner()
recentActivitySection
quickActionsSection
```

- [ ] **Step 4: Build to verify no compile errors**

Run: `xcodebuild build -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run full test suite**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add AgingInPlace/CloudKit/SyncStatusBanner.swift \
       AgingInPlace/Features/SeniorHome/SeniorHomeView.swift \
       AgingInPlace/Features/CaregiverHome/CaregiverHomeView.swift
git commit -m "feat(03): add sync status banner to senior and caregiver home screens"
```

---

### Task 8: CloudSharingControllerRepresentable + Update InviteFlowView

**Files:**
- Create: `AgingInPlace/CloudKit/CloudSharingControllerRepresentable.swift`
- Modify: `AgingInPlace/Features/CareTeam/InviteFlowView.swift`

- [ ] **Step 1: Create UIViewControllerRepresentable wrapper for UICloudSharingController**

```swift
// AgingInPlace/CloudKit/CloudSharingControllerRepresentable.swift
import CloudKit
import SwiftUI
import UIKit

struct CloudSharingControllerRepresentable: UIViewControllerRepresentable {
    let controller: UICloudSharingController

    func makeUIViewController(context: Context) -> UICloudSharingController {
        controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
```

- [ ] **Step 2: Replace InviteFlowView with CKShare UI and local code fallback**

```swift
// AgingInPlace/Features/CareTeam/InviteFlowView.swift
import SwiftUI
import SwiftData
import CloudKit

struct InviteFlowView: View {
    @Environment(\.modelContext) private var context
    @Query private var circles: [CareCircle]

    @State private var showShareSheet = false
    @State private var iCloudAvailable = true
    @State private var currentCode: String = ""
    @State private var showCopiedFeedback = false

    private var circle: CareCircle? { circles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Invite a Caregiver")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(iCloudAvailable
                         ? "Share a link to invite someone to your care team."
                         : "Share this code with the person you want to add to your care team.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if iCloudAvailable {
                    cloudKitShareSection
                } else {
                    localCodeFallbackSection
                }

                Spacer()
            }
            .navigationTitle("Invite Caregiver")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                let status = await CloudKitAvailability.checkAccountStatus()
                iCloudAvailable = (status == .available)
                if !iCloudAvailable && currentCode.isEmpty {
                    generateNewCode()
                }
            }
        }
    }

    // MARK: - CloudKit Share

    private var cloudKitShareSection: some View {
        Button {
            showShareSheet = true
        } label: {
            Label("Share Invite Link", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .frame(minHeight: A11y.minTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .sheet(isPresented: $showShareSheet) {
            if let circle,
               let ckContainer = SharingService.persistentCloudKitContainer(from: context),
               let store = ckContainer.persistentStoreCoordinator.persistentStores.first {
                CloudSharingControllerRepresentable(
                    controller: SharingService.makeSharingController(
                        for: circle,
                        persistentStore: store,
                        container: ckContainer
                    )
                )
            } else {
                ContentUnavailableView(
                    "Sharing Unavailable",
                    systemImage: "icloud.slash",
                    description: Text("Could not connect to iCloud. Try again later.")
                )
            }
        }
    }

    // MARK: - Local Code Fallback

    private var localCodeFallbackSection: some View {
        VStack(spacing: 16) {
            Text(currentCode)
                .font(.system(.title, design: .monospaced, weight: .bold))
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                UIPasteboard.general.string = currentCode
                showCopiedFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showCopiedFeedback = false
                }
            } label: {
                Label(showCopiedFeedback ? "Copied!" : "Copy", systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: A11y.minTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(showCopiedFeedback ? .green : .accentColor)
            .padding(.horizontal)

            ShareLink(item: "Join my care circle with code: \(currentCode)") {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: A11y.minTouchTarget)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Button("Generate New Code") {
                generateNewCode()
            }
            .font(.subheadline)
            .frame(minHeight: A11y.minTouchTarget)
            .padding(.horizontal)
        }
    }

    private func generateNewCode() {
        let code = InviteCodeGenerator.generate()
        currentCode = code

        guard let circle else { return }
        let invite = InviteCode(code: code, circle: circle)
        circle.pendingInvites.append(invite)
        context.insert(invite)
        try? context.save()
    }
}
```

- [ ] **Step 2: Build to verify no compile errors**

Run: `xcodebuild build -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: All tests pass (InviteFlowTests if they exist should still pass since the core logic is unchanged).

- [ ] **Step 4: Commit**

```bash
git add AgingInPlace/CloudKit/CloudSharingControllerRepresentable.swift \
       AgingInPlace/Features/CareTeam/InviteFlowView.swift
git commit -m "feat(03): add CloudSharingControllerRepresentable and update InviteFlowView"
```

---

### Task 9: Update JoinCircleView for Share Acceptance

**Files:**
- Modify: `AgingInPlace/Features/CareTeam/JoinCircleView.swift`

**Note:** The `userDidAcceptCloudKitShareWith` scene delegate handler (which auto-accepts incoming CKShare URLs) is intentionally deferred to Phase 4, where the full identity and onboarding flow is built. In Phase 3, caregivers see messaging about share links but the actual CKShare acceptance requires the app delegate wiring that Phase 4 delivers.

- [ ] **Step 1: Add iCloud share acceptance path alongside local code entry**

The `JoinCircleView` keeps its existing local code join logic as a fallback, but adds messaging about share links when iCloud is available.

```swift
// AgingInPlace/Features/CareTeam/JoinCircleView.swift
import SwiftUI
import SwiftData

struct JoinCircleView: View {
    @Environment(\.modelContext) private var context
    @Query private var circles: [CareCircle]

    @State private var enteredCode = ""
    @State private var displayName = ""
    @State private var selectedRole: MemberRole = .family
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var didJoin = false
    @State private var iCloudAvailable = true

    private var circle: CareCircle? { circles.first }

    var body: some View {
        NavigationStack {
            if didJoin {
                joinedConfirmationView
            } else {
                formView
            }
        }
        .task {
            let status = await CloudKitAvailability.checkAccountStatus()
            iCloudAvailable = (status == .available)
        }
    }

    // MARK: - Form

    private var formView: some View {
        Form {
            if iCloudAvailable {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "link.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.accent)
                        Text("Open the invite link sent by your senior to join their care circle automatically.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Join via Link")
                }
            }

            Section(iCloudAvailable ? "Or Enter Code Manually" : "Invite Code") {
                TextField("CARE-XXXX-XXXX", text: $enteredCode)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .onChange(of: enteredCode) { _, newValue in
                        enteredCode = newValue.uppercased()
                        errorMessage = nil
                    }
            }

            Section("Your Details") {
                TextField("Your name", text: $displayName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)

                Picker("Role", selection: $selectedRole) {
                    ForEach(MemberRole.allCases, id: \.self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    requestToJoin()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Request to Join")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: A11y.minTouchTarget)
                    }
                }
                .disabled(enteredCode.isEmpty || displayName.isEmpty || isLoading)
            }
        }
        .navigationTitle("Join Care Circle")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Joined confirmation

    private var joinedConfirmationView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("Request Sent!")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Wait for the senior to approve your request.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .navigationTitle("Request Sent")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Join logic

    private func requestToJoin() {
        isLoading = true
        errorMessage = nil

        let trimmedCode = enteredCode.trimmingCharacters(in: .whitespaces)
        let fetchDesc = FetchDescriptor<InviteCode>(predicate: #Predicate { $0.code == trimmedCode })

        do {
            let matching = try context.fetch(fetchDesc)

            guard let invite = matching.first else {
                errorMessage = "Invalid code. Please check and try again."
                isLoading = false
                return
            }

            guard !invite.isUsed else {
                errorMessage = "This code has already been used."
                isLoading = false
                return
            }

            guard let circle = invite.circle ?? circles.first else {
                errorMessage = "No care circle found for this code."
                isLoading = false
                return
            }

            let member = CareTeamMember(
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                role: selectedRole,
                circle: circle
            )
            circle.members.append(member)
            context.insert(member)
            invite.isUsed = true
            try context.save()

            didJoin = true
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isLoading = false
    }
}
```

- [ ] **Step 2: Build to verify no compile errors**

Run: `xcodebuild build -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add AgingInPlace/Features/CareTeam/JoinCircleView.swift
git commit -m "feat(03): update JoinCircleView with share link messaging and code fallback"
```

---

### Task 10: Update Existing Tests for V3 Schema

**Files:**
- Modify: `AgingInPlaceTests/SchemaMigrationTests.swift`
- Modify: `AgingInPlaceTests/PersistenceTests.swift`
- Modify: `AgingInPlaceTests/CalendarTests.swift`
- Modify: `AgingInPlaceTests/CareVisitTests.swift`
- Modify: `AgingInPlaceTests/MoodTests.swift`
- Modify: `AgingInPlaceTests/MedicationTests.swift`
- Modify: `AgingInPlaceTests/CareHistoryTests.swift`

All these test files have a `makeContainer()` helper that references `AgingInPlaceSchemaV2.models`. Each must be updated to `AgingInPlaceSchemaV3.models`.

- [ ] **Step 1: Update all test files' makeContainer() helpers**

In each of the following files, change `AgingInPlaceSchemaV2` to `AgingInPlaceSchemaV3` in the `makeContainer()` method:

- `AgingInPlaceTests/SchemaMigrationTests.swift:12`
- `AgingInPlaceTests/CalendarTests.swift:12`
- `AgingInPlaceTests/CareVisitTests.swift:12`
- `AgingInPlaceTests/MoodTests.swift:12`
- `AgingInPlaceTests/MedicationTests.swift:12`
- `AgingInPlaceTests/CareHistoryTests.swift:12`

```swift
// In each file's makeContainer():
for: Schema(AgingInPlaceSchemaV3.models),  // was AgingInPlaceSchemaV2
```

- [ ] **Step 2: Update PersistenceTests if they reference V2 schema**

Check `AgingInPlaceTests/PersistenceTests.swift` for any `AgingInPlaceSchemaV2` references and update them to `AgingInPlaceSchemaV3`.

- [ ] **Step 3: Verify no remaining V2 references in tests**

Run: `grep -r "SchemaV2" AgingInPlaceTests/ --include="*.swift"`
Expected: No results.

- [ ] **Step 4: Run full test suite**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add AgingInPlaceTests/
git commit -m "test(03): update all existing tests to use V3 schema"
```

---

### Task 11: Update Preview Containers for V3 Schema

**Files:**
- Modify: All files with `#Preview` blocks that reference `AgingInPlaceSchemaV2`

The following files have preview containers that reference `AgingInPlaceSchemaV2.models`:
- `AgingInPlace/Features/SeniorHome/SeniorHomeView.swift:172`
- `AgingInPlace/Features/CaregiverHome/CaregiverHomeView.swift:234`
- `AgingInPlace/Features/Mood/LogMoodView.swift:122`
- `AgingInPlace/Features/CareHistory/CareHistoryView.swift:255`
- `AgingInPlace/Features/CareVisit/LogCareVisitView.swift:173`

And preview containers that list models explicitly (should be updated to use V3 schema):
- `AgingInPlace/Features/CareTeam/InviteFlowView.swift`
- `AgingInPlace/Features/CareTeam/JoinCircleView.swift`

- [ ] **Step 1: Update all preview containers referencing SchemaV2**

In each of these files, change `AgingInPlaceSchemaV2` to `AgingInPlaceSchemaV3` in the `#Preview` block:

- `AgingInPlace/Features/SeniorHome/SeniorHomeView.swift:172`
- `AgingInPlace/Features/CaregiverHome/CaregiverHomeView.swift:234`
- `AgingInPlace/Features/Mood/LogMoodView.swift:122`
- `AgingInPlace/Features/CareHistory/CareHistoryView.swift:255`
- `AgingInPlace/Features/CareVisit/LogCareVisitView.swift:173`

```swift
// In each file's #Preview:
for: Schema(AgingInPlaceSchemaV3.models),  // was AgingInPlaceSchemaV2
```

- [ ] **Step 2: Update InviteFlowView and JoinCircleView previews**

Update the explicit model lists to use `AgingInPlaceSchemaV3.models` instead of listing individual models.

- [ ] **Step 3: Search for any remaining V2 references in app code**

Run: `grep -r "SchemaV2" AgingInPlace/ --include="*.swift" -l`
Expected: Only `AgingInPlace/Models/Schema/AgingInPlaceSchemaV2.swift` itself (the schema definition file, which must remain).

- [ ] **Step 4: Build to verify no compile errors**

Run: `xcodebuild build -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add AgingInPlace/
git commit -m "chore(03): update all preview containers to V3 schema"
```

---

### Task 12: Final Integration Verification

- [ ] **Step 1: Run full test suite**

Run: `xcodebuild test -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E '(Test Suite|Tests|PASS|FAIL|error:)'`
Expected: All test suites pass, zero failures.

- [ ] **Step 2: Build for device (release config)**

Run: `xcodebuild build -project AgingInPlace.xcodeproj -scheme AgingInPlace -destination generic/platform=iOS -configuration Release CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED (verifies no debug-only code leaks).

- [ ] **Step 3: Verify no V2 schema references remain**

Run: `grep -r "SchemaV2" AgingInPlace/ AgingInPlaceTests/ --include="*.swift"`
Expected: Only `AgingInPlaceSchemaV2.swift` itself and the migration plan reference it.

- [ ] **Step 4: Commit any remaining fixes and tag**

```bash
git add -A
git commit -m "feat(03): complete Phase 3 CloudKit + CKShare integration" --allow-empty
```
