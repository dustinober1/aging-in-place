# Project Research Summary

**Project:** Aging in Place — Caregiver Coordination App
**Domain:** Native iOS/watchOS local-first P2P caregiver coordination
**Researched:** 2026-03-18
**Confidence:** MEDIUM-HIGH

## Executive Summary

This is a native Apple-platform caregiver coordination app built on a local-first, privacy-preserving architecture. The defining commitment — no PHI stored on third-party servers — shapes every technology choice: SwiftUI + SwiftData for a fully on-device data store, Network framework (NWBrowser/NWListener) for local P2P sync, CryptoKit for end-to-end encryption in transit, and CloudKit Private Database as an optional encrypted relay for remote caregivers. The stack is mature and well-documented; the differentiation is in the deliberate rejection of a cloud-first model that every existing competitor (CareZone, Jointly, Caring Village) depends on.

The recommended approach builds strictly bottom-up: data model and local persistence first, then single-device UI, then P2P sync, then Watch companion, then HealthKit, then the optional iCloud relay. Every phase above is a dependency of the next. The single most important architectural decision — per-record encryption with key rotation on caregiver revocation — must be made in Phase 1 before any sync code is written; retrofitting it is a rewrite.

The primary risks are technical constraints that will surprise the team if not addressed proactively. Multipeer Connectivity (and its recommended replacement, Network framework) provides foreground-only sessions — sync must be opportunistic and local-first by design, never blocking. Fall detection cannot push real-time alerts to third-party apps; it must be reframed as historical HealthKit event display. HealthKit authorization silently returns empty on denial, requiring an explicit permission state machine at the UI layer. If these three constraints are designed around from day one, the rest of the architecture follows naturally.

---

## Key Findings

### Recommended Stack

The entire stack is Apple-native with zero third-party cloud dependencies. SwiftUI (iOS 17+ / watchOS 10+) with the Observation framework (@Observable) replaces the legacy Combine/ObservableObject pattern and is required for @Observable macro support. SwiftData provides on-device persistence with direct SwiftUI integration; it is the authoritative local source of truth and must not be configured with CloudKit sync (which breaks uniqueness constraints and prevents the local-only privacy guarantee). Swift 6 strict concurrency is non-negotiable: Multipeer Connectivity is incompatible with it and the move to Network framework is confirmed as the correct migration path by Apple DTS.

The one third-party dependency warranting careful evaluation is `automerge-swift` (0.5.x stable) for CRDT-based conflict-free merge of care records with concurrent offline edits. For simpler append-only record types, Lamport timestamp last-write-wins is sufficient and avoids the op-log compaction complexity. The `automerge-repo-swift` transport layer is alpha and should not ship in v1.

**Core technologies:**
- SwiftUI (iOS 17+ / watchOS 10+): UI framework for all targets — first-class Watch support, Observation framework integration
- Swift 6 + Xcode 16+: strict concurrency catches data-race bugs at compile time across HealthKit, P2P, and Watch sync actors
- SwiftData (iOS 17+): on-device persistence, @Model + @Query, no CloudKit sync on the main container
- Observation framework (@Observable): replaces Combine; fine-grained dependency tracking, no boilerplate
- Network framework (NWBrowser / NWListener): recommended P2P transport replacing Multipeer Connectivity; Swift concurrency-compatible, QUIC/TLS 1.3
- CryptoKit: AES-GCM encryption of sync payloads; hardware-backed via Secure Enclave; replaces CommonCrypto
- CloudKit Private Database (optional): zero-cost encrypted relay for remote caregivers; additive, not required
- WatchConnectivity: the only supported iPhone-to-Watch data bridge; singleton WCSession
- HealthKit (iOS + watchOS): heart rate, blood oxygen, fall event history; no viable third-party alternative
- Keychain Services: hardware-backed storage for encryption keys and care team identity tokens — never UserDefaults

**Avoid without exception:** Multipeer Connectivity (unfixed crash bug, Swift 6-incompatible), ObservableObject/Combine (legacy), Firebase/third-party cloud (PHI liability), App Groups for iPhone-Watch sync (same-device only), automerge-repo-swift in v1 (alpha).

### Expected Features

The market has four all-cloud, subscription-based competitors (CareZone, Jointly, Caring Village). No competitor offers P2P offline-first sync, HealthKit integration, Apple Watch companion, or senior-controlled granular permissions. The differentiation is real and unoccupied.

