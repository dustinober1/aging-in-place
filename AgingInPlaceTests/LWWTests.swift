import XCTest
import SwiftData
@testable import AgingInPlace

final class LWWTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(
            for: CareCircle.self, CareTeamMember.self, CareRecord.self,
            InviteCode.self, EmergencyContact.self,
            configurations: config
        )
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - Helper

    private func makeRecord(category: PermissionCategory = .mood, lastModified: Date) -> CareRecord {
        let record = CareRecord(
            category: category,
            encryptedPayload: Data([0x01, 0x02]),
            authorMemberID: UUID()
        )
        record.lastModified = lastModified
        context.insert(record)
        return record
    }

    // MARK: - Later timestamp wins (SYNC-03)

    func testLWWResolver_laterTimestampWins() throws {
        let earlier = makeRecord(lastModified: Date(timeIntervalSince1970: 1_000_000))
        let later = makeRecord(lastModified: Date(timeIntervalSince1970: 2_000_000))

        let winner = LWWResolver.resolve(local: earlier, remote: later)
        XCTAssert(winner === later, "Record with later lastModified must win LWW comparison")
    }

    func testLWWResolver_olderTimestampLoses() throws {
        let older = makeRecord(lastModified: Date(timeIntervalSince1970: 500_000))
        let newer = makeRecord(lastModified: Date(timeIntervalSince1970: 999_999))

        let winner = LWWResolver.resolve(local: newer, remote: older)
        XCTAssert(winner === newer, "Local record with later timestamp must beat older remote record")
    }

    // MARK: - Equal timestamps resolve deterministically by UUID

    func testLWWResolver_equalTimestamps_resolveDeterministicallyByUUID() throws {
        let sameDate = Date(timeIntervalSince1970: 1_500_000)
        let recordA = makeRecord(lastModified: sameDate)
        let recordB = makeRecord(lastModified: sameDate)

        let winner1 = LWWResolver.resolve(local: recordA, remote: recordB)
        let winner2 = LWWResolver.resolve(local: recordA, remote: recordB)

        // Must be deterministic — same winner each time
        XCTAssert(winner1 === winner2, "LWW with equal timestamps must resolve deterministically")

        // Winner is whichever UUID string is lexicographically larger
        let expectedWinner = recordA.id.uuidString >= recordB.id.uuidString ? recordA : recordB
        XCTAssert(winner1 === expectedWinner, "LWW tiebreak must use UUID string lexicographic order")
    }

    // MARK: - shouldReplace returns correct answer

    func testShouldReplace_returnsTrueForNewerCandidate() throws {
        let current = makeRecord(lastModified: Date(timeIntervalSince1970: 1_000_000))
        let newer = makeRecord(lastModified: Date(timeIntervalSince1970: 2_000_000))

        XCTAssertTrue(
            LWWResolver.shouldReplace(current: current, with: newer),
            "Newer candidate should replace older current record"
        )
    }

    func testShouldReplace_returnsFalseForOlderCandidate() throws {
        let current = makeRecord(lastModified: Date(timeIntervalSince1970: 2_000_000))
        let older = makeRecord(lastModified: Date(timeIntervalSince1970: 1_000_000))

        XCTAssertFalse(
            LWWResolver.shouldReplace(current: current, with: older),
            "Older candidate should not replace newer current record"
        )
    }
}
