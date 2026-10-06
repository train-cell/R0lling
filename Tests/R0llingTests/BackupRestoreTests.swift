import XCTest
@testable import R0lling

final class BackupRestoreTests: XCTestCase {
    var tempDirectory: URL!
    var storage: JSONFileStorageService!
    var mediaStorage: MediaStorageService!
    var agentManager: AgentFolderManager!
    var backupEngine: BackupRestoreEngine!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestBackup_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        storage = JSONFileStorageService(storageURL: tempDirectory.appendingPathComponent("journal.json"))
        mediaStorage = MediaStorageService(
            baseDirectory: tempDirectory.appendingPathComponent("Media"),
            paradekampseElegxoXorou: true
        )
        agentManager = AgentFolderManager(
            vaultURL: tempDirectory.appendingPathComponent("Vault", isDirectory: true)
        )
        backupEngine = BackupRestoreEngine(
            storage: storage,
            mediaStorage: mediaStorage,
            agentManager: agentManager
        )
    }

    override func tearDown() async throws {
        if let dir = tempDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func testCreateBackupAndRestoreIdempotently() async throws {
        let entry1 = JournalEntry(content: "Σημείωση για Backup 1")
        let entry2 = JournalEntry(content: "Σημείωση για Backup 2")
        try await storage.saveEntry(entry1)
        try await storage.saveEntry(entry2)

        let bundleURL = try await backupEngine.createBackupBundle()
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("manifest.json").path)
        )

        let cleanStorageURL = tempDirectory.appendingPathComponent("clean_journal.json")
        let cleanStorage = JSONFileStorageService(storageURL: cleanStorageURL)
        let cleanMedia = MediaStorageService(
            baseDirectory: tempDirectory.appendingPathComponent("CleanMedia"),
            paradekampseElegxoXorou: true
        )
        let cleanAgent = AgentFolderManager(
            vaultURL: tempDirectory.appendingPathComponent("CleanVault", isDirectory: true)
        )
        let cleanBackupEngine = BackupRestoreEngine(
            storage: cleanStorage,
            mediaStorage: cleanMedia,
            agentManager: cleanAgent
        )

        let result = try await cleanBackupEngine.restoreFromBackupBundle(bundleURL: bundleURL)
        XCTAssertEqual(result.restoredEntries, 2)

        let restoredEntries = await cleanStorage.getAllEntries()
        XCTAssertEqual(restoredEntries.count, 2)
        XCTAssertEqual(Set(restoredEntries.map(\.id)), Set([entry1.id, entry2.id]))
    }

    /// A15: clean sandbox · ίδια IDs · media αρχείο · Agent memory.
    func testRestorePreservesIdsMediaAndAgentMemory() async throws {
        let mediaBytes = Data("fake-photo-bytes".utf8)
        let attachment = try await mediaStorage.saveMediaFile(
            data: mediaBytes,
            originalFilename: "probe.jpg",
            mediaType: .photo
        )
        let entry = JournalEntry(
            content: "Backup με media",
            attachments: [attachment]
        )
        try await storage.saveEntry(entry)

        let memory = AgentMemory(
            memoryNotes: "# Memory\n\n- keep this note\n",
            userPreferences: "# Prefs\n\n",
            openLoops: "# Loops\n\n"
        )
        try await agentManager.saveAgentMemory(memory)

        let bundleURL = try await backupEngine.createBackupBundle()

        let cleanRoot = tempDirectory.appendingPathComponent("CleanFull", isDirectory: true)
        try FileManager.default.createDirectory(at: cleanRoot, withIntermediateDirectories: true)
        let cleanStorage = JSONFileStorageService(storageURL: cleanRoot.appendingPathComponent("journal.json"))
        let cleanMedia = MediaStorageService(
            baseDirectory: cleanRoot.appendingPathComponent("Media"),
            paradekampseElegxoXorou: true
        )
        let cleanAgent = AgentFolderManager(vaultURL: cleanRoot.appendingPathComponent("Vault"))
        let cleanEngine = BackupRestoreEngine(
            storage: cleanStorage,
            mediaStorage: cleanMedia,
            agentManager: cleanAgent
        )

        let result = try await cleanEngine.restoreFromBackupBundle(bundleURL: bundleURL)
        XCTAssertEqual(result.restoredEntries, 1)
        XCTAssertEqual(result.restoredMedia, 1)

        let restored = await cleanStorage.getEntry(id: entry.id)
        XCTAssertEqual(restored?.id, entry.id)
        XCTAssertEqual(restored?.attachments.first?.relativePath, attachment.relativePath)

        let mediaURL = try cleanMedia.getMediaFileURL(relativePath: attachment.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: mediaURL.path))

        let restoredMemory = try await cleanAgent.loadAgentMemory()
        XCTAssertTrue(restoredMemory.memoryNotes.contains("keep this note"))
    }

    /// A15: δεύτερο restore στο ίδιο sandbox → 0 νέα IDs (no-dupe).
    func testSecondRestoreDoesNotDuplicateIds() async throws {
        let entry = JournalEntry(content: "Μία φορά μόνο")
        try await storage.saveEntry(entry)
        let bundleURL = try await backupEngine.createBackupBundle()

        let first = try await backupEngine.restoreFromBackupBundle(bundleURL: bundleURL)
        XCTAssertEqual(first.restoredEntries, 0, "Source sandbox ήδη έχει το ID")

        let all = await storage.getAllEntries()
        XCTAssertEqual(all.count, 1)
    }

    /// A15/SEC-002: traversal relativePath στο bundle → skip χωρίς crash.
    func testRestoreSkipsTraversalMediaPaths() async throws {
        let safeEntry = JournalEntry(content: "safe")
        try await storage.saveEntry(safeEntry)
        let bundleURL = try await backupEngine.createBackupBundle()

        // Εμβόλιμο κακόβουλο relativePath στο manifest (χειροκίνητα).
        let manifestURL = bundleURL.appendingPathComponent("manifest.json")
        var manifestData = try Data(contentsOf: manifestURL)
        var json = try JSONSerialization.jsonObject(with: manifestData) as! [String: Any]
        var entries = json["entries"] as! [[String: Any]]
        let evilAttachment: [String: Any] = [
            "id": UUID().uuidString,
            "relativePath": "../evil.bin",
            "mediaType": "photo",
            "byteSize": 1,
            "captureTimestamp": ISO8601DateFormatter().string(from: Date()),
            "hasAudio": false
        ]
        var first = entries[0]
        first["attachments"] = [evilAttachment]
        entries[0] = first
        json["entries"] = entries
        manifestData = try JSONSerialization.data(withJSONObject: json)
        try manifestData.write(to: manifestURL)

        let cleanStorage = JSONFileStorageService(
            storageURL: tempDirectory.appendingPathComponent("trav_journal.json")
        )
        let cleanMedia = MediaStorageService(
            baseDirectory: tempDirectory.appendingPathComponent("TravMedia"),
            paradekampseElegxoXorou: true
        )
        let cleanEngine = BackupRestoreEngine(storage: cleanStorage, mediaStorage: cleanMedia)

        let result = try await cleanEngine.restoreFromBackupBundle(bundleURL: bundleURL)
        XCTAssertEqual(result.restoredEntries, 1)
        XCTAssertEqual(result.restoredMedia, 0, "Traversal path πρέπει να αγνοηθεί")
    }

    func testMissingManifestThrowsBackupTaxonomy() async throws {
        let emptyBundle = tempDirectory.appendingPathComponent("EmptyBundle", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyBundle, withIntermediateDirectories: true)

        do {
            _ = try await backupEngine.restoreFromBackupBundle(bundleURL: emptyBundle)
            XCTFail("Expected missing manifest error")
        } catch {
            let ns = error as NSError
            XCTAssertEqual(ns.domain, AppErrorTaxonomy.backupDomain)
            XCTAssertEqual(ns.code, AppErrorTaxonomy.backupMissingManifest)
        }
    }
}
