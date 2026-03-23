import XCTest
import SwiftData
import CloudKit
@testable import AgingInPlace

final class SharingServiceTests: XCTestCase {
    func testShareTitleUsesCircleSeniorName() throws {
        let circle = CareCircle(seniorName: "Margaret")
        let title = SharingService.shareTitle(for: circle)
        XCTAssertEqual(title, "Margaret's Care Circle")
    }

    func testShareTitleFallsBackForEmptyName() throws {
        let circle = CareCircle(seniorName: "")
        let title = SharingService.shareTitle(for: circle)
        XCTAssertEqual(title, "Care Circle")
    }
}
