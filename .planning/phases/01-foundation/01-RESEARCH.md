# Phase 1: Foundation - Research

**Researched:** 2026-03-18
**Domain:** SwiftData persistence, CryptoKit per-record encryption, care team identity, senior-first SwiftUI accessibility
**Confidence:** HIGH (core APIs verified via official docs and authoritative sources)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Care Team Invitation Flow**
- Shareable alphanumeric code (e.g., "CARE-7X9K") — senior can read aloud, text, or show on screen
- Single-use: each code works for one caregiver only
- No expiry — code stays valid until used or manually cancelled by the senior
- Senior must approve: caregiver enters code, senior sees pending request and taps to confirm
- Copy and Share sheet buttons on the invite screen

**Senior Home Screen Design**
- Large card layout — one column, scrollable, big tappable cards for each section (Medications, Mood, Care Team, Calendar)
- Each card shows a quick summary (e.g., "Next: Metformin 2pm")
- iOS system default colors — standard system colors, Dynamic Type, automatic Dark Mode and accessibility adaptation
- Personalized greeting: "Good morning/afternoon/evening, [Name]" — time-of-day oriented
- Separate home screens for senior vs caregiver — each optimized for their primary tasks

**Permission Categories and Defaults**
- 4 permission categories: Medications, Mood, Care Visits, Calendar (Vitals added in Phase 5)
- New care team members get all categories granted by default (opt-out model)
- Permissions managed from care team member detail screen — tap person, see toggles
- Immediate toggle with brief "Undo" toast (like iOS Mail delete) — key rotation happens in background
- Revoked categories hidden entirely from caregiver's view (no "locked" indicators)
- Emergency contacts and medical ID always visible to all care team members regardless of permissions
- No audit trail for v1 — permissions are the trust boundary
- Senior can designate one proxy/delegate who can manage permissions and invites on their behalf

**Care Team Roles and Structure**
- One senior per care circle — caregivers helping multiple seniors join multiple circles
- Named roles displayed as labels: Family, Paid Aide, Nurse, Doctor, Other
- Roles are informational only — they don't auto-set permissions
- Caregiver selects role when joining the care team
- Removing a member: confirmation dialog, then immediate removal with key rotation. Can be re-invited later.

### Claude's Discretion
- Loading skeleton and empty state designs
- Exact spacing, typography, and card styling within iOS system guidelines
- Error state handling and edge cases
- Caregiver home screen layout and content
- Invite code format and length
- Pending request UI for the senior

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TEAM-01 | Senior or proxy can invite new care team members via shareable code or link | Offline alphanumeric code generation with UUID + Base36 encoding; ShareLink for native share sheet |
| TEAM-02 | Invited caregiver can accept invitation and join the care circle | Pending invite SwiftData model; code lookup + senior approval flow |
| TEAM-03 | Senior can view all current care team members and their roles | SwiftData @Model with @Query fetch; List/ScrollView with role labels |
| TEAM-04 | Senior can remove a care team member from the circle | Delete from SwiftData context + explicit save(); triggers key rotation |
| TEAM-05 | Senior can grant per-category access permissions to each care team member | Permission model stored as Set<PermissionCategory> on CareTeamMember; toggle UI |
| TEAM-06 | Senior can revoke a permission category from a care team member at any time | Toggle off triggers background key rotation Task |
| TEAM-07 | Permission revocation prevents future access to newly created records in that category | New records encrypted with rotated SymmetricKey; old key discarded from Keychain |
| TEAM-08 | Caregiver can view a shared care team overview showing recent activity across all members | Caregiver home screen with @Query sorted by timestamp |
| TEAM-09 | Senior or caregiver can store and access emergency contacts and medical ID information | Separate SwiftData model not gated by category permissions |
| SYNC-01 | All data reads and writes work fully offline on a single device | SwiftData with modelContainer(for:) + explicit save(); no network dependency |
| SYNC-03 | Sync resolves concurrent edits using CRDT/LWW merge strategy without data loss | Each CareRecord carries a lastModified: Date timestamp for LWW; design locked here, engine in Phase 3 |
| SYNC-04 | Each care record is encrypted with per-record keys via CryptoKit | AES-GCM SealedBox per record; SymmetricKey stored in Keychain keyed by category |
| SYNC-05 | Permission revocation rotates encryption keys so revoked members cannot decrypt new records | Generate new SymmetricKey, update Keychain, all new records use rotated key |
| SYNC-08 | No PHI is stored unencrypted on any Apple server | Encryption happens before any SwiftData write; no CloudKit in Phase 1 |
| SENR-01 | Senior-facing UI uses Dynamic Type XXL+ with minimum 44pt touch targets | .font(.title2) or larger system fonts; .frame(minHeight: 44) on all controls |
| SENR-02 | Senior-facing UI uses high-contrast colors meeting WCAG AAA standards | iOS system colors (Color.primary, Color.label) pass AAA by design; avoid custom palette |
| SENR-03 | Senior-facing UI has minimal navigation depth (max 2 taps to any primary action) | Home screen cards → detail; no intermediate nav layers |
| SENR-04 | Senior can view their own care log, vitals, and upcoming medications on a single home screen | Senior home screen with summary cards driven by @Query |
</phase_requirements>

