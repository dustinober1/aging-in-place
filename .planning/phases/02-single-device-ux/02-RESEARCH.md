# Phase 2: Single-Device UX - Research

**Researched:** 2026-03-19
**Domain:** SwiftData schema migration, UserNotifications local scheduling, SwiftUI forms and history browsing, mood and care visit modeling
**Confidence:** HIGH (core APIs verified via official documentation and multiple authoritative community sources)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MEDS-01 | Caregiver or senior can log a medication administration (drug name, dose, time, who administered) | New `MedicationLog` SwiftData model; encrypted payload via existing EncryptionService; log form with structured fields |
| MEDS-02 | Caregiver or senior can set up a recurring medication schedule with local push notification reminders | New `MedicationSchedule` SwiftData model; UNCalendarNotificationTrigger with repeats: true; NotificationService to manage scheduling |
| MEDS-04 | Caregiver can view medication history showing all administrations with timestamps and who logged them | FetchDescriptor on `MedicationLog` sorted by `administeredAt`; decrypt and display author + dose |
| MEDS-05 | Caregiver receives notification if a scheduled medication is not confirmed within a configurable window | UNTimeIntervalNotificationTrigger scheduled `missedWindowMinutes` after dose time; cancelled on log confirmation |
| CARE-01 | Caregiver can log a care visit with structured fields (meals, mobility, observations, concerns) | New `CareVisitLog` SwiftData model with Codable payload struct; Form UI with TextEditor and pickers |
| CARE-02 | Senior can self-report mood on a simple scale (e.g., 1-5 or emoji) | New `MoodLog` SwiftData model; simple 5-option segmented or button picker; senior home card integration |
| CARE-03 | Caregiver can log observed mood for the senior during a visit | Same `MoodLog` model with `authorType: .caregiver`; caregiver quick-action wired to mood form |
| CARE-04 | User can browse full care history with filtering by category, date range, and author | CareHistoryView with `FetchDescriptor` + `#Predicate` filtering on category/date/author; sorted by `lastModified` descending |
| CARE-05 | User can search care logs by keyword | `localizedStandardContains()` in `#Predicate` on decrypted summary fields; search bar tied to `@State` query string |
| CALR-01 | Caregiver or senior can create appointments (doctor visits, PT, etc.) on a shared calendar | New `CalendarEvent` SwiftData model; simple create form with title, date, notes, attendees |
| CALR-02 | Shared calendar is visible to all permitted care team members | CareCalendarView using `@Query` on `CalendarEvent` sorted by `startDate`; permission-gated via `.calendar` category |
| CALR-03 | Appointment reminders are sent as local notifications to relevant care team members | UNCalendarNotificationTrigger at `startDate minus reminderOffset`; removed on event deletion or update |
</phase_requirements>

---

## Summary

Phase 2 builds the complete single-device care workflow on top of the Phase 1 foundation. The three interlocking concerns are: (1) safely migrating the existing unversioned SwiftData schema to add five new model types (`MedicationSchedule`, `MedicationLog`, `CareVisitLog`, `MoodLog`, `CalendarEvent`) without corrupting Phase 1 user data; (2) implementing the `UserNotifications` framework for three distinct notification scenarios — scheduled medication reminders, missed-dose caregiver alerts, and appointment reminders — within the 64-notification system limit; and (3) building history browsing with `FetchDescriptor` + `#Predicate` that supports category, date-range, author, and keyword filtering entirely offline.

The most urgent architectural issue is the **VersionedSchema gap from Phase 1**. The existing models were shipped unversioned. Adding new models in Phase 2 requires a two-step schema migration strategy: Wave 0 must first wrap all Phase 1 models in `AgingInPlaceSchemaV1` and release that before adding `SchemaV2` with new models. Doing this in a single release causes "Cannot use staged migration with an unknown model version" crashes for existing users. Since this is pre-release development with no live users, both steps can be combined in the same development cycle — but they must be done in strict order within Wave 0.

The second key decision is how to implement the missed-dose caregiver notification (MEDS-05). The correct pattern is: schedule a `UNTimeIntervalNotificationTrigger` set `missedWindowMinutes` after the scheduled dose time (e.g., 30 minutes). When a `MedicationLog` record is written confirming the dose, cancel the pending missed-dose notification by its deterministic identifier. This requires no background tasks — the cancellation happens in the foreground when the log is saved.

