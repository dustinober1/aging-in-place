import XCTest
import SwiftData
@testable import AgingInPlace

final class CalendarTests: XCTestCase {

    // MARK: - Container helper

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Schema(AgingInPlaceSchemaV3.models),
            migrationPlan: AgingInPlaceMigrationPlan.self,
            configurations: [config]
        )
    }

    // MARK: - Helpers

    private func makeEncryptedPayload(
        location: String = "Dr. Smith Office",
        notes: String = "Annual checkup",
        attendees: [String] = ["Mom", "Dad"]
    ) throws -> Data {
        let dict: [String: Any] = [
            "location": location,
            "notes": notes,
            "attendees": attendees
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: dict)
        return try EncryptionService.seal(jsonData, for: .calendar)
    }

    private func decryptPayload(_ data: Data) throws -> [String: Any] {
        let plain = try EncryptionService.open(data, for: .calendar)
        return try JSONSerialization.jsonObject(with: plain) as! [String: Any]
    }

    // MARK: - Test 1: CalendarEvent round-trip

    func testCalendarEventRoundTrip() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let memberID = UUID()
        let eventDate = Date(timeIntervalSinceNow: 3600)
        let encryptedPayload = try makeEncryptedPayload(
            location: "City Hospital",
            notes: "Bring insurance card",
            attendees: ["Mom"]
        )

        let event = CalendarEvent(
            title: "Cardiology Appointment",
            eventDate: eventDate,
            reminderOffsetMinutes: 60,
            encryptedPayload: encryptedPayload,
            createdByMemberID: memberID
        )
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CalendarEvent>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Cardiology Appointment")
        XCTAssertEqual(
            fetched[0].eventDate.timeIntervalSince1970,
            eventDate.timeIntervalSince1970,
            accuracy: 1.0
        )
        XCTAssertEqual(fetched[0].reminderOffsetMinutes, 60)
        XCTAssertEqual(fetched[0].createdByMemberID, memberID)
    }

    // MARK: - Test 2: Chronological sort

    func testCalendarEventChronologicalSort() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let memberID = UUID()
        let payload = try makeEncryptedPayload()

        let laterDate = Date(timeIntervalSinceNow: 7200)
        let earlierDate = Date(timeIntervalSinceNow: 3600)

        // Insert in reverse order to confirm sort works
        let laterEvent = CalendarEvent(
            title: "Later Event",
            eventDate: laterDate,
            encryptedPayload: payload,
            createdByMemberID: memberID
        )
        let earlierEvent = CalendarEvent(
            title: "Earlier Event",
            eventDate: earlierDate,
            encryptedPayload: payload,
            createdByMemberID: memberID
        )
        context.insert(laterEvent)
        context.insert(earlierEvent)
        try context.save()

        let descriptor = FetchDescriptor<CalendarEvent>(
            sortBy: [SortDescriptor(\.eventDate, order: .forward)]
        )
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched[0].title, "Earlier Event")
        XCTAssertEqual(fetched[1].title, "Later Event")
    }

    // MARK: - Test 3: Encrypted payload decrypts correctly

    func testCalendarEventEncryptedPayloadDecryption() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let location = "Dr. Smith Office"
        let notes = "Annual checkup"
        let attendees = ["Mom", "Dad"]
        let encryptedPayload = try makeEncryptedPayload(
            location: location,
            notes: notes,
            attendees: attendees
        )

        let event = CalendarEvent(
            title: "Annual Checkup",
            eventDate: Date(timeIntervalSinceNow: 3600),
            encryptedPayload: encryptedPayload,
            createdByMemberID: UUID()
        )
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CalendarEvent>())
        XCTAssertEqual(fetched.count, 1)

        let decrypted = try decryptPayload(fetched[0].encryptedPayload)
        XCTAssertEqual(decrypted["location"] as? String, location)
        XCTAssertEqual(decrypted["notes"] as? String, notes)
        let fetchedAttendees = decrypted["attendees"] as? [String]
        XCTAssertEqual(fetchedAttendees, attendees)
    }

    // MARK: - Test 4: Deletion removes event from store

    func testCalendarEventDeletion() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let payload = try makeEncryptedPayload()
        let event = CalendarEvent(
            title: "PT Session",
            eventDate: Date(timeIntervalSinceNow: 3600),
            encryptedPayload: payload,
            createdByMemberID: UUID()
        )
        context.insert(event)
        try context.save()

        let beforeDelete = try context.fetch(FetchDescriptor<CalendarEvent>())
        XCTAssertEqual(beforeDelete.count, 1)

        context.delete(beforeDelete[0])
        try context.save()

        let afterDelete = try context.fetch(FetchDescriptor<CalendarEvent>())
        XCTAssertEqual(afterDelete.count, 0)
    }
}
