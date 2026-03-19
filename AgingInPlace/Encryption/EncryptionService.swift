import CryptoKit
import Foundation

struct EncryptionService {
    /// Seal plaintext Data for the given category using its Keychain key.
    /// Returns the AES-GCM combined sealed box (nonce + ciphertext + tag).
    static func seal(_ plaintext: Data, for category: PermissionCategory) throws -> Data {
        let key = try KeychainService.loadOrCreateKey(for: category)
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        // combined is nonce (12 bytes) + ciphertext + tag (16 bytes)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    /// Open AES-GCM sealed box bytes using the current category key.
    static func open(_ ciphertext: Data, for category: PermissionCategory) throws -> Data {
        let key = try KeychainService.loadKey(for: category)
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(sealedBox, using: key)
    }

    /// Rotate the key for a category.
    /// Generates a new SymmetricKey and overwrites the Keychain entry.
    /// Old key is permanently lost — new records use new key;
    /// revoked members cannot decrypt records written after rotation.
    static func rotateKey(for category: PermissionCategory) throws {
        let newKey = SymmetricKey(size: .bits256)
        try KeychainService.storeKey(newKey, for: category)
    }
}

enum EncryptionError: Error {
    case sealFailed
}