**Primary recommendation:** Wave 0 introduces VersionedSchema. New models go in SchemaV2. Notification scheduling uses deterministic identifiers keyed to schedule UUID + date so they can be reliably cancelled. History browsing uses `FetchDescriptor` with dynamic `#Predicate` — not in-memory filtering — to keep performance acceptable as records accumulate.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ | Persistent storage for new models | Already in use from Phase 1; no alternatives |
| UserNotifications | iOS 10+ | Local push notifications for meds and appointments | Apple-native; no server required; works fully offline |
| Swift Concurrency (async/await) | Swift 5.9 / 6 | `UNUserNotificationCenter.add()` is async throws | Required for Swift 6 strict concurrency compliance |
| SwiftUI | iOS 17+ | All forms, lists, calendar view | Already in use; system Dynamic Type and accessibility automatic |
| CryptoKit + Keychain | iOS 13+ | Encrypting all new care record payloads | Phase 1 services already built; reuse EncryptionService |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation `DateComponents` | built-in | Calendar trigger configuration for recurring notifications | Used in UNCalendarNotificationTrigger for medication schedules |
| Foundation `Calendar` | built-in | Date arithmetic for notification offset calculation | Computing `startDate - reminderOffset` for appointment reminders |
| SwiftUI `Form` | iOS 13+ | Structured input for care visit, medication, and appointment logging | Standard form layout; native section and field grouping |
| SwiftUI `DatePicker` | iOS 13+ | Date and time selection for schedules, appointments, logs | Native; integrates with Dynamic Type |
| `ContentUnavailableView` | iOS 17+ | Empty states in history and calendar views | Already used in Phase 1 |
| `UNNotificationInterruptionLevel.timeSensitive` | iOS 15+ | Medication reminders break through Focus mode | Requires `com.apple.developer.usernotifications.time-sensitive` entitlement |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UserNotifications local scheduling | Background task + local notification at runtime | Background tasks are not guaranteed to fire on time; UNCalendarNotificationTrigger is OS-delivered and reliable without the app running |
| `#Predicate` + `FetchDescriptor` for history | In-memory filtering of all records | FetchDescriptor filtering happens at the SQL layer — correct as record count grows; in-memory filtering fetches all records regardless of predicate |
| Custom mood picker UI | Third-party emoji picker library | No external dependencies; a 5-button row with SF Symbols or emoji literals is accessible, testable, and zero-dependency |
| EventKit / system Calendar | Custom `CalendarEvent` SwiftData model | EventKit requires user permission for their personal calendar; CALR-02 requires a shared care-circle-scoped calendar not tied to the personal calendar — SwiftData is the correct choice |

**Installation:** No new external package dependencies for Phase 2. All frameworks are built into iOS 15+.

---

## Architecture Patterns

### Recommended Project Structure Additions

```
AgingInPlace/
├── Models/
│   ├── Schema/                        # NEW: VersionedSchema wrappers
│   │   ├── AgingInPlaceSchemaV1.swift # Wraps all Phase 1 models
│   │   └── AgingInPlaceSchemaV2.swift # Adds Phase 2 models
│   ├── MedicationSchedule.swift       # NEW
│   ├── MedicationLog.swift            # NEW
│   ├── CareVisitLog.swift             # NEW
│   ├── MoodLog.swift                  # NEW
│   └── CalendarEvent.swift            # NEW
├── Notifications/                     # NEW
│   └── NotificationService.swift      # Schedule, cancel, permission request
├── Features/
│   ├── Medications/                   # NEW
│   │   ├── MedicationListView.swift
│   │   ├── LogMedicationView.swift
│   │   └── MedicationScheduleView.swift
│   ├── CareHistory/                   # NEW
│   │   ├── CareHistoryView.swift
│   │   └── CareHistoryRow.swift
│   ├── CareVisit/                     # NEW
│   │   └── LogCareVisitView.swift
│   ├── Mood/                          # NEW
│   │   └── LogMoodView.swift
│   └── Calendar/                      # NEW
│       ├── CareCalendarView.swift
│       └── AddEventView.swift
└── App/
    └── AgingInPlaceApp.swift          # MODIFIED: add VersionedSchema migration plan
```

### Pattern 1: VersionedSchema Migration (CRITICAL — Wave 0)

**What:** Wrap Phase 1 models in `SchemaV1`, add Phase 2 models in `SchemaV2` with a lightweight migration plan. Update `AgingInPlaceApp` to use the migration-aware `ModelContainer`.

**When to use:** This is the FIRST thing done in Phase 2. No new models can be added until the schema is versioned.

**Why it matters:** Phase 1 shipped without `VersionedSchema`. Adding new models to an unversioned store triggers the crash "Cannot use staged migration with an unknown model version" for existing users. Adding new entity types is a lightweight migration — no data transformation needed.

```swift
// Source: Apple WWDC23 "Model your schema with SwiftData" + multiple developer forum confirmations

import SwiftData

// AgingInPlaceSchemaV1.swift
// Wraps EXACTLY the Phase 1 models — no changes to their definitions
enum AgingInPlaceSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CareCircle.self,
            CareTeamMember.self,
            CareRecord.self,
            InviteCode.self,
            EmergencyContact.self
        ]
    }
}

// AgingInPlaceSchemaV2.swift
// Adds Phase 2 models
enum AgingInPlaceSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

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

// AgingInPlaceMigrationPlan.swift
enum AgingInPlaceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AgingInPlaceSchemaV1.self, AgingInPlaceSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        // Adding new entities is a lightweight migration — no data transformation needed
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AgingInPlaceSchemaV1.self,
        toVersion: AgingInPlaceSchemaV2.self
    )
}
```

**Updated AgingInPlaceApp.swift:**
```swift
// Source: Apple SwiftData documentation on ModelContainer with migration plan

@main
struct AgingInPlaceApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(
            for: AgingInPlaceSchemaV2.models,
            migrationPlan: AgingInPlaceMigrationPlan.self,
            isAutosaveEnabled: false  // Phase 1 decision: explicit save only
        )
    }
}
```

