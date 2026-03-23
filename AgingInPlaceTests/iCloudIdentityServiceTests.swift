import XCTest
@testable import AgingInPlace

final class iCloudIdentityServiceTests: XCTestCase {
    func testRecordIDStringIsNonEmpty() async throws {
        let recordID = await iCloudIdentityService.fetchRecordID()
        XCTAssertTrue(recordID == nil || !recordID!.isEmpty)
    }
    func testUserNameReturnsOptional() async throws {
        let name = await iCloudIdentityService.fetchUserName()
        XCTAssertTrue(name == nil || !name!.isEmpty)
    }
}
