import XCTest
import SwiftData
@testable import AgingInPlace

final class MedicationTests: XCTestCase {

    // MARK: - Container helper

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Schema(AgingInPlaceSchemaV2.models),
            migrationPlan: AgingInPlaceMigrationPlan.self,
            configurations: [config]
        )
    }

    // MARK: - Test 1: Encrypted payload round-trip (MEDS-01)
    // MedicationLog created via EncryptionService.seal with .medications category
    // round-trips drugName, dose, notes through encrypt/decrypt.

    func testMedicationLogEncryptedPayloadRoundTrip() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()

        // Build payload struct
        struct MedPayload: Codable {
            let drugName: String
            let dose: String
            let notes: String
        }
        let original = MedPayload(drugName: "Lisinopril", dose: "10mg", notes: "With food")
        let jsonData = try JSONEncoder().encode(original)
        let encrypted = try EncryptionService.seal(jsonData, for: .medications)

        let log = MedicationLog(
            scheduleID: nil,
            encryptedPayload: encrypted,
            administeredAt: Date(),
            authorMemberID: memberID
        )
        context.insert(log)
        try context.save()

        // Fetch and decrypt
        let fetched = try context.fetch(FetchDescriptor<MedicationLog>())
        XCTAssertEqual(fetched.count, 1)
        let decryptedData = try EncryptionService.open(fetched[0].encryptedPayload, for: .medications)
        let decoded = try JSONDecoder().decode(MedPayload.self, from: decryptedData)
        XCTAssertEqual(decoded.drugName, "Lisinopril")
        XCTAssertEqual(decoded.dose, "10mg")
        XCTAssertEqual(decoded.notes, "With food")
    }

    // MARK: - Test 2: Fetch sorted by administeredAt descending (MEDS-04)

    func testMedicationLogFetchSortedByAdministeredAtDescending() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let now = Date()

        // Create three logs at different times
        let dummyPayload = try EncryptionService.seal(
            "{\"drugName\":\"A\",\"dose\":\"1\",\"notes\":\"\"}".data(using: .utf8)!,
            for: .medications
        )
        let earliest = MedicationLog(
            scheduleID: nil,
            encryptedPayload: dummyPayload,
            administeredAt: now.addingTimeInterval(-7200),  // 2 hours ago
            authorMemberID: memberID
        )
        let middle = MedicationLog(
            scheduleID: nil,
            encryptedPayload: dummyPayload,
            administeredAt: now.addingTimeInterval(-3600),  // 1 hour ago
            authorMemberID: memberID
        )
        let latest = MedicationLog(
            scheduleID: nil,
            encryptedPayload: dummyPayload,
            administeredAt: now,                            // now
            authorMemberID: memberID
        )
        context.insert(earliest)
        context.insert(middle)
        context.insert(latest)
        try context.save()

        let descriptor = FetchDescriptor<MedicationLog>(
            sortBy: [SortDescriptor(\.administeredAt, order: .reverse)]
        )
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 3)
        // First result should be most recent
        XCTAssertEqual(
            fetched[0].administeredAt.timeIntervalSince1970,
            now.timeIntervalSince1970,
            accuracy: 1.0
        )
        XCTAssertGreaterThan(fetched[0].administeredAt, fetched[1].administeredAt)
        XCTAssertGreaterThan(fetched[1].administeredAt, fetched[2].administeredAt)
    }

    // MARK: - Test 3: scheduleID links to the correct MedicationSchedule (MEDS-01)

    func testMedicationLogScheduleIDLinksToSchedule() throws {
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

        let payload = try EncryptionService.seal(
            "{\"drugName\":\"Metformin\",\"dose\":\"500mg\",\"notes\":\"\"}".data(using: .utf8)!,
            for: .medications
        )
        let log = MedicationLog(
            scheduleID: schedule.id,
            encryptedPayload: payload,
            administeredAt: Date(),
            authorMemberID: memberID
        )
        context.insert(log)
        try context.save()

        let fetchedLogs = try context.fetch(FetchDescriptor<MedicationLog>())
        XCTAssertEqual(fetchedLogs.count, 1)
        XCTAssertEqual(fetchedLogs[0].scheduleID, schedule.id)

        // Verify we can look up the schedule from the log's scheduleID
        let scheduleID = try XCTUnwrap(fetchedLogs[0].scheduleID)
        let scheduleDescriptor = FetchDescriptor<MedicationSchedule>()
        let fetchedSchedules = try context.fetch(scheduleDescriptor)
        let linkedSchedule = fetchedSchedules.first(where: { $0.id == scheduleID })
        XCTAssertNotNil(linkedSchedule)
        XCTAssertEqual(linkedSchedule?.drugName, "Metformin")
    }

    // MARK: - Test 4: isActive=false excluded from active-only queries

    func testInactiveMedicationScheduleExcludedFromActiveQuery() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()

        let activeSchedule = MedicationSchedule(
            drugName: "Aspirin",
            dose: "81mg",
            hour: 9,
            minute: 0,
            createdByMemberID: memberID
        )
        let inactiveSchedule = MedicationSchedule(
            drugName: "Stopped Drug",
            dose: "100mg",
            hour: 10,
            minute: 0,
            createdByMemberID: memberID
        )
        inactiveSchedule.isActive = false

        context.insert(activeSchedule)
        context.insert(inactiveSchedule)
        try context.save()

        // Fetch only active schedules using #Predicate
        let activeDescriptor = FetchDescriptor<MedicationSchedule>(
            predicate: #Predicate<MedicationSchedule> { schedule in
                schedule.isActive == true
            },
            sortBy: [SortDescriptor(\.drugName)]
        )
        let fetchedActive = try context.fetch(activeDescriptor)
        XCTAssertEqual(fetchedActive.count, 1)
        XCTAssertEqual(fetchedActive[0].drugName, "Aspirin")

        // Verify total count is 2 (both exist in store)
        let allSchedules = try context.fetch(FetchDescriptor<MedicationSchedule>())
        XCTAssertEqual(allSchedules.count, 2)
    }
}
