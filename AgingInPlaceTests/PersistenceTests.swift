import XCTest
import SwiftData
@testable import AgingInPlace

final class PersistenceTests: XCTestCase {
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

    // MARK: - Insert CareCircle + CareTeamMember, save, fetch persists (SYNC-01)

    func testInsertCareCircleAndMember_saveThenFetch_persists() throws {
        let circle = CareCircle(seniorName: "Margaret", seniorDeviceID: "device-001")
        let member = CareTeamMember(displayName: "Sarah", role: .family, circle: circle)
        circle.members?.append(member)

        context.insert(circle)
        context.insert(member)
        try context.save()

        // Fetch circles after save
        let descriptor = FetchDescriptor<CareCircle>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.seniorName, "Margaret")
        XCTAssertEqual(fetched.first?.members?.count, 1)
        XCTAssertEqual(fetched.first?.members?.first?.displayName, "Sarah")
    }

    // MARK: - CareRecord with encryptedPayload saves and loads ciphertext intact

    func testInsertCareRecord_encryptedPayloadRoundTrips() throws {
        let fakePayload = Data([0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE])
        let authorID = UUID()
        let record = CareRecord(
            category: .medications,
            encryptedPayload: fakePayload,
            authorMemberID: authorID
        )

        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<CareRecord>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.encryptedPayload, fakePayload, "Encrypted payload must survive save/fetch cycle")
        XCTAssertEqual(fetched.first?.category, .medications)
        XCTAssertEqual(fetched.first?.authorMemberID, authorID)
    }

    // MARK: - Delete CareTeamMember cascades correctly from CareCircle

    func testDeleteCareCircle_cascadesDeleteToMembers() throws {
        let circle = CareCircle(seniorName: "Harold")
        let member1 = CareTeamMember(displayName: "Jane", role: .nurse, circle: circle)
        let member2 = CareTeamMember(displayName: "Bob", role: .paidAide, circle: circle)
        circle.members?.append(contentsOf: [member1, member2])

        context.insert(circle)
        context.insert(member1)
        context.insert(member2)
        try context.save()

        // Verify both members exist
        let membersBefore = try context.fetch(FetchDescriptor<CareTeamMember>())
        XCTAssertEqual(membersBefore.count, 2)

        // Delete the circle — should cascade to members
        context.delete(circle)
        try context.save()

        let membersAfter = try context.fetch(FetchDescriptor<CareTeamMember>())
        XCTAssertEqual(membersAfter.count, 0, "Cascade delete from CareCircle must remove all CareTeamMembers")
    }

    // MARK: - Explicit save() actually persists data

    func testExplicitSave_persistsData_notRelyingOnAutosave() throws {
        let circle = CareCircle(seniorName: "Ruth")
        context.insert(circle)
        try context.save()

        // Fetch to confirm explicit save worked
        let fetched = try context.fetch(FetchDescriptor<CareCircle>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.seniorName, "Ruth")
    }
}
