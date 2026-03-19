---
phase: 02-single-device-ux
plan: 01
subsystem: database
tags: [swiftdata, versionedschema, migration, usernotifications, local-notifications, swiftui, cryptokit, swift6]

requires:
  - phase: 01-foundation
    provides: "CareCircle, CareTeamMember, CareRecord, InviteCode, EmergencyContact SwiftData models; EncryptionService AES-GCM; PermissionCategory enum"

provides:
  - "AgingInPlaceSchemaV1 wrapping all 5 Phase 1 models at Schema.Version(1,0,0)"
  - "AgingInPlaceSchemaV2 with all 10 model types at Schema.Version(2,0,0)"
  - "AgingInPlaceMigrationPlan with lightweight V1-to-V2 migration stage"
  - "MedicationSchedule model (drugName/dose unencrypted for notifications, missedWindowMinutes)"
  - "MedicationLog model (encryptedPayload AES-GCM, administeredAt plaintext for predicates)"
  - "CareVisitLog model (encryptedPayload AES-GCM, visitDate plaintext for predicates)"
  - "MoodLog model (moodValue Int plaintext, MoodAuthorType enum, optional encrypted notes)"
  - "CalendarEvent model (title plaintext, eventDate plaintext, encryptedPayload AES-GCM)"
  - "NotificationService with deterministic identifiers for med-reminder, med-missed, and cal-reminder notifications"
  - "com.apple.developer.usernotifications.time-sensitive entitlement"

affects:
  - 02-single-device-ux (all subsequent plans depend on these models)
  - 03-peer-to-peer-sync (LWW sync will use lastModified fields on all 5 new models)

tech-stack:
  added: [UserNotifications]
  patterns:
    - "VersionedSchema migration: SchemaV1 wraps Phase 1 models, SchemaV2 adds Phase 2 models, lightweight migration for additive changes"
    - "Deterministic notification identifiers: med-reminder-{uuid}, med-missed-{uuid}-{YYYY-MM-DD}, cal-reminder-{uuid}"
    - "ModelContainer initialized in AgingInPlaceApp as a lazy stored property using Schema + migrationPlan"
    - "PHI boundary: drug name and event title are NOT encrypted (needed in notifications); payload fields are AES-GCM sealed"
    - "MoodLog authorType stored as String raw value (authorTypeRaw) for SwiftData persistence; computed property exposes MoodAuthorType"

key-files:
  created:
    - AgingInPlace/Models/Schema/AgingInPlaceSchemaV1.swift
    - AgingInPlace/Models/Schema/AgingInPlaceSchemaV2.swift
    - AgingInPlace/Models/Schema/AgingInPlaceMigrationPlan.swift
    - AgingInPlace/Models/MedicationSchedule.swift
    - AgingInPlace/Models/MedicationLog.swift
    - AgingInPlace/Models/CareVisitLog.swift
    - AgingInPlace/Models/MoodLog.swift
    - AgingInPlace/Models/CalendarEvent.swift
    - AgingInPlace/Notifications/NotificationService.swift
    - AgingInPlace/AgingInPlace.entitlements
    - AgingInPlaceTests/SchemaMigrationTests.swift
    - AgingInPlaceTests/NotificationServiceTests.swift
  modified:
    - AgingInPlace/App/AgingInPlaceApp.swift
    - project.yml

key-decisions:
  - "ModelContainer uses Schema(AgingInPlaceSchemaV2.models) + migrationPlan — the .modelContainer(for:migrationPlan:) SwiftUI Scene modifier does not exist on iOS 17+; ModelContainer must be constructed manually and passed via .modelContainer(container:)"
  - "nonisolated(unsafe) required for static var versionIdentifier in both VersionedSchema enums — Swift 6 strict concurrency flags mutable global state"
  - "MoodLog.authorType stored as authorTypeRaw: String with a computed property — SwiftData cannot persist custom enum types without Codable conformance stored as primitives"
  - "Provisional notification authorization used in tests — avoids blocking system dialog; sufficient for verifying pending notification scheduling in test host"
  - "iPhone 16e simulator used (not iPhone 17 Pro) — iPhone 17 Pro simulator has a persistent Mach error -308 preventing test runner launch; 16e works reliably"

