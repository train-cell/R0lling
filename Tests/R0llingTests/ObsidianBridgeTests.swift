import XCTest
@testable import R0lling

final class ObsidianBridgeTests: XCTestCase {
    var tempDirectory: URL!
    var bridge: ObsidianVaultBridge!
    var mediaStorage: MediaStorageService!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("TestObsidian_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        bridge = ObsidianVaultBridge(vaultURL: tempDirectory)
        mediaStorage = MediaStorageService(baseDirectory: tempDirectory.appendingPathComponent("Media"))
    }

    override func tearDown() async throws {
        if let dir = tempDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func testExportEntryCreatesMarkdown() async throws {
        let entry = JournalEntry(
            title: "Ημερολόγιο Δοκιμών",
            content: "Πρώτη δοκιμή εξαγωγής στο Obsidian Vault.",
            source: .manual,
            tags: ["obsidian", "test"]
        )

        let outcome = try await bridge.exportEntry(entry, mediaStorage: mediaStorage)
        XCTAssertFalse(outcome.hadConflict)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outcome.noteURL.path))

        let content = try String(contentsOf: outcome.noteURL, encoding: .utf8)
        XCTAssertTrue(content.contains("Πρώτη δοκιμή εξαγωγής στο Obsidian Vault."))
        XCTAssertTrue(content.contains("#obsidian"))
    }

    func testIdempotentExportDoesNotDuplicate() async throws {
        let entry = JournalEntry(
            content: "Σταθερή σημείωση για έλεγχο idempotency."
        )

        let url1 = try await bridge.exportEntry(entry, mediaStorage: mediaStorage).noteURL
        _ = try String(contentsOf: url1, encoding: .utf8)

        let url2 = try await bridge.exportEntry(entry, mediaStorage: mediaStorage).noteURL
        let content2 = try String(contentsOf: url2, encoding: .utf8)

        XCTAssertEqual(url1.path, url2.path)
        let occurrences = content2.components(separatedBy: "r0lling:id:\(entry.id.uuidString)").count - 1
        XCTAssertEqual(occurrences, 2) // Opening and closing tag
    }

    /// R3-005: Εξωτερική τροποποίηση → πρωτότυπο παραμένει + sidecar conflict.
    func testExternalEditCreatesConflictSidecarWithoutOverwrite() async throws {
        let entry = JournalEntry(content: "Αρχική σημείωση R0lling.")
        let first = try await bridge.exportEntry(entry, mediaStorage: mediaStorage)
        XCTAssertFalse(first.hadConflict)

        let external = (try String(contentsOf: first.noteURL, encoding: .utf8))
            + "\n\n## Χειροκίνητη σημείωση χρήστη\nΜην με σβήσεις.\n"
        try external.write(to: first.noteURL, atomically: true, encoding: .utf8)

        let secondEntry = JournalEntry(content: "Νέα σημείωση μετά την εξωτερική αλλαγή.")
        let second = try await bridge.exportEntry(secondEntry, mediaStorage: mediaStorage)

        XCTAssertTrue(second.hadConflict)
        XCTAssertNotNil(second.conflictSidecarRelativePath)

        let preserved = try String(contentsOf: first.noteURL, encoding: .utf8)
        XCTAssertTrue(preserved.contains("Μην με σβήσεις."))
        XCTAssertFalse(preserved.contains("Νέα σημείωση μετά την εξωτερική αλλαγή."))

        let dayBase = first.noteURL.deletingPathExtension().lastPathComponent
        let sidecarURL = first.noteURL.deletingLastPathComponent()
            .appendingPathComponent("\(dayBase).r0lling-conflict.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sidecarURL.path))
        let sidecarBody = try String(contentsOf: sidecarURL, encoding: .utf8)
        XCTAssertTrue(sidecarBody.contains("Νέα σημείωση μετά την εξωτερική αλλαγή."))

        let batch = try await bridge.exportBatch(entries: [secondEntry], mediaStorage: mediaStorage)
        XCTAssertFalse(batch.conflictsDetected.isEmpty)
    }

    /// A09: hashes επιβιώνουν σε νέο bridge instance (sim restart).
    func testHashPersistenceDetectsConflictAfterRestart() async throws {
        let entry = JournalEntry(content: "Baseline πριν το restart.")
        let first = try await bridge.exportEntry(entry, mediaStorage: mediaStorage)
        XCTAssertFalse(first.hadConflict)

        let hashStore = tempDirectory.appendingPathComponent("R0llingMeta/export-hashes.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: hashStore.path))

        let external = (try String(contentsOf: first.noteURL, encoding: .utf8))
            + "\n\n## External after restart\nKeep me.\n"
        try external.write(to: first.noteURL, atomically: true, encoding: .utf8)

        let restarted = ObsidianVaultBridge(vaultURL: tempDirectory)
        await restarted.setVaultURL(tempDirectory, requiresScopedAccess: false)
        let conflictEntry = JournalEntry(content: "Μετά το restart.")
        let second = try await restarted.exportEntry(conflictEntry, mediaStorage: mediaStorage)
        XCTAssertTrue(second.hadConflict)
        let preserved = try String(contentsOf: first.noteURL, encoding: .utf8)
        XCTAssertTrue(preserved.contains("Keep me."))
        XCTAssertFalse(preserved.contains("Μετά το restart."))
    }

    /// A08: διπλή εξαγωγή ίδιας ημέρας — idempotent + batch count.
    func testA08DoubleExportIdempotentBatch() async throws {
        let e1 = JournalEntry(content: "Πρώτη καταγραφή A08.")
        let e2 = JournalEntry(content: "Δεύτερη καταγραφή A08.")
        _ = try await bridge.exportEntry(e1, mediaStorage: mediaStorage)
        _ = try await bridge.exportEntry(e2, mediaStorage: mediaStorage)

        let batch1 = try await bridge.exportBatch(entries: [e1, e2], mediaStorage: mediaStorage)
        XCTAssertEqual(batch1.conflictsDetected.count, 0)
        XCTAssertEqual(batch1.exportedFilesCount, 2)

        let batch2 = try await bridge.exportBatch(entries: [e1, e2], mediaStorage: mediaStorage)
        XCTAssertEqual(batch2.conflictsDetected.count, 0)
        XCTAssertEqual(batch2.exportedFilesCount, 2)

        let note = try await bridge.diabase_imerisia_simeiosi(dateKey: e1.dateKey)
        XCTAssertNotNil(note)
        XCTAssertTrue(note!.contains("Πρώτη καταγραφή A08."))
        XCTAssertTrue(note!.contains("Δεύτερη καταγραφή A08."))
        let idCount = note!.components(separatedBy: "r0lling:id:\(e1.id.uuidString)").count - 1
        XCTAssertEqual(idCount, 2)
    }

    /// SEC-002: PathAsfaleia σε vault write — reject traversal.
    func testPathAsfaleiaRejectsTraversalOnVaultWrite() async throws {
        do {
            _ = try await bridge.grapse_arxeio_sto_vault(
                relativePath: "../escape.md",
                contents: "nope"
            )
            XCTFail("Έπρεπε να απορρίψει traversal")
        } catch {
            let ns = error as NSError
            XCTAssertEqual(ns.domain, PathAsfaleia.errorDomain)
        }
    }

    /// Agent folder χρησιμοποιεί PathAsfaleia.
    func testAgentFolderUsesPathAsfaleia() async throws {
        let agent = AgentFolderManager(vaultURL: tempDirectory)
        var mem = try await agent.loadAgentMemory()
        mem.memoryNotes = "# Memory\n- test path asfaleia\n"
        try await agent.saveAgentMemory(mem)
        let memURL = tempDirectory.appendingPathComponent("Agent/Memory.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: memURL.path))
        let body = try String(contentsOf: memURL, encoding: .utf8)
        XCTAssertTrue(body.contains("test path asfaleia"))
    }

    /// VaultBookmarkStore display path defaults.
    func testVaultBookmarkStoreDefaultDisplay() throws {
        VaultBookmarkStore.epanekkinisi_proepilegmenou()
        XCTAssertEqual(VaultBookmarkStore.display_path_i_default(), "Documents/R0lling/ObsidianVault")
        let resolved = try VaultBookmarkStore.fortosi_vault_url()
        XCTAssertNil(resolved)
    }
}
