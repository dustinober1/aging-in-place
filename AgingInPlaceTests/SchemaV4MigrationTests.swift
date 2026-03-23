import XCTest
import SwiftData
@testable import AgingInPlace

final class SchemaV4MigrationTests: XCTestCase {

    // MARK: - Container helpers

    private func makeContainer(cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .none) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: cloudKitDatabase)
        return try ModelContainer(
            for: Schema(AgingInPlaceSchemaV4.models),
            migrationPlan: AgingInPlaceMigrationPlan.self,
            configurations: [config]
        )
    }

    // MARK: - Tests

    func testContainerOpensWithV4MigrationPlan() throws {
        XCTAssertNoThrow(try makeContainer(cloudKitDatabase: .none))
    }

    func testCloudKitCompatibleContainerOpens() throws {
        // KEY TEST: All model attributes have defaults, so .automatic must succeed.
        XCTAssertNoThrow(try makeContainer(cloudKitDatabase: .automatic))
    }

    func testExistingModelsStillInsertable() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let circle = CareCircle(seniorName: "Margaret")
        context.insert(circle)

        let member = CareTeamMember(displayName: "Alice", role: .family, circle: circle)
        context.insert(member)

        let payload = try EncryptionService.seal("{\"note\":\"test\"}".data(using: .utf8)!, for: .medications)
        let record = CareRecord(category: .medications, encryptedPayload: payload, authorMemberID: member.id, circle: circle)
        context.insert(record)

        let invite = InviteCode(code: "CARE-V4-0001", circle: circle)
        context.insert(invite)

        let emergency = EmergencyContact(name: "Dr. Patel", phone: "555-9999", relationship: "Primary Doctor")
        context.insert(emergency)

        let schedule = MedicationSchedule(drugName: "Lisinopril", dose: "10mg", hour: 9, minute: 0, createdByMemberID: member.id)
        context.insert(schedule)

        let medPayload = try EncryptionService.seal("{\"drugName\":\"Lisinopril\",\"dose\":\"10mg\",\"notes\":\"\"}".data(using: .utf8)!, for: .medications)
        let medLog = MedicationLog(encryptedPayload: medPayload, administeredAt: Date(), authorMemberID: member.id)
        context.insert(medLog)

        let visitPayload = try EncryptionService.seal("{\"meals\":\"oatmeal\",\"mobility\":\"good\",\"observations\":\"alert\",\"concerns\":\"none\"}".data(using: .utf8)!, for: .careVisits)
        let visitLog = CareVisitLog(encryptedPayload: visitPayload, visitDate: Date(), authorMemberID: member.id)
        context.insert(visitLog)

        let moodLog = MoodLog(moodValue: 4, authorMemberID: member.id, authorType: .senior)
        context.insert(moodLog)

        let eventPayload = try EncryptionService.seal("{\"location\":\"Clinic\",\"notes\":\"Checkup\",\"attendees\":[]}".data(using: .utf8)!, for: .calendar)
        let event = CalendarEvent(title: "Annual Checkup", eventDate: Date().addingTimeInterval(3600), encryptedPayload: eventPayload, createdByMemberID: member.id)
        context.insert(event)

        try context.save()

        let circles = try context.fetch(FetchDescriptor<CareCircle>())
        let members = try context.fetch(FetchDescriptor<CareTeamMember>())
        let records = try context.fetch(FetchDescriptor<CareRecord>())
        let invites = try context.fetch(FetchDescriptor<InviteCode>())
        let contacts = try context.fetch(FetchDescriptor<EmergencyContact>())
        let schedules = try context.fetch(FetchDescriptor<MedicationSchedule>())
        let medLogs = try context.fetch(FetchDescriptor<MedicationLog>())
        let visitLogs = try context.fetch(FetchDescriptor<CareVisitLog>())
        let moods = try context.fetch(FetchDescriptor<MoodLog>())
        let events = try context.fetch(FetchDescriptor<CalendarEvent>())

        XCTAssertEqual(circles.count, 1)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(invites.count, 1)
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(schedules.count, 1)
        XCTAssertEqual(medLogs.count, 1)
        XCTAssertEqual(visitLogs.count, 1)
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(events.count, 1)

        // Verify new iCloudRecordID field is present with default empty string
        XCTAssertEqual(members[0].iCloudRecordID, "")
    }
}