**Must have (table stakes):**
- Care team member management with invite/accept flow — root dependency for attribution and permissions
- Medication logging (drug, dose, time, who) with local push notification reminders
- Care visit log / shift notes with structured entry (meals, mobility, observations, concerns)
- Shared care team view showing recent logs across all caregivers
- Emergency contact quick-access screen
- Offline-capable operation — all reads and writes work without network; sync is eventual
- Senior-facing simplified UI — large text (Dynamic Type XXL+), 44pt+ tap targets, high contrast, no gestures

**Should have (differentiators for v1):**
- Local P2P sync via Network framework — no cloud, no subscription, no HIPAA surface
- Senior-controlled granular permissions (per-category, per-person access grants)
- Apple Watch companion — medication confirm and mood quick-log in 2 taps from wrist
- Mood observation logging by both caregiver and senior — dual perspective surfaces divergence
- Optional encrypted iCloud relay for remote caregivers — enhances but does not replace P2P

**Should have (v1.x after validation):**
- HealthKit vital signs surfacing (heart rate, blood oxygen, sleep) — passive data layer
- Fall event history display via HealthKit (not real-time — see Pitfalls)
- Shared appointment calendar
- Medication refill alerts

**Defer (v2+):**
- Trend visualization / health dashboard
- PDF export for physician visits
- Web viewer for non-Apple care team members
- Caregiver burnout tracking

**Anti-features to reject explicitly:** real-time chat (async logs replace it), video monitoring (dignity violation), HIPAA-compliant cloud backend (destroys the value prop), AI-generated care summaries (requires PHI to third-party LLM), Android support (requires a central broker, collapses the architecture).

### Architecture Approach

The architecture is a three-layer iOS app (Presentation → Domain → Infrastructure) with a separate watchOS target sharing the Domain models via a shared framework. The Domain layer (CareLogManager, PermissionEngine, SyncCoordinator) is framework-free and testable in isolation. Infrastructure contains all I/O: SwiftData persistence, P2P transport, and the optional CloudKit relay. The SyncCoordinator is a Swift actor that serializes all sync state, preventing data races from Network framework callbacks arriving on arbitrary queues. The SyncTransport protocol abstracts both the local P2P transport and the CloudKit relay, enabling Phase 3 relay addition without touching sync logic.

**Major components:**
1. Watch App (watchOS target) — SwiftUI quick-input UI, HealthKit observer for HR/SpO2/fall events, WCSession bridge to paired iPhone; no SwiftData on Watch (memory constraints)
2. Presentation Layer (iOS) — Senior UI and Caregiver UI as separate view hierarchies sharing no SwiftUI components; Permissions Management UI
3. Domain Layer — CareLogManager (CRUD + LWW merge), PermissionEngine (per-record access grant evaluation), SyncCoordinator (actor, transport orchestration + retry)
4. Infrastructure Layer — SwiftData local store (source of truth), P2PTransport (Network framework NWBrowser/NWListener), CloudKitRelay (optional), HealthKitManager

**Key patterns:**
- Actor-isolated SyncCoordinator prevents threading bugs when transport callbacks arrive off-MainActor
- Last-write-wins with Lamport timestamps for care entries; append-only for visit notes (no field-level conflicts expected)
- Protocol-backed SyncTransport makes P2P and CloudKit relay interchangeable drop-ins
- WCSession singleton initialized at app startup; views observe its @Observable properties

**Build order constraint:** Domain Models → SwiftData persistence → Single-device UI → P2P Transport → Merge logic → WatchConnectivity → HealthKit → Permissions Engine → CloudKit relay → Fall detection alerts. Each layer is a hard dependency of the next.

### Critical Pitfalls

1. **Per-record encryption must be designed in Phase 1** — Permission revocation in a P2P system cannot delete data already synced to a device. The only protection is encrypting records with a key distributed only to authorized members; on revocation, rotate the key. Building role-only permissions without cryptographic binding is a rewrite if discovered later. Cost to retrofit: HIGH.

2. **P2P sync is foreground-only — design for disconnection as the default** — Network framework sessions (like Multipeer Connectivity before it) drop when any device backgrounds. Sync must be opportunistic: write locally first, sync when convenient, always show "Last synced X ago." Never block UI on sync completion. The iCloud relay path handles remote caregivers who never share physical proximity.

3. **SwiftData explicit save is non-negotiable** — Auto-save has documented reliability failures. Every care log write must call `context.save()` explicitly. Add crash recovery tests (write 1 second before kill, verify on relaunch). Silent data loss on a care record is unacceptable. Cost to retrofit: MEDIUM but avoidable entirely.

