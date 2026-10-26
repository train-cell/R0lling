import Foundation

/// Τοπική ασφαλής αποθήκευση καταγραφών σε Sandboxed JSON με Schema Versioning v1
public actor JSONFileStorageService: JournalStorageProtocol {
    public static let maximumJournalFileBytes = 64 * 1024 * 1024

    private let storageURL: URL
    private let maximumFileBytes: Int
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
        self.storageURL = Self.resolvedStorageURL(storageURL)
        self.maximumFileBytes = Self.maximumJournalFileBytes
    }

    init(storageURL: URL? = nil, testingMaximumFileBytes: Int) {
        self.storageURL = Self.resolvedStorageURL(storageURL)
        self.maximumFileBytes = max(1, min(testingMaximumFileBytes, Self.maximumJournalFileBytes))
    }

    private static func resolvedStorageURL(_ storageURL: URL?) -> URL {
        if let storageURL { return storageURL }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let r0llingDir = appSupport.appendingPathComponent("R0lling", isDirectory: true)
        try? FileManager.default.createDirectory(at: r0llingDir, withIntermediateDirectories: true)
        return r0llingDir.appendingPathComponent("journal_v1.json")
    }

    private func ensureLoaded() throws {
        guard !isLoaded else { return }

        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            entriesCache = [:]
            isLoaded = true
            return
        }

        do {
            try R0llingFileProtection.apply(to: storageURL)
            let data = try BoundedRegularFileReader.readData(
                at: storageURL,
                maximumBytes: maximumFileBytes
            )
            let decoder = JSONDecoder()
            // R3-001: encode χρησιμοποιεί .iso8601 — το decode πρέπει να ταιριάζει αλλιώς χάνεται το journal στο restart.
            decoder.dateDecodingStrategy = .iso8601
            let container = try decoder.decode(StorageContainer.self, from: data)
            guard container.schemaVersion == 1,
                  Set(container.entries.map(\.id)).count == container.entries.count else {
                throw NSError(domain: "R0lling.Journal", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Μη υποστηριζόμενο schema ή διπλότυπα IDs. Το journal διατηρήθηκε άθικτο."
                ])
            }
            entriesCache = Dictionary(uniqueKeysWithValues: container.entries.map { ($0.id, $0) })
            isLoaded = true
        } catch {
            throw NSError(domain: "R0lling.Journal", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Αδυναμία φόρτωσης journal. Η εγγραφή αποκλείστηκε για προστασία των δεδομένων.",
                NSUnderlyingErrorKey: error
            ])
        }
    }

    private func flushToDisk(entries: [UUID: JournalEntry]) throws {
        try enforceSerializedSizeUpperBound(entries: entries)
        let container = StorageContainer(entries: Array(entries.values))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)
        guard data.count <= maximumFileBytes else {
            throw journalSizeExceededError()
        }

        // Ατομική εγγραφή για προστασία από διακοπές ρεύματος / crashes
        try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try R0llingFileProtection.apply(to: storageURL.deletingLastPathComponent())
        try data.write(to: storageURL, options: R0llingFileProtection.atomicWriteOptions)
    }

    /// Rejects huge string/collection payloads before JSONEncoder allocates the full document.
    private func enforceSerializedSizeUpperBound(entries: [UUID: JournalEntry]) throws {
        var estimatedBytes = 1_024 // Container keys, metadata, and formatting.

        func add(_ byteCount: Int) throws {
            let (next, overflow) = estimatedBytes.addingReportingOverflow(byteCount)
            guard !overflow, next <= maximumFileBytes else {
                throw journalSizeExceededError()
            }
            estimatedBytes = next
        }

        func addString(_ value: String?) throws {
            guard let value else { return }
            try add(2) // JSON string delimiters.
            for scalar in value.unicodeScalars {
                let encodedByteCount: Int
                switch scalar.value {
                case 0x22, 0x2F, 0x5C: // Quote, slash, and backslash.
                    encodedByteCount = 2
                case 0x00...0x1F:
                    encodedByteCount = 6 // Conservative upper bound for a JSON control escape.
                default:
                    encodedByteCount = scalar.utf8.count
                }
                try add(encodedByteCount)
            }
        }

        for entry in entries.values {
            try add(512) // Keys, dates, UUID, flags, separators, and number fields.
            try addString(entry.timeZoneIdentifier)
            try addString(entry.title)
            try addString(entry.content)
            try addString(entry.source.rawValue)
            try addString(entry.locationName)
            try add(entry.tags.count) // Array separators.
            for tag in entry.tags { try addString(tag) }

            for attachment in entry.attachments {
                try add(512) // Attachment keys and fixed metadata.
                try addString(attachment.relativePath)
                try addString(attachment.originalFilename)
                try addString(attachment.mediaType.rawValue)
            }
        }
    }

    private func journalSizeExceededError() -> NSError {
        NSError(domain: "R0lling.Journal", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Το journal υπερβαίνει το όριο των \(maximumFileBytes) bytes. Η προηγούμενη εγγραφή διατηρήθηκε."
        ])
    }

    public func saveEntry(_ entry: JournalEntry) throws {
        try ensureLoaded()
        var updated = entriesCache
        updated[entry.id] = entry
        try flushToDisk(entries: updated)
        entriesCache = updated
        R0llingTelemetry.shared.log(.storage, stathmi: .debug, "Επιτυχής αποθήκευση entry \(entry.id.uuidString)")
    }

    public func updateEntryIfPresent(_ entry: JournalEntry) async throws -> Bool {
        try ensureLoaded()
        guard entriesCache[entry.id] != nil else { return false }
        var updated = entriesCache
        updated[entry.id] = entry
        try flushToDisk(entries: updated)
        entriesCache = updated
        return true
    }

    public func appendAttachmentIfPresent(
        _ attachment: MediaAttachment,
        toEntryID id: UUID
    ) async throws -> JournalEntry? {
        try ensureLoaded()
        guard var entry = entriesCache[id] else { return nil }
        entry.attachments.append(attachment)
        entry.lastModified = Date()
        var updated = entriesCache
        updated[id] = entry
        try flushToDisk(entries: updated)
        entriesCache = updated
        return entry
    }

    public func insertEntriesIfAbsentAtomically(_ entries: [JournalEntry]) throws -> Set<UUID> {
        guard !entries.isEmpty else { return [] }
        try ensureLoaded()
        guard Set(entries.map(\.id)).count == entries.count else {
            throw NSError(domain: "R0lling.Journal", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Η μαζική εγγραφή περιέχει διπλότυπα IDs."
            ])
        }

        let additions = entries.filter { entriesCache[$0.id] == nil }
        guard !additions.isEmpty else { return [] }
        var updated = entriesCache
        for entry in additions {
            updated[entry.id] = entry
        }
        try flushToDisk(entries: updated)
        entriesCache = updated
        return Set(additions.map(\.id))
    }

    public func deleteEntry(id: UUID) throws {
        try ensureLoaded()
        var updated = entriesCache
        updated.removeValue(forKey: id)
        try flushToDisk(entries: updated)
        entriesCache = updated
    }

    public func getEntry(id: UUID) throws -> JournalEntry? {
        try ensureLoaded()
        return entriesCache[id]
    }

    /// Protocol witness — default display TZ = τρέχουσα συσκευής.
    public func getEntriesForDate(_ date: Date) throws -> [JournalEntry] {
        try getEntriesForDate(date, displayTimeZone: .current)
    }

    /// R3-009: φιλτράρει με `entry.dateKey` (TZ εγγραφής) έναντι UI day key σε `displayTimeZone`.
    /// Πολιτική: η εγγραφή ανήκει στην ημερολογιακή ημέρα της ζώνης καταγραφής· το UI day
    /// υπολογίζεται ρητά στη ζώνη προβολής, όχι με σιωπηλό DateFormatter.
    public func getEntriesForDate(_ date: Date, displayTimeZone: TimeZone) throws -> [JournalEntry] {
        try ensureLoaded()
        let targetKey = JournalEntry.makeDateKey(for: date, timeZone: displayTimeZone)

        return entriesCache.values
            .filter { $0.dateKey == targetKey }
            .sorted { $0.timestamp < $1.timestamp }
    }

    public func getAllEntries() throws -> [JournalEntry] {
        try ensureLoaded()
        return Array(entriesCache.values).sorted { $0.timestamp > $1.timestamp }
    }

    public func searchEntries(query: String, tag: String?, source: EntrySource?) throws -> [JournalEntry] {
        try ensureLoaded()
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

    public func getDatesWithEntries() throws -> Set<String> {
        try ensureLoaded()
        return Set(entriesCache.values.map { $0.dateKey })
    }
}
