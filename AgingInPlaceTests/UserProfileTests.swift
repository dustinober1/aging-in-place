import XCTest
import SwiftData
@testable import AgingInPlace

final class UserProfileTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Schema(AgingInPlaceSchemaV4.models),
            migrationPlan: AgingInPlaceMigrationPlan.self,
            configurations: [config]
        )
    }

    func testUserProfileInsertAndFetch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let profile = UserProfile(iCloudRecordID: "user-record-123", displayName: "Margaret", role: .senior)
        context.insert(profile)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].iCloudRecordID, "user-record-123")
        XCTAssertEqual(fetched[0].displayName, "Margaret")
        XCTAssertEqual(fetched[0].role, .senior)
        XCTAssertTrue(fetched[0].notificationsEnabled)
    }

    func testUserProfileCaregiverRole() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let profile = UserProfile(iCloudRecordID: "caregiver-456", displayName: "Bob", role: .caregiver)
        context.insert(profile)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(fetched[0].role, .caregiver)
    }

    func testUserProfileDefaultValues() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let profile = UserProfile(iCloudRecordID: "", displayName: "", role: .senior)
        context.insert(profile)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched[0].notificationsEnabled)
        XCTAssertNil(fetched[0].avatarData)
    }
}
