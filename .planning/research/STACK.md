# Stack Research

**Domain:** Native SwiftUI local-first caregiver coordination app (iOS/watchOS)
**Researched:** 2026-03-18
**Confidence:** MEDIUM-HIGH (Apple frameworks HIGH; CRDT sync layer MEDIUM due to ecosystem immaturity)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SwiftUI | iOS 17+ / watchOS 10+ | UI framework for all targets | Native, first-class Watch support, integrates with SwiftData and Observation framework without bridging layers; required for @Observable macro |
| Swift 6 | 6.0+ (Xcode 16+) | Language | Strict concurrency model catches data-race bugs at compile time — essential when care records flow across actors (HealthKit, P2P, Watch sync) |
| SwiftData | iOS 17+ | On-device persistence | Apple's modern persistence layer built on Core Data; direct SwiftUI integration via @Model and @Query; no separate model files; required for local-first data ownership |
| Observation Framework (@Observable) | iOS 17+ | State management | Replaces Combine + @ObservedObject pattern; automatic fine-grained dependency tracking; eliminates boilerplate; do not use ObservableObject on iOS 17+ targets |
| HealthKit | iOS 17+ / watchOS 10+ | Vital signs, fall detection, activity | Only Apple-native API for heart rate, blood oxygen, fall detection events from Apple Watch; no viable third-party alternative |
| WatchConnectivity | watchOS 10+ | iOS ↔ Watch data transfer | The only supported mechanism for transferring app data between paired iPhone and Watch; App Groups do not span devices |
| Network framework (NWBrowser / NWListener) | iOS 17+ | Local P2P peer discovery and transport | Apple's recommended modern replacement for Multipeer Connectivity; supports Bonjour service browsing, peer-to-peer Wi-Fi, and QUIC/TLS 1.3; Swift concurrency compatible |
| CryptoKit | iOS 17+ | End-to-end encryption for relay transit | Apple-native, hardware-backed (Secure Enclave) crypto; AES-GCM for symmetric encryption of care records in transit; zero external dependencies; zeroizes secrets on dealloc |
| CloudKit (Private Database) | iOS 17+ | Optional encrypted relay for remote sync | Per-user private databases; with Advanced Data Protection (iOS 18) CloudKit data is end-to-end encrypted and Apple cannot access it; zero infrastructure cost; respects local-first: cloud is additive, not required |
| Keychain Services | iOS 17+ | Secure key and credential storage | Hardware-backed storage for per-user encryption keys and care team identity tokens; never store these in UserDefaults or SwiftData |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| automerge-swift | 0.5.x (latest stable) | CRDT-based conflict-free merge of care records | Use for care log entries, medication confirmations, and visit notes that multiple caregivers may write simultaneously while offline; provides deterministic merge without a central arbiter |
| automerge-repo-swift | 0.1.0-alpha (experimental) | Network transport and storage coordination layer over automerge-swift | Consider only if you want batteries-included sync coordination; currently alpha — evaluate stability before committing; fallback is manual Automerge document sync over Network framework transport |
| heckj/CRDT | Latest (Swift Package Index) | Lightweight state-based CRDTs (G-Set, LWW-Register, etc.) | Use as an alternative or supplement to Automerge for simpler record types (e.g., presence/absence of a medication dose) where Automerge's document model is overkill |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16+ | Primary IDE, simulator, Instruments | Required for Swift 6 strict concurrency; use Instruments → Time Profiler and HealthKit Simulator for Watch testing |
| Swift Package Manager | Dependency management | Only dependency manager to use; no CocoaPods or Carthage for a new SwiftUI project |
| XCTest + Swift Testing | Unit and integration tests | Swift Testing (swift-testing framework, WWDC 2024) is the modern replacement for XCTest-only test suites; use both during transition |
| Xcode Previews | Rapid UI iteration | Mock care data with PreviewProvider/macro; do not gate previews on HealthKit authorization — always provide mock data paths |
| TestFlight | Beta distribution | Standard for distributing to care team testers before App Store |

---

## Installation

This is a native Swift project — all dependencies are added via Xcode's Swift Package Manager UI or Package.swift.

```swift
// Package.swift dependencies (if using SPM-first project structure)
dependencies: [
    .package(url: "https://github.com/automerge/automerge-swift", from: "0.5.0"),
    // Optionally — only if automerge-repo-swift reaches beta+:
    // .package(url: "https://github.com/automerge/automerge-repo-swift", branch: "main"),
    // heckj/CRDT for simpler use cases:
    .package(url: "https://github.com/heckj/CRDT", from: "0.3.0"),
]
```

