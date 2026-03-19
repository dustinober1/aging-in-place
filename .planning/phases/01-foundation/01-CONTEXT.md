# Phase 1: Foundation - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Data model, care team identity, per-record encryption design, SwiftData persistence, and senior UI as a first-class design constraint. Every subsequent phase builds on this without requiring architectural rewrites. This phase delivers: care team invite/join/remove, per-category permissions with key rotation, senior-facing home screen, and offline persistence.

</domain>

<decisions>
## Implementation Decisions

### Care Team Invitation Flow
- Shareable alphanumeric code (e.g., "CARE-7X9K") — senior can read aloud, text, or show on screen
- Single-use: each code works for one caregiver only
- No expiry — code stays valid until used or manually cancelled by the senior
- Senior must approve: caregiver enters code, senior sees pending request and taps to confirm
- Copy and Share sheet buttons on the invite screen

### Senior Home Screen Design
- Large card layout — one column, scrollable, big tappable cards for each section (Medications, Mood, Care Team, Calendar)
- Each card shows a quick summary (e.g., "Next: Metformin 2pm")
- iOS system default colors — standard system colors, Dynamic Type, automatic Dark Mode and accessibility adaptation
- Personalized greeting: "Good morning/afternoon/evening, [Name]" — time-of-day oriented
- Separate home screens for senior vs caregiver — each optimized for their primary tasks

### Permission Categories & Defaults
- 4 permission categories: Medications, Mood, Care Visits, Calendar (Vitals added in Phase 5)
- New care team members get all categories granted by default (opt-out model)
- Permissions managed from care team member detail screen — tap person, see toggles
- Immediate toggle with brief "Undo" toast (like iOS Mail delete) — key rotation happens in background
- Revoked categories hidden entirely from caregiver's view (no "locked" indicators)
- Emergency contacts and medical ID always visible to all care team members regardless of permissions
- No audit trail for v1 — permissions are the trust boundary
- Senior can designate one proxy/delegate who can manage permissions and invites on their behalf

### Care Team Roles & Structure
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

</decisions>

<specifics>
## Specific Ideas

- Senior home screen mockup approved: greeting header + large single-column cards showing Medications, Mood, Care Team sections with summary text
- Permission UI mockup approved: member detail screen with "Can see:" header and toggle rows per category, plus "Remove from team" at bottom
- Care team list shows role labels next to names (e.g., "Sarah — Family", "Maria — Paid Aide")

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- None yet — Phase 1 establishes the patterns all subsequent phases follow
- iOS system colors and Dynamic Type are the foundation for all UI

### Integration Points
- SwiftData models created here will be used by every subsequent phase
- Per-record encryption design must support the 4 permission categories (expandable to 5+ in Phase 5)
- Care team identity model must support the proxy/delegate concept
- Invite code generation and validation must work offline (no server)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-03-18*
