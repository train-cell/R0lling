import Foundation

/// Normalizes a user-edited IANA time-zone identifier; blank input means the current zone.
enum JournalTimeZoneIdentifier {
    static func normalized(_ value: String, fallback: TimeZone = .current) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback.identifier }
        return TimeZone(identifier: trimmed)?.identifier
    }
}