patterns-established:
  - "VersionedSchema: always wrap existing models in SchemaV1 before adding new models in SchemaV2"
  - "Notification identifiers: format {type}-{uuid}[-{date-key}] for deterministic cancellation"
  - "PHI boundary in notifications: generic title, drug name/event title in body is acceptable, no payload content"

requirements-completed: [MEDS-01, MEDS-02, MEDS-05, CARE-01, CARE-02, CARE-03, CALR-01, CALR-03]

duration: 20min
completed: 2026-03-19
---

# Phase 2 Plan 01: SwiftData V2 Schema, Five Phase 2 Models, and NotificationService Summary

**VersionedSchema migration from V1 to V2 with 5 new SwiftData models (MedicationSchedule, MedicationLog, CareVisitLog, MoodLog, CalendarEvent) and NotificationService with deterministic med-reminder/med-missed/cal-reminder identifiers**

## Performance

- **Duration:** 20 min
- **Started:** 2026-03-19T12:36:23Z
- **Completed:** 2026-03-19T12:56:50Z
- **Tasks:** 2
- **Files modified:** 14

## Accomplishments

- Versioned SwiftData schema migration from V1 (5 Phase 1 models) to V2 (10 models total) — prevents "unknown model version" crash on update
- Five Phase 2 models with consistent PHI boundary (AES-GCM encrypted payloads, plaintext fields for predicate filtering)
- NotificationService with three distinct notification scenarios, deterministic cancellable identifiers, and timeSensitive interruption level for medications
- 62 tests passing (50 Phase 1 + 8 schema migration + 12 notification service), zero regressions

## Task Commits

1. **Task 1: VersionedSchema migration, five new models, entitlements, migration tests** - `de8e055` (feat)
2. **Task 2: NotificationService with deterministic identifiers and unit tests** - `ee3eb57` (feat)

**Plan metadata:** (docs commit — recorded after summary)

## Files Created/Modified

- `AgingInPlace/Models/Schema/AgingInPlaceSchemaV1.swift` - V1 schema wrapping 5 Phase 1 models at Schema.Version(1,0,0)
- `AgingInPlace/Models/Schema/AgingInPlaceSchemaV2.swift` - V2 schema with all 10 model types at Schema.Version(2,0,0)
- `AgingInPlace/Models/Schema/AgingInPlaceMigrationPlan.swift` - Lightweight migration plan V1 to V2
- `AgingInPlace/Models/MedicationSchedule.swift` - Recurring medication schedule model (drugName/dose unencrypted)
- `AgingInPlace/Models/MedicationLog.swift` - Medication administration log with AES-GCM payload
- `AgingInPlace/Models/CareVisitLog.swift` - Care visit log with AES-GCM payload
- `AgingInPlace/Models/MoodLog.swift` - Mood log with moodValue Int plaintext and MoodAuthorType enum
- `AgingInPlace/Models/CalendarEvent.swift` - Calendar event with title/eventDate plaintext and AES-GCM payload
- `AgingInPlace/Notifications/NotificationService.swift` - All notification scheduling/cancellation
- `AgingInPlace/AgingInPlace.entitlements` - time-sensitive notification entitlement
- `AgingInPlace/App/AgingInPlaceApp.swift` - Updated to use ModelContainer with V2 schema + migration plan
- `project.yml` - Added CODE_SIGN_ENTITLEMENTS reference
- `AgingInPlaceTests/SchemaMigrationTests.swift` - 8 tests for V1-V2 migration and all 5 new models
- `AgingInPlaceTests/NotificationServiceTests.swift` - 12 tests for all notification scenarios

## Decisions Made

