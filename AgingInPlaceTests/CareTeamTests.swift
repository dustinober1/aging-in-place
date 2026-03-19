import XCTest
import SwiftData
@testable import AgingInPlace

final class CareTeamTests: XCTestCase {
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

    // MARK: - Add member persists correctly

    func testAddMemberToCareCircle_persistsCorrectly() throws {
        let member = CareTeamMember(displayName: "Sarah", role: .family, circle: circle)
        circle.members.append(member)
        context.insert(member)
        try context.save()

        // Fetch and verify
        let circles = try context.fetch(FetchDescriptor<CareCircle>())
        XCTAssertEqual(circles.count, 1)
        XCTAssertEqual(circles.first?.members.count, 1)
        XCTAssertEqual(circles.first?.members.first?.displayName, "Sarah")
        XCTAssertEqual(circles.first?.members.first?.role, .family)
    }

    // MARK: - Remove member cascades from SwiftData

    func testRemoveMember_deletesFromSwiftData() throws {
        let member = CareTeamMember(displayName: "Maria", role: .paidAide, circle: circle)
        circle.members.append(member)
        context.insert(member)
        try context.save()

        // Verify member exists
        let beforeDelete = try context.fetch(FetchDescriptor<CareTeamMember>())
        XCTAssertEqual(beforeDelete.count, 1)

        // Remove the member
        context.delete(member)
        try context.save()

        // Verify deleted
        let afterDelete = try context.fetch(FetchDescriptor<CareTeamMember>())
        XCTAssertEqual(afterDelete.count, 0, "Deleted member must be removed from SwiftData")
    }

    // MARK: - Members list has correct role display

    func testMembersList_fetchedWithCorrectRoleDisplay() throws {
        let sarah = CareTeamMember(displayName: "Sarah", role: .family, circle: circle)
        let maria = CareTeamMember(displayName: "Maria", role: .paidAide, circle: circle)
        let nurse = CareTeamMember(displayName: "Dr. Smith", role: .nurse, circle: circle)
        circle.members.append(contentsOf: [sarah, maria, nurse])
        context.insert(sarah)
        context.insert(maria)
        context.insert(nurse)
        try context.save()

        let members = try context.fetch(FetchDescriptor<CareTeamMember>())
        XCTAssertEqual(members.count, 3)

        let membersByName = Dictionary(uniqueKeysWithValues: members.map { ($0.displayName, $0.role) })
        XCTAssertEqual(membersByName["Sarah"], .family)
        XCTAssertEqual(membersByName["Maria"], .paidAide)
        XCTAssertEqual(membersByName["Dr. Smith"], .nurse)

        // Verify displayName values from MemberRole enum
        XCTAssertEqual(MemberRole.family.displayName, "Family")
        XCTAssertEqual(MemberRole.paidAide.displayName, "Paid Aide")
        XCTAssertEqual(MemberRole.nurse.displayName, "Nurse")
    }
}
