---
phase: 2
slug: single-device-ux
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing from Phase 1) |
| **Config file** | None — existing Xcode project with AgingInPlaceTests target |
| **Quick run command** | `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests` |
| **Full suite command** | `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests/SchemaMigrationTests -only-testing:AgingInPlaceTests/NotificationServiceTests`
- **After every plan wave:** Run `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 0 | Schema migration | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/SchemaMigrationTests` | Wave 0 | ⬜ pending |
| 2-02-01 | 02 | 1 | MEDS-01 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/MedicationTests` | Wave 0 | ⬜ pending |
| 2-02-02 | 02 | 1 | MEDS-04 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/MedicationTests` | Wave 0 | ⬜ pending |
| 2-02-03 | 02 | 1 | MEDS-02 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/NotificationServiceTests` | Wave 0 | ⬜ pending |
| 2-02-04 | 02 | 1 | MEDS-05 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/NotificationServiceTests` | Wave 0 | ⬜ pending |
| 2-03-01 | 03 | 1 | CARE-01 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CareVisitTests` | Wave 0 | ⬜ pending |
| 2-03-02 | 03 | 1 | CARE-02 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/MoodTests` | Wave 0 | ⬜ pending |
| 2-03-03 | 03 | 1 | CARE-03 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/MoodTests` | Wave 0 | ⬜ pending |
| 2-03-04 | 03 | 1 | CARE-04 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CareHistoryTests` | Wave 0 | ⬜ pending |
| 2-03-05 | 03 | 1 | CARE-05 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CareHistoryTests` | Wave 0 | ⬜ pending |
| 2-04-01 | 04 | 1 | CALR-01 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CalendarTests` | Wave 0 | ⬜ pending |
| 2-04-02 | 04 | 1 | CALR-02 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CalendarTests` | Wave 0 | ⬜ pending |
| 2-04-03 | 04 | 1 | CALR-03 | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/NotificationServiceTests` | Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `AgingInPlaceTests/SchemaMigrationTests.swift` — verifies V1→V2 migration
- [ ] `AgingInPlaceTests/MedicationTests.swift` — covers MEDS-01, MEDS-04
- [ ] `AgingInPlaceTests/NotificationServiceTests.swift` — covers MEDS-02, MEDS-05, CALR-03
- [ ] `AgingInPlaceTests/CareVisitTests.swift` — covers CARE-01
- [ ] `AgingInPlaceTests/MoodTests.swift` — covers CARE-02, CARE-03
- [ ] `AgingInPlaceTests/CareHistoryTests.swift` — covers CARE-04, CARE-05
- [ ] `AgingInPlaceTests/CalendarTests.swift` — covers CALR-01, CALR-02
- [ ] `AgingInPlace/Models/Schema/AgingInPlaceSchemaV1.swift` — wraps Phase 1 models
- [ ] `AgingInPlace/Models/Schema/AgingInPlaceSchemaV2.swift` — adds Phase 2 models
- [ ] `AgingInPlace/Notifications/NotificationService.swift`
- [ ] `com.apple.developer.usernotifications.time-sensitive` entitlement

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Local push notification appears on screen | MEDS-02 | UNUserNotificationCenter delivery not observable in unit tests | Schedule notification, background app, verify banner in Simulator |
| Missed-dose notification fires after window | MEDS-05 | Requires real-time delay | Schedule dose, wait past window, verify notification in Simulator |
| Calendar appointment reminder notification | CALR-03 | Real notification delivery | Create appointment, verify reminder notification in Simulator |
| Lock screen does not show PHI | All | Visual inspection | Check notification content on lock screen shows generic text only |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
