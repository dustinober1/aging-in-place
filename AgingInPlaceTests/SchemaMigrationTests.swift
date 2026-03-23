import XCTest
import SwiftData
@testable import AgingInPlace

final class SchemaMigrationTests: XCTestCase {

    // MARK: - Container helper

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Schema(AgingInPlaceSchemaV3.models),
            migrationPlan: AgingInPlaceMigrationPlan.self,
            configurations: [config]
        )
    }

    // MARK: - Migration smoke test

    func testContainerOpensWithMigrationPlan() throws {
        XCTAssertNoThrow(try makeContainer())
    }

    // MARK: - MedicationSchedule

    func testMedicationScheduleInsertAndFetch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let schedule = MedicationSchedule(
            drugName: "Metformin",
            dose: "500mg",
            hour: 8,
            minute: 0,
            missedWindowMinutes: 30,
            createdByMemberID: memberID
        )
        context.insert(schedule)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MedicationSchedule>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].drugName, "Metformin")
        XCTAssertEqual(fetched[0].dose, "500mg")
        XCTAssertEqual(fetched[0].scheduledHour, 8)
        XCTAssertEqual(fetched[0].scheduledMinute, 0)
        XCTAssertEqual(fetched[0].missedWindowMinutes, 30)
        XCTAssertTrue(fetched[0].isActive)
        XCTAssertEqual(fetched[0].createdByMemberID, memberID)
    }

    // MARK: - MedicationLog

    func testMedicationLogWithEncryptedPayloadRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let payload = try EncryptionService.seal(
            "{\"drugName\":\"Metformin\",\"dose\":\"500mg\",\"notes\":\"\"}".data(using: .utf8)!,
            for: .medications
        )
        let log = MedicationLog(
            scheduleID: nil,
            encryptedPayload: payload,
            administeredAt: Date(),
            authorMemberID: memberID
        )
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MedicationLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].encryptedPayload, payload)
        XCTAssertEqual(fetched[0].authorMemberID, memberID)

        // Verify decryption succeeds
        let decrypted = try EncryptionService.open(fetched[0].encryptedPayload, for: .medications)
        let json = try XCTUnwrap(String(data: decrypted, encoding: .utf8))
        XCTAssertTrue(json.contains("Metformin"))
    }

    // MARK: - CareVisitLog

    func testCareVisitLogWithEncryptedPayloadRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let visitDate = Date()
        let payload = try EncryptionService.seal(
            "{\"meals\":\"oatmeal\",\"mobility\":\"good\",\"observations\":\"alert\",\"concerns\":\"none\"}".data(using: .utf8)!,
            for: .careVisits
        )
        let log = CareVisitLog(
            encryptedPayload: payload,
            visitDate: visitDate,
            authorMemberID: memberID
        )
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CareVisitLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].encryptedPayload, payload)
        XCTAssertEqual(fetched[0].authorMemberID, memberID)
        XCTAssertEqual(fetched[0].visitDate.timeIntervalSince1970,
                       visitDate.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - MoodLog

    func testMoodLogSeniorAuthorType() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let log = MoodLog(
            moodValue: 4,
            authorMemberID: memberID,
            authorType: .senior
        )
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MoodLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].moodValue, 4)
        XCTAssertEqual(fetched[0].authorType, .senior)
    }

    func testMoodLogCaregiverAuthorType() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let log = MoodLog(
            moodValue: 2,
            authorMemberID: memberID,
            authorType: .caregiver
        )
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MoodLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].moodValue, 2)
        XCTAssertEqual(fetched[0].authorType, .caregiver)
    }

    // MARK: - CalendarEvent

    func testCalendarEventRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let eventDate = Date().addingTimeInterval(3600)
        let payload = try EncryptionService.seal(
            "{\"location\":\"Clinic\",\"notes\":\"Annual checkup\",\"attendees\":[]}".data(using: .utf8)!,
            for: .calendar
        )
        let event = CalendarEvent(
            title: "Doctor Appointment",
            eventDate: eventDate,
            reminderOffsetMinutes: 60,
            encryptedPayload: payload,
            createdByMemberID: memberID
        )
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CalendarEvent>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Doctor Appointment")
        XCTAssertEqual(fetched[0].reminderOffsetMinutes, 60)
        XCTAssertEqual(fetched[0].encryptedPayload, payload)
    }

    // MARK: - Phase 1 model backward compatibility

    func testPhase1ModelsStillInsertableAfterV2Migration() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let circle = CareCircle(seniorName: "Alice", seniorDeviceID: "device-001")
        context.insert(circle)

        let member = CareTeamMember(displayName: "Bob", role: .family)
        context.insert(member)

        let payload = try EncryptionService.seal(
            "{\"note\":\"test\"}".data(using: .utf8)!,
            for: .medications
        )
        let record = CareRecord(
            category: .medications,
            encryptedPayload: payload,
            authorMemberID: member.id
        )
        context.insert(record)

        let invite = InviteCode(code: "CARE-TEST-1234", circle: circle)
        context.insert(invite)

        let emergency = EmergencyContact(
            name: "Dr. Smith",
            phone: "555-1234",
            relationship: "Primary Doctor"
        )
        context.insert(emergency)

        try context.save()

        let circles = try context.fetch(FetchDescriptor<CareCircle>())
        let members = try context.fetch(FetchDescriptor<CareTeamMember>())
        let records = try context.fetch(FetchDescriptor<CareRecord>())
        let invites = try context.fetch(FetchDescriptor<InviteCode>())
        let contacts = try context.fetch(FetchDescriptor<EmergencyContact>())

        XCTAssertEqual(circles.count, 1)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(invites.count, 1)
        XCTAssertEqual(contacts.count, 1)
    }
}
