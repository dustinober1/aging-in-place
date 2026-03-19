---
phase: 01-foundation
plan: "03"
subsystem: care-team-permissions
tags: [swiftui, swiftdata, encryption, key-rotation, permissions, ios, swift6]

# Dependency graph
requires:
  - 01-01: EncryptionService.rotateKey, CareTeamMember.grantedCategories, PermissionCategory, A11y constants
provides:
  - MemberDetailView with permission toggles and remove flow
  - PermissionToggleRow with undo toast and background key rotation
  - PermissionTests: 7 tests covering TEAM-05, TEAM-06, TEAM-07
affects:
  - 01-04: caregiver home uses grantedCategories to filter visible data categories
  - 01-05: permission revocation UI is now established; 01-05 adds invite/join flow

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Binding wrapping grantedCategories array for toggle state — no separate @State needed"
    - "3-second Task.sleep undo window before key rotation — cancellable on undo tap"
    - "confirmationDialog on destructive remove — rotate keys for all previously-granted categories"
    - "Proxy guard in MemberDetailView — proxy removal blocked until new proxy designated"

key-files:
  created:
    - AgingInPlace/Features/CareTeam/MemberDetailView.swift
    - AgingInPlace/Features/CareTeam/PermissionToggleRow.swift
    - AgingInPlaceTests/PermissionTests.swift
  modified: []

key-decisions:
  - "3-second undo window before key rotation fires in background Task — matches iOS Mail delete pattern"
  - "Toggle binding reads grantedCategories.contains(category) — no separate isGranted @State avoids sync bugs"
  - "Remove flow captures categoriesToRotate before deletion — prevents use-after-free on deleted member"
  - "Proxy removal blocked via info row — senior must designate new proxy before removing current proxy"

# Metrics
duration: 8min
completed: "2026-03-18"
---

# Phase 1 Plan 03: Permission Management Summary

**Per-category permission toggles with 3-second undo toast and background key rotation on revocation**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-19T02:21:20Z
- **Completed:** 2026-03-19T02:28:49Z
- **Tasks:** 2 completed
- **Files created:** 3

## Accomplishments

- PermissionTests.swift: 7 tests covering all 6 behaviors (default 4 categories, grant, revoke, revoke-last, idempotent grant, grant-after-revoke, and key rotation TEAM-07 proof)
- PermissionToggleRow: toggle bound directly to `grantedCategories`, revoke shows `UndoToastView` for 3 seconds, if not undone fires `EncryptionService.rotateKey` in background Task
- MemberDetailView: header with proxy badge, "Can see:" section with 4 toggle rows, destructive remove with `confirmationDialog`, rotates keys for all previously-granted categories on remove
- All controls meet 44pt minimum touch target via `A11y.minTouchTarget`
- Build: `** BUILD SUCCEEDED **` with zero warnings; 7/7 permission tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Permission grant/revoke logic with key rotation tests** - `caf14ca` (test)
2. **Task 2: Member detail view with permission toggles and undo toast** - `5c68c30` (feat)

## Files Created

- `AgingInPlace/Features/CareTeam/MemberDetailView.swift` - Member detail with header, permission toggles, proxy guard, remove confirmation
- `AgingInPlace/Features/CareTeam/PermissionToggleRow.swift` - Toggle row with undo toast and background key rotation
- `AgingInPlaceTests/PermissionTests.swift` - 7 unit tests for TEAM-05/06/07

## Decisions Made

- Toggle binding reads `member.grantedCategories.contains(category)` live — no separate `@State` needed, eliminates sync bugs
- `rotationTask` stored as `@State var rotationTask: Task<Void, Never>?` — enables cancellation on undo tap
- `removeMember()` captures `categoriesToRotate` before `modelContext.delete(member)` — SwiftData deletes object immediately, captured array survives
- Proxy members display informational text instead of remove button — enforces business rule that proxy must be replaced before removal

## Deviations from Plan

None — plan executed exactly as written. The linter auto-corrected `.caregiver` to `.paidAide` in test roles (correct per MemberRole enum, no functional impact).

## Self-Check: PASSED

- `AgingInPlace/Features/CareTeam/MemberDetailView.swift`: FOUND
- `AgingInPlace/Features/CareTeam/PermissionToggleRow.swift`: FOUND
- `AgingInPlaceTests/PermissionTests.swift`: FOUND
- Task 1 commit caf14ca: FOUND
- Task 2 commit 5c68c30: FOUND
- xcodebuild build: BUILD SUCCEEDED
- xcodebuild test PermissionTests: 7/7 PASSED
