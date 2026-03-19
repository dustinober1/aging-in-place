# Pitfalls Research

**Domain:** Local-first P2P sync, senior care caregiver coordination, iOS/watchOS native
**Researched:** 2026-03-18
**Confidence:** HIGH (multiple authoritative sources; Apple documentation, peer-reviewed UX research, Ink & Switch original local-first research)

---

## Critical Pitfalls

### Pitfall 1: Multipeer Connectivity Has No Background Mode — Sessions Silently Drop

**What goes wrong:**
When any device goes to the background (user switches apps, screen locks, device sleeps), MCSession automatically disconnects all peers. There is no way to maintain an MPC session in the background. A caregiver who receives a phone call while syncing will silently lose their connection. Sync will appear to complete without error, but no data will have transferred.

**Why it happens:**
Developers expect MPC to behave like a TCP socket or CloudKit sync, which can operate in the background. Apple explicitly limits MPC to foreground-only. The framework does not surface this as an error — it just disconnects, and the delegate fires `didChange state: .notConnected`, which developers often treat as a transient failure rather than a fundamental constraint.

**How to avoid:**
Design sync as opportunistic, not required. When two devices come to foreground in the same location, they sync. Never block a UI action waiting for MPC sync to complete. Queue all writes locally first, then attempt sync. Implement a "sync when convenient" model with explicit status indicators ("Last synced 4 minutes ago"). Consider supplementing MPC with the optional iCloud relay path so remote caregivers who never share physical proximity still get data.

**Warning signs:**
- Sync "works in testing" because testers hold the app open during development
- No explicit handling of `.notConnected` state in delegate
- UI shows "syncing..." spinner without a timeout
- Testers notice sync fails after receiving a phone call

**Phase to address:** Phase 1 (Core Data + Sync Architecture). The data layer must assume disconnection is the default state and local persistence is the source of truth.

---

### Pitfall 2: Permission Revocation Cannot Erase Already-Synced Data

**What goes wrong:**
The senior removes a caregiver from the care team. The caregiver's device already has all care logs synced. In a P2P local-first system, you cannot remotely delete data from another device. The revoked caregiver continues to have full historical access to all care records on their device, indefinitely. This is the most serious trust violation in the system.

**Why it happens:**
Local-first architecture is asymmetric: syncing data onto a device is easy; removing it is impossible without the device actively cooperating. Most implementations build the "grant access" flow and never fully reckon with what revocation actually means at the data layer.

**How to avoid:**
Design a per-document encryption model from day one. Each care record is encrypted with a key that is distributed only to authorized team members. On revocation, the key is rotated. Future records become unreadable to the revoked peer immediately (no new key distributed to them). Historical records from before revocation remain readable on the revoked device — communicate this clearly to users and document it in the UI as expected behavior ("Removing a caregiver prevents future access. They may retain access to records already synced to their device."). For high-sensitivity scenarios (e.g., removing a paid aide), the senior can optionally wipe their care log history after revocation (creates a new encrypted document lineage). Never promise or imply that revoking access deletes the data from a remote device.

**Warning signs:**
- Permission model is role-based only (no cryptographic binding)
- "Remove caregiver" button deletes a database row but does not invalidate any keys
- No user-facing explanation of what revocation does and does not do

**Phase to address:** Phase 1 (Data Architecture). Encryption key distribution must be designed alongside the data model, not added later. This is a rewrite if retrofitted.

---

### Pitfall 3: CRDT History Grows Without Bound — Devices Slow and Fill Up

**What goes wrong:**
CRDT operation logs preserve every edit to enable conflict-free merging. A care log that has been written to daily for 2 years by 5 caregivers accumulates enormous metadata overhead. Ink & Switch found this caused "performance and memory/disk usage [to] quickly become a problem" in their Pixelpusher and Trellis prototypes. On constrained devices (older iPhones used by elderly users, full Apple Watch storage), this becomes unacceptable.

