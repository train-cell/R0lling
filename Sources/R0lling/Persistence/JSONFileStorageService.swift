import Foundation

/// Τοπική ασφαλής αποθήκευση καταγραφών σε Sandboxed JSON με Schema Versioning v1
public actor JSONFileStorageService: JournalStorageProtocol {
    private let storageURL: URL
    private var entriesCache: [UUID: JournalEntry] = [:]
    private var isLoaded = false

    public struct StorageContainer: Codable {
        public let schemaVersion: Int
        public let appVersion: String
        public let lastUpdated: Date
        public var entries: [JournalEntry]

        public init(entries: [JournalEntry]) {
            self.schemaVersion = 1
            self.appVersion = "1.0.0"
            self.lastUpdated = Date()
            self.entries = entries
        }
    }

    public init(storageURL: URL? = nil) {
        if let url = storageURL {
            self.storageURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let r0llingDir = appSupport.appendingPathComponent("R0lling", isDirectory: true)
            try? FileManager.default.createDirectory(at: r0llingDir, withIntermediateDirectories: true)
            self.storageURL = r0llingDir.appendingPathComponent("journal_v1.json")
        }
    }

    private func ensureLoaded() {
        guard !isLoaded else { return }
        isLoaded = true

        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            entriesCache = [:]
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            // R3-001: encode χρησιμοποιεί .iso8601 — το decode πρέπει να ταιριάζει αλλιώς χάνεται το journal στο restart.
            decoder.dateDecodingStrategy = .iso8601
            let container = try decoder.decode(StorageContainer.self, from: data)
            entriesCache = Dictionary(uniqueKeysWithValues: container.entries.map { ($0.id, $0) })
        } catch {
            print("[JSONFileStorageService] Σφάλμα φόρτωσης αρχείου: \(error). Δημιουργία καθαρού cache.")
            entriesCache = [:]
        }
    }

    private func flushToDisk() throws {
        let container = StorageContainer(entries: Array(entriesCache.values))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)

        // Ατομική εγγραφή για προστασία από διακοπές ρεύματος / crashes
        try data.write(to: storageURL, options: .atomic)
    }

    public func saveEntry(_ entry: JournalEntry) throws {
        ensureLoaded()
        entriesCache[entry.id] = entry
        try flushToDisk()
    }

    public func deleteEntry(id: UUID) throws {
        ensureLoaded()
        entriesCache.removeValue(forKey: id)
        try flushToDisk()
    }

    public func getEntry(id: UUID) -> JournalEntry? {
        ensureLoaded()
        return entriesCache[id]
    }

    /// Protocol witness — default display TZ = τρέχουσα συσκευής.
    public func getEntriesForDate(_ date: Date) -> [JournalEntry] {
        getEntriesForDate(date, displayTimeZone: .current)
    }

    /// R3-009: φιλτράρει με `entry.dateKey` (TZ εγγραφής) έναντι UI day key σε `displayTimeZone`.
    /// Πολιτική: η εγγραφή ανήκει στην ημερολογιακή ημέρα της ζώνης καταγραφής· το UI day
    /// υπολογίζεται ρητά στη ζώνη προβολής, όχι με σιωπηλό DateFormatter.
    public func getEntriesForDate(_ date: Date, displayTimeZone: TimeZone) -> [JournalEntry] {
        ensureLoaded()
        let targetKey = JournalEntry.makeDateKey(for: date, timeZone: displayTimeZone)

        return entriesCache.values
            .filter { $0.dateKey == targetKey }
            .sorted { $0.timestamp < $1.timestamp }
    }

    public func getAllEntries() -> [JournalEntry] {
        ensureLoaded()
        return Array(entriesCache.values).sorted { $0.timestamp > $1.timestamp }
    }

    public func searchEntries(query: String, tag: String?, source: EntrySource?) -> [JournalEntry] {
        ensureLoaded()
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return entriesCache.values.filter { entry in
            var matches = true
            if !cleanQuery.isEmpty {
                let inContent = entry.content.lowercased().contains(cleanQuery)
                let inTitle = entry.title?.lowercased().contains(cleanQuery) ?? false
                let inTags = entry.tags.contains { $0.lowercased().contains(cleanQuery) }
                matches = matches && (inContent || inTitle || inTags)
            }
            if let tag = tag, !tag.isEmpty {
                matches = matches && entry.tags.contains(tag)
            }
            if let source = source {
                matches = matches && (entry.source == source)
            }
            return matches
        }.sorted { $0.timestamp > $1.timestamp }
    }

    public func getDatesWithEntries() -> Set<String> {
        ensureLoaded()
        return Set(entriesCache.values.map { $0.dateKey })
    }
}
