---
phase: 01-foundation
plan: "02"
subsystem: ui
tags: [swiftui, swiftdata, careteam, invite, ios, swift6]

# Dependency graph
requires:
  - phase: 01-foundation plan 01
    provides: "SwiftData models: InviteCode, CareTeamMember, CareCircle, MemberRole, PermissionCategory"
provides:
  - InviteCodeGenerator: offline "CARE-XXXX-XXXX" code generation from UUID hex
  - InviteFlowView: senior invite screen with code display, Copy, Share, Generate New buttons
  - JoinCircleView: caregiver join screen with code entry, role picker, display name, error states
  - PendingRequestView: senior approval screen with approve/reject for pending members
  - CareTeamListView: member list with role labels, swipe-to-delete confirmation, ContentUnavailableView empty state
  - 10 unit tests covering invite code format, invite flow logic, and care team persistence
affects:
  - 01-03: senior UI integrates CareTeamListView into home screen
  - 01-05: CareTeamListView member removal will trigger key rotation for ALL categories (placeholder wired, rotation deferred to Plan 05)
  - 01-integration: CareTeamListView NavigationLink placeholder replaced with MemberDetailView

# Tech tracking
tech-stack:
  added:
    - ShareLink (SwiftUI) — share sheet for invite code
    - UIPasteboard — clipboard copy for invite code
    - ContentUnavailableView — empty state for no team members
  patterns:
    - InviteCodeGenerator.generate() uses UUID hex prefix — offline, no server, format CARE-XXXX-XXXX
    - JoinCircleView validates code via SwiftData FetchDescriptor predicate before accepting
    - CareTeamListView uses @Query for live SwiftData updates without manual refresh
    - PendingRequestView approves by setting grantedCategories = PermissionCategory.allCases
    - Swipe-to-delete uses confirmationDialog before context.delete — prevents accidental removal

key-files:
  created:
    - AgingInPlace/Features/CareTeam/InviteCodeGenerator.swift
    - AgingInPlace/Features/CareTeam/InviteFlowView.swift
    - AgingInPlace/Features/CareTeam/JoinCircleView.swift
    - AgingInPlace/Features/CareTeam/PendingRequestView.swift
    - AgingInPlace/Features/CareTeam/CareTeamListView.swift
    - AgingInPlaceTests/InviteCodeTests.swift
    - AgingInPlaceTests/InviteFlowTests.swift
    - AgingInPlaceTests/CareTeamTests.swift
  modified:
    - AgingInPlace.xcodeproj/project.pbxproj

key-decisions:
  - "InviteCodeGenerator.generate() takes UUID hex prefix (no dashes), uppercased, split 4+4 — offline uniqueness from UUID entropy"
  - "CareTeamListView NavigationLink uses placeholder Text('Member Detail') — MemberDetailView created in Plan 03, wired in Plan 05 integration"
  - "Member removal in CareTeamListView defers key rotation to Plan 05 — comment in code documents the integration point"
  - "JoinCircleView validates code by FetchDescriptor predicate lookup before insert — single-use enforced at data layer"

patterns-established:
  - "Pattern: FetchDescriptor predicate lookup for single-use code validation — re-use in any single-use token flow"
  - "Pattern: confirmationDialog before context.delete on swipe — required for all destructive member actions"
  - "Pattern: ShareLink(item: String) for system share sheet — standard iOS sharing without custom implementation"

requirements-completed:
  - TEAM-01
  - TEAM-02
  - TEAM-03
  - TEAM-04

# Metrics
duration: 10min
completed: "2026-03-18"
---

# Phase 1 Plan 02: Care Team Invite and Join Summary

**Offline invite code generation (CARE-XXXX-XXXX) with SwiftUI invite/join/approve/list/remove flows and 10 unit tests covering code format, single-use enforcement, and member persistence**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-19T02:21:22Z
- **Completed:** 2026-03-19T02:31:30Z
- **Tasks:** 2 completed
- **Files modified:** 9

## Accomplishments

