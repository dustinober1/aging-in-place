import Foundation
import UserNotifications

/// Manages all local notification scheduling and cancellation.
/// Uses deterministic identifiers keyed to model UUIDs so notifications
/// can be reliably cancelled when confirmed or deleted.
struct NotificationService {

    // MARK: - Permission

    /// Request authorization for alert, sound, and badge notifications.
    /// Returns `true` if granted.
    static func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Medication Schedule Reminder (MEDS-02)

    /// Schedules a recurring daily notification at the schedule's configured hour and minute.
    /// Identifier: `"med-reminder-{schedule.id}"`
    /// Interruption level: `.timeSensitive` — breaks through Focus mode for medication adherence.
    static func scheduleMedicationReminder(for schedule: MedicationSchedule) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Medication Reminder"
        content.body = "\(schedule.drugName) — \(schedule.dose)"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        var dateComponents = DateComponents()
        dateComponents.hour = schedule.scheduledHour
        dateComponents.minute = schedule.scheduledMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = "med-reminder-\(schedule.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Missed Dose Alert (MEDS-05)

    /// Schedules a one-time alert `schedule.missedWindowMinutes` after the given dose time.
    /// Identifier: `"med-missed-{schedule.id}-{YYYY-MM-DD}"`
    /// Cancel this notification when a MedicationLog is written for this schedule + date.
    static func scheduleMissedDoseAlert(
        for schedule: MedicationSchedule,
        onDate date: Date
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Missed Dose Alert"
        content.body = "\(schedule.drugName) was not confirmed within \(schedule.missedWindowMinutes) minutes"
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive

        let fireDate = date.addingTimeInterval(Double(schedule.missedWindowMinutes) * 60)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, fireDate.timeIntervalSinceNow),
            repeats: false
        )
        let dateKey = ISO8601DateFormatter().string(from: date).prefix(10)
        let identifier = "med-missed-\(schedule.id.uuidString)-\(dateKey)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }

    /// Cancels the missed-dose alert for the given schedule and date.
    /// Call this when a MedicationLog confirms the dose was taken.
    static func cancelMissedDoseAlert(for schedule: MedicationSchedule, onDate date: Date) {
        let dateKey = ISO8601DateFormatter().string(from: date).prefix(10)
        let identifier = "med-missed-\(schedule.id.uuidString)-\(dateKey)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Calendar Appointment Reminder (CALR-03)

    /// Schedules a one-time notification `event.reminderOffsetMinutes` before the event.
    /// Identifier: `"cal-reminder-{event.id}"`
    /// Silently skips past events (where fireDate <= now).
    static func scheduleAppointmentReminder(for event: CalendarEvent) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Appointment"
        content.body = "\(event.title) starts in \(event.reminderOffsetMinutes) minutes"
        content.sound = .default
        content.interruptionLevel = .active

        let fireDate = event.eventDate.addingTimeInterval(-Double(event.reminderOffsetMinutes) * 60)
        guard fireDate > Date() else { return }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireDate.timeIntervalSinceNow,
            repeats: false
        )
        let identifier = "cal-reminder-\(event.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }

    /// Cancels the appointment reminder for the given event.
    /// Call this when an event is deleted or rescheduled.
    static func cancelAppointmentReminder(for event: CalendarEvent) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["cal-reminder-\(event.id.uuidString)"]
        )
    }

    // MARK: - Notification Refresh (64-slot limit management)

    /// Removes and re-schedules all active medication reminder notifications.
    /// Call on `scenePhase == .active` to ensure the 64-slot limit is managed correctly.
    static func refreshScheduledNotifications(schedules: [MedicationSchedule]) async throws {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let medReminderIDs = pending
            .filter { $0.identifier.hasPrefix("med-reminder-") }
            .map(\.identifier)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: medReminderIDs)

        for schedule in schedules where schedule.isActive {
            try await scheduleMedicationReminder(for: schedule)
        }
    }
}
