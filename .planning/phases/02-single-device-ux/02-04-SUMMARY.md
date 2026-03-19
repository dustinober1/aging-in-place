---
phase: 02-single-device-ux
plan: 04
subsystem: calendar
tags: [swiftui, swiftdata, calendar, notifications, cryptokit, tdd, swift6]

requires:
  - phase: 02-single-device-ux
    plan: 01
    provides: "CalendarEvent SwiftData model; NotificationService.scheduleAppointmentReminder / cancelAppointmentReminder; EncryptionService.seal/.open for .calendar category"

provides:
  - "CareCalendarView: shared care calendar with Upcoming/Past sections, swipe-to-delete with notification cancellation, ContentUnavailableView empty state"
  - "AddEventView: appointment creation form with title/date/location/notes/attendees, PermissionCategory.calendar AES-GCM encryption, local reminder notification scheduling"
  - "CalendarTests: 4 unit tests covering round-trip persistence, chronological sort, payload decryption, and deletion"

affects:
  - 02-single-device-ux (CALR-01, CALR-02, CALR-03 completed)
  - future phases using CalendarEvent model

tech-stack:
  added: []
  patterns:
    - "CalendarEvent payload: {location, notes, attendees} JSON sealed with EncryptionService.seal(.calendar) — title and eventDate left plaintext for notification title and predicate filtering"
    - "Notification scheduling: fire-and-forget Task { try? await NotificationService.scheduleAppointmentReminder(for:) } from AddEventView.saveEvent()"
    - "Notification cancellation: synchronous NotificationService.cancelAppointmentReminder(for:) called before modelContext.delete in swipe-to-delete handler"
    - "Preview fix: .modelContainer(for: Schema(...), inMemory:) overload does not exist — use manually constructed ModelContainer with migrationPlan"

key-files:
  created:
    - AgingInPlace/Features/Calendar/CareCalendarView.swift
    - AgingInPlace/Features/Calendar/AddEventView.swift
    - AgingInPlaceTests/CalendarTests.swift
  modified:
    - AgingInPlace/Features/CareVisit/LogCareVisitView.swift

key-decisions:
  - "Notification scheduling in AddEventView uses Task { try? await ... } — fire-and-forget is appropriate; if it fails the event is already saved and user can reschedule"
  - "Attendees parsed from comma-separated TextField in AddEventView — stored as [String] in encrypted JSON payload, matching CalendarEvent model design"
  - "CareCalendarView uses now: Date { Date() } computed property for section partitioning — evaluated at body render time, no state needed"
  - "createdByMemberID uses placeholder UUID() in AddEventView — real implementation requires AppStorage memberID from onboarding (same pattern as CaregiverHomeView)"

requirements-completed: [CALR-01, CALR-02, CALR-03]

duration: 7min
completed: 2026-03-19
---

# Phase 2 Plan 04: Shared Care Calendar with Encrypted Payloads and Notification Wiring Summary

**CareCalendarView (Upcoming/Past sections, swipe-to-delete with notification cancellation) and AddEventView (AES-GCM encrypted {location, notes, attendees} payload, local reminder scheduling) with 4 CalendarTests covering persistence, sort, decryption, and deletion**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-19T13:02:54Z
- **Completed:** 2026-03-19T13:10:00Z
- **Tasks:** 1
- **Files modified:** 4

## Accomplishments

- CareCalendarView with @Query sorted by eventDate ascending, Upcoming/Past sections, swipe-to-delete that cancels notification before removing event, ContentUnavailableView for empty state, and + toolbar navigating to AddEventView
- AddEventView with five form fields across three sections (Appointment/Details/Reminder), AES-GCM encryption of {location, notes, attendees} JSON before SwiftData insert, and fire-and-forget Task for notification scheduling
- 4 CalendarTests: round-trip persistence, chronological sort via SortDescriptor, payload decryption verifying all three encrypted fields, and deletion confirms empty store
- 16 tests passing (4 calendar + 12 notification service), zero regressions

## Task Commits

1. **TDD RED: CalendarTests with 4 failing tests** - `3691a4c` (test)
2. **TDD GREEN: CareCalendarView, AddEventView, LogCareVisitView fix** - `2e884d0` (feat)

**Plan metadata:** (docs commit — recorded after summary)

## Files Created/Modified

- `AgingInPlace/Features/Calendar/CareCalendarView.swift` - Shared care calendar with Upcoming/Past sections, swipe-to-delete, empty state, + toolbar
- `AgingInPlace/Features/Calendar/AddEventView.swift` - Appointment creation form with title/date/location/notes/attendees, encryption, notification scheduling
- `AgingInPlaceTests/CalendarTests.swift` - 4 unit tests: round-trip, sort, decryption, deletion
- `AgingInPlace/Features/CareVisit/LogCareVisitView.swift` - Fixed #Preview to use manually constructed ModelContainer (pre-existing blocking build error)

## Decisions Made

- **Notification fire-and-forget:** `Task { try? await NotificationService.scheduleAppointmentReminder(for:) }` called after successful save — if scheduling fails, the event record is still persisted and the user can reschedule. This avoids blocking the dismiss animation on a permission error.
- **Attendee parsing:** Comma-separated TextField in AddEventView; split/trim/filter into `[String]` array stored in the encrypted JSON payload — matches the CalendarEvent model's `encryptedPayload` contract from Plan 01.
- **createdByMemberID placeholder:** Uses `UUID()` in AddEventView — same deferred-until-onboarding pattern as CaregiverHomeView.caregiverMemberIDString.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] LogCareVisitView.swift #Preview used invalid `.modelContainer(for: Schema(...), inMemory:)` overload**
- **Found during:** Task 1 (build verification after creating Calendar views)
- **Issue:** `LogCareVisitView.swift` (from Plan 03) had `#Preview { .modelContainer(for: Schema(AgingInPlaceSchemaV2.models), inMemory: true) }` — this overload does not exist; xcodebuild reported "No exact matches in call to instance method 'modelContainer'" and failed the build
- **Fix:** Replaced with manually constructed `ModelContainer` using `Schema(AgingInPlaceSchemaV2.models)` + `migrationPlan:` init, then `.modelContainer(container:)`
- **Files modified:** AgingInPlace/Features/CareVisit/LogCareVisitView.swift
- **Verification:** BUILD SUCCEEDED after fix
- **Committed in:** 2e884d0 (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (blocking)
**Impact on plan:** Required for compilation. No scope creep.

## Issues Encountered

- Transient simulator crash (signal kill) on first test run after project regeneration — re-running without changes resolved it (same pattern documented in Plan 01)

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- CareCalendarView and AddEventView are complete and ready for integration into the home tab navigation
- CALR-01, CALR-02, CALR-03 requirements fully satisfied
- All Phase 2 feature UI (medications, care visits, mood, calendar) is now built
- Ready for 02-05 integration plan to wire all features into the tab navigation

## Self-Check: PASSED

All 4 key files exist on disk. Both task commits (3691a4c, 2e884d0) verified in git log. Calendar + NotificationService tests: 16 tests, 0 failures.

---
*Phase: 02-single-device-ux*
*Completed: 2026-03-19*
