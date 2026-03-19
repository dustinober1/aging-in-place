import CryptoKit
import Foundation
import Security

enum KeychainError: Error {
    case storeFailed(OSStatus)
    case notFound
    case deleteFailed(OSStatus)
}

struct KeychainService {
    private static let service = "com.agingInPlace.carekeys"

    /// Store a SymmetricKey for the given category in the Keychain.
    /// Deletes any existing entry first to handle key rotation.
    static func storeKey(_ key: SymmetricKey, for category: PermissionCategory) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: category.rawValue,
            kSecAttrService as String: service
        ]
        // Delete before add to handle rotation cleanly
        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: category.rawValue,
            kSecAttrService as String: service,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    /// Load a SymmetricKey for the given category from the Keychain.
    /// Throws `KeychainError.notFound` if no key exists.
    static func loadKey(for category: PermissionCategory) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: category.rawValue,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let keyData = result as? Data else {
            throw KeychainError.notFound
        }
        return SymmetricKey(data: keyData)
    }

    /// Load the key for the category, creating and storing a new one if absent.
    static func loadOrCreateKey(for category: PermissionCategory) throws -> SymmetricKey {
        do {
            return try loadKey(for: category)
        } catch KeychainError.notFound {
            let newKey = SymmetricKey(size: .bits256)
            try storeKey(newKey, for: category)
            return newKey
        }
    }

    /// Delete the key for the given category from the Keychain.
    /// Used for cleanup in tests and on permission revocation.
    static func deleteKey(for category: PermissionCategory) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: category.rawValue,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