- **ModelContainer API:** The `.modelContainer(for:migrationPlan:isAutosaveEnabled:)` modifier shown in the research plan does not exist in iOS 17+. Constructed ModelContainer manually in `AgingInPlaceApp` using `Schema(AgingInPlaceSchemaV2.models)` + `migrationPlan:` init and passed it via `.modelContainer(container:)` Scene modifier.
- **Swift 6 nonisolated:** Both `AgingInPlaceSchemaV1` and `AgingInPlaceSchemaV2` `versionIdentifier` static vars required `nonisolated(unsafe)` for Swift 6 strict concurrency compliance.
- **MoodAuthorType storage:** SwiftData cannot persist a custom Codable enum directly without a transformer. Used `authorTypeRaw: String` as the persisted property with a computed `authorType: MoodAuthorType` property backed by it.
- **Test notification authorization:** Used `.provisional` option in `requestAuthorization` during test setUp to enable notification scheduling without triggering the system permission dialog in the test host.
- **Simulator selection:** iPhone 17 Pro simulator has a persistent `Mach error -308` that prevents test runner launch. All tests run on iPhone 16e which works reliably.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] modelContainer Scene modifier does not accept migrationPlan parameter**
- **Found during:** Task 1 (update AgingInPlaceApp.swift)
- **Issue:** The plan specified `.modelContainer(for: AgingInPlaceSchemaV2.models, migrationPlan: AgingInPlaceMigrationPlan.self, isAutosaveEnabled: false)` but this overload does not exist in the iOS 17+ SwiftUI framework
- **Fix:** Construct `ModelContainer` manually as a stored property using `Schema(AgingInPlaceSchemaV2.models)` + `migrationPlan:` init, then attach via `.modelContainer(container:)`
- **Files modified:** AgingInPlace/App/AgingInPlaceApp.swift
- **Verification:** Build succeeded, all schema migration tests pass
- **Committed in:** de8e055 (Task 1 commit)

**2. [Rule 3 - Blocking] Swift 6 strict concurrency error on static versionIdentifier**
- **Found during:** Task 1 (build verification)
- **Issue:** `static var versionIdentifier = Schema.Version(1, 0, 0)` flagged as "nonisolated global shared mutable state" under Swift 6 strict concurrency
- **Fix:** Added `nonisolated(unsafe)` to both `AgingInPlaceSchemaV1` and `AgingInPlaceSchemaV2` versionIdentifier declarations
- **Files modified:** AgingInPlace/Models/Schema/AgingInPlaceSchemaV1.swift, AgingInPlaceSchemaV2.swift
- **Verification:** Build succeeded with no errors
- **Committed in:** de8e055 (Task 1 commit)

**3. [Rule 1 - Bug] MoodAuthorType enum cannot be persisted directly by SwiftData**
- **Found during:** Task 1 (model design for MoodLog)
- **Issue:** SwiftData does not support direct persistence of custom Codable enums without a value transformer; storing `authorType: MoodAuthorType` directly would cause runtime failures
- **Fix:** Store `authorTypeRaw: String` as the persisted SwiftData field; expose `authorType: MoodAuthorType` as a computed property with get/set backed by `authorTypeRaw`
- **Files modified:** AgingInPlace/Models/MoodLog.swift
- **Verification:** testMoodLogSeniorAuthorType and testMoodLogCaregiverAuthorType both pass
- **Committed in:** de8e055 (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (2 blocking, 1 bug)
**Impact on plan:** All auto-fixes required for compilation and correctness. No scope creep.

## Issues Encountered

- **Simulator instability:** iPhone 17 Pro simulator consistently returns `Mach error -308` preventing test runner launch. Switched all test runs to iPhone 16e which is stable.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All 5 Phase 2 SwiftData models are insertable and queryable
- NotificationService ready for use in medication schedule, care visit, and calendar feature views
- Schema migration is proven safe for existing Phase 1 data
- `lastModified` field on all new models prepares them for Phase 3 LWW sync
- Ready for 02-02 (medication schedule + log UI), 02-03 (care visit + mood UI), 02-04 (calendar UI)

## Self-Check: PASSED

All 12 key files exist on disk. Both task commits (de8e055, ee3eb57) verified in git log. Full test suite: 62 tests, 0 failures.

---
*Phase: 02-single-device-ux*
*Completed: 2026-03-19*