All other frameworks (SwiftUI, SwiftData, HealthKit, WatchConnectivity, Network, CryptoKit, CloudKit, Keychain) are Apple system frameworks — no installation needed, add via target capabilities in Xcode.

**Required Xcode Capabilities to enable:**
- HealthKit (iOS target + Watch target)
- HealthKit Background Delivery (entitlement: `com.apple.developer.healthkit.background-delivery`)
- iCloud + CloudKit (for relay feature)
- Wireless Accessory Configuration is NOT needed (Multipeer is replaced by Network framework)

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Network framework (NWBrowser/NWListener) | Multipeer Connectivity (MCSession) | Almost never for new code: Apple's own DTS engineers recommend against Multipeer for new projects; it has known unfixed crash bugs, lacks Swift concurrency support, and has poor throughput. Only use Multipeer if targeting iOS 16 and need the auto-negotiated Bluetooth/Wi-Fi fallback without writing your own |
| SwiftData | Core Data | When you need heavyweight/custom migrations (SwiftData only supports lightweight migrations as of iOS 18), or when your schema is extremely complex with advanced fetch result controllers. For this project, SwiftData is sufficient |
| automerge-swift (CRDT) | Manual last-write-wins merge | Only choose LWW if the care record domain is trivial (single writer per field). Care logs with multiple simultaneous caregivers need true CRDT merge — LWW will silently discard care entries |
| CloudKit Private Database | Custom encrypted relay server | Never build a relay server for this app: it creates HIPAA surface area, ongoing infrastructure costs, and a trust problem. CloudKit is zero-cost and Apple-managed; if iCloud isn't acceptable, consider a home hub device (Mac mini always-on) running an automerge-repo peer |
| Observation Framework (@Observable) | Combine | Combine is legacy for new SwiftUI code on iOS 17+ targets. @Observable is simpler, faster (fine-grained dependency tracking), and has no publisher/subscriber mental overhead. Combine remains necessary only when consuming non-Apple event streams |
| Keychain Services | UserDefaults / File storage | Never store care team identity keys, encryption keys, or access tokens in UserDefaults or flat files. Keychain is hardware-backed; UserDefaults is plaintext |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Multipeer Connectivity (MCSession) | Has an unfixed crash bug known for 5+ years; MCSession delegate callbacks are not Swift concurrency-safe (crashes under Swift 6 strict concurrency); Apple DTS recommends against new code using it; poor throughput | Network framework with NWBrowser + NWListener + Bonjour service type |
| ObservableObject / @Published / Combine (for new code) | Legacy pattern replaced by @Observable in iOS 17; Combine introduces complex publisher chains and retain cycles for patterns that @Observable handles declaratively | Observation framework (@Observable macro) |
| Firebase / third-party cloud database | Stores PHI on a third-party server — the entire architecture is designed to avoid this; introduces HIPAA liability and ongoing costs | CloudKit Private Database (Apple-managed, encrypted) or no relay at all |
| GRDB or SQLite direct | Adds a dependency layer under SwiftData without meaningful benefit for this domain; SwiftData IS Core Data with a Swift API | SwiftData |
| Realm | Cross-platform sync story is its strength — not useful here (Apple-only); adds a large binary dependency and its own sync cloud | SwiftData + automerge-swift |
| WCSession (WatchConnectivity) for bulk care log sync | WatchConnectivity is for Watch↔Phone coordination, NOT for syncing the full care database between iPhones; sending large payloads over WCSession causes session saturation and dropped messages | Use WatchConnectivity only for Watch-specific interactions (quick mood input, medication confirmation ACK); sync the care database between iPhones via Network framework P2P or CloudKit |
| App Group containers for iPhone↔Watch sync | App Groups are same-device only; cannot bridge iPhone storage to Apple Watch storage | WatchConnectivity for Watch data handoff; CloudKit for remote sync |
| CommonCrypto | C API, error-prone; superseded | CryptoKit (Swift-native, type-safe, hardware-backed) |

---

## Stack Patterns by Variant

**If caregiver is on local network (same home Wi-Fi or peer-to-peer Wi-Fi):**
- Use Network framework NWBrowser to discover other care team devices advertising a Bonjour service type (e.g., `_ageinplace._tcp`)
- Establish NWConnection with TLS for encrypted transport
- Exchange Automerge sync messages (binary diffs) to merge care records
- No iCloud needed — fully offline capable

**If caregiver is remote (different network, out of town):**
- Use CloudKit Private Database as the relay
- Each device writes Automerge binary diffs to a CKRecord
- Other devices poll or receive CloudKit push notifications and apply diffs locally
- Enable Advanced Data Protection on iCloud so CloudKit records are end-to-end encrypted (keys never leave user devices)

