# Architecture Research

**Domain:** Local-first P2P sync iOS/watchOS caregiver coordination app
**Researched:** 2026-03-18
**Confidence:** MEDIUM — Framework capabilities confirmed via official sources; specific multi-user CRDT + P2P + Watch patterns assembled from component-level research, not a single reference implementation

---

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         watchOS Target                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  Watch UI    │  │  HealthKit   │  │  WatchConnectivity       │  │
│  │  (SwiftUI)   │  │  Observer    │  │  (WCSession delegate)    │  │
│  │  Quick input │  │  HR/SpO2/    │  │  Sends vitals + actions  │  │
│  │  mood/meds   │  │  fall events │  │  to iOS counterpart      │  │
│  └──────┬───────┘  └──────┬───────┘  └────────────┬─────────────┘  │
│         └─────────────────┴──────────────────────┘                 │
│                          Watch App State (@Observable)              │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ WCSession (bidirectional)
┌───────────────────────────────▼─────────────────────────────────────┐
│                          iOS Target                                 │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                      Presentation Layer                      │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐    │   │
│  │  │  Senior UI    │  │  Caregiver UI │  │  Permissions  │    │   │
│  │  │  (large text) │  │  (care log)   │  │  Management   │    │   │
│  │  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘    │   │
│  └──────────┼──────────────────┼───────────────────┼────────────┘   │
│             │                  │                   │                │
│  ┌──────────▼──────────────────▼───────────────────▼────────────┐   │
│  │                      Domain Layer                             │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐    │   │
│  │  │  CareLog      │  │  Permission   │  │  Sync         │    │   │
│  │  │  Manager      │  │  Engine       │  │  Coordinator  │    │   │
│  │  │  (CRUD +      │  │  (who sees    │  │  (orchestrate │    │   │
│  │  │   merge)      │  │   what)       │  │   transports) │    │   │
│  │  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘    │   │
│  └──────────┼──────────────────┼───────────────────┼────────────┘   │
│             │                  │                   │                │
│  ┌──────────▼──────────────────▼───────────────────▼────────────┐   │
│  │                      Infrastructure Layer                     │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐    │   │
│  │  │  SwiftData    │  │  P2P Transport│  │  iCloud       │    │   │
│  │  │  Store        │  │  (MPC or NW   │  │  Relay        │    │   │
│  │  │  (local SQLite│  │   framework)  │  │  (CloudKit    │    │   │
│  │  │   source of   │  │  LAN/BT/P2PWi-│  │   optional)   │    │   │
│  │  │   truth)      │  │   Fi sync     │  │               │    │   │
│  │  └───────────────┘  └───────────────┘  └───────────────┘    │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                │ Optional CloudKit / iCloud relay
┌───────────────────────────────▼─────────────────────────────────────┐
│               Peer iOS Devices (Caregiver instances)                │
│  Same three-layer structure; SwiftData local store; P2P transport   │
│  receives sync payloads; merges via CRDT-style logic                │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Watch Quick-Input UI | Mood taps, medication confirmation, surface fall alerts | SwiftUI on watchOS 10+, .tabViewStyle(.verticalPage) |
| Watch HealthKit Observer | Subscribe to HKWorkoutSession, background delivery for HR/SpO2 | HKHealthStore on watch, background delivery via entitlement |
| WatchConnectivity Bridge | Move vitals and quick-input events to iOS counterpart | WCSession singleton, `sendMessage` for real-time, `transferUserInfo` for queued |
| Senior UI | Large-text simplified iPhone/iPad interface | SwiftUI with .dynamicTypeSize(.accessibility5) floor, senior-tuned accessibility |
| Caregiver UI | Full care log browse, add notes, view vitals history | SwiftUI, NavigationStack, standard dynamic type |
| Permissions Engine | Enforce per-caregiver read/write grants stored by senior | Local model layer — no external auth; identities are device-scoped peer IDs |
| CareLog Manager | CRUD operations, conflict-free merge of concurrent edits | SwiftData @Model objects; vector-clock or LWW (last-write-wins) on log entries |
| Sync Coordinator | Choose transport, serialize payloads, drive retry | Actor-isolated coordinator; switches between P2P and iCloud relay |
| P2P Transport | Discover nearby peers, send/receive sync payloads | Multipeer Connectivity (current v1) or Network framework (migration path) |
| SwiftData Store | Authoritative local persistence for all care events | SwiftData ModelContainer with SQLite backing; no CloudKit sync on main container |
| iCloud Relay | Encrypted remote sync when caregivers are not co-located | CloudKit private database + CKShare for caregiver sharing; separate container from local store |

