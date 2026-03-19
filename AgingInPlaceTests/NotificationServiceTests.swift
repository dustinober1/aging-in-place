import XCTest
import UserNotifications
@testable import AgingInPlace

final class NotificationServiceTests: XCTestCase {

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        // Request authorization (provisional to avoid blocking system dialog in tests)
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .provisional]
        )
        // Clear all pending notifications before each test
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        // Small delay to let removals take effect
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
    }

    override func tearDown() async throws {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeMedicationSchedule(
        drugName: String = "Metformin",
        dose: String = "500mg",
        hour: Int = 8,
        minute: Int = 0,
        missedWindowMinutes: Int = 30
    ) -> MedicationSchedule {
        MedicationSchedule(
            drugName: drugName,
            dose: dose,
            hour: hour,
            minute: minute,
            missedWindowMinutes: missedWindowMinutes,
            createdByMemberID: UUID()
        )
    }

    private func makeCalendarEvent(
        title: String = "Doctor Visit",
        minutesFromNow: Double = 120,
        reminderOffsetMinutes: Int = 60
    ) -> CalendarEvent {
        let payload = try! EncryptionService.seal(
            "{\"location\":\"Clinic\"}".data(using: .utf8)!,
            for: .calendar
        )
        return CalendarEvent(
            title: title,
            eventDate: Date().addingTimeInterval(minutesFromNow * 60),
            reminderOffsetMinutes: reminderOffsetMinutes,
            encryptedPayload: payload,
            createdByMemberID: UUID()
        )
    }

    // MARK: - Medication Reminder (MEDS-02)

    func testScheduleMedicationReminderCreatesCorrectIdentifier() async throws {
        let schedule = makeMedicationSchedule()
        let expectedID = "med-reminder-\(schedule.id.uuidString)"

        try await NotificationService.scheduleMedicationReminder(for: schedule)

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let found = pending.first { $0.identifier == expectedID }
        XCTAssertNotNil(found, "Expected pending notification with identifier '\(expectedID)'")
    }

    func testScheduleMedicationReminderUsesCalendarTriggerWithRepeats() async throws {
        let schedule = makeMedicationSchedule(hour: 9, minute: 30)
        try await NotificationService.scheduleMedicationReminder(for: schedule)

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let req = pending.first { $0.identifier == "med-reminder-\(schedule.id.uuidString)" }
        XCTAssertNotNil(req)

        let trigger = try XCTUnwrap(req?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats, "Medication reminder trigger should repeat daily")
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
    }

    func testScheduleMedicationReminderUsesTimeSensitiveInterruptionLevel() async throws {
        let schedule = makeMedicationSchedule()
        try await NotificationService.scheduleMedicationReminder(for: schedule)

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let req = pending.first { $0.identifier == "med-reminder-\(schedule.id.uuidString)" }
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.content.interruptionLevel, .timeSensitive)
    }

    func testScheduleMedicationReminderUsesGenericTitle() async throws {
        let schedule = makeMedicationSchedule(drugName: "Lisinopril")
        try await NotificationService.scheduleMedicationReminder(for: schedule)

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let req = pending.first { $0.identifier == "med-reminder-\(schedule.id.uuidString)" }
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.content.title, "Medication Reminder")
        // Drug name in body is acceptable per research — not PHI in isolation
        XCTAssertTrue(req?.content.body.contains("Lisinopril") == true)
    }

    // MARK: - Missed Dose Alert (MEDS-05)

    func testScheduleMissedDoseAlertCreatesCorrectIdentifier() async throws {
        let schedule = makeMedicationSchedule()
        let date = Date()
        let dateKey = ISO8601DateFormatter().string(from: date).prefix(10)
        let expectedID = "med-missed-\(schedule.id.uuidString)-\(dateKey)"

        try await NotificationService.scheduleMissedDoseAlert(for: schedule, onDate: date)

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let found = pending.first { $0.identifier == expectedID }
        XCTAssertNotNil(found, "Expected pending notification with identifier '\(expectedID)'")
    }

    func testScheduleMissedDoseAlertUsesTimeIntervalTriggerNoRepeat() async throws {
        let schedule = makeMedicationSchedule(missedWindowMinutes: 30)
        let date = Date()
        let dateKey = ISO8601DateFormatter().string(from: date).prefix(10)

        try await NotificationService.scheduleMissedDoseAlert(for: schedule, onDate: date)

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let req = pending.first { $0.identifier == "med-missed-\(schedule.id.uuidString)-\(dateKey)" }
        XCTAssertNotNil(req)

        let trigger = try XCTUnwrap(req?.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertFalse(trigger.repeats, "Missed dose alert should not repeat")
    }

    func testCancelMissedDoseAlertRemovesIdentifier() async throws {
        let schedule = makeMedicationSchedule()
        let date = Date()
        let dateKey = ISO8601DateFormatter().string(from: date).prefix(10)
        let expectedID = "med-missed-\(schedule.id.uuidString)-\(dateKey)"

        try await NotificationService.scheduleMissedDoseAlert(for: schedule, onDate: date)

        // Verify it was added
        var pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        XCTAssertTrue(pending.contains { $0.identifier == expectedID })

        // Cancel it
        NotificationService.cancelMissedDoseAlert(for: schedule, onDate: date)
        try await Task.sleep(nanoseconds: 100_000_000)

        pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        XCTAssertFalse(pending.contains { $0.identifier == expectedID },
                       "Missed dose alert should have been cancelled")
    }

    // MARK: - Appointment Reminder (CALR-03)

    func testScheduleAppointmentReminderCreatesCorrectIdentifier() async throws {
        let event = makeCalendarEvent()
        let expectedID = "cal-reminder-\(event.id.uuidString)"

        try await NotificationService.scheduleAppointmentReminder(for: event)

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let found = pending.first { $0.identifier == expectedID }
        XCTAssertNotNil(found, "Expected pending notification with identifier '\(expectedID)'")
    }

    func testScheduleAppointmentReminderUsesCorrectTriggerInterval() async throws {
        let event = makeCalendarEvent(minutesFromNow: 120, reminderOffsetMinutes: 60)
        try await NotificationService.scheduleAppointmentReminder(for: event)

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let req = pending.first { $0.identifier == "cal-reminder-\(event.id.uuidString)" }
        XCTAssertNotNil(req)

        let trigger = try XCTUnwrap(req?.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertFalse(trigger.repeats, "Appointment reminder should not repeat")
        // Trigger should fire ~60 minutes from now (120 - 60 = 60 min = 3600s)
        XCTAssertEqual(trigger.timeInterval, 3600.0, accuracy: 10.0)
    }

    func testCancelAppointmentReminderRemovesIdentifier() async throws {
        let event = makeCalendarEvent()
        let expectedID = "cal-reminder-\(event.id.uuidString)"

        try await NotificationService.scheduleAppointmentReminder(for: event)

        // Verify it was added
        var pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        XCTAssertTrue(pending.contains { $0.identifier == expectedID })

        // Cancel it
        NotificationService.cancelAppointmentReminder(for: event)
        try await Task.sleep(nanoseconds: 100_000_000)

        pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        XCTAssertFalse(pending.contains { $0.identifier == expectedID },
                       "Appointment reminder should have been cancelled")
    }

    func testScheduleAppointmentReminderSkipsPastEvents() async throws {
        // Event in the past — should not schedule
        let payload = try EncryptionService.seal(
            "{}".data(using: .utf8)!,
            for: .calendar
        )
        let pastEvent = CalendarEvent(
            title: "Past Appointment",
            eventDate: Date().addingTimeInterval(-3600), // 1 hour ago
            reminderOffsetMinutes: 60,
            encryptedPayload: payload,
            createdByMemberID: UUID()
        )
        try await NotificationService.scheduleAppointmentReminder(for: pastEvent)

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let found = pending.first { $0.identifier == "cal-reminder-\(pastEvent.id.uuidString)" }
        XCTAssertNil(found, "Past event should not have a scheduled notification")
    }

    func testScheduleAppointmentReminderContentUsesGenericTitle() async throws {
        let event = makeCalendarEvent(title: "Physical Therapy")
        try await NotificationService.scheduleAppointmentReminder(for: event)

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let req = pending.first { $0.identifier == "cal-reminder-\(event.id.uuidString)" }
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.content.title, "Upcoming Appointment")
        XCTAssertTrue(req?.content.body.contains("Physical Therapy") == true)
    }
}