4. **Fall detection is historical display, not real-time push** — `CMFallDetectionManager` requires the Watch app to be in the foreground; there is no background delivery API for fall events to third-party apps. The feature must be framed as "fall event history from HealthKit" from day one. Promising real-time fall alerts misleads users and cannot be delivered. Confirm this in a spike before Phase 2 planning.

5. **Senior UI must be designed first, not retrofitted** — Building caregiver UI first and adding "senior mode" as a style override consistently fails accessibility requirements. WCAG AAA for seniors (7:1 contrast, 44pt+ targets, gesture-free navigation) invalidates most standard SwiftUI component choices. Senior view constraints must inform the data model in Phase 1; a dedicated Senior UX phase must precede caregiver feature sprints, not follow them. Cost to retrofit: HIGH.

---

## Implications for Roadmap

Based on research, the architecture has hard sequential dependencies that directly determine phase order. Phases cannot be safely reordered without violating build-order constraints.

### Phase 1: Foundation — Data Architecture and Identity

**Rationale:** Care team identity, per-record encryption design, and the local SwiftData store are root dependencies for everything else. Sync, permissions, and attribution all require these to exist first. The most expensive pitfalls (permission revocation without crypto, SwiftData data loss, senior UI as afterthought) must be addressed here or they become rewrites.
**Delivers:** Working SwiftData persistence with explicit save discipline; care team identity and invite flow; per-record encryption key model; basic single-device care log CRUD; Senior UI view hierarchy established as a first-class constraint (not a skin); Domain model types locked.
**Addresses features:** Care team member management, basic care visit log, medication logging (local only), emergency contacts, senior-facing simplified UI foundation.
**Avoids pitfalls:** Permission revocation without crypto (Pitfall 2); SwiftData data loss (Pitfall 10); MPC asymmetric roles (Pitfall 6); Senior UI as afterthought (Pitfall 7).

### Phase 2: Single-Device UX — Senior and Caregiver Interfaces

**Rationale:** UI must be validated before sync complexity is introduced. The senior UI must be built and tested with real older adults before caregiver features are added; adding it later produces an inaccessible product. This phase locks the interaction model before P2P changes the data flow.
**Delivers:** Full Senior UI (Dynamic Type XXL, gesture-free, VoiceOver-compliant); Caregiver care log UI; medication logging with local push notification reminders; mood observation logging; permission management UI; shared care team view.
**Uses:** SwiftUI, SwiftData @Query, Observation framework, UserNotifications (local only).
**Implements:** Senior UI and Caregiver UI presentation layers; notification taxonomy (digest model, not per-event).
**Avoids pitfalls:** Senior UI as afterthought (Pitfall 7); notification overload (Pitfall 8).

### Phase 3: P2P Sync — Local Network Sync Engine

**Rationale:** P2P sync is the core differentiator and the highest-complexity component. It must be built on top of a validated data model and UI; adding sync before those are stable multiplies debugging complexity. The SyncTransport protocol abstraction must be implemented here so the CloudKit relay in Phase 5 is a drop-in, not a refactor.
**Delivers:** Network framework P2P transport (NWBrowser + NWListener); actor-isolated SyncCoordinator; Lamport timestamp LWW merge logic; sync status UI ("Last synced X ago"); reconnection with exponential backoff; care records sync correctly across 2+ iOS devices on the same local network.
**Uses:** Network framework, CryptoKit (encrypt payloads in transit), Swift actors.
**Implements:** P2PTransport, SyncCoordinator, SyncPayload, SyncTransport protocol.
**Avoids pitfalls:** P2P foreground-only disconnection (Pitfall 1); MPC asymmetric roles / authorization at record layer (Pitfall 6).

### Phase 4: Apple Watch Companion

**Rationale:** WatchConnectivity requires iOS persistence and care entry model to be working before Watch inputs can be stored. Watch adds the quick-input friction reduction that drives daily habit formation, but it depends entirely on Phase 3 sync working correctly.
**Delivers:** watchOS app target; medication confirm and mood quick-log from Watch; WCSession singleton bridge; watch complication; vitals buffering on Watch (in-memory, not SwiftData); care inputs flow from Watch to iPhone to care team peers.
**Uses:** WatchConnectivity, watchOS SwiftUI (.tabViewStyle(.verticalPage), large buttons), WCSession (sendMessage for foreground, transferUserInfo for background-queued).
**Implements:** WatchConnectivityManager singleton, WatchHealthKitManager, QuickMoodView, MedConfirmView.
**Avoids pitfalls:** WCSession per-view initialization (Anti-Pattern 3 from ARCHITECTURE.md); WCSession for bulk sync (use only for Watch-specific interactions).

