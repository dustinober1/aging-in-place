import XCTest
import SwiftData
@testable import AgingInPlace

final class CareVisitTests: XCTestCase {

    // MARK: - Container helper

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Schema(AgingInPlaceSchemaV2.models),
            migrationPlan: AgingInPlaceMigrationPlan.self,
            configurations: [config]
        )
    }

    // MARK: - Encrypted payload round-trip

    func testCareVisitEncryptedPayloadRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let visitDate = Date()

        let fields: [String: String] = [
            "meals": "Oatmeal with berries",
            "mobility": "Walked to kitchen unassisted",
            "observations": "Appeared alert and engaged",
            "concerns": "Mild cough, monitor"
        ]
        let jsonData = try JSONEncoder().encode(fields)
        let encrypted = try EncryptionService.seal(jsonData, for: .careVisits)

        let log = CareVisitLog(
            encryptedPayload: encrypted,
            visitDate: visitDate,
            authorMemberID: memberID
        )
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CareVisitLog>())
        XCTAssertEqual(fetched.count, 1)

        // Decrypt and verify all fields
        let decryptedData = try EncryptionService.open(fetched[0].encryptedPayload, for: .careVisits)
        let decoded = try JSONDecoder().decode([String: String].self, from: decryptedData)
        XCTAssertEqual(decoded["meals"], "Oatmeal with berries")
        XCTAssertEqual(decoded["mobility"], "Walked to kitchen unassisted")
        XCTAssertEqual(decoded["observations"], "Appeared alert and engaged")
        XCTAssertEqual(decoded["concerns"], "Mild cough, monitor")
    }

    // MARK: - visitDate stored as plaintext

    func testCareVisitDateIsPlaintext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()

        // Use a specific known date for deterministic comparison
        let components = DateComponents(year: 2026, month: 3, day: 15, hour: 10, minute: 30)
        let visitDate = Calendar.current.date(from: components)!

        let jsonData = try JSONEncoder().encode(["meals": "Soup"])
        let encrypted = try EncryptionService.seal(jsonData, for: .careVisits)

        let log = CareVisitLog(
            encryptedPayload: encrypted,
            visitDate: visitDate,
            authorMemberID: memberID
        )
        context.insert(log)
        try context.save()

        // Fetch using a predicate on visitDate — proves it's stored as a plaintext Date
        let startOfDay = Calendar.current.startOfDay(for: visitDate)
        let endOfDay = startOfDay.addingTimeInterval(86_400)
        let descriptor = FetchDescriptor<CareVisitLog>(
            predicate: #Predicate { log in
                log.visitDate >= startOfDay && log.visitDate < endOfDay
            }
        )
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(
            fetched[0].visitDate.timeIntervalSince1970,
            visitDate.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    // MARK: - authorMemberID persists correctly

    func testCareVisitAuthorMemberIDPersists() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let expectedMemberID = UUID()

        let jsonData = try JSONEncoder().encode(["meals": "Eggs"])
        let encrypted = try EncryptionService.seal(jsonData, for: .careVisits)

        let log = CareVisitLog(
            encryptedPayload: encrypted,
            visitDate: Date(),
            authorMemberID: expectedMemberID
        )
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CareVisitLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].authorMemberID, expectedMemberID)
    }
}
