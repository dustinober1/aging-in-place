import XCTest
@testable import AgingInPlace

final class SeniorHomeTests: XCTestCase {

    // MARK: - SENR-04: Time-of-day greeting

    func testGreetingForMorningHours() {
        let view = SeniorHomeView()
        // morning: 0 – 11
        for hour in 0..<12 {
            let greeting = view.greetingForTimeOfDay(hour: hour)
            XCTAssertTrue(
                greeting.hasPrefix("Good morning"),
                "Hour \(hour) should return 'Good morning', got '\(greeting)'"
            )
        }
    }

    func testGreetingForAfternoonHours() {
        let view = SeniorHomeView()
        // afternoon: 12 – 16
        for hour in 12..<17 {
            let greeting = view.greetingForTimeOfDay(hour: hour)
            XCTAssertTrue(
                greeting.hasPrefix("Good afternoon"),
                "Hour \(hour) should return 'Good afternoon', got '\(greeting)'"
            )
        }
    }

    func testGreetingForEveningHours() {
        let view = SeniorHomeView()
        // evening: 17 – 23
        for hour in 17..<24 {
            let greeting = view.greetingForTimeOfDay(hour: hour)
            XCTAssertTrue(
                greeting.hasPrefix("Good evening"),
                "Hour \(hour) should return 'Good evening', got '\(greeting)'"
            )
        }
    }

    func testGreetingIncludesSeniorName() {
        let view = SeniorHomeView()
        // Default name when no CareCircle exists is "there"
        let greeting = view.greetingForTimeOfDay(hour: 8)
        XCTAssertTrue(
            greeting.hasSuffix(", there"),
            "Greeting should end with senior name, got '\(greeting)'"
        )
    }

    // MARK: - Summary card categories

    /// Verify the expected 4 summary card categories exist in PermissionCategory.
    func testSummaryCardCategoriesMatchPermissionCategories() {
        let expectedCategories: Set<PermissionCategory> = [
            .medications, .mood, .careVisits, .calendar
        ]
        let allCases = Set(PermissionCategory.allCases)
        XCTAssertEqual(
            allCases,
            expectedCategories,
            "PermissionCategory should contain exactly 4 cases matching the 4 summary cards"
        )
    }
}
