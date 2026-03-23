import XCTest
import SwiftData
@testable import AgingInPlace

final class SchemaV3MigrationTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Schema(AgingInPlaceSchemaV3.models),
            migrationPlan: AgingInPlaceMigrationPlan.self,
            configurations: [config]
        )
    }

    func testContainerOpensWithV3MigrationPlan() throws {
        XCTAssertNoThrow(try makeContainer())
    }

    func testCareRecordLinkedToCareCircle() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let circle = CareCircle(seniorName: "Margaret")
        context.insert(circle)
        let payload = try EncryptionService.seal("{\"note\":\"test\"}".data(using: .utf8)!, for: .medications)
        let record = CareRecord(category: .medications, encryptedPayload: payload, authorMemberID: UUID(), circle: circle)
        context.insert(record)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<CareCircle>())
        XCTAssertEqual(fetched.first?.careRecords.count, 1)
        XCTAssertEqual(fetched.first?.careRecords.first?.id, record.id)
    }

    func testCareRecordCascadeDeletesWithCircle() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let circle = CareCircle(seniorName: "Margaret")
        context.insert(circle)
        let payload = try EncryptionService.seal("{\"note\":\"test\"}".data(using: .utf8)!, for: .medications)
        let record = CareRecord(category: .medications, encryptedPayload: payload, authorMemberID: UUID(), circle: circle)
        context.insert(record)
        try context.save()
        context.delete(circle)
        try context.save()
        let records = try context.fetch(FetchDescriptor<CareRecord>())
        XCTAssertEqual(records.count, 0)
    }

    func testPhase2ModelsStillInsertableAfterV3Migration() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let schedule = MedicationSchedule(drugName: "Metformin", dose: "500mg", hour: 8, minute: 0, createdByMemberID: UUID())
        context.insert(schedule)
        let moodLog = MoodLog(moodValue: 3, authorMemberID: UUID(), authorType: .senior)
        context.insert(moodLog)
        try context.save()
        let schedules = try context.fetch(FetchDescriptor<MedicationSchedule>())
        let moods = try context.fetch(FetchDescriptor<MoodLog>())
        XCTAssertEqual(schedules.count, 1)
        XCTAssertEqual(moods.count, 1)
    }
}
