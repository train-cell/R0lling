import Foundation
import Security

/// Ασφαλής αποθήκευση secrets στο Keychain (R3-004).
/// UserDefaults επιτρέπεται ΜΟΝΟ όταν `R0LLING_ALLOW_USERDEFAULTS_SECRETS=1` (test harness).
public enum KeychainSecretStore {
    public static let serviceName = "com.r0lling.secrets"
    /// Environment flag για ρητό UserDefaults fallback σε tests (ποτέ production default).
    public static let userDefaultsFallbackEnvKey = "R0LLING_ALLOW_USERDEFAULTS_SECRETS"

    /// Αποθηκεύει secret στο Keychain (ή UserDefaults αν επιτρέπεται ρητά από env).
    public static func store(value: String, forKey key: String) throws {
        if shouldUseUserDefaultsFallback() {
            UserDefaults.standard.set(value, forKey: key)
            return
        }

        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let changes: [String: Any] = [kSecValueData as String: data]
        let updated = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else {
            throw NSError(domain: "R0lling.Keychain", code: Int(updated), userInfo: [
                NSLocalizedDescriptionKey: "Αποτυχία ενημέρωσης Keychain (status \(updated))."
            ])
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(
                domain: "R0lling.Keychain",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Αποτυχία αποθήκευσης Keychain (status \(status))."]
            )
        }
    }

    /// Ανακτά secret από Keychain (ή UserDefaults fallback όταν επιτρέπεται).
    public static func retrieve(forKey key: String) -> String? {
        if shouldUseUserDefaultsFallback() {
            return UserDefaults.standard.string(forKey: key)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Διαγράφει secret από Keychain / UserDefaults fallback.
    public static func delete(forKey key: String) {
        try? deleteChecked(forKey: key)
    }

    /// Deletes a secret and reports Keychain failures to interactive callers.
    public static func deleteChecked(forKey key: String) throws {
        if shouldUseUserDefaultsFallback() {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(
                domain: "R0lling.Keychain",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Αποτυχία διαγραφής από Keychain (status \(status))."]
            )
        }
    }

    /// UserDefaults fallback ΜΟΝΟ σε DEBUG + ρητό env — ποτέ σε Release (Keychain audit).
    private static func shouldUseUserDefaultsFallback() -> Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment[userDefaultsFallbackEnvKey] == "1"
        #else
        return false
        #endif
    }
}