### Pattern 2: New SwiftData Models for Phase 2

**What:** Five new `@Model` classes, all carrying `lastModified: Date` for Phase 3 LWW sync and storing PHI as encrypted payloads.

**When to use:** All structured care data. Non-PHI metadata (drug name for notification display, appointment title for notification) must be considered carefully — see Pitfall 4 below.

```swift
// Source: Phase 1 pattern — same conventions applied to new models

@Model
final class MedicationSchedule {
    var id: UUID
    var drugName: String              // NOT encrypted — used in notification titles
    var dose: String                  // NOT encrypted — used in notification bodies
    var scheduledHour: Int            // Hour of day for recurring reminder
    var scheduledMinute: Int
    var missedWindowMinutes: Int      // Default: 30. How long before caregiver alert fires.
    var isActive: Bool
    var createdByMemberID: UUID
    var createdAt: Date
    var lastModified: Date

    init(drugName: String, dose: String, hour: Int, minute: Int,
         missedWindowMinutes: Int = 30, createdByMemberID: UUID) {
        self.id = UUID()
        self.drugName = drugName
        self.dose = dose
        self.scheduledHour = hour
        self.scheduledMinute = minute
        self.missedWindowMinutes = missedWindowMinutes
        self.isActive = true
        self.createdByMemberID = createdByMemberID
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

@Model
final class MedicationLog {
    var id: UUID
    var scheduleID: UUID?             // Links to MedicationSchedule if scheduled dose
    var encryptedPayload: Data        // AES-GCM: { drugName, dose, notes } as JSON
    var administeredAt: Date          // Not encrypted — needed for predicate sorting
    var authorMemberID: UUID
    var createdAt: Date
    var lastModified: Date

    init(scheduleID: UUID? = nil, encryptedPayload: Data, administeredAt: Date, authorMemberID: UUID) {
        self.id = UUID()
        self.scheduleID = scheduleID
        self.encryptedPayload = encryptedPayload
        self.administeredAt = administeredAt
        self.authorMemberID = authorMemberID
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

@Model
final class CareVisitLog {
    var id: UUID
    var encryptedPayload: Data        // AES-GCM: { meals, mobility, observations, concerns }
    var visitDate: Date               // Not encrypted — needed for predicate date filtering
    var authorMemberID: UUID
    var createdAt: Date
    var lastModified: Date

    init(encryptedPayload: Data, visitDate: Date, authorMemberID: UUID) {
        self.id = UUID()
        self.encryptedPayload = encryptedPayload
        self.visitDate = visitDate
        self.authorMemberID = authorMemberID
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

@Model
final class MoodLog {
    var id: UUID
    var moodValue: Int                // 1–5 scale (not PHI — no encryption needed)
    var authorMemberID: UUID
    var authorType: MoodAuthorType    // .senior or .caregiver
    var notes: Data?                  // Optional encrypted payload for free-text notes
    var loggedAt: Date
    var lastModified: Date

    init(moodValue: Int, authorMemberID: UUID, authorType: MoodAuthorType, notes: Data? = nil) {
        self.id = UUID()
        self.moodValue = moodValue
        self.authorMemberID = authorMemberID
        self.authorType = authorType
        self.notes = notes
        self.loggedAt = Date()
        self.lastModified = Date()
    }
}

enum MoodAuthorType: String, Codable, CaseIterable {
    case senior
    case caregiver
}

@Model
final class CalendarEvent {
    var id: UUID
    var title: String                 // NOT encrypted — used in notification titles
    var eventDate: Date               // Not encrypted — needed for trigger calculation
    var reminderOffsetMinutes: Int    // Default: 60. Minutes before event to notify.
    var encryptedPayload: Data        // AES-GCM: { location, notes, attendees }
    var createdByMemberID: UUID
    var createdAt: Date
    var lastModified: Date

    init(title: String, eventDate: Date, reminderOffsetMinutes: Int = 60,
         encryptedPayload: Data, createdByMemberID: UUID) {
        self.id = UUID()
        self.title = title
        self.eventDate = eventDate
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.encryptedPayload = encryptedPayload
        self.createdByMemberID = createdByMemberID
        self.createdAt = Date()
        self.lastModified = Date()
    }
}
```

### Pattern 3: NotificationService

**What:** A service that manages all notification scheduling and cancellation. Uses deterministic identifiers keyed to model UUIDs so notifications can be reliably cancelled.

**When to use:** Called from view models / form submit handlers after SwiftData save succeeds.

