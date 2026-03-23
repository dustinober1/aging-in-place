# AgingInPlace App Store Launch Design

## Overview

Four-phase plan to take the AgingInPlace iOS app from its current local-only state to a fully synced, polished App Store release. The app coordinates care for seniors aging in place, connecting seniors with their caregivers through a shared care circle.

**Current state (Phases 1-2 complete):** SwiftUI + SwiftData app with role-based home screens, encrypted care records (AES-GCM per category), medication tracking, mood logging, care visit logging, calendar/appointments, care history browser, emergency contacts, invite code system, LWW conflict resolution, and 17 test files. All data is local — no sync, no auth, no real onboarding.

**Target state:** App Store 1.0 with CloudKit sync, iCloud-based identity, polished UX, and full accessibility.

## Architecture Decisions

- **Backend:** CloudKit (CKShare private shared zones) — no Firebase, no custom backend
- **Auth:** iCloud identity — no separate account system
- **Sync strategy:** NSPersistentCloudKitContainer via SwiftData's native CloudKit backing
- **Encryption:** Existing AES-GCM per-category encryption preserved; keys distributed to caregivers via app-generated asymmetric key pairs stored in CloudKit
- **Conflict resolution:** Existing LWW (Last-Writer-Wins) pattern with CloudKit server change tokens for ordering
- **Approach:** CloudKit first (Approach A) — solve the hardest technical risk first, then identity, then polish

## Phase 3: CloudKit + CKShare Integration

### Goal

Sync the senior's care data to all caregiver devices via CloudKit shared zones while preserving the existing encryption model.

### Architecture

- `NSPersistentCloudKitContainer` replaces the current pure `ModelContainer`. SwiftData supports CloudKit backing natively via `ModelConfiguration` with a CloudKit container identifier.
- The senior's device owns a CKShare private zone. When a caregiver joins the care circle, they become a participant on the share — Apple handles the iCloud identity handshake.
- `CareRecord.encryptedPayload` stays as-is — CloudKit syncs the opaque bytes. Decryption keys are shared via a separate secure channel (Phase 4).

### Key Changes to Existing Code

- **`AgingInPlaceApp.swift`** — `ModelConfiguration` gains a `cloudKitContainerIdentifier` pointing to the iCloud container (e.g., `iCloud.com.agingInPlace.app`).
- **`CareCircle`** becomes the root record of the shared zone. Currently `CareCircle` only has relationships to `CareTeamMember` and `InviteCode`. A new `@Relationship(deleteRule: .cascade, inverse: \CareRecord.circle)` from `CareCircle` to `[CareRecord]` must be added, along with a `circle: CareCircle?` property on `CareRecord`. This requires a **schema migration from V2 to V3**. Once linked, members, invites, and care records all sync via the shared zone.
- **`InviteCode` system** evolves to generate `CKShare` URLs instead of local codes. `InviteFlowView` and `JoinCircleView` adapt to use `UICloudSharingController`.
- **Conflict resolution:** Existing `LWWResolver` maps to CloudKit merge semantics. Records carry `lastModified` timestamps — LWW strategy stays, with CloudKit server change tokens providing ordering.

### New Components

- **`CloudKitSyncMonitor`** — Observable object tracking sync state (syncing, synced, error) for UI feedback.
- **`SharingService`** — Wraps `CKShare` creation, participant management, and share acceptance.
- **Entitlements update** — Add CloudKit capability and iCloud container.

### What Stays the Same

- All SwiftData `@Model` classes keep their current shape except `CareCircle` and `CareRecord` (new relationship, see above).
- Encryption/decryption logic is unchanged.
- All existing views continue to work — they query SwiftData the same way.

## Phase 4: Identity & Onboarding

### Goal

Replace the bare role-selection screen with a guided onboarding flow backed by iCloud identity.

### Authentication

- iCloud account = identity. Use `CKContainer.default().fetchUserRecordID()` for the user's CloudKit record ID, and `discoverUserIdentity()` for their name (with permission).
- The current `@AppStorage("userRole")` and `@AppStorage("caregiverName")` pattern evolves into a `UserProfile` model persisted in SwiftData, linked to the iCloud record ID.

### New Model

- **`UserProfile`** — iCloud record ID, display name, role, avatar (optional), notification preferences. One per device, acts as the local identity anchor.

### Onboarding Flow (4 Screens)

1. **Welcome** — App name, value proposition, "Continue with iCloud" button. Checks iCloud availability, shows error if not signed in.
2. **Role selection** — "I am the senior" / "I am a caregiver". Writes to `UserProfile` instead of `@AppStorage`.
3. **Profile setup** — Name entry (pre-filled from iCloud if permission granted), optional photo.
4. **Care circle** — Seniors create a new circle. Caregivers join via share link.

### Key Changes

