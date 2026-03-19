---
phase: 01-foundation
plan: "04"
subsystem: ui
tags: [swiftui, swiftdata, ios, swift6, accessibility, seniorui, wcag, viewthatfits]

# Dependency graph
requires:
  - phase: 01-foundation plan 01
    provides: SwiftData models (CareCircle, CareTeamMember, CareRecord, EmergencyContact), A11y constants, RootView placeholder

provides:
  - SeniorHomeView: personalized greeting + 4 summary cards (Medications, Mood, Care Team, Calendar)
  - SummaryCardView: reusable 44pt tappable card with ViewThatFits for AX text sizes, system colors
  - CaregiverHomeView: recent activity feed filtered by granted categories + quick action grid
  - EmergencyContactListView: CRUD list with tap-to-call and swipe-to-delete, no permission gating
  - EmergencyContactFormView: add/edit form with name+phone validation
  - RootView: role-based routing to senior or caregiver home screen
  - 12 new unit tests: EmergencyContactTests, SeniorHomeTests, CaregiverHomeTests

affects:
  - 01-02: care team join flow needs to set caregiverName/caregiverMemberID in AppStorage
  - 01-05: permission revocation UI adds to CareTeamMember detail (not yet built)
  - Phase 2: Medications, Mood, Calendar detail screens behind placeholder NavigationLinks

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ViewThatFits to switch HStack->VStack at AX text sizes — per-card pattern for all senior UI
    - A11y.minTouchTarget (44pt) enforced via .frame(minHeight:) on all tappable elements
    - System colors only (Color.primary, Color.secondary, Color.accentColor, uiColor .secondarySystemBackground) — no custom palette
    - @Query with sort: SortDescriptor(\.lastModified, order: .reverse) for activity feeds
    - AppStorage for userRole (senior/caregiver) routing, caregiverName for display
    - ContentUnavailableView for all empty states
    - Permission filtering via Set<PermissionCategory>.contains() — pure client-side, no DB predicate

key-files:
  created:
    - AgingInPlace/Features/SeniorHome/SeniorHomeView.swift
    - AgingInPlace/Features/SeniorHome/SummaryCardView.swift
    - AgingInPlace/Features/CaregiverHome/CaregiverHomeView.swift
    - AgingInPlace/Features/EmergencyContacts/EmergencyContactListView.swift
    - AgingInPlace/Features/EmergencyContacts/EmergencyContactFormView.swift
    - AgingInPlaceTests/EmergencyContactTests.swift
    - AgingInPlaceTests/SeniorHomeTests.swift
    - AgingInPlaceTests/CaregiverHomeTests.swift
  modified:
    - AgingInPlace/App/RootView.swift

key-decisions:
  - "greetingForTimeOfDay exposed as internal method on SeniorHomeView for direct unit-test access without needing a ModelContainer"
  - "PlaceholderDetailView placed in SeniorHomeView.swift as a private-to-file struct — Phase 2 will replace NavigationLink destinations"
  - "CaregiverHomeView reads caregiverMemberID from AppStorage and filters allRecords client-side — avoids SwiftData predicate with UUID join"
  - "EmergencyContactListView uses @Query sort by name (alphabetical) — no permission filter per user decision (always accessible)"

patterns-established:
  - "Pattern: ViewThatFits(in: .horizontal) — HStack first, VStack fallback — standard for all senior-facing cards"
  - "Pattern: @Query + client-side Set.contains filter for permission gating — no SwiftData predicate complexity"
  - "Pattern: PlaceholderDetailView for Phase 2 navigation destinations — keeps NavigationLink valid without real destinations"

requirements-completed:
  - SENR-01
  - SENR-02
  - SENR-03
  - SENR-04
  - TEAM-08
  - TEAM-09

# Metrics
duration: 12min
completed: "2026-03-18"
---

# Phase 1 Plan 04: Home Screens and Emergency Contacts Summary

**Senior home with 44pt accessible cards using ViewThatFits, role-based navigation, caregiver activity feed filtered by granted categories, and emergency contact CRUD accessible to all care team members**

## Performance

- **Duration:** 12 min
- **Started:** 2026-03-18T22:21:30Z
- **Completed:** 2026-03-18T22:33:41Z
- **Tasks:** 2 completed
- **Files modified:** 9

## Accomplishments

- SeniorHomeView with personalized time-of-day greeting and 4 accessibility-first summary cards (SENR-01, SENR-02, SENR-04)
- SummaryCardView using ViewThatFits to switch horizontal/vertical layout at AX text sizes — all touch targets 44pt+ with system colors only (SENR-03)
- CaregiverHomeView with @Query sorted activity feed filtered client-side by granted permission categories (TEAM-08)
- EmergencyContactListView with no permission gating (TEAM-09), tap-to-call via tel: URL, swipe-to-delete
- EmergencyContactFormView with name+phone validation, explicit context.save()
- 12 new unit tests: 4 EmergencyContactTests, 5 SeniorHomeTests, 3 CaregiverHomeTests — all pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Senior home, caregiver home, emergency contacts, role routing** - `fbabbe8` (feat)
2. **Task 2: Unit tests for emergency contacts, senior home, caregiver home** - `825cbd0` (test)