```swift
// Source: Apple UserNotifications documentation + async/await pattern

import UserNotifications

struct NotificationService {

    // MARK: - Permission

    static func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Medication Schedule Reminder (MEDS-02)
    // Schedules a recurring daily notification at the schedule's time.
    // Identifier: "med-reminder-\(schedule.id.uuidString)"
    static func scheduleMedicationReminder(for schedule: MedicationSchedule) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Medication Reminder"
        content.body = "\(schedule.drugName) — \(schedule.dose)"
        content.sound = .default
        content.interruptionLevel = .timeSensitive  // Breaks through Focus mode

        var dateComponents = DateComponents()
        dateComponents.hour = schedule.scheduledHour
        dateComponents.minute = schedule.scheduledMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = "med-reminder-\(schedule.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Missed Dose Caregiver Alert (MEDS-05)
    // Schedules a one-time alert missedWindowMinutes after scheduled dose time.
    // Identifier: "med-missed-\(schedule.id.uuidString)-\(dateString)"
    // Cancel this notification when MedicationLog is written for this schedule + date.
    static func scheduleMissedDoseAlert(
        for schedule: MedicationSchedule,
        onDate date: Date
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Missed Dose Alert"
        content.body = "\(schedule.drugName) was not confirmed within \(schedule.missedWindowMinutes) minutes"
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive

        let fireDate = date.addingTimeInterval(Double(schedule.missedWindowMinutes) * 60)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, fireDate.timeIntervalSinceNow),
            repeats: false
        )
        let dateKey = ISO8601DateFormatter().string(from: date).prefix(10)
        let identifier = "med-missed-\(schedule.id.uuidString)-\(dateKey)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }

    // Cancel missed-dose alert when caregiver/senior logs the dose (MEDS-05)
    static func cancelMissedDoseAlert(for schedule: MedicationSchedule, onDate date: Date) {
        let dateKey = ISO8601DateFormatter().string(from: date).prefix(10)
        let identifier = "med-missed-\(schedule.id.uuidString)-\(dateKey)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Calendar Appointment Reminder (CALR-03)
    // Identifier: "cal-reminder-\(event.id.uuidString)"
    static func scheduleAppointmentReminder(for event: CalendarEvent) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Appointment"
        content.body = "\(event.title) starts in \(event.reminderOffsetMinutes) minutes"
        content.sound = .default
        content.interruptionLevel = .active

        let fireDate = event.eventDate.addingTimeInterval(-Double(event.reminderOffsetMinutes) * 60)
        guard fireDate > Date() else { return }  // Skip past events

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireDate.timeIntervalSinceNow,
            repeats: false
        )
        let identifier = "cal-reminder-\(event.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }

    // Cancel appointment reminder when event is deleted or rescheduled
    static func cancelAppointmentReminder(for event: CalendarEvent) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["cal-reminder-\(event.id.uuidString)"]
        )
    }

    // MARK: - Notification Refresh on Launch (64-limit workaround)
    // Call on app foreground to rotate the 64 soonest notifications.
    static func refreshScheduledNotifications(schedules: [MedicationSchedule]) async throws {
        // Remove all existing med-reminder notifications
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let medReminderIDs = pending
            .filter { $0.identifier.hasPrefix("med-reminder-") }
            .map(\.identifier)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: medReminderIDs)

        // Re-schedule active schedules
        for schedule in schedules where schedule.isActive {
            try await scheduleMedicationReminder(for: schedule)
        }
    }
}
```

### Pattern 4: Care History Browsing with FetchDescriptor (CARE-04, CARE-05)

**What:** A unified history view driven by dynamic `FetchDescriptor` predicates. Category, date range, author, and keyword filters compose into a single descriptor fetch — not in-memory filtering.

**When to use:** `CareHistoryView` with `@State` filter properties; rebuild descriptor on filter change.

**Limitation:** `CARE-05` (keyword search) requires that the search term match against a non-encrypted field. For Phase 2, a `plainTextSummary: String` field storing a non-sensitive summary (drug name only, mood value only — no PHI) enables keyword search. Full-text search within encrypted payloads is not possible at the SwiftData layer.

```swift
// Source: Apple FetchDescriptor documentation + Hacking with Swift SwiftData predicates

// Search model for unified history — non-PHI summary stored alongside encrypted payload
// This is added to CareRecord in SchemaV2 as a new optional field (lightweight migration eligible)
// OR implemented as a separate index model — decision for the plan

// Dynamic predicate construction for date range + author filter:
func makeHistoryDescriptor(
    category: PermissionCategory?,
    from startDate: Date?,
    to endDate: Date?,
    authorMemberID: UUID?
) -> FetchDescriptor<CareRecord> {
    // #Predicate must be constructed at compile time — use conditional composition
    var descriptor = FetchDescriptor<CareRecord>(
        sortBy: [SortDescriptor(\.lastModified, order: .reverse)]
    )

    // Apply category filter
    if let category {
        descriptor.predicate = #Predicate<CareRecord> { record in
            record.category == category
        }
    }

    // Note: SwiftData iOS 17.4+ supports predicate combination via &&
    // For complex multi-filter predicates, build a single compound #Predicate
    return descriptor
}

// Keyword search pattern using localizedStandardContains (case-insensitive, locale-aware)
// Applied against a non-encrypted summary field, not the encryptedPayload blob
```

### Pattern 5: Mood Picker UI (CARE-02, CARE-03)

**What:** A 5-button horizontal row using SF Symbol faces or emoji. No external library. Accessible via `.accessibilityLabel`.

**When to use:** Both senior self-report and caregiver observed mood forms.

