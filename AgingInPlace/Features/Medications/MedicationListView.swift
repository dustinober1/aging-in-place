import SwiftUI
import SwiftData

/// Main medications screen with two sections: active schedules and medication history.
/// Schedules: sorted by drug name, filtered to isActive == true, swipe to deactivate.
/// History: sorted by administeredAt descending, decrypted payload displayed per row.
struct MedicationListView: View {
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<MedicationSchedule> { $0.isActive == true },
        sort: \MedicationSchedule.drugName
    )
    private var activeSchedules: [MedicationSchedule]

    @Query(sort: \MedicationLog.administeredAt, order: .reverse)
    private var medicationLogs: [MedicationLog]

    @Query private var members: [CareTeamMember]

    @State private var showingAddSchedule = false
    @State private var showingLogDose = false
    @State private var scheduleForLogging: MedicationSchedule?

    var body: some View {
        NavigationStack {
            List {
                schedulesSection
                historySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Medications")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingLogDose = true
                        scheduleForLogging = nil
                    } label: {
                        Label("Log Dose", systemImage: "plus.circle")
                    }
                    .frame(minWidth: A11y.minTouchTarget, minHeight: A11y.minTouchTarget)
                    .accessibilityLabel("Log a medication dose")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSchedule = true
                    } label: {
                        Label("Add Schedule", systemImage: "plus")
                    }
                    .frame(minWidth: A11y.minTouchTarget, minHeight: A11y.minTouchTarget)
                    .accessibilityLabel("Add medication schedule")
                }
            }
            .sheet(isPresented: $showingAddSchedule) {
                MedicationScheduleView()
            }
            .sheet(isPresented: $showingLogDose) {
                LogMedicationView(schedule: scheduleForLogging)
            }
        }
    }

    // MARK: - Schedules Section

    private var schedulesSection: some View {
        Section {
            if activeSchedules.isEmpty {
                ContentUnavailableView(
                    "No Schedules",
                    systemImage: "pill.circle",
                    description: Text("Tap + to create a recurring medication schedule.")
                )
                .frame(minHeight: 100)
                .listRowInsets(EdgeInsets())
            } else {
                ForEach(activeSchedules) { schedule in
                    ScheduleRow(schedule: schedule)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            scheduleForLogging = schedule
                            showingLogDose = true
                        }
                        .frame(minHeight: A11y.minTouchTarget)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deactivateSchedule(schedule)
                            } label: {
                                Label("Deactivate", systemImage: "bell.slash")
                            }
                        }
                        .accessibilityLabel("\(schedule.drugName), \(schedule.dose), scheduled at \(formattedTime(schedule)). Swipe to deactivate.")
                        .accessibilityHint("Tap to log a dose for this schedule")
                }
            }
        } header: {
            Text("Schedules")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        Section {
            if medicationLogs.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Logged doses will appear here.")
                )
                .frame(minHeight: 100)
                .listRowInsets(EdgeInsets())
            } else {
                ForEach(medicationLogs) { log in
                    HistoryRow(log: log, members: members)
                        .frame(minHeight: A11y.minTouchTarget)
                }
            }
        } header: {
            Text("History")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Actions

    private func deactivateSchedule(_ schedule: MedicationSchedule) {
        schedule.isActive = false
        schedule.lastModified = Date()
        try? context.save()
        // Cancel recurring reminder for this schedule
        let identifier = "med-reminder-\(schedule.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Helpers

    private func formattedTime(_ schedule: MedicationSchedule) -> String {
        var components = DateComponents()
        components.hour = schedule.scheduledHour
        components.minute = schedule.scheduledMinute
        guard let date = Calendar.current.date(from: components) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Schedule Row

private struct ScheduleRow: View {
    let schedule: MedicationSchedule

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pill.fill")
                .font(.body)
                .frame(width: A11y.minTouchTarget, height: A11y.minTouchTarget)
                .foregroundStyle(Color.accentColor)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.drugName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
                Text(schedule.dose)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Text(formattedTime)
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(.vertical, 4)
    }

    private var formattedTime: String {
        var components = DateComponents()
        components.hour = schedule.scheduledHour
        components.minute = schedule.scheduledMinute
        guard let date = Calendar.current.date(from: components) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let log: MedicationLog
    let members: [CareTeamMember]

    private var authorName: String {
        members.first(where: { $0.id == log.authorMemberID })?.displayName ?? "Unknown"
    }

    /// Decrypted payload fields. Returns nil if decryption fails.
    private var decryptedPayload: (drugName: String, dose: String)? {
        guard let plaintext = try? EncryptionService.open(log.encryptedPayload, for: .medications),
              let json = try? JSONDecoder().decode(MedPayload.self, from: plaintext) else {
            return nil
        }
        return (json.drugName, json.dose)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .frame(width: A11y.minTouchTarget, height: A11y.minTouchTarget)
                .foregroundStyle(Color.green)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                if let payload = decryptedPayload {
                    Text(payload.drugName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primary)
                    Text("\(payload.dose) · by \(authorName)")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                } else {
                    Text("Encrypted")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    Text("by \(authorName)")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }

            Spacer()

            Text(log.administeredAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            if let payload = decryptedPayload {
                return "\(payload.drugName) \(payload.dose) logged by \(authorName), \(log.administeredAt.formatted(.relative(presentation: .named)))"
            } else {
                return "Medication logged by \(authorName), \(log.administeredAt.formatted(.relative(presentation: .named)))"
            }
        }())
    }

    // Codable struct for decryption — mirrors the struct used in LogMedicationView
    private struct MedPayload: Codable {
        let drugName: String
        let dose: String
        let notes: String
    }
}

// MARK: - UserNotifications import for deactivation

import UserNotifications

#Preview {
    MedicationListView()
        .modelContainer(
            for: [MedicationSchedule.self, MedicationLog.self, CareTeamMember.self],
            inMemory: true
        )
}