---

## Summary

Phase 1 establishes the architectural spine that every subsequent phase builds upon. The three interlocking concerns are: (1) a SwiftData schema that models the care circle, members, permissions, and records in a way that supports Phase 3 LWW sync without restructuring; (2) a CryptoKit encryption layer where each permission category has its own SymmetricKey stored in the iOS Keychain, so revoking access rotates only the affected key while leaving other categories intact; and (3) a senior-first UI layer built on SwiftUI system primitives (Dynamic Type, system colors, 44pt targets) from day one so it cannot drift out of compliance.

The most critical architectural decision is that **SwiftData does not encrypt at rest by default**. The recommended approach is to store only ciphertext in SwiftData and manage keys exclusively in the Keychain. Each `CareRecord` stores a `Data` blob (AES-GCM sealed box) rather than plaintext fields. Decryption happens in the app layer at read time using the current active key for the record's category. When a permission is revoked, the category key is rotated in the Keychain; subsequent records are sealed with the new key; old ciphertext sealed under the old key remains inaccessible because the old key no longer exists in the Keychain.

The second architectural decision is that the SwiftData schema must carry `lastModified: Date` timestamps on every mutable record from Phase 1. Phase 3 will implement the LWW sync engine over these timestamps, but the schema must support it from the start. Adding this field retroactively would require a schema migration.

**Primary recommendation:** Use SwiftData for the structural graph (models, relationships, queries), CryptoKit AES-GCM + Keychain for PHI at rest, and ShareLink + UIPasteboard for the invite share/copy flow. Build the senior UI entirely with system fonts, system colors, and explicit 44pt hit areas.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ (ship iOS 17 min) | Persistent graph database | Apple-native, Swift-macro-driven, replaces Core Data for new apps |
| CryptoKit | iOS 13+ | AES-GCM per-record encryption, SymmetricKey generation | Apple-native, hardware-accelerated, audited |
| Security framework (Keychain) | iOS 2+ | Storing SymmetricKey material between launches | Only trusted store for cryptographic secrets on-device |
| SwiftUI | iOS 17+ | All UI | System integration, Dynamic Type, Dark Mode automatic |
| Swift Concurrency (async/await, actors) | Swift 5.9 / 6 | Background encryption, key rotation tasks | Required for Swift 6 strict concurrency |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ShareLink (SwiftUI) | iOS 16+ | Native share sheet for invite code | Use for the "Share" button on invite screen |
| UIPasteboard | iOS 3+ | Copy invite code to clipboard | Use for the "Copy" button on invite screen |
| ContentUnavailableView | iOS 17+ | Empty states (no care team members yet, no records) | Use wherever a list may be empty |
| ViewThatFits | iOS 16+ | Adaptive layouts at AX text sizes | Use wherever horizontal layout breaks at Dynamic Type AX1–AX5 |
| UserDefaults / AppStorage | built-in | Non-PHI user preferences (selected role, greeting name) | Do not put PHI here |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftData | Core Data | Core Data is more mature but requires NSManagedObject ceremony; SwiftData's macro-driven API is the correct foundation for a new Swift 6 project |
| CryptoKit AES-GCM | CryptoSwift | CryptoSwift is a third-party library; CryptoKit is Apple-native with hardware acceleration and no external dependency |
| Keychain via SecItem | KeychainWrapper SPM package | Wrapper reduces boilerplate but adds a dependency; for Phase 1, direct SecItem calls are sufficient |
| ShareLink | UIActivityViewController wrapped in UIViewControllerRepresentable | ShareLink is native SwiftUI (iOS 16+); UIKit wrapper is unnecessary |

**Installation:** No external package dependencies for Phase 1. All frameworks are built into iOS 17+.

---

## Architecture Patterns

### Recommended Project Structure

```
AgingInPlace/
├── App/
│   ├── AgingInPlaceApp.swift          # @main, modelContainer setup, role routing
│   └── RootView.swift                 # Senior vs Caregiver home branch
├── Models/                            # SwiftData @Model classes
│   ├── CareCircle.swift
│   ├── CareTeamMember.swift
│   ├── InviteCode.swift
│   ├── CareRecord.swift               # Stores ciphertext Data, not plaintext
│   ├── EmergencyContact.swift
│   └── PermissionCategory.swift       # Enum, not a @Model
├── Encryption/
│   ├── EncryptionService.swift        # AES-GCM seal/open, key rotation
│   └── KeychainService.swift          # SecItem read/write for SymmetricKey
├── Features/
│   ├── CareTeam/
│   │   ├── InviteFlowView.swift
│   │   ├── PendingRequestView.swift
│   │   ├── CareTeamListView.swift
│   │   └── MemberDetailView.swift     # Permission toggles
│   ├── SeniorHome/
│   │   ├── SeniorHomeView.swift       # Greeting + large cards
│   │   └── SummaryCardView.swift
│   └── CaregiverHome/
│       └── CaregiverHomeView.swift
└── Design/
    └── Accessibility.swift            # Shared constants: minTouchTarget = 44
```