```swift
// Source: SwiftUI built-in — no external library needed

struct MoodPickerView: View {
    @Binding var selectedMood: Int  // 1–5

    private let moodOptions: [(value: Int, symbol: String, label: String)] = [
        (1, "😞", "Very sad"),
        (2, "😕", "Sad"),
        (3, "😐", "Neutral"),
        (4, "🙂", "Happy"),
        (5, "😄", "Very happy")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(moodOptions, id: \.value) { option in
                Button {
                    selectedMood = option.value
                } label: {
                    Text(option.symbol)
                        .font(.largeTitle)
                        .padding(8)
                        .background(selectedMood == option.value
                            ? Color.accentColor.opacity(0.2) : Color.clear)
                        .clipShape(Circle())
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(selectedMood == option.value ? .isSelected : [])
            }
        }
    }
}
```

### Anti-Patterns to Avoid

- **Adding new models to an unversioned store without VersionedSchema first:** Causes "Cannot use staged migration with an unknown model version" crash. Always wrap Phase 1 models in SchemaV1 before adding SchemaV2.
- **Storing PHI in notification title/body:** UNNotificationContent is visible on the lock screen and in Notification Center — never put medication details, mood values, or care observations there. Use generic titles ("Medication Reminder", "Appointment Coming Up").
- **Using in-memory filtering for history browsing:** Fetching all `CareRecord` objects and filtering in the view layer scales poorly. Use `FetchDescriptor` with `#Predicate` so filtering is handled at the SQLite layer.
- **Scheduling notifications without a deterministic identifier:** Notifications must be identifiable by UUID + date key so they can be precisely cancelled when a dose is confirmed. Avoid random `UUID().uuidString` as notification identifiers.
- **Not refreshing the 64-notification pool on app launch:** Recurring calendar triggers count as one; but one-time missed-dose notifications consume slots. Refresh on `scenePhase == .active` to ensure the 64 nearest fire.
- **Using EventKit for the care calendar:** EventKit writes to the user's personal calendar and requires a distinct permission that users often deny. The care calendar is care-circle-scoped, not system-calendar-scoped.
- **Encrypting the `eventDate` or `administeredAt` date fields:** These are needed for `#Predicate` date range filtering at the SwiftData layer. Encrypt only PHI payload fields.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Local notification scheduling | Custom timer-based background checks | `UNCalendarNotificationTrigger` + `UNTimeIntervalNotificationTrigger` | OS-delivered, fire without the app running, battery-efficient |
| Notification cancellation | Scan all notifications and find by content | Deterministic identifiers (`"med-missed-{uuid}-{date}"`) + `removePendingNotificationRequests(withIdentifiers:)` | O(1) removal; no need to enumerate pending queue |
| System calendar integration | EventKit + user permission | Custom `CalendarEvent` SwiftData model | Avoids personal calendar permission; keeps data care-circle-scoped |
| In-app notification permission prompt | Custom UI explaining permissions | System `requestAuthorization(options:)` — add pre-prompt explanation in app UI before calling | System dialog is required; pre-prompt in SwiftUI can improve acceptance |
| Mood scale picker | Third-party emoji picker library | Five-button `HStack` with `Text` emoji | Zero dependency; fully accessible; exactly 5 values |

**Key insight:** UserNotifications does all scheduling persistence through the OS — the app does not need to be running when the notification fires. This is the only correct approach for medication reminders that must fire even when the phone is locked.

---

## Common Pitfalls

### Pitfall 1: The VersionedSchema Crash (CRITICAL)

**What goes wrong:** Adding new `@Model` types to an app that shipped SwiftData without `VersionedSchema` causes a crash on launch for existing users: "Cannot use staged migration with an unknown model version."

**Why it happens:** SwiftData stores a version checksum in the persistent store metadata. If the checksum does not match any versioned schema's identifier, the migration engine cannot determine the starting point and throws.

**How to avoid:** Wave 0 of Phase 2 MUST wrap all Phase 1 models in `AgingInPlaceSchemaV1` before any new models are added. Then add Phase 2 models in `AgingInPlaceSchemaV2` with a lightweight migration. These two steps can be in the same development cycle (pre-launch, no live users), but the SchemaV1 wrapper must be committed and tested first.

**Warning signs:** App crashes immediately on launch after adding new model types; no visible error in UI, only in console.

### Pitfall 2: PHI in Notification Content

**What goes wrong:** Drug name, dose, or mood value appears on the iOS lock screen or in Notification Center, visible to anyone who glances at the phone.

**Why it happens:** `UNMutableNotificationContent.title` and `.body` are stored by iOS in a non-encrypted notification queue and displayed on the lock screen by default.

**How to avoid:** Use generic, non-identifying notification titles and bodies ("Medication Reminder", "Appointment Soon"). The user taps the notification to open the app and see full details. Consider setting `content.targetContentIdentifier` to deep-link to the correct screen without putting PHI in the notification content itself.

**Warning signs:** Lock screen showing drug names, dosage amounts, or mood descriptions.

### Pitfall 3: 64-Notification Limit Exhaustion

**What goes wrong:** When a patient has more than ~30 medications on recurring schedules PLUS missed-dose one-time notifications PLUS appointment reminders, the 64-notification pool is exhausted. New notifications silently fail to schedule; older notifications are discarded by the OS.