**Why it happens:**
CRDT data structures are append-only by design. Developers implement the happy path (sync works!) and defer the compaction problem. Compaction (producing a snapshot that all peers have seen, then pruning operations older than that snapshot) is non-trivial to implement correctly and easy to get wrong when peers go offline for extended periods.

**How to avoid:**
Design the op-log lifecycle from the start. Use a CRDT library (e.g., Automerge-swift) that has compaction support built in. Define a compaction policy: "Produce a compact snapshot when the op-log exceeds N operations and all known peers have ACKed the baseline." For peers that have been offline more than 30 days, design a re-onboarding flow rather than trying to replay 30 days of ops. Set a storage budget per device and surface a warning when approaching it.

**Warning signs:**
- No compaction strategy in the data model design
- Database file size grows linearly with time in load testing
- No "last seen" timestamp tracked per peer
- Performance degrades after months of simulated use in testing

**Phase to address:** Phase 1 (Data Architecture) for design; Phase 3 (Performance/Optimization) for compaction implementation and testing.

---

### Pitfall 4: HealthKit Authorization Silently Returns Empty — Appears as No Data

**What goes wrong:**
When a user denies HealthKit read permission, the API returns no error and no data. The app silently renders "no heart rate readings" or "no fall events" because HealthKit deliberately hides whether permission was denied (to protect privacy). Developers treat empty results as "no data exists" when the real problem is "no permission granted." The caregiver sees a blank vital signs screen with no actionable explanation.

**Why it happens:**
This is a deliberate HealthKit API design. Apple does not let apps know whether a permission was denied vs. data genuinely doesn't exist. Developers who test only on their own devices (where they've granted permission) never encounter this case. On a senior's device where HealthKit access was declined during setup — or where the privacy prompt was dismissed by mistake — all health data flows silently break.

