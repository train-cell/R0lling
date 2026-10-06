import Foundation
import CryptoKit

extension Date {
    /// Μορφοποίηση ημερομηνίας σε αναγνώσιμη μορφή για τίτλους (π.χ. "Τρίτη, 6 Οκτωβρίου 2026")
    public func formattedGreekHeader() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    /// Επιστροφή της αρχής της ημέρας για υπολογισμούς calendar
    public var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// ISO8601 μορφοποιημένο string
    public var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

extension Int64 {
    /// Μορφοποίηση μεγέθους bytes σε KB/MB/GB
    public func formattedByteCount() -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: self)
    }
}

extension String {
    /// Υπολογισμός SHA256 hash για σύγκριση αρχείων και ανίχνευση συγκρούσεων
    public var sha256Hash: String {
        let data = Data(self.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension Data {
    /// Υπολογισμός SHA256 hash για δυαδικά δεδομένα
    public var sha256Hash: String {
        let digest = SHA256.hash(data: self)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// SEC-002: Ασφαλής επίλυση relative paths μέσα σε base directory (path traversal guard).
public enum PathAsfaleia {
    public static let errorDomain = "R0lling.PathAsfaleia"
    public static let kodikosApokleismou = 3001

    /// Επιστρέφει URL κάτω από `baseDirectory` ή throw αν το relative path επιχειρεί escape.
    public static func asfalhs_resolved_url(relativePath: String, baseDirectory: URL) throws -> URL {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw pathError("Κενό relative path.")
        }
        guard !trimmed.contains("\0") else {
            throw pathError("Null byte στο relative path.")
        }
        // Absolute / UNC / Windows drive
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("\\") {
            throw pathError("Απαγορεύεται absolute relativePath.")
        }
        if trimmed.count >= 2 {
            let second = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 1)]
            if second == ":" {
                throw pathError("Απαγορεύεται Windows drive path.")
            }
        }

        let normalizedSeparators = trimmed
            .replacingOccurrences(of: "\\", with: "/")
        let components = normalizedSeparators
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard !components.isEmpty else {
            throw pathError("Κενά path components.")
        }
        guard !components.contains("..") && !components.contains(".") else {
            // "." μόνο του μπορεί να είναι αβλαβές, αλλά απορρίπτουμε για απλότητα/ασφάλεια.
            throw pathError("Απαγορεύονται '.' / '..' στο relativePath.")
        }

        let candidate = baseDirectory
            .appendingPathComponent(normalizedSeparators)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let baseResolved = baseDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL

        let basePath = baseResolved.path
        let candidatePath = candidate.path
        let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
        guard candidatePath == basePath || candidatePath.hasPrefix(prefix) else {
            throw pathError("Το resolved path βγαίνει εκτός base directory.")
        }
        return candidate
    }

    private static func pathError(_ message: String) -> NSError {
        NSError(
            domain: errorDomain,
            code: kodikosApokleismou,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