**Plan metadata:** committed with SUMMARY.md, STATE.md, ROADMAP.md (docs)

## Files Created/Modified

- `AgingInPlace/Features/SeniorHome/SeniorHomeView.swift` - Greeting header + 4 SummaryCardView instances, toolbar emergency contacts shortcut
- `AgingInPlace/Features/SeniorHome/SummaryCardView.swift` - Reusable 44pt card with ViewThatFits HStack/VStack, system colors, accessibility labels
- `AgingInPlace/Features/CaregiverHome/CaregiverHomeView.swift` - Recent activity feed filtered by granted categories, quick action grid
- `AgingInPlace/Features/EmergencyContacts/EmergencyContactListView.swift` - List with tap-to-call, swipe-to-delete, add button
- `AgingInPlace/Features/EmergencyContacts/EmergencyContactFormView.swift` - Add/edit form with name+phone validation and explicit save
- `AgingInPlace/App/RootView.swift` - Updated to route to SeniorHomeView or CaregiverHomeView by role
- `AgingInPlaceTests/EmergencyContactTests.swift` - 4 persistence and no-gating tests
- `AgingInPlaceTests/SeniorHomeTests.swift` - 5 greeting and card category tests
- `AgingInPlaceTests/CaregiverHomeTests.swift` - 3 sort and filter tests

## Decisions Made

- `greetingForTimeOfDay(hour:)` takes an optional `Int` parameter so unit tests can inject specific hours without needing system time — no test framework mocking required
- `PlaceholderDetailView` placed in `SeniorHomeView.swift` to keep NavigationLink valid until Phase 2 builds real destinations
- Caregiver permission filtering is client-side (`Set<PermissionCategory>.contains`) rather than a SwiftData predicate to avoid UUID join complexity — performance is acceptable at Phase 1 scale
- EmergencyContactListView sorts contacts alphabetically by name — simpler and more useful for emergency reference than chronological order

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Pre-existing PermissionTests.swift used MemberRole.caregiver which does not exist**
- **Found during:** Task 2 verification (test compilation)
- **Issue:** PermissionTests.swift referenced `.caregiver` but MemberRole has `.family`, `.paidAide`, `.nurse`, `.doctor`, `.other` — compilation error blocking all tests
- **Fix:** The file was auto-corrected by the linter (all `.caregiver` replaced with `.paidAide`) before our test run — verified the fix
- **Files modified:** `AgingInPlaceTests/PermissionTests.swift`
- **Verification:** xcodebuild test succeeds, all 12 new tests pass
- **Committed in:** `825cbd0` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (pre-existing bug in test file)
**Impact on plan:** Necessary for test compilation. No scope creep.

## Issues Encountered

- PermissionTests.swift (written in a prior plan) referenced a non-existent `MemberRole.caregiver` case. Linter auto-corrected to `.paidAide` before test execution. No functional impact.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Senior and caregiver home screens are complete and functional shells
- EmergencyContact CRUD is fully working (Plan 02 can rely on it)
- NavigationLink destinations are placeholders — Plan 02 (care team) and Phase 2 (medications, mood, calendar) will replace them
- `caregiverName` and `caregiverMemberID` in AppStorage need to be populated by Plan 02's invite/join flow
- 25 total unit tests passing (13 from Plan 01 + 12 from Plan 04)

---
*Phase: 01-foundation*
*Completed: 2026-03-18*

## Self-Check: PASSED

- `AgingInPlace/Features/SeniorHome/SeniorHomeView.swift`: FOUND
- `AgingInPlace/Features/SeniorHome/SummaryCardView.swift`: FOUND
- `AgingInPlace/Features/CaregiverHome/CaregiverHomeView.swift`: FOUND
- `AgingInPlace/Features/EmergencyContacts/EmergencyContactListView.swift`: FOUND
- `AgingInPlace/Features/EmergencyContacts/EmergencyContactFormView.swift`: FOUND
- `AgingInPlace/App/RootView.swift`: FOUND (modified)
- `AgingInPlaceTests/EmergencyContactTests.swift`: FOUND
- `AgingInPlaceTests/SeniorHomeTests.swift`: FOUND
- `AgingInPlaceTests/CaregiverHomeTests.swift`: FOUND
- Task 1 commit `fbabbe8`: FOUND
- Task 2 commit `825cbd0`: FOUND
- 12 tests: ALL PASSED