- **`RootView`** — Checks for existence of `UserProfile` instead of `@AppStorage` string. No profile = onboarding. Has profile = appropriate home screen.
- **`CareTeamMember.id`** links to `UserProfile`'s iCloud record ID instead of random UUID, so the same person is recognized across devices.
- **Invite flow** transitions from local invite codes to `UICloudSharingController` share acceptance.

### Key Encryption: Key Distribution

- When a caregiver joins via CKShare, they can read CloudKit records but still need decryption keys.
- **Key pair generation:** Each device generates a `SecKey` P-256 key pair on first launch. The public key is stored in a `DevicePublicKey` record in the shared zone (linked to the user's `CareTeamMember`). The private key stays in the local Keychain.
- **Key exchange flow:** When a caregiver joins, the senior's device reads the caregiver's public key from the shared zone, encrypts each per-category `SymmetricKey` with it using ECIES (via `SecKeyCreateEncryptedData`), and writes the encrypted keys as a `KeyExchange` record. The caregiver's device decrypts with its local private key.
- `KeychainService` gains `importKey(for:)` (caregiver side) and `exportEncryptedKey(for:recipientPublicKey:)` (senior side) methods.
- **Fallback:** If the automated exchange fails, support manual key transfer via QR code displayed on the senior's device and scanned by the caregiver.

### What Stays the Same

- Encryption service logic is unchanged — just the key distribution is new.
- Home screens keep their current structure.
- All feature views (meds, mood, visits, calendar) are unaffected.

## Phase 5: UX Polish

### Goal

Bring the app to App Store quality with polished design, full accessibility, and a settings screen.

### Visual Design Refresh

- **Color system** — Custom `ColorPalette` in the asset catalog with semantic colors (primary, secondary, accent, category-specific tints). Replace hardcoded color references with named palette colors.
- **Typography** — Standardize on a type scale, applied consistently via a `DesignConstants` enum (extending the existing `A11y` pattern).
- **Card components** — Unify `SummaryCardContent`, `ActivityRow`, `QuickActionLabel` into a shared card style system.
- **Subtle animations** — `.animation(.spring)` transitions for card appearances and data updates. Functional, not decorative.

### Settings/Profile Screen

- Accessible from both home screens via toolbar gear icon.
- Sections: profile (name, role), notifications (toggle per category), care circle management (view members, leave circle), data (export, about), sign out / reset.
- No role switching — changing from senior to caregiver requires new circle setup, behind a confirmation flow.

### Accessibility Audit

- Dynamic Type support across all views — audit for truncation and layout breakage at `.accessibility5`.
- VoiceOver pass — ensure all interactive elements have labels, hints, and correct traits.
- Contrast check — WCAG AA compliance (4.5:1 body, 3:1 large text).
- Reduce Motion — respect `accessibilityReduceMotion` for added animations.

### Edge Cases & Error Handling

- iCloud unavailable / signed out — graceful degradation with clear messaging.
- Sync conflict indicators — "Updated on another device" UI.
- Empty states for all list views.
- Network offline banner when CloudKit can't reach the server.

## Phase 6: App Store Prep

### Goal

Meet all App Store Review Guidelines and ship 1.0.

### Required Assets

- App icon (1024x1024 + standard sizes).
- Screenshots for required device sizes (6.7", 6.1", optionally iPad).
- App Store description, keywords, subtitle, promotional text.
- Privacy policy URL (GitHub Pages or similar).

### App Store Review Compliance

- **Privacy Nutrition Label** — Declare CloudKit data usage. Care/medication data may trigger "Health & Fitness" category review.
- **Data deletion** — Settings screen needs "Delete My Data" flow that clears CloudKit shared zone and local SwiftData store.
- **Purpose strings** — Add `NSFaceIDUsageDescription` if biometrics gate key access.
- **No login wall** — Provide a local-only fallback mode for users without iCloud (the current single-device experience).

### Pre-Submission Checklist

- Full test suite passes (17+ test files).
- Test on physical devices (at least 2) for real CloudKit sync.
- Profile with Instruments for memory leaks and performance.
- Verify app works on iOS 17.0 (minimum deployment target).
- TestFlight beta with small group before public submission.

## Phase Dependencies

```
Phase 3 (CloudKit)
    |
    v
Phase 4 (Identity & Onboarding)
    |
    v
Phase 5 (UX Polish)
    |
    v
Phase 6 (App Store Prep)
```

Each phase builds on the previous. Phase 3 must complete before Phase 4 (identity depends on CloudKit). Phase 5 depends on Phase 4 (polish the real onboarding flow). Phase 6 is the final gate.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| CloudKit + SwiftData integration is immature | High | Prototype the sync layer early; fall back to raw CKRecord if SwiftData-CloudKit has gaps |
| CKShare key distribution is complex | Medium | Start with manual key sharing (QR code / AirDrop) as fallback |
| App Store rejection for health-adjacent data | Medium | Avoid HealthKit APIs; frame as "care coordination" not "medical" |
| iCloud unavailability on user devices | Low | Local-only fallback mode preserves current functionality |
