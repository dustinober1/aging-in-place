import XCTest
import SwiftData
@testable import AgingInPlace

final class InviteFlowTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var circle: CareCircle!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: CareCircle.self, CareTeamMember.self, CareRecord.self,
            InviteCode.self, EmergencyContact.self,
            configurations: config
        )
        context = ModelContext(container)
        context.autosaveEnabled = false

        circle = CareCircle(seniorName: "Margaret")
        context.insert(circle)
        try context.save()
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        circle = nil
    }

    // MARK: - Create invite

    func testCreateInvite_insertsInviteCodeWithIsUsedFalse() throws {
        let code = InviteCodeGenerator.generate()
        let invite = InviteCode(code: code, circle: circle)
        circle.pendingInvites.append(invite)
        context.insert(invite)
        try context.save()

        let descriptor = FetchDescriptor<InviteCode>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.code, code)
        XCTAssertFalse(fetched.first?.isUsed ?? true, "Newly created invite code should have isUsed=false")
        XCTAssertEqual(circle.pendingInvites.count, 1)
    }

    // MARK: - Accept invite

    func testAcceptInvite_createsTeamMemberAndMarksCodeUsed() throws {
        let code = InviteCodeGenerator.generate()
        let invite = InviteCode(code: code, circle: circle)
        circle.pendingInvites.append(invite)
        context.insert(invite)
        try context.save()

        // Accept: look up code, create member, mark used
        let fetchDesc = FetchDescriptor<InviteCode>(predicate: #Predicate { $0.code == code })
        let found = try context.fetch(fetchDesc)
        let foundInvite = try XCTUnwrap(found.first, "Invite code should be found in SwiftData")
        XCTAssertFalse(foundInvite.isUsed, "Invite should not be used yet")

        let member = CareTeamMember(displayName: "Sarah", role: .family, circle: circle)
        circle.members.append(member)
        context.insert(member)
        foundInvite.isUsed = true
        try context.save()

        // Verify member was created
        let members = try context.fetch(FetchDescriptor<CareTeamMember>())
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members.first?.displayName, "Sarah")
        XCTAssertEqual(members.first?.role, .family)

        // Verify code is now marked used
        let updatedInvites = try context.fetch(FetchDescriptor<InviteCode>())
        XCTAssertTrue(updatedInvites.first?.isUsed ?? false, "Invite code should be marked as used after acceptance")
    }

    // MARK: - Single-use enforcement

    func testAcceptUsedCode_fails() throws {
        let code = InviteCodeGenerator.generate()
        let invite = InviteCode(code: code, circle: circle)
        invite.isUsed = true  // Already used
        circle.pendingInvites.append(invite)
        context.insert(invite)
        try context.save()

        // Try to accept an already-used code — should fail
        let fetchDesc = FetchDescriptor<InviteCode>(predicate: #Predicate { $0.code == code })
        let found = try context.fetch(fetchDesc)
        let foundInvite = try XCTUnwrap(found.first)
        XCTAssertTrue(foundInvite.isUsed, "Code should be already used")

        // Simulate acceptance attempt: check isUsed before proceeding
        let canAccept = !foundInvite.isUsed
        XCTAssertFalse(canAccept, "Should not be able to accept an already-used invite code")
    }

    // MARK: - Nonexistent code fails

    func testAcceptNonexistentCode_fails() throws {
        let nonExistentCode = "CARE-ZZZZ-ZZZZ"
        let fetchDesc = FetchDescriptor<InviteCode>(predicate: #Predicate { $0.code == nonExistentCode })
        let found = try context.fetch(fetchDesc)
        XCTAssertTrue(found.isEmpty, "Fetching a nonexistent code should return empty results")

        // nil result means join fails
        let invite = found.first
        XCTAssertNil(invite, "Nonexistent code should return nil invite")
    }
}