---

## Recommended Project Structure

```
AgingInPlace/
├── App/
│   ├── AgingInPlaceApp.swift       # App entry, ModelContainer setup
│   └── AppEnvironment.swift        # Dependency injection root (@Observable)
│
├── Domain/
│   ├── Models/                     # @Model SwiftData types
│   │   ├── CareEntry.swift         # Base log entry (medication, note, vital)
│   │   ├── Caregiver.swift         # Team member identity + permissions
│   │   └── SyncMetadata.swift      # Vector clock / lamport timestamps
│   ├── CareLogManager.swift        # CRUD + merge logic
│   ├── PermissionEngine.swift      # Access grant evaluation
│   └── SyncCoordinator.swift       # Transport orchestration (actor)
│
├── Infrastructure/
│   ├── Persistence/
│   │   └── PersistenceController.swift  # ModelContainer factory
│   ├── Sync/
│   │   ├── P2PTransport.swift           # MPC / Network framework wrapper
│   │   ├── SyncPayload.swift            # Codable sync envelope
│   │   └── CloudKitRelay.swift          # Optional iCloud transport
│   └── HealthKit/
│       └── HealthKitManager.swift       # HKHealthStore wrapper, query builder
│
├── Features/
│   ├── Senior/
│   │   ├── SeniorHomeView.swift
│   │   └── SeniorQuickLogView.swift
│   ├── CareLog/
│   │   ├── CareLogView.swift
│   │   ├── AddCareEntryView.swift
│   │   └── CareLogViewModel.swift
│   ├── Vitals/
│   │   ├── VitalsTimelineView.swift
│   │   └── VitalsViewModel.swift
│   ├── Permissions/
│   │   ├── AccessGrantView.swift
│   │   └── PermissionsViewModel.swift
│   └── Notifications/
│       └── FallAlertHandler.swift
│
└── AgingInPlaceWatch/ (watchOS target)
    ├── WatchApp.swift
    ├── WatchConnectivityManager.swift  # WCSession singleton
    ├── Views/
    │   ├── QuickMoodView.swift
    │   ├── MedConfirmView.swift
    │   └── FallAlertView.swift
    └── HealthKit/
        └── WatchHealthKitManager.swift
```

### Structure Rationale