### Phase 5: HealthKit Integration

**Rationale:** HealthKit requires the Watch companion to be the data source and the care entry model to accept VitalEntry types. Fall detection must be handled here as historical HealthKit display — confirm via a spike before this phase is planned. The permission state machine is the first task in this phase.
**Delivers:** HealthKit permission state machine with "Enable in Settings" empty states; heart rate and blood oxygen history display with "Last updated" timestamps; fall event history from HealthKit (presented as historical log entries, not real-time alerts); HealthKit background delivery via complication.
**Uses:** HealthKit (iOS + watchOS), HKObserverQuery, HKAnchoredObjectQuery, CMFallDetectionManager (foreground-only, confirmed in spike).
**Implements:** HealthKitManager, WatchHealthKitManager, VitalsTimelineView, FallAlertHandler.
**Avoids pitfalls:** HealthKit silent empty state (Pitfall 4); fall detection real-time push assumption (Pitfall 5); HealthKit sync latency (Pitfall 9).

### Phase 6: iCloud Relay — Remote Caregiver Sync

**Rationale:** CloudKit relay is additive — it enhances P2P sync for caregivers who cannot be physically co-located, but P2P must be proven stable first. The SyncTransport protocol abstraction from Phase 3 makes this a drop-in. Enabling Advanced Data Protection for true E2E encryption requires user opt-in during setup.
**Delivers:** Optional CloudKit Private Database relay; CKShare for caregiver access grants; encrypted SyncPayload as CKAsset (field-level CryptoKit encryption); CloudKit push notification delivery; onboarding prompt for iCloud Advanced Data Protection; care records sync correctly for remote caregiver who has never been on the same local network.
**Uses:** CloudKit, CKContainer.privateCloudDatabase, CKShare, CryptoKit (payload encryption before CloudKit write).
**Implements:** CloudKitRelay, SyncCoordinator fallback to relay when P2P peer count is 0.
**Avoids pitfalls:** PHI stored in iCloud without encryption (Anti-Pattern 4 from ARCHITECTURE.md); CloudKit as permission boundary (Security Mistakes from PITFALLS.md).

### Phase 7: Optimization and Hardening

**Rationale:** CRDT op-log compaction and storage budgeting cannot be validated until months of simulated data exist. This phase runs performance testing, compaction implementation, and the "looks done but isn't" checklist from PITFALLS.md before launch.
**Delivers:** Op-log compaction policy (snapshot when all peers have ACKed baseline); storage budget warning UI; paginated care log queries (FetchDescriptor with date windows); HealthKit query batching on Watch (5-minute windows); crash recovery test suite; notification taxonomy verified with 5-peer test scenario; full accessibility audit at Dynamic Type Accessibility XXL.
**Implements:** Compaction logic in CareLogManager; delta-only sync (change tokens to avoid full sync on every connection).
**Avoids pitfalls:** CRDT history grows without bound (Pitfall 3); performance traps (loading all care log history, rebuilding MPC session without backoff, syncing all data on every connection).

### Phase Ordering Rationale