### Pattern 1: SwiftData Model Graph

**What:** Define the care circle schema using `@Model` classes with explicit inverse relationships.

**When to use:** All persistent data. Every mutable model carries `lastModified: Date` for Phase 3 LWW.

```swift
// Source: Apple developer documentation on SwiftData relationships
// Always declare inverse relationships explicitly to avoid SwiftData bugs

@Model
final class CareCircle {
    var id: UUID
    var seniorName: String
    @Relationship(deleteRule: .cascade, inverse: \CareTeamMember.circle)
    var members: [CareTeamMember] = []
    @Relationship(deleteRule: .cascade, inverse: \InviteCode.circle)
    var pendingInvites: [InviteCode] = []

    init(seniorName: String) {
        self.id = UUID()
        self.seniorName = seniorName
    }
}

@Model
final class CareTeamMember {
    var id: UUID
    var displayName: String
    var role: MemberRole          // enum: family, paidAide, nurse, doctor, other
    var isProxy: Bool
    var grantedCategories: [PermissionCategory]  // defaults to all 4
    var joinedAt: Date
    var lastModified: Date
    var circle: CareCircle?

    init(displayName: String, role: MemberRole, circle: CareCircle) {
        self.id = UUID()
        self.displayName = displayName
        self.role = role
        self.isProxy = false
        self.grantedCategories = PermissionCategory.allCases
        self.joinedAt = Date()
        self.lastModified = Date()
        self.circle = circle
    }
}

@Model
final class CareRecord {
    var id: UUID
    var category: PermissionCategory
    var encryptedPayload: Data    // AES-GCM sealed box bytes — never plaintext
    var authorMemberID: UUID
    var createdAt: Date
    var lastModified: Date        // Required for Phase 3 LWW merge

    init(category: PermissionCategory, encryptedPayload: Data, authorMemberID: UUID) {
        self.id = UUID()
        self.category = category
        self.encryptedPayload = encryptedPayload
        self.authorMemberID = authorMemberID
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

@Model
final class InviteCode {
    var id: UUID
    var code: String              // e.g. "CARE-7X9K" — alphanumeric, human-readable
    var isUsed: Bool
    var createdAt: Date
    var circle: CareCircle?

    init(code: String, circle: CareCircle) {
        self.id = UUID()
        self.code = code
        self.isUsed = false
        self.createdAt = Date()
        self.circle = circle
    }
}

enum PermissionCategory: String, Codable, CaseIterable {
    case medications, mood, careVisits, calendar
}

enum MemberRole: String, Codable, CaseIterable {
    case family, paidAide, nurse, doctor, other
}
```

### Pattern 2: CryptoKit AES-GCM Per-Record Encryption

**What:** Each `PermissionCategory` has one active `SymmetricKey` stored in the Keychain. Records are sealed with the category key at write time and opened at read time. Key rotation generates a new key and stores it, making all future records unreadable by holders of the old key.

**When to use:** Every write of PHI into `CareRecord.encryptedPayload`.

```swift
// Source: Apple CryptoKit documentation + Storing CryptoKit Keys in the Keychain
// https://developer.apple.com/documentation/cryptokit/storing-cryptokit-keys-in-the-keychain

import CryptoKit
import Security

struct EncryptionService {

    // Seal plaintext Data for a given category, returning the sealed box bytes
    static func seal(_ plaintext: Data, for category: PermissionCategory) throws -> Data {
        let key = try KeychainService.loadOrCreateKey(for: category)
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        return sealedBox.combined!  // combined = nonce + ciphertext + tag
    }

    // Open sealed box bytes using current category key
    static func open(_ ciphertext: Data, for category: PermissionCategory) throws -> Data {
        let key = try KeychainService.loadKey(for: category)
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // Rotate the key for a category — call on permission revocation
    // Old key is overwritten; new records use new key; revoked member cannot decrypt new records
    static func rotateKey(for category: PermissionCategory) throws {
        let newKey = SymmetricKey(size: .bits256)
        try KeychainService.storeKey(newKey, for: category)
    }
}
```

### Pattern 3: Keychain SymmetricKey Storage

**What:** Store CryptoKit `SymmetricKey` as `GenericPassword` in the Keychain, keyed by category identifier string.

