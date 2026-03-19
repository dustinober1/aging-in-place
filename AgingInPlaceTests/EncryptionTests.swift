import XCTest
@testable import AgingInPlace

final class EncryptionTests: XCTestCase {

    override func tearDown() async throws {
        // Clean up all Keychain keys after each test
        for category in PermissionCategory.allCases {
            try? KeychainService.deleteKey(for: category)
        }
    }

    // MARK: - seal() returns ciphertext, not plaintext (SYNC-04, SYNC-08)

    func testSealReturnsCiphertext_notPlaintext() throws {
        let plaintext = "Take Metformin 500mg at 2pm".data(using: .utf8)!
        let ciphertext = try EncryptionService.seal(plaintext, for: .medications)
        XCTAssertNotEqual(ciphertext, plaintext, "Sealed data must not equal plaintext (SYNC-04, SYNC-08)")
    }

    // MARK: - Round-trip: open(seal(plaintext)) == plaintext

    func testRoundTrip_openAfterSeal_returnsOriginalPlaintext() throws {
        let plaintext = "Mood: feeling well today".data(using: .utf8)!
        let ciphertext = try EncryptionService.seal(plaintext, for: .mood)
        let decrypted = try EncryptionService.open(ciphertext, for: .mood)
        XCTAssertEqual(decrypted, plaintext, "Round-trip seal/open must return original plaintext")
    }

    // MARK: - Key rotation: new records cannot be opened with old key (SYNC-05)

    func testKeyRotation_newRecordCannotBeOpenedWithOldKey() throws {
        // Capture old key before rotation
        let oldKey = try KeychainService.loadOrCreateKey(for: .medications)

        // Rotate the key
        try EncryptionService.rotateKey(for: .medications)

        // Seal data with the new key
        let plaintext = "New record after rotation".data(using: .utf8)!
        let ciphertext = try EncryptionService.seal(plaintext, for: .medications)

        // Store old key back temporarily to attempt decryption
        try KeychainService.storeKey(oldKey, for: .medications)

        // Attempting to open with old key must fail
        XCTAssertThrowsError(
            try EncryptionService.open(ciphertext, for: .medications),
            "Opening a record sealed under rotated key with old key must throw"
        )
    }

    // MARK: - open() with wrong category key throws

    func testOpen_wrongCategoryKey_throws() throws {
        let plaintext = "Care visit at 10am".data(using: .utf8)!
        // Seal under .careVisits
        let ciphertext = try EncryptionService.seal(plaintext, for: .careVisits)

        // Make sure .calendar key exists (different key)
        _ = try KeychainService.loadOrCreateKey(for: .calendar)

        // Open with wrong category must fail
        XCTAssertThrowsError(
            try EncryptionService.open(ciphertext, for: .calendar),
            "Opening ciphertext sealed under .careVisits with .calendar key must throw"
        )
    }
}
