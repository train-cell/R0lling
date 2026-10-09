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

        let restoredEntries = try await cleanStorage.getAllEntries()
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

        let restored = try await cleanStorage.getEntry(id: entry.id)
        XCTAssertEqual(restored?.id, entry.id)
        XCTAssertEqual(restored?.attachments.first?.relativePath, attachment.relativePath)

        // Inspect the restored file before getMediaFileURL can migrate/protect it on access.
        let restoredMediaURL = try PathAsfaleia.asfalhs_resolved_url(
            relativePath: attachment.relativePath,
            baseDirectory: cleanRoot.appendingPathComponent("Media", isDirectory: true)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoredMediaURL.path))
        #if os(iOS)
        let restoredAttributes = try FileManager.default.attributesOfItem(atPath: restoredMediaURL.path)
        XCTAssertEqual(
            restoredAttributes[.protectionKey] as? FileProtectionType,
            .completeUntilFirstUserAuthentication
        )
        #endif

        let mediaURL = try cleanMedia.getMediaFileURL(relativePath: attachment.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: mediaURL.path))

        let restoredMemory = try await cleanAgent.loadAgentMemory()
        XCTAssertTrue(restoredMemory.memoryNotes.contains("keep this note"))
    }

    func testRestoreUsesBackupBytesWhenTargetPathIsAnExistingDirectory() async throws {
        let bytes = Data("trusted backup bytes".utf8)
        let attachment = try await mediaStorage.saveMediaFile(
            data: bytes,
            originalFilename: "photo.jpg",
            mediaType: .photo
        )
        let sourceEntry = JournalEntry(content: "directory collision", attachments: [attachment])
        try await storage.saveEntry(sourceEntry)
        let bundleURL = try await backupEngine.createBackupBundle()

        let targetRoot = tempDirectory.appendingPathComponent("DirectoryCollisionTarget", isDirectory: true)
        let targetStorage = JSONFileStorageService(storageURL: targetRoot.appendingPathComponent("journal.json"))
        let targetMedia = MediaStorageService(
            baseDirectory: targetRoot.appendingPathComponent("Media"),
            paradekampseElegxoXorou: true
        )
        let collidingURL = try targetMedia.getMediaFileURL(relativePath: attachment.relativePath)
        try FileManager.default.createDirectory(at: collidingURL, withIntermediateDirectories: true)
        try Data("must remain a directory".utf8).write(
            to: collidingURL.appendingPathComponent("unrelated.txt")
        )
        let targetEngine = BackupRestoreEngine(
            storage: targetStorage,
            mediaStorage: targetMedia,
            agentManager: AgentFolderManager(vaultURL: targetRoot.appendingPathComponent("Vault"))
        )

        let result = try await targetEngine.restoreFromBackupBundle(bundleURL: bundleURL)
        XCTAssertEqual(result.restoredEntries, 1)
        let restored = try await targetStorage.getEntry(id: sourceEntry.id)
        let restoredAttachment = try XCTUnwrap(restored?.attachments.first)
        XCTAssertNotEqual(restoredAttachment.relativePath, attachment.relativePath)
        let restoredURL = try targetMedia.getMediaFileURL(relativePath: restoredAttachment.relativePath)
        XCTAssertEqual(try Data(contentsOf: restoredURL), bytes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: collidingURL.appendingPathComponent("unrelated.txt").path))
    }

    func testRestoreRejectsMissingBundleMediaEvenWhenTargetAlreadyHasAFile() async throws {
        let bytes = Data("expected bytes".utf8)
        let attachment = try await mediaStorage.saveMediaFile(
            data: bytes,
            originalFilename: "photo.jpg",
            mediaType: .photo
        )
        let sourceEntry = JournalEntry(content: "missing bundle source", attachments: [attachment])
        try await storage.saveEntry(sourceEntry)
        let bundleURL = try await backupEngine.createBackupBundle()
        let bundledFile = try PathAsfaleia.asfalhs_resolved_url(
            relativePath: "Media/\(attachment.relativePath)",
            baseDirectory: bundleURL
        )
        try FileManager.default.removeItem(at: bundledFile)

        let targetRoot = tempDirectory.appendingPathComponent("MissingBundleFileTarget", isDirectory: true)
        let targetStorage = JSONFileStorageService(storageURL: targetRoot.appendingPathComponent("journal.json"))
        let targetMedia = MediaStorageService(
            baseDirectory: targetRoot.appendingPathComponent("Media"),
            paradekampseElegxoXorou: true
        )
        let existingTarget = try targetMedia.getMediaFileURL(relativePath: attachment.relativePath)
        try FileManager.default.createDirectory(at: existingTarget.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: existingTarget)
        let targetEngine = BackupRestoreEngine(
            storage: targetStorage,
            mediaStorage: targetMedia,
            agentManager: AgentFolderManager(vaultURL: targetRoot.appendingPathComponent("Vault"))
        )

        do {
            _ = try await targetEngine.restoreFromBackupBundle(bundleURL: bundleURL)
            XCTFail("Restore must validate that the bundle contains the referenced regular file")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains(attachment.relativePath))
        }
        let targetEntries = try await targetStorage.getAllEntries()
        XCTAssertTrue(targetEntries.isEmpty)
        XCTAssertEqual(try Data(contentsOf: existingTarget), bytes)
    }

    func testRestoreRejectsOversizedManifestBeforeDecoding() async throws {
        let bundleURL = tempDirectory.appendingPathComponent("OversizedManifest.r0backup", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try Data(repeating: 0x20, count: 16 * 1024 * 1024 + 1)
            .write(to: bundleURL.appendingPathComponent("manifest.json"))

        do {
            _ = try await backupEngine.restoreFromBackupBundle(bundleURL: bundleURL)
            XCTFail("Oversized manifest must be rejected before JSON decoding")
        } catch {
            XCTAssertEqual((error as NSError).domain, AppErrorTaxonomy.backupDomain)
            XCTAssertEqual((error as NSError).code, AppErrorTaxonomy.backupInvalidManifest)
        }
    }

    /// A15: δεύτερο restore στο ίδιο sandbox → 0 νέα IDs (no-dupe).
    func testSecondRestoreDoesNotDuplicateIds() async throws {
        let entry = JournalEntry(content: "Μία φορά μόνο")
        try await storage.saveEntry(entry)
        let bundleURL = try await backupEngine.createBackupBundle()

        let first = try await backupEngine.restoreFromBackupBundle(bundleURL: bundleURL)
        XCTAssertEqual(first.restoredEntries, 0, "Source sandbox ήδη έχει το ID")

        let all = try await storage.getAllEntries()
        XCTAssertEqual(all.count, 1)
    }

    /// A15/SEC-002: traversal path rejects the restore without a partial journal row.
    func testRestoreRejectsTraversalMediaPathsAtomically() async throws {
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
        let cleanAgent = AgentFolderManager(vaultURL: tempDirectory.appendingPathComponent("TravVault"))
        let cleanEngine = BackupRestoreEngine(
            storage: cleanStorage,
            mediaStorage: cleanMedia,
            agentManager: cleanAgent
        )

        do {
            _ = try await cleanEngine.restoreFromBackupBundle(bundleURL: bundleURL)
            XCTFail("Expected restore to reject traversal attachment path")
        } catch {
            let typed = error as NSError
            XCTAssertEqual(typed.domain, AppErrorTaxonomy.backupDomain)
            XCTAssertEqual(typed.code, AppErrorTaxonomy.backupPathRejected)
        }

        let restoredEntries = try await cleanStorage.getAllEntries()
        XCTAssertTrue(restoredEntries.isEmpty, "Unsafe entry must not be partially restored")
        let escapedURL = tempDirectory.appendingPathComponent("evil.bin")
        XCTAssertFalse(FileManager.default.fileExists(atPath: escapedURL.path))
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

    func testMissingBackupMediaLeavesJournalAndTargetMediaUntouched() async throws {
        let firstAttachment = try await mediaStorage.saveMediaFile(
            data: Data("photo".utf8),
            originalFilename: "first.jpg",
            mediaType: .photo
        )
        let missingAttachment = try await mediaStorage.saveMediaFile(
            data: Data("photo 2".utf8),
            originalFilename: "second.jpg",
            mediaType: .photo
        )
        let entry = JournalEntry(content: "entry with media", attachments: [firstAttachment, missingAttachment])
        try await storage.saveEntry(entry)
        let bundleURL = try await backupEngine.createBackupBundle()
        let bundledMedia = try PathAsfaleia.asfalhs_resolved_url(
            relativePath: missingAttachment.relativePath,
            baseDirectory: bundleURL.appendingPathComponent("Media", isDirectory: true)
        )
        try FileManager.default.removeItem(at: bundledMedia)

        let targetRoot = tempDirectory.appendingPathComponent("MissingMediaTarget", isDirectory: true)
        let targetStorage = JSONFileStorageService(storageURL: targetRoot.appendingPathComponent("journal.json"))
        let targetMedia = MediaStorageService(
            baseDirectory: targetRoot.appendingPathComponent("Media"),
            paradekampseElegxoXorou: true
        )
        let targetAgent = AgentFolderManager(vaultURL: targetRoot.appendingPathComponent("Vault"))
        let targetEngine = BackupRestoreEngine(
            storage: targetStorage,
            mediaStorage: targetMedia,
            agentManager: targetAgent
        )

        do {
            _ = try await targetEngine.restoreFromBackupBundle(bundleURL: bundleURL)
            XCTFail("Expected restore to reject missing attachment data")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains(missingAttachment.relativePath))
        }

        let restoredEntries = try await targetStorage.getAllEntries()
        XCTAssertTrue(restoredEntries.isEmpty)
        let firstTargetURL = try targetMedia.getMediaFileURL(relativePath: firstAttachment.relativePath)
        let missingTargetURL = try targetMedia.getMediaFileURL(relativePath: missingAttachment.relativePath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstTargetURL.path), "Earlier staged media should be rolled back")
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingTargetURL.path))
    }

    func testJournalWriteFailureRollsBackNewlyInstalledMedia() async throws {
        let attachment = try await mediaStorage.saveMediaFile(
            data: Data("photo".utf8),
            originalFilename: "photo.jpg",
            mediaType: .photo
        )
        let entry = JournalEntry(content: "entry with media", attachments: [attachment])
        try await storage.saveEntry(entry)
        let bundleURL = try await backupEngine.createBackupBundle()

        let fileUsedAsParent = tempDirectory.appendingPathComponent("not-a-directory")
        try Data("blocker".utf8).write(to: fileUsedAsParent)
        let targetStorage = JSONFileStorageService(storageURL: fileUsedAsParent.appendingPathComponent("journal.json"))
        let targetMedia = MediaStorageService(
            baseDirectory: tempDirectory.appendingPathComponent("CommitFailureMedia"),
            paradekampseElegxoXorou: true
        )
        let targetAgent = AgentFolderManager(vaultURL: tempDirectory.appendingPathComponent("CommitFailureVault"))
        let targetEngine = BackupRestoreEngine(
            storage: targetStorage,
            mediaStorage: targetMedia,
            agentManager: targetAgent
        )

        do {
            _ = try await targetEngine.restoreFromBackupBundle(bundleURL: bundleURL)
            XCTFail("Expected journal commit to fail because its parent path is a file")
        } catch {
            XCTAssertNotEqual((error as NSError).code, 0)
        }

        let restoredEntries = try await targetStorage.getAllEntries()
        let targetMediaURL = try targetMedia.getMediaFileURL(relativePath: attachment.relativePath)
        XCTAssertTrue(restoredEntries.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetMediaURL.path))
    }

    func testConcurrentJournalInsertDoesNotLeaveRestoredOrphanMedia() async throws {
        let attachment = try await mediaStorage.saveMediaFile(
            data: Data("photo from backup".utf8),
            originalFilename: "photo.jpg",
            mediaType: .photo
        )
        let backupEntry = JournalEntry(content: "backup version", attachments: [attachment])
        try await storage.saveEntry(backupEntry)
        let bundleURL = try await backupEngine.createBackupBundle()

        let targetRoot = tempDirectory.appendingPathComponent("ConcurrentRestore", isDirectory: true)
        let targetStorage = JSONFileStorageService(storageURL: targetRoot.appendingPathComponent("journal.json"))
        let concurrentEntry = JournalEntry(id: backupEntry.id, content: "concurrent version")
        let racingStorage = InsertRaceJournalStorage(base: targetStorage, racingEntry: concurrentEntry)
        let targetMedia = MediaStorageService(
            baseDirectory: targetRoot.appendingPathComponent("Media"),
            paradekampseElegxoXorou: true
        )
        let targetAgent = AgentFolderManager(vaultURL: targetRoot.appendingPathComponent("Vault"))
        let targetEngine = BackupRestoreEngine(
            storage: racingStorage,
            mediaStorage: targetMedia,
            agentManager: targetAgent
        )

        let result = try await targetEngine.restoreFromBackupBundle(bundleURL: bundleURL)
        XCTAssertEqual(result.restoredEntries, 0, "The concurrent entry must not be overwritten")
        XCTAssertEqual(result.restoredMedia, 0, "Unreferenced staged media should be rolled back after the commit")

        let persistedEntry = try await targetStorage.getEntry(id: backupEntry.id)
        XCTAssertEqual(persistedEntry?.content, "concurrent version")
        XCTAssertTrue(persistedEntry?.attachments.isEmpty == true)
        let mediaURL = try targetMedia.getMediaFileURL(relativePath: attachment.relativePath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: mediaURL.path))
    }

    func testRestoreWithAgentMemoryRequiresManagerBeforeJournalOrMediaMutation() async throws {
        let attachment = try await mediaStorage.saveMediaFile(
            data: Data("photo for no-manager restore".utf8),
            originalFilename: "photo.jpg",
            mediaType: .photo
        )
        try await storage.saveEntry(JournalEntry(content: "entry", attachments: [attachment]))
        try await agentManager.saveAgentMemory(AgentMemory(
            memoryNotes: "# Backup memory\n",
            userPreferences: "# Backup preferences\n",
            openLoops: "# Backup loops\n"
        ))
        let bundleURL = try await backupEngine.createBackupBundle()

        let targetRoot = tempDirectory.appendingPathComponent("NoAgentManagerTarget", isDirectory: true)
        let targetStorage = JSONFileStorageService(storageURL: targetRoot.appendingPathComponent("journal.json"))
        let targetMedia = MediaStorageService(
            baseDirectory: targetRoot.appendingPathComponent("Media"),
            paradekampseElegxoXorou: true
        )
        let targetEngine = BackupRestoreEngine(storage: targetStorage, mediaStorage: targetMedia)

        do {
            _ = try await targetEngine.restoreFromBackupBundle(bundleURL: bundleURL)
            XCTFail("Expected restore to fail when Agent memory has no configured destination")
        } catch {
            let typed = error as NSError
            XCTAssertEqual(typed.domain, AppErrorTaxonomy.backupDomain)
            XCTAssertEqual(typed.code, AppErrorTaxonomy.backupAgentRestoreFailed)
        }

        let noManagerEntries = try await targetStorage.getAllEntries()
        XCTAssertTrue(noManagerEntries.isEmpty)
        let targetMediaURL = try targetMedia.getMediaFileURL(relativePath: attachment.relativePath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetMediaURL.path))
    }

    func testAgentMemoryWriteFailureRollsBackRestoredJournalAndMedia() async throws {
        let attachment = try await mediaStorage.saveMediaFile(
            data: Data("photo for memory-failure restore".utf8),
            originalFilename: "photo.jpg",
            mediaType: .photo
        )
        let entry = JournalEntry(content: "entry", attachments: [attachment])
        try await storage.saveEntry(entry)
        try await agentManager.saveAgentMemory(AgentMemory(
            memoryNotes: "# New memory\n",
            userPreferences: "# New preferences\n",
            openLoops: "# New loops\n"
        ))
        let bundleURL = try await backupEngine.createBackupBundle()

        let targetRoot = tempDirectory.appendingPathComponent("AgentWriteFailureTarget", isDirectory: true)
        let targetStorage = JSONFileStorageService(storageURL: targetRoot.appendingPathComponent("journal.json"))
        let targetMedia = MediaStorageService(
            baseDirectory: targetRoot.appendingPathComponent("Media"),
            paradekampseElegxoXorou: true
        )
        let targetVault = targetRoot.appendingPathComponent("Vault", isDirectory: true)
        let targetAgent = AgentFolderManager(vaultURL: targetVault)
        let oldMemory = AgentMemory(
            memoryNotes: "# Old memory\n",
            userPreferences: "# Old preferences\n",
            openLoops: "# Old loops\n"
        )
        try await targetAgent.saveAgentMemory(oldMemory)

        let agentDirectory = targetVault.appendingPathComponent("Agent", isDirectory: true)
        let loopsURL = agentDirectory.appendingPathComponent("Open-loops.md")
        try FileManager.default.removeItem(at: loopsURL)
        try FileManager.default.createDirectory(at: loopsURL, withIntermediateDirectories: true)

        let targetEngine = BackupRestoreEngine(
            storage: targetStorage,
            mediaStorage: targetMedia,
            agentManager: targetAgent
        )
        do {
            _ = try await targetEngine.restoreFromBackupBundle(bundleURL: bundleURL)
            XCTFail("Expected Agent memory write to fail for a directory at Open-loops.md")
        } catch {
            let typed = error as NSError
            XCTAssertEqual(typed.domain, AppErrorTaxonomy.backupDomain)
            XCTAssertEqual(typed.code, AppErrorTaxonomy.backupAgentRestoreFailed)
        }

        let memoryFailureEntries = try await targetStorage.getAllEntries()
        XCTAssertTrue(memoryFailureEntries.isEmpty)
        let targetMediaURL = try targetMedia.getMediaFileURL(relativePath: attachment.relativePath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetMediaURL.path))
        XCTAssertEqual(
            try String(contentsOf: agentDirectory.appendingPathComponent("Memory.md"), encoding: .utf8),
            oldMemory.memoryNotes
        )
        XCTAssertEqual(
            try String(contentsOf: agentDirectory.appendingPathComponent("Preferences.md"), encoding: .utf8),
            oldMemory.userPreferences
        )
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: loopsURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        let agentFiles = try FileManager.default.contentsOfDirectory(atPath: agentDirectory.path)
        XCTAssertFalse(agentFiles.contains { $0.hasSuffix(".staged") || $0.hasSuffix(".backup") })
    }
}