**How to avoid:**
Add a HealthKit permission status screen in onboarding that distinguishes: "Access granted," "Access not yet requested," and "Please open Settings to enable Health access" (inferred by showing data that Apple Health has but your app doesn't). Never show a blank card without an explanation. Provide a deep link to `UIApplication.openSettingsURLString` for Health permissions. Test with a fresh Simulator that has explicitly denied permissions, not just one that has never been asked. Once a user declines, the system permission prompt will never show again — the only recovery path is Settings.

**Warning signs:**
- Onboarding requests HealthKit access without confirming it was granted
- UI shows empty health data with no "enable in Settings" affordance
- No integration testing with denied permission state

**Phase to address:** Phase 2 (HealthKit + Watch Integration). Build the permission state machine as the first task in that phase.

---

### Pitfall 5: Fall Detection Cannot Push to Caregivers — It's Emergency-Contacts-Only

**What goes wrong:**
The app is designed to "surface fall detection events from Apple Watch to the care team." In practice, watchOS Fall Detection only notifies the watch owner's emergency contacts via Emergency SOS, not third-party apps. There is no background push API for fall events. A third-party app cannot receive a fall event while backgrounded and relay it to caregivers in real time.

**Why it happens:**
CMFallDetectionManager allows an app to receive fall detection events in the foreground, but the watch must be awake, the app must be the active complication or in the foreground, and there is no background delivery mechanism. Developers assume "Apple Watch detects falls" means their app can intercept and relay those events — the reality is far more constrained.

**How to avoid:**
Reframe the feature: the app does not detect falls in real time. Instead, it presents fall event history when the senior's device syncs, and caregivers see "A fall was detected at 3:42 PM yesterday." For genuine fall alerting, instruct users to configure the senior's Emergency Contacts list on their Apple Watch (via the Health app), which is the proper Apple mechanism. Document this clearly in onboarding. Consider integrating `HKCategoryTypeIdentifier.appleWatchSeries4OrLater` fall events via HealthKit queries (polled, not pushed) for historical display only.

**Warning signs:**
- Roadmap describes "real-time fall alerts to caregivers"
- Fall detection listed as a core feature without a verified API path
- No prototype tested on real hardware with CMFallDetectionManager

**Phase to address:** Phase 2 (HealthKit + Watch Integration). Verify this constraint in a spike before committing to the feature roadmap.

---

### Pitfall 6: MPC Assumes Symmetric Peers — Care Team Has Asymmetric Roles

**What goes wrong:**
Multipeer Connectivity is designed for symmetric peer relationships: every node is equivalent. Care team coordination has inherently asymmetric roles: the senior owns the data, professional aides have restricted write access, family members have different read scopes. Mapping access control roles onto MPC's flat peer model requires careful layer separation. Without it, any peer can write any record and broadcast it to all other peers, bypassing the permission model entirely.

**Why it happens:**
Developers use MPC as the transport layer and conflate "can sync data" with "is authorized to modify data." MPC has no built-in authorization. A device that receives a sync connection is just a peer — the app must enforce authorization at the data layer, not the network layer.

**How to avoid:**
Treat MPC purely as transport. Authorization happens at the record layer: each operation includes the author's identity and the permission scope required. Receiving peers validate operations against the current permission model before writing to the local store. Operations from revoked peers are rejected. This requires a deterministic identity scheme (e.g., device public key + care team token) established at onboarding.

**Warning signs:**
- Permission model is implemented only in the UI ("hide this button for aides")
- No server-side or record-layer validation of who authored an operation
- Tests only check that data syncs, not that unauthorized writes are rejected

**Phase to address:** Phase 1 (Data Architecture). Authorization at the record layer must be designed before any sync code is written.

---

### Pitfall 7: Senior UI Built After Caregiver UI — Accessibility as an Afterthought

**What goes wrong:**
The caregiver interface is built first (it's more complex). The senior interface is planned for "later." When the senior UI is finally built, every interaction pattern, navigation model, and content structure is inherited from the caregiver model. Retrofitting for Dynamic Type XXL, motor-friendly tap targets, and reduced cognitive load requires rebuilding most of the views — not just increasing font sizes.

**Why it happens:**
The senior is often not in the room when the app is being designed. Developers design for themselves. Accessibility features are treated as visual tweaks rather than architectural constraints. WCAG AAA compliance for seniors requires minimum 44pt tap targets, 7:1 contrast ratios, and navigation that works without gestures — constraints that invalidate many standard SwiftUI component choices.

**How to avoid:**
Design senior-facing views first, in a separate SwiftUI view hierarchy. Use the senior view as a constraint that forces the underlying data model to be simple enough for it. Run all senior-facing views through VoiceOver and Dynamic Type XXL on day one. Test with actual older adults — researchers at Nielsen Norman Group and multiple PMC studies find that developers' assumptions about senior usability fail consistently. Avoid gestures (swipe actions, pinch, long press) entirely in senior-facing views. Every action must be reachable by tap alone.

**Warning signs:**
- Sprint planning lists "senior mode" as a feature rather than a constraint
- Designs reference WCAG AA instead of AAA
- No older adult user in testing pool before launch
- Senior views are implemented as style overrides of caregiver views

**Phase to address:** Phase 1 (Foundation). Senior view constraints must inform the data model. Phase 2 (Senior UX) is a dedicated phase, not a skin.

---

### Pitfall 8: Notification Overload Burns Out Caregivers

**What goes wrong:**
Every care event generates a notification: medication logged, visit note added, mood observation saved, vital sync completed. A care team of 5 people, each logging multiple events per day, generates dozens of notifications on each caregiver's device. Within weeks, caregivers disable all notifications from the app. The core value proposition — eliminating the communication tax — is destroyed by the tool itself.

**Why it happens:**
Notification design is treated as a feature ("we notify everyone of everything") rather than as a UX problem. P2P sync apps are particularly prone to this: every sync event from every peer triggers a change, and naive implementations fire a notification for each delta.

**How to avoid:**
Implement a digest model for routine events: deliver a daily or configurable summary ("3 medications logged today, 1 visit note from Maria"). Reserve push notifications for high-signal events only: missed medication (more than 2 hours overdue), fall detection event, new mood entry tagged as "concerning" by a caregiver. Make notification granularity configurable per caregiver role. Batch sync-triggered notifications into a single "Care log updated" notification using notification coalescing (UNNotificationRequest with the same identifier overwrites the previous one).

**Warning signs:**
- Every database write triggers a notification
- No notification categories or priority levels in the data model
- No notification preferences screen in the design
- Testers disable notifications during QA

**Phase to address:** Phase 2 (Notifications). Define notification taxonomy before implementing any push code.

---

### Pitfall 9: HealthKit Sync Between iPhone and Apple Watch Is Not Real-Time

**What goes wrong:**
The app reads heart rate, blood oxygen, and activity data from HealthKit expecting it to reflect the current state of the senior's Apple Watch. In practice, HealthKit synchronization between Apple Watch and iPhone is system-controlled and not guaranteed to be current. Background delivery is limited to 4 updates per hour (only if the app has an active complication on the watch face). For apps without a complication, updates may arrive less frequently or not at all.

**Why it happens:**
Developers assume that "data is on the Watch, data is in HealthKit" is a real-time equivalence. The Watch-to-iPhone sync pipeline is opaque and controlled entirely by watchOS — no API can force an immediate sync. This surprises developers who discover that vital signs shown in their app are hours old.

**How to avoid:**
Set explicit user expectations: "Health data reflects the last sync, typically within the hour." Never present HealthKit data as "live" or "current." For cases where freshness matters (e.g., blood oxygen during a concerning event), document that the user must open the companion Watch app to trigger a foreground sync. Build a "last updated" timestamp into every HealthKit data display. Add the app's complication to the senior's Watch face during onboarding setup (guided) to maximize background delivery budget.

**Warning signs:**
- UI says "Live vitals" or "Current heart rate"
- No "last updated" timestamp on health data cards
- Test devices always have the Watch app in the foreground during QA

**Phase to address:** Phase 2 (HealthKit + Watch Integration). Verify delivery timing empirically before committing to any freshness SLA.

---

### Pitfall 10: SwiftData Auto-Save Is Unreliable — Data Loss on App Close

**What goes wrong:**
SwiftData's auto-save mechanism silently fails to persist data when the app closes or crashes. In a care coordination app, a caregiver logs a medication observation, closes the app, and the record is gone. This is not a theoretical concern — SwiftData's auto-save has been documented as failing to trigger reliably in non-trivial use cases.

**Why it happens:**
SwiftData markets automatic persistence, leading developers to not call `context.save()` explicitly. The actual behavior is that auto-save triggers on some conditions (context deallocation, certain lifecycle events) but is unreliable in practice. For a care log app where every write is safety-critical, silent data loss is unacceptable.

**How to avoid:**
Explicitly call `context.save()` after every write to the care log. Treat auto-save as a bonus, not a guarantee. Consider wrapping all care log mutations in a `withAnimation { try context.save() }` pattern. For the CRDT op-log layer (if used), always flush the operation to persistent storage before returning from the write function. Add crash recovery tests that verify data written just before simulated crash is present on relaunch.

**Warning signs:**
- No explicit `context.save()` calls in care log write paths
- Tests only verify that data persists under normal flow (no crash/interrupt tests)
- SwiftData used without Core Data fallback strategy

**Phase to address:** Phase 1 (Data Architecture). Choose persistence strategy carefully; validate SwiftData's save reliability on iOS 17 in a proof-of-concept before committing.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Role-only permissions (no crypto) | Simpler implementation | Revoked caregivers retain all data; no real data isolation | Never — build crypto binding in Phase 1 |
| MPC as both transport and session manager | Less code | Sessions silently drop in background; no recovery path | Never — abstract transport from session state |
| Show blank card when HealthKit returns empty | Faster to build | Users think app is broken; no recovery affordance | Never — always explain empty state |
| Notify on every sync event | Simple implementation | Notification fatigue within weeks; caregivers opt out | MVP only if notifications are trivially silenceable; fix in Phase 2 |
| SwiftData without explicit `context.save()` | Cleaner call sites | Silent data loss on crash or background termination | Never for safety-critical care log writes |
| Senior UI as a font-size override of caregiver UI | Reuses components | Fails accessibility; cognitive load too high for elderly users | Never — senior and caregiver views share data, not UI hierarchy |
| Real-time fall alert framing | More compelling feature | Not technically feasible with current watchOS APIs; misleads users | Never — reframe as historical fall events from day one |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| HealthKit permissions | Treating "no data" as "data doesn't exist" | Detect first-launch state and guide user to Settings; show explicit "Health access needed" state |
| HealthKit permissions | Requesting all 15 data types at once | Request only the types actively displayed; Apple reviewers reject over-broad requests |
| CMFallDetectionManager | Expecting background delivery of fall events | Use it foreground-only for immediate response; use HealthKit history for asynchronous display |
| Multipeer Connectivity | Expecting sessions to persist through backgrounding | Design sync as stateless and opportunistic; rebuild sessions on every foreground event |
| Multipeer Connectivity | Client/server model on top of symmetric P2P | Design as peer-equal transport; enforce asymmetric authorization at the record layer |
| CloudKit relay | Expecting CloudKit to resolve conflicts sensibly | CloudKit uses last-writer-wins by timestamp; implement merge logic client-side; use custom CKRecordZone |
| WCSession (Watch connectivity) | Expecting real-time bidirectional communication | WCSession is unreliable during permission changes (iOS kills Watch app via SIGKILL on permission change); always handle nil session gracefully |
| SwiftData | Using relationships in model constructors | Initializing SwiftData relationships in `init()` corrupts foreign keys; add relationships after insert |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| CRDT op-log without compaction | App launch slows, database file grows without bound | Design compaction policy in Phase 1; snapshot when all peers have ACKed baseline | After 6-12 months of active use |
| HealthKit query on main thread | UI freezes when loading health history | Always execute HKSampleQuery on a background queue; deliver results via async/await | On devices with large HealthKit history (years of Watch data) |
| Loading all care log history for display | Scroll performance degrades | Paginate care log queries; lazy load older records | At ~500 care log entries (common after 6 months) |
| Rebuilding MPC session on every reconnect without back-off | Device floods local network with discovery packets; battery drain | Implement exponential back-off for reconnect attempts | With 8+ devices in proximity (family gathering scenarios) |
| Sync all data on every peer connection | Sync takes minutes on first pair | Send only delta since last known sync point (change tokens); full sync only on first pair | First sync after 30+ days of divergence |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing care logs without encryption at rest | Device theft exposes senior's full medical history | Use iOS Data Protection class `completeUnlessOpen` minimum; prefer `complete` for sensitive records |
| Deriving encryption keys from device ID or UDID | Key rotation is impossible; key is fixed to device | Use cryptographically generated key pairs per care team member; store in Keychain |
| Syncing raw HealthKit data via MPC without end-to-end encryption | Any device on the same Wi-Fi network can intercept P2P traffic if using infrastructure mode | Use MPC's encryption (enabled by default in `MCSession`); do not use MCEncryptionPreference.none |
| Logging PHI to console or crash reporter | Crash reports sent to third-party services expose health data | Scrub all HealthKit and care log values from os_log and crash reporting payloads |
| Treating iCloud as a trusted server for authorization | iCloud relay can be accessed by anyone with the Apple ID; relay is not a permission boundary | Permission validation must happen client-side at the data layer; never rely on relay for access control |
| Embedding care team member identity in display name only | Display names are spoofable in MPC | Use cryptographic peer identity (public key) as the authoritative identity; display name is cosmetic only |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Gesture-heavy navigation in senior view (swipe to delete, swipe to confirm) | Motor decline makes swipes unreliable; seniors accidentally trigger or miss actions | All senior-facing actions reachable by tap only; destructive actions require explicit confirmation dialogs |
| Icon-only buttons without text labels in senior view | Seniors cannot reliably interpret abstract icons; leads to errors and abandonment | Every button in senior view has a visible text label; icon is supplementary only |
| Sync status not surfaced in UI | Caregivers do not know if what they see is current; trust erodes | Persistent "Last synced X ago" indicator on every view; explicit sync-in-progress state |
| "Looks connected" when MPC discovery is active but no session established | User thinks data is syncing when only discovery is running | Distinguish "Nearby devices found" from "Actively syncing"; only show sync progress when data transfer is confirmed |
| Notifications with no context | Caregivers cannot prioritize without opening app | Include subject and action in notification body: "Maria logged: Lunch eaten, good appetite" not "Care log updated" |
| Onboarding that requires the senior to configure HealthKit permissions alone | Seniors decline confusing permission dialogs; app loses all health data access | Include a guided caregiver-assisted setup flow; walk through HealthKit permissions screen by screen with plain language explanations |

---

## "Looks Done But Isn't" Checklist

- [ ] **MPC Sync:** Appears to work in dev (testers keep app foregrounded) — verify sync survives a phone call mid-transfer on both devices
- [ ] **Permission Revocation:** "Remove caregiver" button exists — verify that the removed caregiver's device cannot receive new sync data after removal; verify user-facing copy explains historical data remains
- [ ] **HealthKit Empty State:** Vital signs card renders — verify it renders correctly when HealthKit permission is denied (should show "Enable in Settings," not a spinner or blank card)
- [ ] **Fall Detection:** Fall events appear in care log — verify these are historical HealthKit records, not real-time push events; verify user-facing copy does not promise real-time alerting
- [ ] **CRDT Storage:** Sync works on fresh install — measure database size after 90 days of simulated use with 5 caregivers writing daily; verify it does not exceed 50MB
- [ ] **SwiftData Persistence:** Data saves correctly in normal flow — test data written 1 second before simulated app crash (kill from Xcode) reappears on relaunch
- [ ] **Senior Accessibility:** Senior view looks good at default text size — verify at Dynamic Type "Accessibility XXL" setting; verify all tap targets are at least 44pt; verify VoiceOver reads every element in logical order
- [ ] **Notification Fatigue:** Notifications arrive — verify a test user with 5 active peers does not receive more than 5 notifications in a single day under normal care activity

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Permission revocation without crypto | HIGH | Requires data model redesign; all synced data must be re-encrypted; existing peer data cannot be retrieved; effectively a rewrite of sync architecture |
| MPC session management without reconnection logic | MEDIUM | Add reconnect-on-foreground observer; implement session teardown and rebuild; no data model changes required |
| CRDT log without compaction (storage bloat) | MEDIUM | Implement snapshot + log pruning; requires testing against all peer states; no UI changes required |
| SwiftData data loss (no explicit save) | MEDIUM | Add explicit `context.save()` at all write sites; add crash recovery test suite; no architectural changes |
| Senior UI built as caregiver UI overrides | HIGH | Full view hierarchy rebuild for senior-facing screens; data model likely unaffected but all senior UX must be redesigned with older adult testing |
| HealthKit empty state shown as blank | LOW | Add permission state detection and empty state copy; no data model changes; 1-2 day fix |
| Notification overload without taxonomy | MEDIUM | Design and implement notification categories; requires user notification settings screen; backend notification routing logic update |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| MPC background disconnection | Phase 1 — Data Architecture | Sync test survives phone call interruption on both devices |
| Permission revocation cannot delete synced data | Phase 1 — Data Architecture | Removed peer cannot receive new encrypted operations; copy explains historical data |
| CRDT history grows without bound | Phase 1 — Data Architecture (design); Phase 3 — Optimization (implementation) | Database size after 90-day simulation with 5 peers stays under 50MB |
| HealthKit permission returns empty silently | Phase 2 — HealthKit + Watch Integration | Denied permission shows "Enable in Settings" affordance; not a blank card |
| Fall detection cannot push to caregivers | Phase 2 — HealthKit + Watch Integration | Fall events presented as historical, not real-time; onboarding copy is accurate |
| MPC symmetric peer vs. asymmetric roles | Phase 1 — Data Architecture | Unauthorized write from a restricted peer is rejected at record layer, not UI layer |
| Senior UI as afterthought | Phase 1 — Foundation (constraints); Phase dedicated to Senior UX | All senior views pass VoiceOver audit and Dynamic Type XXL review before any caregiver sprint |
| Notification overload | Phase 2 — Notifications | Test user with 5 peers generates fewer than 5 notifications per day under normal activity |
| HealthKit Watch sync not real-time | Phase 2 — HealthKit + Watch Integration | All HealthKit data displays include "Last updated" timestamp; no "live" language in UI |
| SwiftData auto-save unreliable | Phase 1 — Data Architecture | Crash recovery test: data written 1 second before kill reappears on relaunch |

---

## Sources

- [Apple Developer Forums — Why is MultipeerConnectivity so unreliable?](https://developer.apple.com/forums/thread/74929) — MEDIUM confidence (forum discussion)
- [Apple Developer Forums — Moving from Multipeer Connectivity to Network Framework](https://developer.apple.com/forums/thread/776069) — HIGH confidence (official forum)
- [Apple Developer Documentation — CMFallDetectionManager](https://developer.apple.com/documentation/coremotion/cmfalldetectionmanager) — HIGH confidence (official)
- [Apple Developer Documentation — enableBackgroundDelivery](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:)) — HIGH confidence (official)
- [beda.software — Apple HealthKit Pitfalls](https://beda.software/blog/apple-healthkit-pitfalls) — MEDIUM confidence (practitioner post, specific and detailed)
- [Ink & Switch — Local-First Software](https://www.inkandswitch.com/essay/local-first/) — HIGH confidence (original research, peer-reviewed quality)
- [Wade Tregaskis — SwiftData Pitfalls](https://wadetregaskis.com/swiftdata-pitfalls/) — MEDIUM confidence (practitioner post; specific bugs documented with reproduction steps)
- [fatbobman — watchOS Development Pitfalls and Practical Tips](https://fatbobman.com/en/posts/watchos-development-pitfalls-and-practical-tips) — MEDIUM confidence (practitioner post, real app shipped)
- [PMC — Medication Management Apps: Usable by Older Adults?](https://pmc.ncbi.nlm.nih.gov/articles/PMC5694345/) — HIGH confidence (peer-reviewed research)
- [PMC — Design Guidelines of Mobile Apps for Older Adults](https://pmc.ncbi.nlm.nih.gov/articles/PMC10557006/) — HIGH confidence (peer-reviewed systematic review)
- [Nielsen Norman Group — Usability for Senior Citizens](https://www.nngroup.com/articles/usability-for-senior-citizens/) — HIGH confidence (established UX research authority)
- [CRDT Implementation Guide — Velt (Dec 2025)](https://velt.dev/blog/crdt-implementation-guide-conflict-free-apps) — MEDIUM confidence (practitioner post)
- [Apple HealthKit: What You Can and Can't Do](https://www.themomentum.ai/blog/what-you-can-and-cant-do-with-apple-healthkit-data) — MEDIUM confidence (verified against official docs)

---
*Pitfalls research for: Aging in Place — Caregiver Coordination (local-first P2P sync, iOS/watchOS)*
*Researched: 2026-03-18*
