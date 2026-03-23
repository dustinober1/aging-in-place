import XCTest
import SwiftData
@testable import AgingInPlace

final class PermissionTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(
            for: CareCircle.self, CareTeamMember.self,
            configurations: config
        )
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    override func tearDown() async throws {
        // Clean up all Keychain keys after each test
        for category in PermissionCategory.allCases {
            try? KeychainService.deleteKey(for: category)
        }
        container = nil
        context = nil
    }

    // MARK: - Default permissions (TEAM-05)

    func testNewMember_hasAllFourCategoriesGranted() throws {
        let circle = CareCircle(seniorName: "Alice")
        let member = CareTeamMember(displayName: "Bob", role: .paidAide, circle: circle)
        context.insert(circle)
        context.insert(member)
        try context.save()

        XCTAssertEqual(
            Set(member.grantedCategories),
            Set(PermissionCategory.allCases),
            "New member must have all 4 categories granted by default (TEAM-05)"
        )
    }

    // MARK: - Grant a category (TEAM-05)

    func testGrantCategory_addsToGrantedCategories() throws {
        let circle = CareCircle(seniorName: "Alice")
        let member = CareTeamMember(displayName: "Bob", role: .paidAide, circle: circle)
        // Start with no categories granted
        member.grantedCategories = []
        context.insert(circle)
        context.insert(member)
        try context.save()

        // Grant medications
        if !member.grantedCategories.contains(.medications) {
            member.grantedCategories.append(.medications)
            member.lastModified = Date()
        }
        try context.save()

        XCTAssertTrue(member.grantedCategories.contains(.medications), "Grant must add category to grantedCategories (TEAM-05)")
    }

    // MARK: - Revoke a category (TEAM-06)

    func testRevokeCategory_removesFromGrantedCategories() throws {
        let circle = CareCircle(seniorName: "Alice")
        let member = CareTeamMember(displayName: "Bob", role: .paidAide, circle: circle)
        context.insert(circle)
        context.insert(member)
        try context.save()

        // Revoke medications
        member.grantedCategories.removeAll { $0 == .medications }
        member.lastModified = Date()
        try context.save()

        XCTAssertFalse(member.grantedCategories.contains(.medications), "Revoke must remove category from grantedCategories (TEAM-06)")
        XCTAssertEqual(member.grantedCategories.count, 3)
    }

    // MARK: - Revoke last category leaves empty array

    func testRevokeLastCategory_leavesEmptyArray() throws {
        let circle = CareCircle(seniorName: "Alice")
        let member = CareTeamMember(displayName: "Bob", role: .paidAide, circle: circle)
        member.grantedCategories = [.medications]
        context.insert(circle)
        context.insert(member)
        try context.save()

        member.grantedCategories.removeAll { $0 == .medications }
        member.lastModified = Date()
        try context.save()

        XCTAssertTrue(member.grantedCategories.isEmpty, "Revoking last category must leave empty grantedCategories")
    }

    // MARK: - Granting already-granted category is idempotent

    func testGrantAlreadyGranted_isIdempotent() throws {
        let circle = CareCircle(seniorName: "Alice")
        let member = CareTeamMember(displayName: "Bob", role: .paidAide, circle: circle)
        context.insert(circle)
        context.insert(member)
        try context.save()

        // medications is already granted (default); grant again idempotently
        if !member.grantedCategories.contains(.medications) {
            member.grantedCategories.append(.medications)
        }
        member.lastModified = Date()
        try context.save()

        let medicationsCount = member.grantedCategories.filter { $0 == .medications }.count
        XCTAssertEqual(medicationsCount, 1, "Granting an already-granted category must not duplicate it")
    }

    // MARK: - Key rotation: new records protected after rotation (TEAM-07)

    func testKeyRotation_afterRevoke_newRecordsCannotBeOpenedWithOldKeyPattern() throws {
        // Seal data with the current key for .medications
        let oldData = "Old record before revocation".data(using: .utf8)!
        let oldCiphertext = try EncryptionService.seal(oldData, for: .medications)

        // Simulate revocation: rotate the key
        try EncryptionService.rotateKey(for: .medications)

        // Seal new data with the new key
        let newData = "New record after revocation".data(using: .utf8)!
        let newCiphertext = try EncryptionService.seal(newData, for: .medications)

        // The old ciphertext (sealed with old key) must now fail to open
        XCTAssertThrowsError(
            try EncryptionService.open(oldCiphertext, for: .medications),
            "Old records must be unreadable after key rotation (TEAM-07)"
        )

        // The new ciphertext must open correctly (new key is active)
        let decrypted = try EncryptionService.open(newCiphertext, for: .medications)
        XCTAssertEqual(decrypted, newData, "New records sealed after rotation must be readable with new key")
    }

    // MARK: - Grant back after revoke

    func testGrantAfterRevoke_addsBackToGrantedCategories() throws {
        let circle = CareCircle(seniorName: "Alice")
        let member = CareTeamMember(displayName: "Bob", role: .paidAide, circle: circle)
        context.insert(circle)
        context.insert(member)
        try context.save()

        // Revoke
        member.grantedCategories.removeAll { $0 == .medications }
        member.lastModified = Date()
        try context.save()
        XCTAssertFalse(member.grantedCategories.contains(.medications))

        // Grant back
        member.grantedCategories.append(.medications)
        member.lastModified = Date()
        try context.save()
        XCTAssertTrue(member.grantedCategories.contains(.medications), "Granting after revoke must restore category access")
    }
}
