# Roadmap: Aging in Place — Caregiver Coordination Ecosystem

## Overview

The architecture has hard sequential dependencies that determine phase order: the data model and per-record encryption design must exist before any UI is built; the senior UI must be validated on a single device before sync complexity is introduced; P2P sync must be proven stable before the Watch companion can route inputs through it; HealthKit requires the Watch as the sensor source; and the optional iCloud relay is additive on top of proven P2P. Six phases follow from these constraints — each delivering a coherent, verifiable capability that unblocks the next.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Data model, care team identity, per-record encryption, SwiftData persistence, and senior UI as a first-class design constraint (completed 2026-03-19)
- [ ] **Phase 2: Single-Device UX** - Full senior and caregiver interfaces, medication scheduling, care documentation, mood logging, and shared calendar — all offline-capable on one device
- [ ] **Phase 3: P2P Sync** - Network framework sync engine with LWW merge, actor-isolated SyncCoordinator, and encrypted payloads syncing care logs across devices on the same local network
- [ ] **Phase 4: Apple Watch Companion** - watchOS app for medication confirmation and mood quick-log, WatchConnectivity bridge, HealthKit vitals forwarding, and Watch complication
- [ ] **Phase 5: HealthKit Integration** - Permission onboarding, heart rate / blood oxygen / sleep history display, fall event history surfaced from HealthKit, and synced vitals visible to caregiver
- [ ] **Phase 6: iCloud Relay** - Optional encrypted CloudKit relay for remote caregivers who cannot share physical proximity, with CryptoKit payload encryption before any CloudKit write

## Phase Details

### Phase 1: Foundation
**Goal**: The data model, care team identity, per-record encryption design, and senior UI constraints are locked — every subsequent phase builds on this without requiring architectural rewrites
**Depends on**: Nothing (first phase)
**Requirements**: TEAM-01, TEAM-02, TEAM-03, TEAM-04, TEAM-05, TEAM-06, TEAM-07, TEAM-08, TEAM-09, SYNC-01, SYNC-03, SYNC-04, SYNC-05, SYNC-08, SENR-01, SENR-02, SENR-03, SENR-04
**Success Criteria** (what must be TRUE):
  1. Senior can invite a caregiver via shareable code, the caregiver can accept, and both see each other on the care team list
  2. Senior can grant and revoke per-category access permissions to any care team member, and revoked access prevents reading newly created records in that category
  3. A care record written on one device is readable after the app is force-quit and relaunched (explicit SwiftData save confirmed working)
  4. The senior-facing home screen renders at Dynamic Type XXL+ with all touch targets at minimum 44pt and passes WCAG AAA contrast check
  5. Encryption key rotation is triggered on permission revocation — new records use the rotated key and revoked members cannot decrypt them
**Plans:** 5/5 plans complete

Plans:
- [x] 01-01-PLAN.md — Xcode project setup, SwiftData models, encryption/keychain services, and foundational unit tests
- [x] 01-02-PLAN.md — Care team invite/join flow, team list, and member removal
- [x] 01-03-PLAN.md — Per-category permission management with key rotation
- [x] 01-04-PLAN.md — Senior and caregiver home screens, emergency contacts, role-based navigation
- [x] 01-05-PLAN.md — Integration test suite and visual verification checkpoint

### Phase 2: Single-Device UX
**Goal**: A solo user (either senior or caregiver) can complete every primary care workflow — medication logging, visit notes, mood logging, care history browsing, and shared calendar — entirely offline on a single device
**Depends on**: Phase 1
**Requirements**: MEDS-01, MEDS-02, MEDS-04, MEDS-05, CARE-01, CARE-02, CARE-03, CARE-04, CARE-05, CALR-01, CALR-02, CALR-03
**Success Criteria** (what must be TRUE):
  1. Caregiver can log a medication administration and view the full medication history with timestamps and who administered each dose
  2. Senior receives a local push notification when a scheduled medication is due, and caregiver receives a notification when that medication is not confirmed within the configured window
  3. Caregiver can log a care visit with structured fields (meals, mobility, observations, concerns), and the entry appears in the care history browsable by category, date, and author
  4. Senior can self-report mood and caregiver can log observed mood; both entries appear in the care history with distinct authorship
  5. Caregiver can create a shared appointment, view it on the care calendar, and receive a local notification reminder before the appointment