**Why it happens:** iOS keeps only the 64 soonest-firing pending notification requests. Recurring `UNCalendarNotificationTrigger` counts as one slot (infinite recurrence); one-time `UNTimeIntervalNotificationTrigger` counts as one slot per instance.

**How to avoid:** Call `refreshScheduledNotifications()` on each `scenePhase == .active` transition. Prioritize recurring schedule reminders (one slot each) over ephemeral missed-dose alerts (one slot per dose-day). For a typical care case (2–5 medications, a few appointments), the limit is not a practical concern.

**Warning signs:** Notifications stop firing after a period of heavy scheduling; `getPendingNotificationRequests` returns fewer than expected items.

### Pitfall 4: Encrypting Fields Needed for Predicate Filtering

**What goes wrong:** `CareRecord.encryptedPayload` stores everything, including the category or date, making it impossible to write `#Predicate` filters for history browsing without decrypting every record in memory first.

**Why it happens:** Over-aggressive encryption of all fields. SwiftData predicates operate on stored field values — they cannot see inside an opaque `Data` blob.

**How to avoid:** Store only PHI in `encryptedPayload`. Store metadata needed for filtering — `category`, `administeredAt`, `visitDate`, `authorMemberID`, `loggedAt` — as plaintext SwiftData fields. These dates and IDs are not themselves PHI; they become sensitive only in combination with the payload content.

**Warning signs:** History view requires loading all records and decrypting in-memory before filtering — this will be slow and will grow worse as record count increases.

### Pitfall 5: Notification Authorization Not Requested Early

**What goes wrong:** The app attempts to schedule a medication reminder immediately after the user creates a schedule, but authorization was never requested. The `add()` call throws `UNError.notificationsNotAllowed`. The reminder is silently dropped.

**Why it happens:** Notification authorization requires an explicit `requestAuthorization()` call. The system prompt can only appear once (subsequent calls return the current authorization status, not a new prompt).

**How to avoid:** Request authorization during a natural onboarding moment — the first time the user navigates to the Medications section or attempts to create their first schedule. Show an in-app explanation before calling `requestAuthorization(options:)` to maximize acceptance rate.

**Warning signs:** Schedules appear to be created successfully but no notifications ever fire; `UNUserNotificationCenter.getNotificationSettings()` returns `.denied`.

### Pitfall 6: SwiftData `#Predicate` Compile-Time Restrictions

**What goes wrong:** Developers attempt to build complex dynamic predicates at runtime (combining multiple optional filter criteria) and encounter compiler errors. SwiftData `#Predicate` is a macro evaluated at compile time — it cannot close over runtime-constructed expressions arbitrarily.

**Why it happens:** `#Predicate` uses Swift's macro system to translate Swift expressions into SQLite predicates at compile time. Closures with conditional logic work; dynamically concatenating predicates at runtime does not work cleanly below iOS 17.4.

**How to avoid:** Define a small set of compile-time predicates for the filter combinations needed (category only, date range only, author only, combined). For iOS 17.4+, predicates can be combined with `&&`. For iOS 17.0–17.3 compatibility, use separate `FetchDescriptor` definitions per filter mode and select among them based on active filters.

**Warning signs:** Compiler error "Expression not supported in a predicate"; runtime fetch returning all records regardless of filter.

---

## Code Examples

### Registering Migration Plan in App Entry Point

```swift
// Source: Apple SwiftData documentation on ModelContainer migration
.modelContainer(
    for: AgingInPlaceSchemaV2.models,
    migrationPlan: AgingInPlaceMigrationPlan.self,
    isAutosaveEnabled: false
)
```

### Scheduling and Cancelling a Missed-Dose Notification

```swift
// Schedule when schedule is created or on daily refresh
try await NotificationService.scheduleMissedDoseAlert(for: schedule, onDate: today)

// Cancel immediately when MedicationLog is written (in the save handler)
func logMedicationDose(schedule: MedicationSchedule, context: ModelContext) async throws {
    let payload = try EncryptionService.seal(medicationJSON, for: .medications)
    let log = MedicationLog(
        scheduleID: schedule.id,
        encryptedPayload: payload,
        administeredAt: Date(),
        authorMemberID: currentMemberID
    )
    context.insert(log)
    try context.save()
    // Cancel the missed-dose alert now that the dose is confirmed
    NotificationService.cancelMissedDoseAlert(for: schedule, onDate: Date())
}
```

### Care History FetchDescriptor with Date Filter

```swift
// Source: Apple FetchDescriptor documentation
// Filter to last 7 days of care visits
let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
var descriptor = FetchDescriptor<CareVisitLog>(
    predicate: #Predicate<CareVisitLog> { log in
        log.visitDate >= cutoff
    },
    sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
)
descriptor.fetchLimit = 100  // Safety cap; increase if needed
let recentVisits = try context.fetch(descriptor)
```

### Requesting Notification Authorization with Pre-Prompt

