# Aging in Place — Caregiver Coordination Ecosystem

## What This Is

A native SwiftUI app (iOS, iPadOS, watchOS) that lets families coordinate care for an elderly relative without centralized servers or cloud databases. Caregivers log medications, mood observations, visit notes, and vital signs (via Apple Watch HealthKit). Devices sync care logs locally using Multipeer Connectivity when in proximity, with an optional encrypted relay (iCloud or home hub device) for remote access. The senior remains in control of their own data and decides who on their care team can see what.

## Core Value

All caregivers see the same up-to-date care log without anyone calling, texting, or emailing to coordinate — eliminating the communication tax that burns out family care teams.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Medication logging and scheduling with reminders
- [ ] Mood observation logging (by senior and caregivers)
- [ ] Apple Watch vital signs via HealthKit (heart rate, blood oxygen, etc.)
- [ ] Care visit notes from caregivers (meals, mobility, observations)
- [ ] Fall detection event surfacing from Apple Watch to care team
- [ ] Local peer-to-peer sync via Multipeer Connectivity
- [ ] Optional encrypted relay for remote sync (iCloud or home hub)
- [ ] Senior-controlled permissions (per-person access grants)
- [ ] Simplified senior UI on iPhone/iPad (large text, clear navigation)
- [ ] Apple Watch companion for quick input (mood, medication confirmation)
- [ ] Unbounded care team support (family, paid aides, nurses)

### Out of Scope

- Android/cross-platform — Apple ecosystem only for v1
- Camera-based monitoring — privacy-first approach, no video
- Telehealth/video calls — focus is on asynchronous care coordination
- HIPAA-compliant cloud backend — the local-first architecture deliberately avoids this
- Real-time chat — async care logs, not messaging
- Smart pill dispenser integration — v1 uses manual medication confirmation

## Context

- The US faces a projected shortage of 151,000 paid direct care workers by 2030, with 3.8 million unpaid family caregivers bearing the burden
- Traditional care coordination relies on group texts, shared spreadsheets, or expensive HIPAA-compliant platforms — all inadequate
- Seniors reject camera-based monitoring for dignity/privacy reasons
- The local-first P2P architecture keeps infrastructure costs near zero and avoids HIPAA compliance overhead for cloud-stored PHI
- Apple Watch adoption among seniors is growing, driven by health features and fall detection

## Constraints

- **Platform**: Native SwiftUI — iOS 17+, watchOS 10+ minimum targets
- **Privacy**: No centralized server storing PHI; all data stays on-device or syncs P2P
- **Sync**: Multipeer Connectivity for local sync; optional iCloud/home hub relay for remote
- **Accessibility**: Senior-facing UI must meet or exceed WCAG AAA for text size and contrast
- **Care team size**: Architecture must handle unbounded participants (not just 2-4)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Apple ecosystem only | HealthKit + Multipeer Connectivity are native; cross-platform would require compromises on P2P sync | — Pending |
| Local-first with optional relay | Strict local-only too limiting for caregivers who can't visit daily; relay preserves privacy while enabling remote access | — Pending |
| Senior controls permissions | Preserves dignity and autonomy; senior (or designated proxy) decides who sees what | — Pending |
| Native SwiftUI | Best performance, native Watch support, direct HealthKit/Multipeer access | — Pending |

---
*Last updated: 2026-03-18 after initialization*