**If user is a senior using Apple Watch for quick input:**
- Watch app: SwiftUI with simplified large-button interface
- Watch stores inputs locally using a lightweight in-memory or UserDefaults buffer (SwiftData is NOT recommended on Watch — limited memory and CPU)
- WatchConnectivity transfers confirmed inputs to the paired iPhone
- iPhone applies inputs to SwiftData store and propagates via P2P / CloudKit

**If building the senior "simplified UI" mode:**
- Use `@Environment(\.dynamicTypeSize)` and `dynamicTypeSize.isAccessibilitySize` to branch layouts
- Use `.accessibilitySize()` view modifier to enforce minimum AX3 or AX4 text sizes in the senior profile
- All touch targets must be minimum 44x44pt (Apple HIG); prefer 60x60pt for elderly users
- Use system semantic colors (`.primary`, `.secondary`) not hardcoded hex values — they adapt to high-contrast mode automatically

---

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| SwiftData | iOS 17+, watchOS 10+ | Avoid SwiftData on Watch targets: memory constraints make it unreliable; use WatchConnectivity + in-memory buffers on Watch |
| automerge-swift 0.5.x | iOS 15+, macOS 12+, Swift 5.9+ | Confirmed supports iOS 17 targets; watchOS support included per Package.swift platform targets |
| automerge-repo-swift | Alpha — no stable release | Do not ship in v1 without extensive testing; treat as an internal dependency until it reaches 0.1.0 stable |
| Swift 6 strict concurrency | Xcode 16+, iOS 17+ | Multipeer Connectivity is incompatible with Swift 6 strict concurrency (crashes); this is a primary reason to use Network framework instead |
| CloudKit Advanced Data Protection | iOS 16.2+ | Users must opt in via Settings → iCloud → Advanced Data Protection; your app cannot force this, but should surface a prompt explaining the privacy benefit |
| HealthKit background delivery | Requires `com.apple.developer.healthkit.background-delivery` entitlement | Must call `enableBackgroundDelivery` on every app launch; use HKObserverQuery + HKAnchoredObjectQuery to receive updates while backgrounded |
| WatchConnectivity | watchOS 7+ | Stable and well-supported; WCSession must be activated on app launch on both sides before any data transfer |

---

## Sources

- [Apple Developer: Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity) — framework overview (HIGH confidence — official docs)
- [Apple Developer Forums: Moving from Multipeer to Network Framework](https://developer.apple.com/forums/thread/776069) — Apple DTS recommendation (HIGH confidence)
- [Apple Developer Forums: SwiftData CloudKit sync on WatchOS 10](https://developer.apple.com/forums/thread/733397) — App Group limitation on Watch (HIGH confidence — Apple DTS)
- [automerge/automerge-swift on Swift Package Index](https://swiftpackageindex.com/automerge/automerge-swift) — current version and platform support (HIGH confidence)
- [automerge-repo-swift 0.1.0-alpha release](https://github.com/automerge/automerge-repo-swift/releases/tag/0.1.0-alpha) — alpha status confirmed (HIGH confidence)
- [Apple CryptoKit documentation](https://developer.apple.com/documentation/cryptokit/) — encryption primitives (HIGH confidence — official)
- [iCloud encryption: Advanced Data Protection](https://support.apple.com/guide/security/icloud-encryption-sec3cac31735/web) — E2E encryption for CloudKit third-party apps in iOS 18 (HIGH confidence — Apple)
- [heckj/CRDT on GitHub](https://github.com/heckj/CRDT) — lightweight CRDT library (MEDIUM confidence — GitHub, not official)
- [Core Data vs SwiftData 2025 comparison](https://distantjob.com/blog/core-data-vs-swiftdata/) — migration maturity limitations (MEDIUM confidence — verified across multiple sources)
- [DEV Community: The horrors of Multipeer Connectivity and SwiftUI 4](https://dev.to/joe_diragi_3bb3b9c26bddca/the-horrors-of-multipeer-connectivity-and-swiftui-4-mkb) — crash bugs and delegate issues (MEDIUM confidence — community report, consistent with Apple forums)
- [Swift 6.2 Released — Swift.org](https://www.swift.org/blog/swift-6.2-released/) — concurrency improvements (HIGH confidence — official)
- [Apple enableBackgroundDelivery documentation](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:)) — HealthKit background delivery pattern (HIGH confidence — official)

---

*Stack research for: Native SwiftUI local-first caregiver coordination (iOS 17+ / watchOS 10+)*
*Researched: 2026-03-18*