**When to use:** Every call to EncryptionService needs to fetch the key from Keychain, never from memory or UserDefaults.

```swift
// Source: Apple Developer Documentation — Storing CryptoKit Keys in the Keychain
// https://developer.apple.com/documentation/cryptokit/storing-cryptokit-keys-in-the-keychain

struct KeychainService {

    static func storeKey(_ key: SymmetricKey, for category: PermissionCategory) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      category.rawValue,
            kSecAttrService as String:      "com.yourapp.carekeys",
            kSecValueData as String:        keyData,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)  // delete before add to handle rotation
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.storeFailed(status) }
    }

    static func loadKey(for category: PermissionCategory) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      category.rawValue,
            kSecAttrService as String:      "com.yourapp.carekeys",
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let keyData = result as? Data else {
            throw KeychainError.notFound
        }
        return SymmetricKey(data: keyData)
    }

    static func loadOrCreateKey(for category: PermissionCategory) throws -> SymmetricKey {
        if let key = try? loadKey(for: category) { return key }
        let newKey = SymmetricKey(size: .bits256)
        try storeKey(newKey, for: category)
        return newKey
    }
}

enum KeychainError: Error {
    case storeFailed(OSStatus)
    case notFound
}
```

### Pattern 4: Explicit SwiftData Save

**What:** Always call `try modelContext.save()` explicitly after mutations. Do not rely on autosave — it has documented failures on iOS 18 and inside `Task` closures.

**When to use:** After every insert, update, or delete operation. Wrap in `do/catch`, not `try?`, so failures surface.

```swift
// Source: Hacking with Swift SwiftData documentation
// https://www.hackingwithswift.com/quick-start/swiftdata/how-to-save-a-swiftdata-object

@Environment(\.modelContext) private var modelContext

func addMember(_ member: CareTeamMember) {
    modelContext.insert(member)
    do {
        try modelContext.save()
    } catch {
        // Surface to user — do not silently swallow
        print("SwiftData save failed: \(error)")
    }
}
```

### Pattern 5: Invite Code Generation (Offline)

**What:** Generate a human-readable alphanumeric invite code without a server. Use UUID bytes encoded to Base36, then format with a prefix.

**When to use:** Senior taps "Invite Caregiver".

```swift
// Source: Derived from UUID + Base36 encoding pattern (standard offline ID approach)

struct InviteCodeGenerator {

    static func generate() -> String {
        // Take first 8 hex chars of a UUID, uppercase, group as XXXX-XXXX
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let prefix = String(uuid.prefix(8)).uppercased()
        // Format as "CARE-XXXX-XXXX" for human readability
        let part1 = String(prefix.prefix(4))
        let part2 = String(prefix.suffix(4))
        return "CARE-\(part1)-\(part2)"
    }
}
// Example output: "CARE-7F3A-9C2B"
// Single-use: mark InviteCode.isUsed = true on acceptance
```

### Pattern 6: Senior Home Screen Accessibility

**What:** Use SwiftUI system fonts and system colors. Set explicit minimum frame heights. Use `ViewThatFits` at AX text sizes.

**When to use:** All senior-facing UI components.

```swift
// Source: Apple SwiftUI accessibility documentation + WCAG AAA on iOS system colors

struct SummaryCardView: View {
    let title: String
    let summary: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)      // minimum touch-target axis

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)               // scales with Dynamic Type
                        .foregroundStyle(Color.primary)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.secondary)
            }
            .padding()
            .frame(minHeight: 80)                      // card minimum height at default text size
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel("\(title): \(summary)")
        .accessibilityHint("Double tap to open")
    }
}

struct SeniorHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var greeting = greetingForTimeOfDay()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(greeting)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                SummaryCardView(
                    title: "Medications",
                    summary: "Next: Metformin 2pm",
                    systemImage: "pills.fill"
                ) { /* navigate */ }

                SummaryCardView(
                    title: "Mood",
                    summary: "Not recorded today",
                    systemImage: "heart.fill"
                ) { /* navigate */ }

                // ... additional cards
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    static func greetingForTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }
}
```

### Pattern 7: ModelContainer Setup (App Entry Point)

**What:** Configure the single shared ModelContainer at the app entry point with autosave disabled for explicit control.

```swift
// Source: Apple SwiftData documentation
// https://developer.apple.com/documentation/swiftdata/modelcontainer

@main
struct AgingInPlaceApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(
            for: [CareCircle.self, CareTeamMember.self, CareRecord.self,
                  InviteCode.self, EmergencyContact.self],
            isAutosaveEnabled: false   // Explicit save only — avoids iOS 18 autosave bugs
        )
    }
}
```

### Anti-Patterns to Avoid

