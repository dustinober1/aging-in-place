import XCTest
import SwiftData
@testable import AgingInPlace

final class MoodTests: XCTestCase {

    // MARK: - Container helper

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Schema(AgingInPlaceSchemaV3.models),
            migrationPlan: AgingInPlaceMigrationPlan.self,
            configurations: [config]
        )
    }

    // MARK: - Senior mood log

    func testSeniorMoodLogSavesCorrectly() throws {
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
        XCTAssertEqual(fetched[0].authorMemberID, memberID)
    }

    // MARK: - Caregiver mood log

    func testCaregiverMoodLogSavesCorrectly() throws {
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

    // MARK: - Distinct senior vs caregiver authorship

    func testSeniorAndCaregiverMoodLogsAreDistinct() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let seniorID = UUID()
        let caregiverID = UUID()

        let seniorLog = MoodLog(moodValue: 5, authorMemberID: seniorID, authorType: .senior)
        let caregiverLog = MoodLog(moodValue: 1, authorMemberID: caregiverID, authorType: .caregiver)
        context.insert(seniorLog)
        context.insert(caregiverLog)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MoodLog>())
        XCTAssertEqual(fetched.count, 2)

        let seniors = fetched.filter { $0.authorType == .senior }
        let caregivers = fetched.filter { $0.authorType == .caregiver }
        XCTAssertEqual(seniors.count, 1)
        XCTAssertEqual(caregivers.count, 1)
        XCTAssertEqual(seniors[0].moodValue, 5)
        XCTAssertEqual(caregivers[0].moodValue, 1)
    }

    // MARK: - Notes encryption round-trip

    func testMoodLogNotesEncryptionRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let notesText = "Feeling a bit anxious about upcoming appointment"
        let notesData = notesText.data(using: .utf8)!
        let encryptedNotes = try EncryptionService.seal(notesData, for: .mood)

        let log = MoodLog(
            moodValue: 3,
            authorMemberID: memberID,
            authorType: .senior,
            notes: encryptedNotes
        )
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MoodLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertNotNil(fetched[0].notes)

        let decryptedData = try EncryptionService.open(fetched[0].notes!, for: .mood)
        let decryptedText = String(data: decryptedData, encoding: .utf8)
        XCTAssertEqual(decryptedText, notesText)
    }

    // MARK: - Nil notes

    func testMoodLogWithoutNotesSavesNilNotes() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()

        let log = MoodLog(
            moodValue: 5,
            authorMemberID: memberID,
            authorType: .senior
            // notes defaults to nil
        )
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MoodLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertNil(fetched[0].notes)
    }

    // MARK: - Sort order by loggedAt

    func testMoodLogsSortedByLoggedAtDescending() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()

        let now = Date()
        let earlier = now.addingTimeInterval(-3600) // 1 hour ago

        // Insert older one first
        let olderLog = MoodLog(moodValue: 2, authorMemberID: memberID, authorType: .senior)
        olderLog.loggedAt = earlier
        let newerLog = MoodLog(moodValue: 4, authorMemberID: memberID, authorType: .senior)
        newerLog.loggedAt = now

        context.insert(olderLog)
        context.insert(newerLog)
        try context.save()

        let descriptor = FetchDescriptor<MoodLog>(
            sortBy: [SortDescriptor(\MoodLog.loggedAt, order: .reverse)]
        )
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched[0].moodValue, 4, "Newest should be first")
        XCTAssertEqual(fetched[1].moodValue, 2, "Oldest should be second")
    }
}
