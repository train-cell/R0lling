import Foundation

/// Μηχανή δημιουργίας αντιγράφων ασφαλείας (Backup) και ασφαλούς επαναφοράς (Restore).
/// A15 DoD: no-dupe IDs · clean sandbox restore · media + Agent memory · PathAsfaleia.
public actor BackupRestoreEngine: BackupRestoreProtocol {
    private let storage: JournalStorageProtocol
    private let mediaStorage: MediaStorageProtocol
    private let agentManager: AgentFolderManager?

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

    public init(
        storage: JournalStorageProtocol,
        mediaStorage: MediaStorageProtocol,
        agentManager: AgentFolderManager? = nil
    ) {
        self.storage = storage
        self.mediaStorage = mediaStorage
        self.agentManager = agentManager
    }

    /// Δημιουργεί bundle με manifest.json + Media/ + προαιρετικό Agent memory.
    public func createBackupBundle() async throws -> URL {
        let entries = try await storage.getAllEntries()
        let agentMemory = try? await agentManager?.loadAgentMemory()
        let manifest = BackupManifest(entries: entries, agentMemory: agentMemory)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("R0lling_Backup_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: manifestURL, options: .atomic)

        let mediaBundleDir = tempDir.appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaBundleDir, withIntermediateDirectories: true)

        for entry in entries {
            for attachment in entry.attachments {
                // SEC-002: skip traversal paths — fail-closed ανά attachment.
                guard let sourceURL = try? await mediaStorage.getMediaFileURL(relativePath: attachment.relativePath),
                      let destURL = try? PathAsfaleia.asfalhs_resolved_url(
                        relativePath: attachment.relativePath,
                        baseDirectory: mediaBundleDir
                      ) else {
                    continue
                }
                if FileManager.default.fileExists(atPath: sourceURL.path) {
                    try? FileManager.default.createDirectory(
                        at: destURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try? FileManager.default.copyItem(at: sourceURL, to: destURL)
                }
            }
        }

        return tempDir
    }

    /// Επαναφορά σε καθαρό ή υπάρχον sandbox χωρίς διπλότυπα IDs.
    public func restoreFromBackupBundle(bundleURL: URL) async throws -> (restoredEntries: Int, restoredMedia: Int) {
        let manifestURL = bundleURL.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupMissingManifest,
                message: "Μη έγκυρο backup: Λείπει το αρχείο manifest.json"
            )
        }

        let manifestData: Data
        do {
            manifestData = try Data(contentsOf: manifestURL)
        } catch {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupInvalidManifest,
                message: "Αδυναμία ανάγνωσης manifest.json",
                underlying: error
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest: BackupManifest
        do {
            manifest = try decoder.decode(BackupManifest.self, from: manifestData)
        } catch {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupInvalidManifest,
                message: "Μη έγκυρο περιεχόμενο manifest.json",
                underlying: error
            )
        }

        var restoredEntriesCount = 0
        var restoredMediaCount = 0

        let mediaBundleDir = bundleURL.appendingPathComponent("Media")

        for entry in manifest.entries {
            // Αποφυγή διπλότυπων IDs — υπάρχον entry μένει άθικτο.
            let existing = try await storage.getEntry(id: entry.id)
            if existing == nil {
                try await storage.saveEntry(entry)
                restoredEntriesCount += 1
            }

            // Επαναφορά πολυμέσων (SEC-002: canonicalize + reject ..)
            for attachment in entry.attachments {
                guard let backupMediaURL = try? PathAsfaleia.asfalhs_resolved_url(
                        relativePath: attachment.relativePath,
                        baseDirectory: mediaBundleDir
                      ),
                      let targetMediaURL = try? await mediaStorage.getMediaFileURL(
                        relativePath: attachment.relativePath
                      ) else {
                    continue
                }

                if FileManager.default.fileExists(atPath: backupMediaURL.path)
                    && !FileManager.default.fileExists(atPath: targetMediaURL.path) {
                    try? FileManager.default.createDirectory(
                        at: targetMediaURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try? FileManager.default.copyItem(at: backupMediaURL, to: targetMediaURL)
                    restoredMediaCount += 1
                }
            }
        }

        // Agent memory intact μετά restore (αν υπάρχει στο manifest + agentManager).
        if let memory = manifest.agentMemory, let agentManager {
            do {
                try await agentManager.saveAgentMemory(memory)
            } catch {
                throw AppErrorTaxonomy.makeError(
                    domain: AppErrorTaxonomy.backupDomain,
                    code: AppErrorTaxonomy.backupAgentRestoreFailed,
                    message: "Οι εγγραφές επαναφέρθηκαν, αλλά η Agent memory απέτυχε.",
                    underlying: error
                )
            }
        }

        return (restoredEntriesCount, restoredMediaCount)
    }
}