- **Storing plaintext PHI in SwiftData fields:** SwiftData files are not encrypted at rest unless device Data Protection is active, and even then, file-level encryption does not support per-record access control. Store only `Data` (ciphertext) in `CareRecord`.
- **Using `.allowsCloudEncryption` as the encryption strategy:** This only encrypts data sent to iCloud. Phase 1 has no CloudKit; Phase 6 adds it. The CryptoKit layer must exist independently.
- **Relying on SwiftData autosave inside Task closures:** Autosave may not execute before the context is discarded. Always call `try modelContext.save()` explicitly.
- **Appending to relationships one item at a time in a loop:** SwiftData arrays exhibit 130x–700x worse performance on repeated individual appends. Collect items first, then use `append(contentsOf:)`.
- **Omitting `lastModified` from mutable models:** Phase 3 LWW sync requires this field on every mutable record. It cannot be added without a schema migration.
- **Omitting inverse relationships:** SwiftData does not always infer inverse relationships correctly. Always declare `@Relationship(inverse:)` explicitly.
- **Passing SwiftData model objects across actor boundaries:** Model objects and ModelContext are not `Sendable`. Pass `PersistentIdentifier` (the model's `.id`) across actors, then fetch locally.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Authenticated encryption | Custom AES implementation | `AES.GCM` from CryptoKit | Nonce management, tag verification, timing attacks — all handled correctly by Apple |
| Secure key storage | Encrypt key with another key in UserDefaults | Keychain `SecItemAdd/Copy` | Keychain is hardware-backed, access-controlled, survives reinstall |
| Empty state UI | Custom "no content" view | `ContentUnavailableView` (iOS 17+) | System-consistent appearance, matches iOS Mail/Messages pattern |
| Share sheet | `UIViewControllerRepresentable` wrapping `UIActivityViewController` | `ShareLink` (iOS 16+) | Native SwiftUI, no UIKit bridge needed |
| Adaptive layout at large text | Manual size checks with `@Environment(\.dynamicTypeSize)` everywhere | `ViewThatFits` | Automatically picks horizontal vs vertical layout based on available space |
| Human-readable unique IDs | Sequential integers or complex UUID display | `UUID().uuidString.prefix(8)` formatted | Offline-safe, collision-resistant, copy-safe |

**Key insight:** CryptoKit and the Keychain together solve authenticated-encryption-with-access-control, which is the exact threat model of the permission revocation requirement. Building this correctly from scratch involves subtle timing and side-channel vulnerabilities that Apple has already mitigated.

---

## Common Pitfalls

### Pitfall 1: SwiftData Autosave Failures on iOS 18

**What goes wrong:** Data appears to be persisted during a session but is lost after force-quit. The autosave event fires at unexpected times or not at all inside async Task closures.

**Why it happens:** iOS 18 introduced internal refactoring that shifted SwiftData away from Core Data's autosave trigger mechanism. Using `.modelContext` environment injection can suppress autosave in some configurations. Apple Developer Forums document multiple cases of this.

**How to avoid:** Disable autosave globally at the container level (`isAutosaveEnabled: false`) and call `try modelContext.save()` explicitly after every mutation.

**Warning signs:** Data present in the running app disappears on relaunch; no crash, no error logged.

### Pitfall 2: Implicit Relationship Inverses Missing

**What goes wrong:** Deleting a `CareTeamMember` does not cascade properly, or adding to a relationship array does not update the inverse side.

**Why it happens:** SwiftData's automatic inverse relationship inference has complex rules: it works for optional-to-optional one-to-one relationships but fails for non-optional ends and for to-many relationships where at least one end is non-optional.

**How to avoid:** Always declare `@Relationship(deleteRule:, inverse:)` explicitly on both sides of every relationship, even when it seems redundant.

**Warning signs:** Orphaned records after deletes; relationship array empty on one side when the other side shows members.

### Pitfall 3: ModelContext Actor Isolation Violations in Swift 6

**What goes wrong:** Swift 6 strict concurrency produces compiler errors when model objects are passed across actors. The error reads "Main actor-isolated conformance cannot be used in actor-isolated context."

**Why it happens:** `@Model` objects and `ModelContext` are not `Sendable`. They cannot cross actor boundaries. `ModelActor`'s `DefaultSerialModelExecutor` behavior is also poorly understood — it assigns the context's actor based on creation context.

**How to avoid:** Only pass `PersistentIdentifier` (the `.id` property) across actor boundaries. Create a separate `ModelContext` inside any `@ModelActor`. Enable complete concurrency checking in Xcode build settings early to catch violations.

**Warning signs:** Compiler warnings in Swift 5 compatibility mode that become errors when Swift 6 strict concurrency is enabled.

### Pitfall 4: Key Rotation Does Not Retroactively Protect Old Records

**What goes wrong:** Developer assumes that rotating the Keychain key will make all existing records unreadable. Existing ciphertext sealed under the old key can still be decrypted by anyone who has the old key material.

**Why it happens:** AES-GCM key rotation replaces the Keychain entry but cannot retroactively re-encrypt existing sealed boxes. The old key may still exist in memory or in a backup.

**How to avoid:** Document this boundary clearly in code: "Rotation guarantees new records are protected. Historical records written under the old key remain readable to anyone who captured the old key before rotation." For v1, this is acceptable — the requirement (SYNC-05) specifies new records only.

**Warning signs:** Test that a record written after rotation cannot be opened with the pre-rotation key; test that records written before rotation still open correctly.

### Pitfall 5: Dynamic Type AX Sizes Break Horizontal Layouts

**What goes wrong:** HStack layouts with text truncate or overflow at AX1–AX5 Dynamic Type sizes, rendering the senior home screen unusable for the exact users it targets.

**Why it happens:** SwiftUI HStacks do not automatically wrap to vertical layouts. At AX5, system font sizes can be 4–5x the default size, making horizontal arrangements impossible.

**How to avoid:** Use `ViewThatFits` to offer both HStack and VStack variants. Test in Simulator with Accessibility Inspector and Dynamic Type set to AX5. Apple's 12 Dynamic Type sizes: xSmall, small, medium, large (default), xLarge, xxLarge, xxxLarge, AX1, AX2, AX3, AX4, AX5.

**Warning signs:** Text truncation at large text sizes; labels cut off by frame constraints.

### Pitfall 6: Invite Code Collision Under Single-Use Assumption

**What goes wrong:** Two simultaneous invite code generations produce the same code string, so the second caregiver's accepted invite accidentally matches the first caregiver's pending code.

**Why it happens:** If the code space is too small (e.g., 4 characters = 1.7M combinations), collision probability becomes meaningful with an active care circle that generates many invites.

**How to avoid:** Use 8 hex characters from UUID (16^8 = ~4.3 billion combinations). UUID is cryptographically random. Mark codes as `isUsed = true` immediately on acceptance and save. Single-use + UUID base prevents collisions in practice.

**Warning signs:** Two caregivers joining in quick succession with the same role and no approval dialog shown.

---

## Code Examples

### SwiftData: Explicit Save with Error Handling

```swift
// Always use do/catch, not try?, so failures are never silently swallowed
func revokeCategoryAndRotateKey(member: CareTeamMember, category: PermissionCategory, context: ModelContext) async throws {
    member.grantedCategories.removeAll { $0 == category }
    member.lastModified = Date()
    do {
        try context.save()
    } catch {
        throw PersistenceError.saveFailed(underlying: error)
    }
    // Key rotation happens after confirmed save
    try EncryptionService.rotateKey(for: category)
}
```

### CryptoKit: Writing an Encrypted Care Record

```swift
// Source: CryptoKit AES-GCM pattern
func writeRecord(plaintext: Data, category: PermissionCategory, authorID: UUID, context: ModelContext) throws {
    let ciphertext = try EncryptionService.seal(plaintext, for: category)
    let record = CareRecord(
        category: category,
        encryptedPayload: ciphertext,
        authorMemberID: authorID
    )
    context.insert(record)
    try context.save()
}
```

### SwiftUI: Invite Screen with Copy and Share

```swift
struct InviteView: View {
    let inviteCode: String  // e.g. "CARE-7F3A-9C2B"

    var body: some View {
        VStack(spacing: 24) {
            Text("Invite a Caregiver")
                .font(.title2).bold()

            Text(inviteCode)
                .font(.system(.largeTitle, design: .monospaced))
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 16) {
                Button {
                    UIPasteboard.general.string = inviteCode
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                ShareLink(item: "Join my care circle with code: \(inviteCode)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
```

### SwiftUI: Permission Toggle with Undo Toast

```swift
struct PermissionToggleRow: View {
    @Binding var isGranted: Bool
    let category: PermissionCategory
    let onRevoke: () -> Void

    @State private var showUndo = false

    var body: some View {
        Toggle(isOn: $isGranted) {
            Text(category.displayName)
                .font(.body)
        }
        .frame(minHeight: 44)
        .onChange(of: isGranted) { _, newValue in
            if !newValue {
                showUndo = true
                onRevoke()
            }
        }
        // Undo toast implemented as overlay or .toast modifier
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Core Data NSManagedObject subclasses | SwiftData @Model macro | WWDC 2023 (iOS 17) | Half the boilerplate, Swift-native, no .xcdatamodeld file |
| UIActivityViewController (UIKit) | ShareLink (SwiftUI) | iOS 16 | No UIViewControllerRepresentable wrapper needed |
| Manual empty state views | ContentUnavailableView | iOS 17 | System-consistent, one line |
| Manual layout switching for large text | ViewThatFits | iOS 16 | Declarative adaptive layout |
| Multipeer Connectivity for P2P | Network framework (NWBrowser/NWListener) | Swift 6 era | MPC is Swift 6-incompatible (documented in STATE.md decisions) |
| CommonCrypto / third-party crypto | CryptoKit | iOS 13 | Apple-native, hardware-accelerated, no dependencies |

**Deprecated/outdated:**
- **Multipeer Connectivity for this project:** Explicitly rejected in STATE.md — MPC is Swift 6-incompatible. Use Network framework in Phase 3.
- **SwiftData autosave:** Treated as unreliable. Documented iOS 18 regression. Disable and use explicit save.
- **Core Data NSManagedObjectID across threads:** In SwiftData, use `PersistentIdentifier` for cross-actor identity instead.

---

## Open Questions

1. **VersionedSchema for Day 1**
   - What we know: SwiftData schema migration requires `VersionedSchema` enums and a `SchemaMigrationPlan`. If not set up from the start, adding versioning later requires treating all existing stores as v1.
   - What's unclear: Whether starting with unversioned schemas and retroactively adding `VersionedSchema` in Phase 2 is safe or risks store corruption.
   - Recommendation: Set up `VersionedSchema` from Phase 1 even if there is only one version, to establish the migration infrastructure before any user data exists.

2. **Keychain key persistence across app reinstall**
   - What we know: By default, Keychain items with `kSecAttrAccessibleAfterFirstUnlock` survive app reinstall on the same device.
   - What's unclear: Whether this is desirable behavior for encryption keys — if a user reinstalls and their data was not backed up, old ciphertext would be decryptable with the surviving key.
   - Recommendation: For Phase 1, allow key persistence. Add a "reset care circle" option in Phase 2 that explicitly deletes Keychain keys.

3. **Proxy/delegate permission scope in the data model**
   - What we know: The `isProxy` flag is on `CareTeamMember`. A proxy can manage permissions and invites on the senior's behalf.
   - What's unclear: Whether proxy capability should be enforced at the model layer or the UI layer. Model-layer enforcement is safer but requires the senior's device to validate proxy actions.
   - Recommendation: Enforce at the UI layer for Phase 1 (proxy sees senior's permission management UI). Document this as a known limitation. Phase 3 sync will need to address multi-device permission authority.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest + Swift Testing (iOS 17+, Swift 5.9+) |
| Config file | None — Wave 0 creates the Xcode project with test target |
| Quick run command | `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests` |
| Full suite command | `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TEAM-01 | Invite code generated is unique and matches expected format | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/InviteCodeTests` | Wave 0 |
| TEAM-02 | Caregiver joins circle by entering valid code; pending request created | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/InviteFlowTests` | Wave 0 |
| TEAM-03 | Care team list shows all members with roles | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CareTeamTests` | Wave 0 |
| TEAM-04 | Removing a member deletes from SwiftData and cascades | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CareTeamTests` | Wave 0 |
| TEAM-05 | Granting a category adds it to member's grantedCategories | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/PermissionTests` | Wave 0 |
| TEAM-06 | Revoking a category removes it from member's grantedCategories | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/PermissionTests` | Wave 0 |
| TEAM-07 | Record written after revocation is not readable with old key | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/EncryptionTests` | Wave 0 |
| TEAM-08 | Caregiver home query returns records sorted by lastModified | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/CaregiverHomeTests` | Wave 0 |
| TEAM-09 | Emergency contact created and readable without permission check | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/EmergencyContactTests` | Wave 0 |
| SYNC-01 | Record inserted and saved is readable after ModelContext re-fetch | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/PersistenceTests` | Wave 0 |
| SYNC-03 | Two records with different lastModified values — later one wins in LWW comparison | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/LWWTests` | Wave 0 |
| SYNC-04 | Sealed data is not equal to plaintext input | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/EncryptionTests` | Wave 0 |
| SYNC-05 | New record after key rotation cannot be opened with pre-rotation key | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/EncryptionTests` | Wave 0 |
| SYNC-08 | CareRecord.encryptedPayload is never equal to plaintext bytes | unit | `xcodebuild test ... -only-testing:AgingInPlaceTests/EncryptionTests` | Wave 0 |
| SENR-01 | Senior home cards have frame minHeight >= 44 | manual | — | manual-only: requires Accessibility Inspector |
| SENR-02 | System colors pass WCAG AAA | manual | — | manual-only: use Accessibility Inspector color contrast tool |
| SENR-03 | Primary actions reachable in ≤ 2 taps from home screen | manual | — | manual-only: navigation depth count |
| SENR-04 | Senior home screen shows summary cards for all 4 categories | unit + visual | `xcodebuild test ... -only-testing:AgingInPlaceTests/SeniorHomeTests` | Wave 0 |

**Note on SENR-01/02/03:** These require human judgment with Accessibility Inspector in Xcode. Run the Accessibility Audit (`Product > Accessibility Inspector > Audit`) before phase gate verification.

### Sampling Rate

- **Per task commit:** Run encryption and persistence unit tests: `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AgingInPlaceTests/EncryptionTests -only-testing:AgingInPlaceTests/PersistenceTests`
- **Per wave merge:** Full suite: `xcodebuild test -scheme AgingInPlace -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Phase gate:** Full suite green + manual Accessibility Inspector audit before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `AgingInPlace.xcodeproj` — Xcode project does not yet exist; Wave 0 creates it with iOS 17 deployment target, Swift 6 strict concurrency enabled
- [ ] `AgingInPlaceTests/EncryptionTests.swift` — covers SYNC-04, SYNC-05, SYNC-08, TEAM-07
- [ ] `AgingInPlaceTests/PersistenceTests.swift` — covers SYNC-01; uses in-memory ModelContainer for fast test execution
- [ ] `AgingInPlaceTests/InviteCodeTests.swift` — covers TEAM-01
- [ ] `AgingInPlaceTests/InviteFlowTests.swift` — covers TEAM-02
- [ ] `AgingInPlaceTests/CareTeamTests.swift` — covers TEAM-03, TEAM-04
- [ ] `AgingInPlaceTests/PermissionTests.swift` — covers TEAM-05, TEAM-06
- [ ] `AgingInPlaceTests/EmergencyContactTests.swift` — covers TEAM-09
- [ ] `AgingInPlaceTests/LWWTests.swift` — covers SYNC-03 (LWW timestamp comparison logic)
- [ ] `AgingInPlaceTests/CaregiverHomeTests.swift` — covers TEAM-08
- [ ] `AgingInPlaceTests/SeniorHomeTests.swift` — covers SENR-04

**In-memory ModelContainer for tests:**
```swift
// Use in test setUp to avoid polluting persistent store
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: CareCircle.self, ..., configurations: config)
let context = ModelContext(container)
```

---

## Sources

### Primary (HIGH confidence)
- Apple SwiftData documentation — `@Model`, `@Relationship`, `ModelContext`, `ModelContainer`, explicit save, autosave
- Apple CryptoKit documentation — `AES.GCM`, `SymmetricKey`, `SealedBox`
- Apple Security framework documentation — `SecItemAdd`, `SecItemCopyMatching`, `kSecClassGenericPassword`
- [Storing CryptoKit Keys in the Keychain](https://developer.apple.com/documentation/cryptokit/storing-cryptokit-keys-in-the-keychain) — official Apple article
- [Hacking with Swift — SwiftData autosave](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-enable-or-disable-autosave-for-a-modelcontext) — verified against official behavior
- [Hacking with Swift — SwiftData save](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-save-a-swiftdata-object) — explicit save pattern
- [Hacking with Swift — SwiftData concurrency](https://www.hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency) — ModelContainer/PersistentIdentifier sendability
- [Apple Developer Documentation — ShareLink](https://developer.apple.com/documentation/SwiftUI/ShareLink) — native share sheet
- [Apple Developer Documentation — DynamicTypeSize](https://developer.apple.com/documentation/swiftui/dynamictypesize) — 12 Dynamic Type sizes

### Secondary (MEDIUM confidence)
- [fatbobman.com — SwiftData Relationships Changes and Considerations](https://fatbobman.com/en/posts/relationships-in-swiftdata-changes-and-considerations/) — array performance crisis and inverse relationship pitfalls; corroborated by Apple Developer Forums reports
- [Apple Developer Forums — Swift 6 SwiftData save crashes](https://developer.apple.com/forums/thread/761618) — iOS 18 autosave regression; corroborated by multiple forum threads
- [Apple Developer Forums — iOS 18 SwiftData ModelContext reset](https://developer.apple.com/forums/thread/757521) — ModelActor context lifecycle issues
- [Hacking with Swift — AES-GCM encryption](https://dev.to/craftzdog/how-to-encrypt-decrypt-with-aes-gcm-using-cryptokit-in-swift-24h1) — AES-GCM nonce + tag + ciphertext combined format

### Tertiary (LOW confidence)
- WebSearch results on CRDT/LWW iOS patterns — referenced for Phase 3 preparation context only; not required for Phase 1 implementation

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all core APIs are Apple-native frameworks with official documentation
- Architecture: HIGH — patterns derived from official Apple docs and verified community sources; iOS 18 pitfalls confirmed by Apple Developer Forums
- Pitfalls: HIGH for SwiftData autosave and relationship issues (developer forum evidence); MEDIUM for actor isolation (confirmed behavior, implementation nuance may vary)
- Encryption design: HIGH — AES-GCM + Keychain is the documented Apple-recommended pattern for on-device PHI

**Research date:** 2026-03-18
**Valid until:** 2026-09-18 (stable Apple frameworks; re-verify if iOS 19 beta introduces SwiftData changes)