**Plans:** 2/5 plans executed

Plans:
- [ ] 02-01-PLAN.md — VersionedSchema migration, Phase 2 SwiftData models, NotificationService, and entitlements
- [ ] 02-02-PLAN.md — Medication logging, schedule creation, history, and missed-dose alerting
- [ ] 02-03-PLAN.md — Care visit logging and mood logging with encrypted storage
- [ ] 02-04-PLAN.md — Shared care calendar with appointment reminders
- [ ] 02-05-PLAN.md — Unified care history with filtering/search and home screen wiring

### Phase 3: P2P Sync
**Goal**: Two or more iOS devices on the same local network automatically discover each other and sync care logs without any manual pairing — all care entries written offline appear on peer devices the next time they are in proximity
**Depends on**: Phase 1
**Requirements**: SYNC-02
**Success Criteria** (what must be TRUE):
  1. Two devices on the same Wi-Fi network discover each other automatically and sync care logs written offline without any user action beyond being present on the network
  2. Care records written simultaneously on two devices (simulated concurrent offline edits) merge without data loss when the devices reconnect — no duplicate entries, no lost entries
  3. The app displays "Last synced [time]" status, never blocks UI on sync completion, and handles device backgrounding gracefully by resuming sync on next foreground connection
**Plans**: TBD

### Phase 4: Apple Watch Companion
**Goal**: The senior can confirm a medication taken or log their mood in two taps from the wrist — Watch inputs flow through WatchConnectivity to the iPhone and into the care log visible to the whole care team
**Depends on**: Phase 3
**Requirements**: MEDS-03, WTCH-01, WTCH-02, WTCH-03, WTCH-04, WTCH-05
**Success Criteria** (what must be TRUE):
  1. Senior can confirm a medication taken from the Apple Watch in 2 taps, and the confirmation appears in the medication history on the paired iPhone
  2. Senior can self-report mood from the Apple Watch, and the mood entry syncs to the iPhone care log
  3. The Watch complication shows the next upcoming medication and updates when schedules change
  4. Heart rate and blood oxygen readings collected on the Watch are forwarded to the iPhone app and available to the HealthKit integration in Phase 5
**Plans**: TBD

### Phase 5: HealthKit Integration
**Goal**: Caregiver can view the senior's vital sign history and any recorded fall events from the care team's devices — with senior explicit consent for every data type shared
**Depends on**: Phase 4
**Requirements**: HLTH-01, HLTH-02, HLTH-03, HLTH-04, HLTH-05, HLTH-06
**Success Criteria** (what must be TRUE):
  1. Senior goes through an explicit HealthKit permission onboarding screen that names each data type being requested and why; the app shows a clear empty state with "Enable in Settings" if permission is denied
  2. Caregiver can view a summary of the senior's heart rate, blood oxygen, and sleep data on their own device, stamped with the last-updated time
  3. Historical fall detection events from the senior's Apple Watch appear in the care log as timestamped entries visible to permitted care team members
**Plans**: TBD

### Phase 6: iCloud Relay
**Goal**: A remote caregiver who has never shared physical proximity with the senior's iPhone can still receive synced care logs via an optional encrypted CloudKit relay that the senior explicitly opts into
**Depends on**: Phase 3
**Requirements**: SYNC-06, SYNC-07
**Success Criteria** (what must be TRUE):
  1. Senior can opt in to the iCloud relay from Settings; the onboarding screen explains what is stored, where, and how it is encrypted — and prominently surfaces the iCloud Advanced Data Protection setting
  2. A caregiver on a different home network receives care logs synced via the relay within a reasonable delay after they are created, without any PHI stored in plaintext on any Apple server
  3. Disabling the relay on the senior's device stops future remote sync while leaving P2P sync between co-located devices unaffected
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 5/5 | Complete   | 2026-03-19 |
| 2. Single-Device UX | 2/5 | In Progress|  |
| 3. P2P Sync | 0/TBD | Not started | - |
| 4. Apple Watch Companion | 0/TBD | Not started | - |
| 5. HealthKit Integration | 0/TBD | Not started | - |
| 6. iCloud Relay | 0/TBD | Not started | - |
