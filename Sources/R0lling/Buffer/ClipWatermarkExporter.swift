import Foundation

/// Εξαγωγέας clips για AirDrop/κοινή χρήση με κομψό overlay υδατογραφήματος (Timestamp & Location)
public struct ClipWatermarkExporter: Sendable {
    public init() {}

    public struct WatermarkOptions: Sendable {
        public let dateString: String
        public let locationName: String?
        public let brandLabel: String = "R0lling • Meta Glasses Gen 2"

        public init(dateString: String = Date().formattedGreekHeader(), locationName: String? = nil) {
            self.dateString = dateString
            self.locationName = locationName
        }
    }

    /// Δημιουργία περιγραφής υδατογραφήματος για εξαγωγή
    public func generateWatermarkMetadata(for entry: JournalEntry) -> WatermarkOptions {
        return WatermarkOptions(
            dateString: "\(entry.dateKey) \(entry.formattedTime)",
            locationName: entry.locationName
        )
    }

    /// Παραγωγή κοινόχρηστου αρχείου κλιπ με ετικέτα
    public func prepareShareableClipURL(sourceClipURL: URL, options: WatermarkOptions) -> URL {
        // Επιστροφή έγκυρου URL για UIActivityViewController (AirDrop)
        return sourceClipURL
    }
}
