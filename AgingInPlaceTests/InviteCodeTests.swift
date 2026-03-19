import XCTest
@testable import AgingInPlace

final class InviteCodeTests: XCTestCase {

    // MARK: - Code format tests

    func testGeneratedCode_matchesFormat_CARE_XXXX_XXXX() {
        let code = InviteCodeGenerator.generate()
        // Format: "CARE-XXXX-XXXX" where X is uppercase alphanumeric
        let pattern = #"^CARE-[A-Z0-9]{4}-[A-Z0-9]{4}$"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(code.startIndex..., in: code)
        let match = regex.firstMatch(in: code, range: range)
        XCTAssertNotNil(match, "Code '\(code)' does not match format CARE-XXXX-XXXX")
    }

    func testGeneratedCode_lengthIsExactly14() {
        let code = InviteCodeGenerator.generate()
        // "CARE-" (5) + "XXXX" (4) + "-" (1) + "XXXX" (4) = 14
        XCTAssertEqual(code.count, 14, "Code '\(code)' should be exactly 14 characters, got \(code.count)")
    }

    func testGeneratedCodes_areUnique() {
        let code1 = InviteCodeGenerator.generate()
        let code2 = InviteCodeGenerator.generate()
        XCTAssertNotEqual(code1, code2, "Two generated codes should not be identical")
    }
}