- InviteCodeGenerator produces offline alphanumeric "CARE-XXXX-XXXX" codes using UUID hex prefix; 3 tests verify format, length, and uniqueness
- Complete invite/join/approve/remove UI flow: InviteFlowView, JoinCircleView, PendingRequestView, CareTeamListView — all with 44pt touch targets and system colors
- 4 InviteFlowTests cover create/accept/single-use/nonexistent code scenarios using in-memory ModelContainer with explicit context.save()
- 3 CareTeamTests cover add/remove member persistence and role display from MemberRole.displayName

## Task Commits

Each task was committed atomically:

1. **Task 1: Invite code generator and join flow logic with tests (TDD)** - `11814fe` (test+feat)
2. **Task 2: Care team UI views — invite, join, pending requests, team list, remove** - `0fc9459` (feat)

## Files Created/Modified

- `AgingInPlace/Features/CareTeam/InviteCodeGenerator.swift` - Static generate() producing CARE-XXXX-XXXX from UUID hex
- `AgingInPlace/Features/CareTeam/InviteFlowView.swift` - Senior invite screen: code display, Copy, Share, Generate New
- `AgingInPlace/Features/CareTeam/JoinCircleView.swift` - Caregiver join screen: code entry (auto-uppercase), role picker, display name, error states
- `AgingInPlace/Features/CareTeam/PendingRequestView.swift` - Senior approval: approve (grants all 4 categories) or reject (deletes member)
- `AgingInPlace/Features/CareTeam/CareTeamListView.swift` - Member list: role labels, NavigationLink placeholder, swipe-to-delete confirmation, ContentUnavailableView empty state
- `AgingInPlaceTests/InviteCodeTests.swift` - 3 code format/length/uniqueness tests
- `AgingInPlaceTests/InviteFlowTests.swift` - 4 create/accept/single-use/nonexistent-code tests
- `AgingInPlaceTests/CareTeamTests.swift` - 3 add/remove/role-display tests

## Decisions Made

- `InviteCodeGenerator.generate()` uses UUID hex prefix (not random chars) — UUID provides guaranteed uniqueness without a counter or server
- `CareTeamListView` NavigationLink targets `Text("Member Detail")` as placeholder — MemberDetailView is Plan 03's output, integration is Plan 05
- Member removal comment documents the key rotation integration point for Plan 05 — avoids silent omission
- `JoinCircleView` validates code via `FetchDescriptor` predicate before accepting — data-layer single-use enforcement, not UI-layer

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed invalid MemberRole.caregiver in PermissionTests.swift**
- **Found during:** Task 1 (running tests — compile error in PermissionTests blocked test execution)
- **Issue:** PermissionTests.swift used `.caregiver` which is not a MemberRole case (valid cases: family, paidAide, nurse, doctor, other)
- **Fix:** Replaced all 5 occurrences of `.caregiver` with `.paidAide` — semantically equivalent for permission tests
- **Files modified:** AgingInPlaceTests/PermissionTests.swift
- **Verification:** Build succeeds, PermissionTests.swift compiles cleanly
- **Committed in:** 11814fe (Task 1 commit — already committed in prior Plan 03 execution)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Necessary to unblock compilation. No scope creep.

## Issues Encountered

- PermissionTests.swift from a concurrent Plan 03 execution had an invalid `.caregiver` role reference — auto-fixed per Rule 1 before running targeted tests

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Care team invite/join/approve/list/remove flows complete and tested
- InviteCodeGenerator ready for use from any part of the app
- CareTeamListView integrated into senior home screen (Plan 03 responsibility)
- MemberDetailView (Plan 03) placeholder NavigationLink destination ready for replacement in Plan 05 integration
- Key rotation on member removal documented as a Plan 05 integration point

---
*Phase: 01-foundation*
*Completed: 2026-03-18*

## Self-Check: PASSED

- All 8 production and test files: FOUND
- SUMMARY.md: FOUND
- Task 1 commit (11814fe): FOUND
- Task 2 commit (0fc9459): FOUND
- xcodebuild test InviteCodeTests + InviteFlowTests + CareTeamTests: 10/10 pass, 0 failures
