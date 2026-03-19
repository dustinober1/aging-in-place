# Requirements: Aging in Place — Caregiver Coordination

**Defined:** 2026-03-18
**Core Value:** All caregivers see the same up-to-date care log without anyone calling, texting, or emailing to coordinate

## v1 Requirements

### Care Team

- [x] **TEAM-01**: Senior or proxy can invite new care team members via shareable code or link
- [x] **TEAM-02**: Invited caregiver can accept invitation and join the care circle
- [x] **TEAM-03**: Senior can view all current care team members and their roles
- [x] **TEAM-04**: Senior can remove a care team member from the circle
- [x] **TEAM-05**: Senior can grant per-category access permissions to each care team member (e.g., medications yes, mood logs no)
- [x] **TEAM-06**: Senior can revoke a permission category from a care team member at any time
- [x] **TEAM-07**: Permission revocation prevents future access to newly created records in that category
- [x] **TEAM-08**: Caregiver can view a shared care team overview showing recent activity across all members
- [x] **TEAM-09**: Senior or caregiver can store and access emergency contacts and medical ID information

### Medication

- [x] **MEDS-01**: Caregiver or senior can log a medication administration (drug name, dose, time, who administered)
- [x] **MEDS-02**: Caregiver or senior can set up a recurring medication schedule with local push notification reminders
- [ ] **MEDS-03**: Senior can confirm medication taken via Apple Watch with 2 taps
- [x] **MEDS-04**: Caregiver can view medication history showing all administrations with timestamps and who logged them
- [x] **MEDS-05**: Caregiver receives notification if a scheduled medication is not confirmed within a configurable window

### Care Documentation

- [x] **CARE-01**: Caregiver can log a care visit with structured fields (meals, mobility, observations, concerns)
- [x] **CARE-02**: Senior can self-report mood on a simple scale (e.g., 1-5 or emoji)
- [x] **CARE-03**: Caregiver can log observed mood for the senior during a visit
- [ ] **CARE-04**: User can browse full care history with filtering by category, date range, and author
- [ ] **CARE-05**: User can search care logs by keyword

### Health Monitoring

- [ ] **HLTH-01**: App reads heart rate data from senior's Apple Watch via HealthKit
- [ ] **HLTH-02**: App reads blood oxygen data from senior's Apple Watch via HealthKit
- [ ] **HLTH-03**: App reads sleep data from senior's Apple Watch via HealthKit
- [ ] **HLTH-04**: Caregiver can view senior's vital signs summary on their own device (synced)
- [ ] **HLTH-05**: App surfaces historical fall detection events from HealthKit to the care team
- [ ] **HLTH-06**: Senior goes through an explicit HealthKit permission onboarding flow with clear explanation of what is shared

### Sync & Privacy

- [x] **SYNC-01**: All data reads and writes work fully offline on a single device
- [ ] **SYNC-02**: Devices discover and sync care logs over local network via Network framework when in proximity
- [x] **SYNC-03**: Sync resolves concurrent edits using CRDT/LWW merge strategy without data loss
- [x] **SYNC-04**: Each care record is encrypted with per-record keys via CryptoKit
- [x] **SYNC-05**: Permission revocation rotates encryption keys so revoked members cannot decrypt new records
- [ ] **SYNC-06**: Senior can opt in to encrypted iCloud relay for remote caregiver sync
- [ ] **SYNC-07**: Remote caregivers receive synced care logs via CloudKit when relay is enabled
- [x] **SYNC-08**: No PHI is stored unencrypted on any Apple server

### User Experience

- [x] **SENR-01**: Senior-facing UI uses Dynamic Type XXL+ with minimum 44pt touch targets
- [x] **SENR-02**: Senior-facing UI uses high-contrast colors meeting WCAG AAA standards
- [x] **SENR-03**: Senior-facing UI has minimal navigation depth (max 2 taps to any primary action)
- [x] **SENR-04**: Senior can view their own care log, vitals, and upcoming medications on a single home screen

### Apple Watch

- [ ] **WTCH-01**: Watch app displays today's medication schedule with confirm/skip actions
- [ ] **WTCH-02**: Watch app allows mood self-report via simple selector
- [ ] **WTCH-03**: Watch syncs medication confirmations and mood logs to iPhone via WatchConnectivity
- [ ] **WTCH-04**: Watch reads and forwards HealthKit vital signs (HR, SpO2) to iPhone app
- [ ] **WTCH-05**: Watch complication shows next upcoming medication

