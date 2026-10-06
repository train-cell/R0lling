import Foundation

/// Μηχανή δημιουργίας αντιγράφων ασφαλείας (Backup) και ασφαλούς επαναφοράς (Restore)
public actor BackupRestoreEngine: BackupRestoreProtocol {
    private let storage: JournalStorageProtocol
    private let mediaStorage: MediaStorageProtocol

    public struct BackupManifest: Codable {
        public let schemaVersion: Int
        public let backupTimestamp: Date
        public let appVersion: String
        public let entriesCount: Int
        public let entries: [JournalEntry]
        public let agentMemory: AgentMemory?

        public init(entries: [JournalEntry], agentMemory: AgentMemory? = nil) {
            self.schemaVersion = 1
            self.backupTimestamp = Date()
            self.appVersion = "1.0.0"
            self.entriesCount = entries.count
            self.entries = entries
            self.agentMemory = agentMemory
        }
    }

    public init(storage: JournalStorageProtocol, mediaStorage: MediaStorageProtocol) {
        self.storage = storage
        self.mediaStorage = mediaStorage
    }

    public func createBackupBundle() async throws -> URL {
        let entries = try await storage.getAllEntries()
        let manifest = BackupManifest(entries: entries)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("R0lling_Backup_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: manifestURL, options: .atomic)

        // Αντιγραφή συνημμένων μέσων
        let mediaBundleDir = tempDir.appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaBundleDir, withIntermediateDirectories: true)

        for entry in entries {
            for attachment in entry.attachments {
                let sourceURL = await mediaStorage.getMediaFileURL(relativePath: attachment.relativePath)
                if FileManager.default.fileExists(atPath: sourceURL.path) {
                    let destURL = mediaBundleDir.appendingPathComponent(attachment.relativePath)
                    try? FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? FileManager.default.copyItem(at: sourceURL, to: destURL)
                }
            }
        }

        return tempDir
    }

    public func restoreFromBackupBundle(bundleURL: URL) async throws -> (restoredEntries: Int, restoredMedia: Int) {
        let manifestURL = bundleURL.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw NSError(domain: "R0lling.BackupRestore", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Μη έγκυρο backup: Λείπει το αρχείο manifest.json"])
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupManifest.self, from: manifestData)

        var restoredEntriesCount = 0
        var restoredMediaCount = 0

        let mediaBundleDir = bundleURL.appendingPathComponent("Media")

        for entry in manifest.entries {
            // Έλεγχος αν υπάρχει ήδη η εγγραφή (αποφυγή διπλότυπων)
            let existing = try await storage.getEntry(id: entry.id)
            if existing == nil {
                try await storage.saveEntry(entry)
                restoredEntriesCount += 1
            }

            // Επαναφορά πολυμέσων
            for attachment in entry.attachments {
                let backupMediaURL = mediaBundleDir.appendingPathComponent(attachment.relativePath)
                let targetMediaURL = await mediaStorage.getMediaFileURL(relativePath: attachment.relativePath)

                if FileManager.default.fileExists(atPath: backupMediaURL.path) && !FileManager.default.fileExists(atPath: targetMediaURL.path) {
                    try? FileManager.default.createDirectory(at: targetMediaURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? FileManager.default.copyItem(at: backupMediaURL, to: targetMediaURL)
                    restoredMediaCount += 1
                }
            }
        }

        return (restoredEntriesCount, restoredMediaCount)
    }
}
