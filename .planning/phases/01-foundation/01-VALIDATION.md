---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest + Swift Testing (iOS 17+, Swift 5.9+) |
| **Config file** | None — Wave 0 creates the Xcode project with test target |
| **Quick run command** | `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests/EncryptionTests -only-testing:AgingInPlaceTests/PersistenceTests` |
| **Full suite command** | `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests/EncryptionTests -only-testing:AgingInPlaceTests/PersistenceTests`
- **After every plan wave:** Run `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Before `/gsd:verify-work`:** Full suite must be green + manual Accessibility Inspector audit
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | TEAM-01 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/InviteCodeTests` | Wave 0 | ⬜ pending |
| 01-01-02 | 01 | 1 | TEAM-02 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/InviteFlowTests` | Wave 0 | ⬜ pending |
| 01-01-03 | 01 | 1 | TEAM-03, TEAM-04 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CareTeamTests` | Wave 0 | ⬜ pending |
| 01-01-04 | 01 | 1 | TEAM-05, TEAM-06 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/PermissionTests` | Wave 0 | ⬜ pending |
| 01-01-05 | 01 | 1 | TEAM-07, SYNC-04, SYNC-05, SYNC-08 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/EncryptionTests` | Wave 0 | ⬜ pending |
| 01-01-06 | 01 | 1 | SYNC-01 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/PersistenceTests` | Wave 0 | ⬜ pending |
| 01-01-07 | 01 | 1 | SYNC-03 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/LWWTests` | Wave 0 | ⬜ pending |
| 01-01-08 | 01 | 1 | TEAM-08 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CaregiverHomeTests` | Wave 0 | ⬜ pending |
| 01-01-09 | 01 | 1 | TEAM-09 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/EmergencyContactTests` | Wave 0 | ⬜ pending |
| 01-01-10 | 01 | 1 | SENR-04 | unit + visual | `xcodebuild test ... -only-testing:AgingInPlaceTests/SeniorHomeTests` | Wave 0 | ⬜ pending |
| 01-01-11 | 01 | 1 | SENR-01 | manual | — | manual-only | ⬜ pending |
| 01-01-12 | 01 | 1 | SENR-02 | manual | — | manual-only | ⬜ pending |
| 01-01-13 | 01 | 1 | SENR-03 | manual | — | manual-only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `AgingInPlace.xcodeproj` — Xcode project with iOS 17 deployment target, Swift 6 strict concurrency
- [ ] `AgingInPlaceTests/EncryptionTests.swift` — covers SYNC-04, SYNC-05, SYNC-08, TEAM-07
- [ ] `AgingInPlaceTests/PersistenceTests.swift` — covers SYNC-01; uses in-memory ModelContainer
- [ ] `AgingInPlaceTests/InviteCodeTests.swift` — covers TEAM-01
- [ ] `AgingInPlaceTests/InviteFlowTests.swift` — covers TEAM-02
- [ ] `AgingInPlaceTests/CareTeamTests.swift` — covers TEAM-03, TEAM-04
- [ ] `AgingInPlaceTests/PermissionTests.swift` — covers TEAM-05, TEAM-06
- [ ] `AgingInPlaceTests/EmergencyContactTests.swift` — covers TEAM-09
- [ ] `AgingInPlaceTests/LWWTests.swift` — covers SYNC-03
- [ ] `AgingInPlaceTests/CaregiverHomeTests.swift` — covers TEAM-08
- [ ] `AgingInPlaceTests/SeniorHomeTests.swift` — covers SENR-04

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Touch targets >= 44pt at XXL+ | SENR-01 | Requires Accessibility Inspector frame measurement | Run Accessibility Audit in Xcode (`Product > Accessibility Inspector > Audit`), verify all interactive elements have minHeight >= 44 |
| System colors pass WCAG AAA | SENR-02 | Requires Accessibility Inspector color contrast tool | Use Accessibility Inspector color contrast audit on senior home screen |
| Primary actions reachable in <= 2 taps | SENR-03 | Navigation depth count requires human judgment | From senior home screen, verify each primary action (medications, appointments, vitals, notes) is reachable in at most 2 taps |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