- **Domain/** is framework-free business logic, testable without SwiftUI or SwiftData imports. CareLogManager and PermissionEngine have no UIKit/SwiftUI dependencies.
- **Infrastructure/** contains all I/O: disk, network, HealthKit. SyncCoordinator lives in Domain (orchestration logic) but calls Infrastructure transports via protocol.
- **Features/** holds feature-vertical view + viewmodel pairs; each feature owns its SwiftData queries via `@Query` or explicit `ModelContext` fetch.
- **watchOS target** is a separate Xcode target but shares the Domain models via Swift package or shared framework target. Do not duplicate model types.

---

## Architectural Patterns

### Pattern 1: Actor-Isolated Sync Coordinator

**What:** A Swift actor wraps all sync state — connected peers, pending payload queue, retry backoff — preventing data races when MPC delegates deliver on arbitrary queues.

**When to use:** Required when Multipeer Connectivity (pre-Swift 6 concurrency support) callbacks land on unspecified serial queues while SwiftData operations need structured concurrency.

**Trade-offs:** Slight overhead on actor hops; eliminates entire class of threading bugs; makes retry/backoff logic deterministic.

**Example:**
```swift
actor SyncCoordinator {
    private var pendingPayloads: [SyncPayload] = []
    private let transport: any SyncTransport
    private let careLogManager: CareLogManager

    func enqueue(_ payload: SyncPayload) {
        pendingPayloads.append(payload)
        Task { await flush() }
    }

    private func flush() async {
        for payload in pendingPayloads {
            do {
                try await transport.send(payload)
                pendingPayloads.removeAll { $0.id == payload.id }
            } catch {
                // exponential backoff via Task.sleep
            }
        }
    }

    func receive(_ payload: SyncPayload) async throws {
        try await careLogManager.merge(payload.entries)
    }
}
```

### Pattern 2: Last-Write-Wins with Lamport Timestamps for Care Entries

**What:** Each CareEntry carries a Lamport timestamp (logical clock integer) and the originating peer ID. On merge, the entry with the highest timestamp wins for a given entry ID. For append-only types (visit notes), all entries are kept.

**When to use:** Care entries are nearly always append-only. Medication confirmation is the one case where two devices might independently mark the same dose — LWW resolves this cheaply without full CRDT library overhead.

**Trade-offs:** Simpler than full CRDT; sufficient for care-log semantics where eventual consistency (not real-time collaboration) is the goal. Does not handle partial-field merges (not needed here).

**Example:**
```swift
struct SyncMetadata: Codable {
    let originPeerID: String
    var lamportClock: UInt64
}

extension CareLogManager {
    func merge(_ incoming: [CareEntry]) throws {
        let context = ModelContext(container)
        for entry in incoming {
            if let existing = try context.fetch(
                FetchDescriptor<CareEntry>(
                    predicate: #Predicate { $0.id == entry.id }
                )
            ).first {
                if entry.syncMetadata.lamportClock > existing.syncMetadata.lamportClock {
                    existing.update(from: entry)
                }
            } else {
                context.insert(entry)
            }
        }
        try context.save()
    }
}
```

### Pattern 3: Protocol-Backed Transport Abstraction

**What:** Define a `SyncTransport` protocol that both P2PTransport (MPC) and CloudKitRelay conform to. SyncCoordinator depends on the protocol, not the concrete type.

**When to use:** Required given the two-transport architecture (local P2P + optional iCloud relay). Also makes the forthcoming migration from Multipeer Connectivity to Network framework a drop-in swap.

**Trade-offs:** Adds a protocol layer; the payoff is that CloudKit relay can be added in Phase 3 without touching sync logic.

```swift
protocol SyncTransport: Actor {
    func send(_ payload: SyncPayload) async throws
    var receivedPayloads: AsyncStream<SyncPayload> { get }
    var connectedPeerCount: Int { get }
}
```

### Pattern 4: WCSession Singleton for Watch-to-iPhone Bridge

**What:** A singleton `WatchConnectivityManager` manages the WCSession lifecycle on both targets. iOS side receives vitals and quick-input events; Watch side sends them.

**When to use:** Required for all Watch companion apps — Apple's WCSession only supports one active delegate per process.

**Trade-offs:** Singleton is non-ideal for testing; mitigate with a protocol wrapper. The singleton pattern is Apple's prescribed approach, not a design choice.

**Key method selection:**
- `sendMessage` — real-time mood/medication tap while both apps are foreground
- `transferUserInfo` — background-queued vital snapshots (guaranteed delivery, no order guarantee)
- `transferFile` — not needed for this domain
- `updateApplicationContext` — current state sync on Watch app launch (last-known vitals)

---

## Data Flow

### Care Entry Created on Caregiver iPhone

```
User taps "Add Visit Note"
    ↓
AddCareEntryView (SwiftUI)
    ↓ calls
CareLogViewModel.save(entry)
    ↓ writes
CareLogManager.create(entry) → SwiftData ModelContext.insert + save
    ↓ notifies
SyncCoordinator.enqueue(SyncPayload(entries: [entry]))
    ↓
P2PTransport.send(payload) — to all connected peers via MCSession
    [if no peers] → CloudKitRelay.send(payload) — iCloud fallback
    ↓
Peer devices receive payload → SyncCoordinator.receive(payload)
    ↓
CareLogManager.merge(entries) → SwiftData merge with LWW
    ↓
@Query in CareLogView auto-refreshes (SwiftData change notification)
```

### Vital Signs from Apple Watch

```
HKHealthStore on Watch delivers HR/SpO2 sample (background delivery)
    ↓
WatchHealthKitManager.didReceiveSamples(samples)
    ↓
WatchConnectivityManager.transferUserInfo(["vitals": encoded])
    [if foreground] WCSession.sendMessage(["vitals": encoded], ...)
    ↓
iOS WatchConnectivityManager.session(_:didReceiveUserInfo:)
    ↓
HealthKitManager.store(vitals) → CareLogManager.create(VitalEntry)
    ↓
SyncCoordinator.enqueue(payload) — propagates to other caregivers
```

### Fall Detection Event

```
CMFallDetectionManager on Watch detects fall
    ↓
WatchApp receives CMFallDetectionEvent (watchOS delegate)
    ↓
WatchConnectivityManager.sendMessage(["fallEvent": timestamp]) [real-time]
    ↓
iOS FallAlertHandler.receiveFallAlert(timestamp)
    ↓
CareLogManager.create(FallAlertEntry) → immediate local persist
SyncCoordinator.enqueue(payload) → high-priority send to all peers
    ↓
Each peer device: UserNotification.add(fallAlert) → caregiver notified
```

### Remote Sync via iCloud Relay

```
Caregiver B is not on local network
    ↓
SyncCoordinator: P2PTransport.connectedPeerCount == 0
    ↓ falls back to
CloudKitRelay.send(payload)
    ↓
CKRecord saved to senior's private CloudKit database
CKShare grants read/write to invited caregivers
    ↓
Caregiver B's CloudKit subscription fires push notification
    ↓
CloudKitRelay.fetchPendingPayloads() → SyncCoordinator.receive(payload)
    ↓
CareLogManager.merge → SwiftData save → UI refresh
```

### State Management

```
SwiftData ModelContainer (source of truth, per device)
    ↓ @Query / FetchDescriptor
Feature ViewModels (@Observable) — pull model state
    ↓ @State / bindings
SwiftUI Views — render from ViewModel properties
    ↓ user action
ViewModel → CareLogManager (write) → ModelContext.save()
    ↓ SwiftData triggers @Query invalidation
Views re-render
```

---

## Build Order (Phase Dependencies)

These are sequential dependencies — each layer must exist before the next can be tested end-to-end.

| Build Order | Component | Why This Position | Depends On |
|-------------|-----------|-------------------|------------|
| 1 | Domain Models (SwiftData @Model) | Every other component depends on data shape | Nothing |
| 2 | SwiftData persistence (ModelContainer, CRUD) | P2P sync and UI both need working local store | Domain Models |
| 3 | Senior + Caregiver UI (single device) | Validates UX and data model before sync complexity | Persistence |
| 4 | P2P Transport (MPC wrapper + SyncCoordinator) | Multi-device sync on local network | Persistence, Domain Models |
| 5 | Merge logic (LWW timestamps) | Conflict handling requires transport to exist | P2P Transport |
| 6 | WatchConnectivity Bridge | Watch needs iOS persistence working to write to | Persistence |
| 7 | HealthKit integration (Watch + iOS) | Requires WCSession bridge and care entry model | WatchConnectivity Bridge |
| 8 | Permissions Engine | Needs full caregiver identity model established | Domain Models, P2P Transport |
| 9 | iCloud Relay (CloudKit) | Optional layer; P2P must be proven first | P2P Transport, Permissions |
| 10 | Fall Detection alerts | Needs WCSession, notifications, and care log pipeline | HealthKit, Notifications |

---

## Scaling Considerations

This app scales differently from server-side software — "scale" here means care team size and data volume per device, not concurrent requests.

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 2–5 caregivers | Default MPC session (max ~8 peers); SwiftData in-process; no special handling needed |
| 5–15 caregivers | MPC starts degrading with many simultaneous peers; use a designated "relay node" role among in-home devices (e.g., iPad hub); CloudKit relay handles the rest |
| 15+ caregivers | MPC unsuitable as mesh; CloudKit becomes primary sync; P2P demoted to opportunistic local-only fast-path |
| 1+ years of care logs | SwiftData/SQLite handles millions of rows fine; add FetchDescriptor predicates with date windows to bound query results in UI |

### Scaling Priorities

1. **First bottleneck:** MPC peer count — 8 peers is the documented soft limit. Mitigation: treat the senior's iPhone or a home iPad as a hub node that all caregivers sync through. Caregivers sync to hub, hub syncs to other caregivers.
2. **Second bottleneck:** HealthKit query volume — continuous background delivery of HR samples generates high event frequency. Mitigation: batch vital snapshots on the Watch (5-minute windows) before transferring to iPhone.

---

## Anti-Patterns

### Anti-Pattern 1: Direct SwiftData Writes from MPC Delegate Callbacks

**What people do:** Call `modelContext.insert()` directly inside `MCSessionDelegate.session(_:didReceive:fromPeer:)` which fires on an unspecified serial queue.

**Why it's wrong:** SwiftData ModelContext is not thread-safe. Writes from arbitrary queues cause crashes (Swift 6 strict concurrency) or silent corruption (Swift 5). MPC predates Swift concurrency and its delegates do not hop to MainActor.

**Do this instead:** In the delegate, decode the payload and `await syncCoordinator.receive(payload)`. The actor hop moves execution to the actor's serial executor before any ModelContext access.

---

### Anti-Pattern 2: Using CloudKit-Synced SwiftData as the Local Store

**What people do:** Configure `ModelContainer` with a CloudKit container to get "free sync," then treat CloudKit as the P2P relay.

**Why it's wrong:** (a) CloudKit sync requires all properties to be optional and forbids `.unique` constraints — unworkable for care entry IDs. (b) CloudKit sync is asynchronous and opaque; you cannot interleave it with MPC sync without race conditions. (c) This approach cannot be turned off per-user, removing the local-only privacy guarantee.

**Do this instead:** Maintain a pure local SwiftData container (no CloudKit sync) as the source of truth. Build a separate CloudKit relay service that reads from SwiftData and writes CKRecords independently. The relay is opt-in and additive.

---

### Anti-Pattern 3: WCSession Per-View Initialization

**What people do:** Create a new WCSession delegate object inside each SwiftUI view that needs Watch data.

**Why it's wrong:** WCSession only supports one delegate. Multiple registrations silently override each other; only the last-registered delegate receives callbacks.

**Do this instead:** `WatchConnectivityManager` is a singleton initialized at app startup. Views observe its `@Published` or `@Observable` properties. The manager owns the single WCSession activation.

---

### Anti-Pattern 4: Storing PHI in iCloud Without Encryption

**What people do:** Use standard CKRecord with plain-text fields for care notes and vital signs, relying on iCloud's transport encryption.

**Why it's wrong:** iCloud encrypts data in transit and at rest for CloudKit private databases, but Apple can technically access private database records. The project's privacy contract is "no PHI visible to third parties." For sensitive care data, field-level encryption (e.g., encrypting the payload `Data` before storing as a CKAsset) satisfies this constraint.

**Do this instead:** Encrypt `SyncPayload` data using CryptoKit (AES-GCM with a key derived from the care team's shared secret) before writing to CloudKit. Store the encrypted blob as a `CKAsset`. CloudKit becomes a dumb delivery pipe, not a data processor.

---

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| HealthKit (iOS) | HKHealthStore singleton; `HKObserverQuery` for background delivery | Requires entitlement + NSHealthUpdateUsageDescription |
| HealthKit (watchOS) | Separate HKHealthStore instance on Watch; `HKWorkoutSession` needed for background HR | watchOS background modes entitlement required |
| WatchConnectivity | WCSession singleton, one delegate per process | Must activate session in both iOS and watchOS targets |
| CMFallDetectionManager | CoreMotion framework on watchOS; CMFallDetectionDelegate receives fall events | Only on Apple Watch with fall detection hardware (Series 4+) |
| CloudKit (optional relay) | CKContainer.privateCloudDatabase; CKShare for caregiver access grants | Requires iCloud entitlement + CloudKit container in Signing & Capabilities |
| UserNotifications | UNUserNotificationCenter for fall alerts and medication reminders | Request authorization at first launch; schedule locally |
| Multipeer Connectivity | MCPeerID + MCSession + MCNearbyServiceAdvertiser/Browser | Service type string: max 15 chars, lowercase + hyphens (e.g., "aging-care-sync") |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| SwiftUI View ↔ ViewModel | `@Observable` property observation, direct method calls | ViewModels are `@Observable` classes, injected via `.environment` |
| ViewModel ↔ CareLogManager | Direct async method calls | CareLogManager is not an actor; protect with MainActor on ViewModels |
| CareLogManager ↔ SwiftData | ModelContext (per-feature, created from shared ModelContainer) | Use `@Environment(\.modelContext)` in views; pass context to manager |
| SyncCoordinator ↔ Transports | `SyncTransport` protocol async methods | Coordinator is an actor; transport calls await inside actor |
| P2PTransport ↔ MCSession | MCSessionDelegate callbacks → async continuation bridging | Bridge: `withCheckedContinuation` or `AsyncStream` for incoming data |
| WatchConnectivityManager ↔ CareLogManager | Post-receive: call CareLogManager on MainActor to insert vitals | WCSession callbacks arrive on background; must hop before writing |
| iOS HealthKitManager ↔ CareLogManager | Observer query callback → CareLogManager.create(VitalEntry) | HealthKit delivers on background queue; same hop required |

---

## Sources

- [Multipeer Connectivity — Apple Developer Documentation](https://developer.apple.com/documentation/multipeerconnectivity) — MEDIUM confidence (JS-gated page; component names confirmed via community articles)
- [Building Peer-to-Peer Sessions with Multipeer Connectivity — createwithswift.com](https://www.createwithswift.com/building-peer-to-peer-sessions-sending-and-receiving-data-with-multipeer-connectivity/) — MEDIUM confidence
- [Getting Started with Multipeer Connectivity — createwithswift.com](https://www.createwithswift.com/getting-started-with-multipeer-connectivity-in-swift/) — MEDIUM confidence
- [Moving from Multipeer Connectivity to Network Framework — Apple Developer Forums thread 776069](https://developer.apple.com/forums/thread/776069) — MEDIUM confidence (forum; confirms migration direction)
- [MultiPeer Connectivity Swift 6 crashes — Apple Developer Forums thread 806107](https://developer.apple.com/forums/thread/806107) — MEDIUM confidence (confirms Swift 6 concurrency incompatibility)
- [Use structured concurrency with Network framework — WWDC25 Session 250](https://developer.apple.com/videos/play/wwdc2025/250/) — HIGH confidence (official Apple session; confirms Network framework is the forward path)
- [WatchConnectivity Data Sync iOS/watchOS — Medium](https://medium.com/@sheik25bareeth/data-synchronization-between-ios-and-watchos-using-watchconnectivity-009a3064e12a) — LOW confidence (community article)
- [watchOS App Development Complete Guide 2025 — netsetsoftware.com](https://www.netsetsoftware.com/insights/a-complete-guide-to-watchos-app-development-in-2025/) — LOW confidence
- [Syncing SwiftData with CloudKit — Hacking with Swift](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit) — MEDIUM confidence
- [Syncing model data across devices — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) — HIGH confidence (official)
- [Sharing CloudKit Data with Other iCloud Users — Apple Developer Documentation](https://developer.apple.com/documentation/CloudKit/sharing-cloudkit-data-with-other-icloud-users) — HIGH confidence (official)
- [CMFallDetectionManager — Apple Developer Documentation](https://developer.apple.com/documentation/coremotion/cmfalldetectionmanager) — MEDIUM confidence (JS-gated; class existence confirmed)
- [heckj/CRDT Swift library — GitHub](https://github.com/heckj/CRDT) — MEDIUM confidence (open source; existence confirmed)
- [P2P Chat App with iOS Multipeer Connectivity, Jan 2026 — Medium](https://medium.com/@kanybekov668/building-a-p2p-chat-app-with-ios-multipeer-connectivity-a791d52805ab) — LOW confidence (community, recent)

---

*Architecture research for: Local-first P2P sync iOS/watchOS caregiver coordination*
*Researched: 2026-03-18*
