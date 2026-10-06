import Foundation

/// Persistence security-scoped bookmark για επιλεγμένο Obsidian vault (A08 Files picker).
public enum VaultBookmarkStore {
    public static let kleidiBookmark = "r0lling.obsidian.vaultBookmark"
    public static let kleidiDisplayPath = "r0lling.obsidian.vaultDisplayPath"
    public static let kleidiUsesDefault = "r0lling.obsidian.usesDefaultVault"

    /// Αποθήκευση bookmark από URL που δόθηκε από document picker / Files.
    public static func apothikeusi_bookmark(apo url: URL) throws {
        let data = try dimiourgia_bookmark_data(apo: url)
        UserDefaults.standard.set(data, forKey: kleidiBookmark)
        UserDefaults.standard.set(url.path, forKey: kleidiDisplayPath)
        UserDefaults.standard.set(false, forKey: kleidiUsesDefault)
    }

    /// Επαναφορά σε default Documents vault (χωρίς external bookmark).
    public static func epanekkinisi_proepilegmenou() {
        UserDefaults.standard.removeObject(forKey: kleidiBookmark)
        UserDefaults.standard.removeObject(forKey: kleidiDisplayPath)
        UserDefaults.standard.set(true, forKey: kleidiUsesDefault)
    }

    /// Εμφανίσιμο path για Settings UI.
    public static func display_path_i_default() -> String {
        if let path = UserDefaults.standard.string(forKey: kleidiDisplayPath), !path.isEmpty {
            return path
        }
        return "Documents/R0lling/ObsidianVault"
    }

    /// Resolve bookmark → URL. `nil` αν δεν υπάρχει bookmark (χρήση default vault).
    public static func fortosi_vault_url() throws -> (url: URL, requiresScopedAccess: Bool)? {
        guard let data = UserDefaults.standard.data(forKey: kleidiBookmark) else {
            return nil
        }
        let resolved = try epilysi_url(apo: data)
        if resolved.isStale {
            // Stale bookmark: ξαναγράψε αν το URL παραμένει προσβάσιμο.
            if FileManager.default.fileExists(atPath: resolved.url.path) {
                try apothikeusi_bookmark(apo: resolved.url)
            }
        }
        return (resolved.url, true)
    }

    // MARK: - Platform bookmark APIs

    private static func dimiourgia_bookmark_data(apo url: URL) throws -> Data {
        #if os(macOS)
        return try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #else
        return try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #endif
    }

    private static func epilysi_url(apo bookmarkData: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        #if os(macOS)
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        #else
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        #endif
        return (url, isStale)
    }
}
