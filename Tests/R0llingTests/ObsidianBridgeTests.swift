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
}