```swift
// Show in-app explanation BEFORE calling system requestAuthorization
struct NotificationPermissionView: View {
    @State private var showingSystemPrompt = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)
            Text("Medication Reminders")
                .font(.title2).bold()
            Text("Allow notifications so you receive reminders when medications are due and alerts when a dose is missed.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondary)
            Button("Enable Notifications") {
                Task {
                    _ = try? await NotificationService.requestAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
        }
        .padding()
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Unversioned SwiftData | VersionedSchema + SchemaMigrationPlan | Must be done before Phase 2 ships | Prevents crash-on-update for existing users |
| UILocalNotification (deprecated) | UNUserNotificationCenter | iOS 10 | Async/await API, OS-delivered even when app not running |
| EventKit for in-app calendars | Custom SwiftData CalendarEvent model | Project decision | Avoids personal calendar permission; care-circle-scoped |
| NSPredicate (Core Data) | #Predicate macro (SwiftData) | iOS 17 | Compile-time type-safe predicates; iOS 17.4+ adds dynamic combination |
| CommonCrypto | CryptoKit (Phase 1 decision) | iOS 13 | All new models use the same EncryptionService |

**Deprecated/outdated:**
- **UILocalNotification:** Removed in iOS 14. Never use. UNUserNotificationCenter is the only API.
- **Background task approach for notifications:** BGAppRefreshTask is not reliably timed — OS decides when to run it. UNCalendarNotificationTrigger / UNTimeIntervalNotificationTrigger fire at exact times without any background task.

---

## Open Questions

1. **Plain-text summary field for keyword search (CARE-05)**
   - What we know: SwiftData `#Predicate` with `localizedStandardContains()` works against `String` fields. The `encryptedPayload` blob cannot be searched at the SQLite layer.
   - What's unclear: Whether adding a `searchSummary: String` field (e.g., "Metformin 500mg") alongside the encrypted payload is an acceptable privacy trade-off, or whether keyword search should be implemented purely in-memory after decryption (accepting performance limits).
   - Recommendation: For Phase 2 with single-device, in-memory search after decryption is acceptable (record counts will be small). Avoid storing unencrypted PHI in a dedicated search field. Document this limitation for Phase 3 (sync) which may need a different approach.

2. **`timeSensitive` entitlement for medication reminders**
   - What we know: `UNNotificationInterruptionLevel.timeSensitive` requires the `com.apple.developer.usernotifications.time-sensitive` entitlement. This entitlement does not require App Store review for TestFlight builds but must be present in the app's entitlements file.
   - What's unclear: Whether the App Store will require justification for the time-sensitive entitlement in a care app context (likely yes, but a medication reminder use case is explicitly cited by Apple as the canonical example).
   - Recommendation: Add the entitlement in Wave 0. Use `timeSensitive` for medication reminders and missed-dose alerts only; use `.active` for appointment reminders.

3. **`MoodLog` encryption threshold**
   - What we know: A mood value of 1–5 is not by itself PHI. Free-text notes attached to a mood entry are PHI.
   - What's unclear: Whether the mood value integer (stored plaintext for SwiftData querying) combined with the timestamp constitutes sensitive information in context.
   - Recommendation: Store `moodValue: Int` as a plaintext SwiftData field (needed for predicate-based history queries). Store free-text notes in `notes: Data?` (optional encrypted payload). Document this boundary.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (existing from Phase 1) |
| Config file | None — existing Xcode project with AgingInPlaceTests target |
| Quick run command | `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests` |
| Full suite command | `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MEDS-01 | MedicationLog inserted with encrypted payload survives save/fetch | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/MedicationTests` | Wave 0 |
| MEDS-02 | NotificationService.scheduleMedicationReminder adds pending notification | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/NotificationServiceTests` | Wave 0 |
| MEDS-04 | MedicationLog fetch sorted by administeredAt returns all logs with author | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/MedicationTests` | Wave 0 |
| MEDS-05 | scheduleMissedDoseAlert schedules notification; cancelMissedDoseAlert removes it | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/NotificationServiceTests` | Wave 0 |
| CARE-01 | CareVisitLog inserted with encrypted payload survives save/fetch | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CareVisitTests` | Wave 0 |
| CARE-02 | MoodLog with authorType .senior saves correct moodValue | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/MoodTests` | Wave 0 |
| CARE-03 | MoodLog with authorType .caregiver is distinct from senior log in history | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/MoodTests` | Wave 0 |
| CARE-04 | FetchDescriptor with date range predicate returns only matching records | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CareHistoryTests` | Wave 0 |
| CARE-05 | In-memory keyword search filters decrypted summaries correctly | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CareHistoryTests` | Wave 0 |
| CALR-01 | CalendarEvent inserted with title and eventDate survives save/fetch | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CalendarTests` | Wave 0 |
| CALR-02 | CalendarEvent query returns events sorted by eventDate ascending | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CalendarTests` | Wave 0 |
| CALR-03 | scheduleAppointmentReminder adds pending notification; cancel removes it | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/NotificationServiceTests` | Wave 0 |
| Schema migration | V1 store opens under V2 schema without crash; new models insertable | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/SchemaMigrationTests` | Wave 0 |

### Sampling Rate

