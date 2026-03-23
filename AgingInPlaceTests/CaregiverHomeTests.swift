import XCTest
import SwiftData
@testable import AgingInPlace

final class CaregiverHomeTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(
            for: CareRecord.self, CareTeamMember.self, CareCircle.self,
            configurations: config
        )
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - TEAM-08: Records sorted by lastModified descending

    /// Query returns CareRecords sorted by lastModified descending.
    @MainActor
    func testCareRecordsSortedByLastModifiedDescending() throws {
        let authorID = UUID()
        let dummyPayload = Data([0x01, 0x02])

        let oldest = CareRecord(category: .medications, encryptedPayload: dummyPayload, authorMemberID: authorID)
        let middle = CareRecord(category: .mood, encryptedPayload: dummyPayload, authorMemberID: authorID)
        let newest = CareRecord(category: .calendar, encryptedPayload: dummyPayload, authorMemberID: authorID)

        // Space them out so timestamps differ
        oldest.lastModified = Date(timeIntervalSinceNow: -200)
        middle.lastModified = Date(timeIntervalSinceNow: -100)
        newest.lastModified = Date(timeIntervalSinceNow: -10)

        context.insert(oldest)
        context.insert(middle)
        context.insert(newest)
        try context.save()

        var descriptor = FetchDescriptor<CareRecord>(
            sortBy: [SortDescriptor(\.lastModified, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 3)
        XCTAssertEqual(fetched[0].category, .calendar, "Newest record should be first")
        XCTAssertEqual(fetched[1].category, .mood)
        XCTAssertEqual(fetched[2].category, .medications, "Oldest record should be last")
    }

    // MARK: - Revoked categories filtered out

    /// Records in revoked categories are excluded from caregiver's view.
    @MainActor
    func testRevokedCategoryRecordsAreFiltered() throws {
        let authorID = UUID()
        let dummyPayload = Data([0x01])

        let medRecord = CareRecord(category: .medications, encryptedPayload: dummyPayload, authorMemberID: authorID)
        let moodRecord = CareRecord(category: .mood, encryptedPayload: dummyPayload, authorMemberID: authorID)
        let calendarRecord = CareRecord(category: .calendar, encryptedPayload: dummyPayload, authorMemberID: authorID)

        context.insert(medRecord)
        context.insert(moodRecord)
        context.insert(calendarRecord)
        try context.save()

        // Simulate: caregiver has medications revoked — only mood and calendar granted
        let grantedCategories: Set<PermissionCategory> = [.mood, .calendar]

        let allRecords = try context.fetch(FetchDescriptor<CareRecord>())
        let filtered = allRecords.filter { grantedCategories.contains($0.category) }

        XCTAssertEqual(filtered.count, 2, "Should only return records in granted categories")
        XCTAssertFalse(filtered.contains(where: { $0.category == .medications }),
                       "Revoked category (medications) must not appear in filtered results")
        XCTAssertTrue(filtered.contains(where: { $0.category == .mood }))
        XCTAssertTrue(filtered.contains(where: { $0.category == .calendar }))
    }

    /// When all categories are granted, all records are returned.
    @MainActor
    func testAllCategoriesGrantedReturnsAllRecords() throws {
        let authorID = UUID()
        let dummyPayload = Data([0x01])

        for category in PermissionCategory.allCases {
            context.insert(CareRecord(category: category, encryptedPayload: dummyPayload, authorMemberID: authorID))
        }
        try context.save()

        let grantedCategories = Set(PermissionCategory.allCases)
        let allRecords = try context.fetch(FetchDescriptor<CareRecord>())
        let filtered = allRecords.filter { grantedCategories.contains($0.category) }

        XCTAssertEqual(filtered.count, PermissionCategory.allCases.count)
    }
}
