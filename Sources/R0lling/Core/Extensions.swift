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