private actor InsertRaceJournalStorage: JournalStorageProtocol {
    private let base: JSONFileStorageService
    private let racingEntry: JournalEntry
    private var didInsertConcurrentEntry = false

    init(base: JSONFileStorageService, racingEntry: JournalEntry) {
        self.base = base
        self.racingEntry = racingEntry
    }

    func saveEntry(_ entry: JournalEntry) async throws {
        try await base.saveEntry(entry)
    }

    func insertEntriesIfAbsentAtomically(_ entries: [JournalEntry]) async throws -> Set<UUID> {
        if !didInsertConcurrentEntry {
            didInsertConcurrentEntry = true
            try await base.saveEntry(racingEntry)
        }
        return try await base.insertEntriesIfAbsentAtomically(entries)
    }

    func deleteEntry(id: UUID) async throws {
        try await base.deleteEntry(id: id)
    }

    func getEntry(id: UUID) async throws -> JournalEntry? {
        try await base.getEntry(id: id)
    }

    func getEntriesForDate(_ date: Date) async throws -> [JournalEntry] {
        try await base.getEntriesForDate(date)
    }

    func getAllEntries() async throws -> [JournalEntry] {
        try await base.getAllEntries()
    }

    func searchEntries(query: String, tag: String?, source: EntrySource?) async throws -> [JournalEntry] {
        try await base.searchEntries(query: query, tag: tag, source: source)
    }

    func getDatesWithEntries() async throws -> Set<String> {
        try await base.getDatesWithEntries()
    }
}
