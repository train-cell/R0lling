import Foundation
import CryptoKit
import Security

/// AES-GCM keys stored in this device's Keychain. This is not Secure Enclave AES.
enum VaultCryptography {
    static let diaryKeychainService = "com.r0lling.vault.aes"
    static let helperKeychainService = "com.r0lling.local-aes-helper"

    /// Retrieves an existing key, or creates it only when Keychain reports item-not-found.
    static func key(tag: String, create: Bool, service: String = diaryKeychainService) throws -> SymmetricKey {
        guard !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw failure(errSecParam)
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tag
        ]
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        if status == errSecSuccess {
            guard let bytes = item as? Data, bytes.count == 32 else { throw failure(errSecDecode) }
            return SymmetricKey(data: bytes)
        }
        guard status == errSecItemNotFound, create else { throw failure(status) }
        let newKey = SymmetricKey(size: .bits256)
        var addition = query
        addition[kSecValueData as String] = newKey.withUnsafeBytes { Data($0) }
        addition[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let added = SecItemAdd(addition as CFDictionary, nil)
        if added == errSecDuplicateItem { return try key(tag: tag, create: false, service: service) }
        guard added == errSecSuccess else { throw failure(added) }
        return newKey
    }

    /// Reports Keychain failures without exposing key bytes.
    private static func failure(_ status: OSStatus) -> NSError {
        NSError(domain: "R0lling.Vault.Keychain", code: Int(status), userInfo: [
            NSLocalizedDescriptionKey: "Το κλειδί vault δεν είναι διαθέσιμο (Keychain status \(status))."
        ])
    }
}