- Phases 1-2 are sequential: data model before UI, because senior UI constraints inform what the data model must support.
- Phase 3 (P2P sync) cannot start until Phase 1 provides the care entry model and per-record encryption design.
- Phase 4 (Watch) cannot start until Phase 3 provides working P2P; Watch inputs must flow through the sync pipeline to be useful.
- Phase 5 (HealthKit) requires Watch companion as the sensor data source; the fall detection spike should be a fast first task.
- Phase 6 (iCloud relay) is explicitly additive; the SyncTransport abstraction in Phase 3 makes it feasible without a refactor.
- Phase 7 (optimization) depends on having months of simulated load to measure; schedule it after Phases 1-6 are feature-complete.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (P2P Sync):** Network framework NWBrowser/NWListener patterns for multi-peer coordination are less documented than Multipeer Connectivity; needs implementation-level research before detailed task breakdown.
- **Phase 5 (HealthKit):** Fall detection via CMFallDetectionManager has conflicting community reports on what is available to third-party apps; a technical spike on real hardware must precede Phase 5 planning to confirm exactly what HealthKit APIs are available for historical fall events.
- **Phase 6 (CloudKit relay):** CKShare access model for multi-caregiver scenarios and field-level CryptoKit encryption before CKAsset storage has sparse real-world examples; needs API research during planning.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Data Architecture):** SwiftData, CryptoKit, and Keychain are well-documented with official Apple sources; patterns are established.
- **Phase 2 (Single-Device UX):** SwiftUI with Observation framework and local UserNotifications are thoroughly documented; senior accessibility guidelines are well-researched (NNGroup, PMC studies).
- **Phase 4 (Watch Companion):** WatchConnectivity WCSession singleton pattern is stable and documented; watchOS SwiftUI constraints are well-understood.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core Apple frameworks backed by official documentation and Apple DTS forum guidance; automerge-swift stability confirmed on Swift Package Index; only MEDIUM concern is automerge-repo-swift (excluded from v1 recommendation) |
| Features | MEDIUM-HIGH | Competitor feature set verified from live products; P2P-specific feature patterns assembled from smaller evidence base; differentiator claims are sound but market validation is pre-launch |
| Architecture | MEDIUM | Component-level capabilities confirmed via official sources; the specific combination (CRDT + P2P + Watch + CloudKit relay) is assembled from parts, not a single reference implementation; patterns are directionally correct |
| Pitfalls | HIGH | Multiple authoritative sources; Apple DTS forum confirmations for MPC/Network framework migration; peer-reviewed UX research for senior UI; Ink & Switch original local-first research for CRDT compaction; SwiftData save reliability documented with reproduction steps |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **automerge-swift vs. manual LWW decision:** The research recommends Lamport timestamp LWW for append-only care entries and Automerge only for concurrent edit scenarios (medication confirmations). The boundary between these in the actual data model needs a deliberate design decision in Phase 1 planning — it cannot be deferred.
- **CMFallDetectionManager real-device behavior:** Confirmed foreground-only constraint via documentation; exact HealthKit historical query API for fall events needs a working spike on Series 4+ hardware before Phase 5 is planned.
- **MPC peer count scaling:** Network framework does not document a hard peer limit the way Multipeer Connectivity's ~8 peer soft limit was established. Empirical testing with 10+ devices needed during Phase 3 to validate hub-and-spoke vs. mesh topology for larger care teams.
- **CloudKit Advanced Data Protection adoption rate:** User opt-in is required; if most users do not enable it, the privacy guarantee for the iCloud relay path is weaker than designed. Onboarding design should address this directly and surface the setting prominently.
- **SwiftData on iOS 17 vs. 18 migration behavior:** Research notes SwiftData supports only lightweight migrations as of iOS 18. Phase 1 must define a migration strategy before the schema is locked, especially for the encryption key model fields.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — SwiftUI, SwiftData, HealthKit, WatchConnectivity, Network framework, CloudKit, CryptoKit, CMFallDetectionManager, UserNotifications
- Apple Developer Forums thread 776069 — Network framework migration recommendation from Apple DTS
- Apple Developer Forums thread 806107 — Swift 6 concurrency incompatibility with Multipeer Connectivity confirmed
- WWDC25 Session 250 — Network framework as the forward path for structured concurrency
- iCloud encryption / Advanced Data Protection — Apple Security Guide
- Ink & Switch — Local-First Software (original research on CRDT compaction and storage growth)
- PMC 5694345 — Medication Management Apps: Usability by Older Adults (peer-reviewed)
- PMC 10557006 — Design Guidelines of Mobile Apps for Older Adults (peer-reviewed systematic review)
- Nielsen Norman Group — Usability for Senior Citizens (established UX research authority)

### Secondary (MEDIUM confidence)
- automerge/automerge-swift on Swift Package Index — version and platform support confirmed
- beda.software — Apple HealthKit Pitfalls (practitioner post, specific and detailed)
- Wade Tregaskis — SwiftData Pitfalls (practitioner post with reproduction steps)
- fatbobman — watchOS Development Pitfalls (practitioner, real app shipped)
- createwithswift.com — Multipeer Connectivity building and getting started guides
- Hacking with Swift — Syncing SwiftData with CloudKit
- CRDT Implementation Guide — Velt (Dec 2025)

### Tertiary (LOW confidence)
- WatchConnectivity Data Sync iOS/watchOS — Medium community article (direction confirmed but implementation details need verification)
- P2P Chat App with Multipeer Connectivity Jan 2026 — Medium community article (recent; consistent with higher-confidence sources)

---
*Research completed: 2026-03-18*
*Ready for roadmap: yes*
