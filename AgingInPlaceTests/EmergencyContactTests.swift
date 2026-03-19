import XCTest
import SwiftData
@testable import AgingInPlace

final class EmergencyContactTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: EmergencyContact.self, configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - TEAM-09: Emergency contacts persist and are accessible without permission gating

    /// Create, save, and fetch an emergency contact — must persist correctly.
    @MainActor
    func testCreateAndFetchEmergencyContact() throws {
        let contact = EmergencyContact(
            name: "Dr. Jane Smith",
            phone: "555-0100",
            relationship: "Doctor",
            medicalNotes: "Cardiologist at City Hospital"
        )
        context.insert(contact)
        try context.save()

        let descriptor = FetchDescriptor<EmergencyContact>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].name, "Dr. Jane Smith")
        XCTAssertEqual(fetched[0].phone, "555-0100")
        XCTAssertEqual(fetched[0].relationship, "Doctor")
        XCTAssertEqual(fetched[0].medicalNotes, "Cardiologist at City Hospital")
    }

    /// Emergency contacts are stored with no PermissionCategory field — no permission gating.
    @MainActor
    func testEmergencyContactHasNoPermissionCategory() throws {
        let contact = EmergencyContact(name: "Bob", phone: "555-0101", relationship: "Neighbor")
        context.insert(contact)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<EmergencyContact>())
        XCTAssertEqual(fetched.count, 1)
        // EmergencyContact has no `category` property — any care team member can access it.
        // This test verifies the model compiles and is fetchable without any category check.
        XCTAssertNotNil(fetched[0].name)
    }

    /// Delete an emergency contact — it must be removed from the store.
    @MainActor
    func testDeleteEmergencyContact() throws {
        let contactA = EmergencyContact(name: "Alice", phone: "555-0200", relationship: "Spouse")
        let contactB = EmergencyContact(name: "Charlie", phone: "555-0201", relationship: "Son")
        context.insert(contactA)
        context.insert(contactB)
        try context.save()

        context.delete(contactA)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<EmergencyContact>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].name, "Charlie")
    }

    /// Optional medicalNotes can be nil.
    @MainActor
    func testEmergencyContactWithoutMedicalNotes() throws {
        let contact = EmergencyContact(name: "Sarah", phone: "555-0300", relationship: "Daughter")
        XCTAssertNil(contact.medicalNotes)
        context.insert(contact)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<EmergencyContact>())
        XCTAssertNil(fetched[0].medicalNotes)
    }
}