- **Per task commit:** `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests/SchemaMigrationTests -only-testing:AgingInPlaceTests/NotificationServiceTests`
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green + manual notification delivery verification in Simulator before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `AgingInPlaceTests/SchemaMigrationTests.swift` — verifies V1→V2 migration; creates V1 in-memory store, migrates, confirms new models are insertable
- [ ] `AgingInPlaceTests/MedicationTests.swift` — covers MEDS-01, MEDS-04
- [ ] `AgingInPlaceTests/NotificationServiceTests.swift` — covers MEDS-02, MEDS-05, CALR-03; mocks UNUserNotificationCenter with test delegate
- [ ] `AgingInPlaceTests/CareVisitTests.swift` — covers CARE-01
- [ ] `AgingInPlaceTests/MoodTests.swift` — covers CARE-02, CARE-03
- [ ] `AgingInPlaceTests/CareHistoryTests.swift` — covers CARE-04, CARE-05
- [ ] `AgingInPlaceTests/CalendarTests.swift` — covers CALR-01, CALR-02
- [ ] `AgingInPlace/Models/Schema/AgingInPlaceSchemaV1.swift` — wraps Phase 1 models
- [ ] `AgingInPlace/Models/Schema/AgingInPlaceSchemaV2.swift` — adds Phase 2 models
- [ ] `AgingInPlace/Notifications/NotificationService.swift`
- [ ] `com.apple.developer.usernotifications.time-sensitive` entitlement in `AgingInPlace.entitlements`

**In-memory ModelContainer for migration tests:**
```swift
// Test that V1 store can be opened and migrated to V2
// In-memory migration testing uses ModelContainer with migration plan
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(
    for: AgingInPlaceSchemaV2.models,
    migrationPlan: AgingInPlaceMigrationPlan.self,
    configurations: config
)
```

---

## Sources

### Primary (HIGH confidence)

- [Apple UNUserNotificationCenter documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) — authorization, scheduling, cancellation
- [Apple UNCalendarNotificationTrigger documentation](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger) — calendar-based recurring triggers
- [Apple UNTimeIntervalNotificationTrigger documentation](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger) — interval-based one-time triggers
- [Apple UNNotificationInterruptionLevel.timeSensitive documentation](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive) — Focus mode bypass
- [Apple FetchDescriptor documentation](https://developer.apple.com/documentation/swiftdata/fetchdescriptor) — predicate and sort configuration
- [Apple WWDC23 "Model your schema with SwiftData"](https://developer.apple.com/videos/play/wwdc2023/10195/) — VersionedSchema and SchemaMigrationPlan
- [Apple VersionedSchema documentation](https://developer.apple.com/documentation/swiftdata/versionedschema) — schema versioning protocol

### Secondary (MEDIUM confidence)

- [Hacking with Swift — SwiftData predicates](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-filter-swiftdata-results-with-predicates) — `localizedStandardContains()` for user-facing search; iOS 17.4+ dynamic predicate combination
- [Hacking with Swift — VersionedSchema migration](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema) — two-version migration setup
- [createwithswift.com — Local notifications with async/await](https://www.createwithswift.com/notifications-tutorial-creating-and-scheduling-user-notifications-with-async-await/) — async throws pattern for notification scheduling
- [tanaschita.com — Notification triggers](https://tanaschita.com/ios-local-notification-triggers/) — calendar and interval trigger patterns
- [Donnywals.com — Daily notifications with DateComponents](https://www.donnywals.com/scheduling-daily-notifications-on-ios-using-calendar-and-datecomponents/) — recurring medication schedule pattern

### Tertiary (LOW confidence — flagged for validation)

- [mertbulan.com — Never use SwiftData without VersionedSchema](https://mertbulan.com/programming/never-use-swiftdata-without-versionedschema) — crash reproduction for unversioned-to-versioned migration; corroborated by Apple Developer Forums thread 761735 and multiple community reports
- [Apple Developer Forums thread 761735](https://developer.apple.com/forums/thread/761735) — "Cannot use staged migration with an unknown model version" crash description; multi-release workaround confirmed
- [GitHub cordova-plugin — 64 notification limit](https://github.com/katzer/cordova-plugin-local-notifications/issues/1525) — 64-slot limit and fetch-nearest-64 workaround; corroborated by Hacking with Swift forums discussion

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — UserNotifications, SwiftData, and SwiftUI are Apple-native frameworks with official documentation
- Architecture — VersionedSchema migration: HIGH — crash confirmed by multiple forum threads + official WWDC session coverage; two-step approach is the documented Apple recommendation
- Architecture — notification patterns: HIGH — UNCalendarNotificationTrigger/UNTimeIntervalNotificationTrigger patterns verified against official Apple documentation
- Pitfalls — PHI in notifications: HIGH — lock screen display is documented iOS behavior
- Pitfalls — 64-notification limit: MEDIUM — limit confirmed by Apple Developer Forums and community; refresh pattern is community-confirmed workaround, not in official docs
- Pitfalls — #Predicate limitations: HIGH — compile-time macro restriction is documented SwiftData behavior

**Research date:** 2026-03-19
**Valid until:** 2026-09-19 (stable Apple frameworks; re-verify if iOS 19 beta changes SwiftData migration behavior)