### Calendar

- [x] **CALR-01**: Caregiver or senior can create appointments (doctor visits, PT, etc.) on a shared calendar
- [ ] **CALR-02**: Shared calendar is visible to all permitted care team members
- [x] **CALR-03**: Appointment reminders are sent as local notifications to relevant care team members

## v2 Requirements

### Notifications & Alerts

- **NOTF-01**: Configurable notification preferences per care team member
- **NOTF-02**: Smart alerts when vital sign trends deviate from baseline
- **NOTF-03**: Weekly care summary digest for remote family members

### Data Export

- **EXPRT-01**: Export care log to PDF for physician visits
- **EXPRT-02**: Export medication history for pharmacy review

### Advanced Features

- **ADV-01**: Trend visualization dashboard for vitals and mood over time
- **ADV-02**: Medication refill tracking and alerts
- **ADV-03**: Caregiver self-care / burnout check-in prompts

## Out of Scope

| Feature | Reason |
|---------|--------|
| Real-time chat / messaging | Duplicates iMessage; async care logs are the communication medium |
| Camera-based monitoring | Rejected by seniors for dignity; undermines privacy-first architecture |
| Telehealth / video calls | Separate technical domain; FaceTime exists natively |
| HIPAA-compliant cloud backend | Destroys core value; $20K+/year compliance overhead |
| Smart pill dispenser integration | Hardware partnerships and scope explosion; manual confirm covers 80% |
| AI-generated care summaries | Requires sending PHI to third-party LLM; violates privacy premise |
| Android / cross-platform | HealthKit and Network framework are Apple-only; web viewer is v2+ |
| Automatic emergency dispatch | Apple Watch already handles SOS; duplicating creates liability |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TEAM-01 | Phase 1 | Complete |
| TEAM-02 | Phase 1 | Complete |
| TEAM-03 | Phase 1 | Complete |
| TEAM-04 | Phase 1 | Complete |
| TEAM-05 | Phase 1 | Complete |
| TEAM-06 | Phase 1 | Complete |
| TEAM-07 | Phase 1 | Complete |
| TEAM-08 | Phase 1 | Complete |
| TEAM-09 | Phase 1 | Complete |
| MEDS-01 | Phase 2 | Complete |
| MEDS-02 | Phase 2 | Complete |
| MEDS-03 | Phase 4 | Pending |
| MEDS-04 | Phase 2 | Complete |
| MEDS-05 | Phase 2 | Complete |
| CARE-01 | Phase 2 | Complete |
| CARE-02 | Phase 2 | Complete |
| CARE-03 | Phase 2 | Complete |
| CARE-04 | Phase 2 | Pending |
| CARE-05 | Phase 2 | Pending |
| HLTH-01 | Phase 5 | Pending |
| HLTH-02 | Phase 5 | Pending |
| HLTH-03 | Phase 5 | Pending |
| HLTH-04 | Phase 5 | Pending |
| HLTH-05 | Phase 5 | Pending |
| HLTH-06 | Phase 5 | Pending |
| SYNC-01 | Phase 1 | Complete |
| SYNC-02 | Phase 3 | Pending |
| SYNC-03 | Phase 3 | Complete |
| SYNC-04 | Phase 1 | Complete |
| SYNC-05 | Phase 1 | Complete |
| SYNC-06 | Phase 6 | Pending |
| SYNC-07 | Phase 6 | Pending |
| SYNC-08 | Phase 1 | Complete |
| SENR-01 | Phase 1 | Complete |
| SENR-02 | Phase 1 | Complete |
| SENR-03 | Phase 1 | Complete |
| SENR-04 | Phase 1 | Complete |
| WTCH-01 | Phase 4 | Pending |
| WTCH-02 | Phase 4 | Pending |
| WTCH-03 | Phase 4 | Pending |
| WTCH-04 | Phase 4 | Pending |
| WTCH-05 | Phase 4 | Pending |
| CALR-01 | Phase 2 | Complete |
| CALR-02 | Phase 2 | Pending |
| CALR-03 | Phase 2 | Complete |

**Coverage:**
- v1 requirements: 45 total
- Mapped to phases: 45
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-18 after roadmap creation*
