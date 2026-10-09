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

        let thirdEntry = JournalEntry(content: "Άλλη σύγκρουση, χωρίς overwrite του πρώτου sidecar.")
        let third = try await bridge.exportEntry(thirdEntry, mediaStorage: mediaStorage)
        XCTAssertTrue(third.hadConflict)
        XCTAssertNotEqual(third.conflictSidecarRelativePath, second.conflictSidecarRelativePath)
        XCTAssertEqual(try String(contentsOf: sidecarURL, encoding: .utf8), sidecarBody)
        let thirdSidecar = try XCTUnwrap(third.conflictSidecarRelativePath)
        let thirdSidecarURL = tempDirectory.appendingPathComponent(thirdSidecar)
        XCTAssertTrue(try String(contentsOf: thirdSidecarURL, encoding: .utf8)
            .contains("Άλλη σύγκρουση, χωρίς overwrite του πρώτου sidecar."))
        let repeatedThird = try await bridge.exportEntry(thirdEntry, mediaStorage: mediaStorage)
        XCTAssertEqual(repeatedThird.conflictSidecarRelativePath, third.conflictSidecarRelativePath)

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

    func testCorruptHashMetadataFailsClosedWithoutChangingExistingNote() async throws {
        let entry = JournalEntry(content: "Do not overwrite external note")
        let noteURL = try noteURL(for: entry)
        let original = Data("# User-authored note\nKeep this content.\n".utf8)
        try original.write(to: noteURL)

        let hashStore = tempDirectory.appendingPathComponent("R0llingMeta/export-hashes.json")
        try FileManager.default.createDirectory(at: hashStore.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not valid json".utf8).write(to: hashStore)

        do {
            _ = try await bridge.exportEntry(entry, mediaStorage: mediaStorage)
            XCTFail("Corrupt export metadata must stop writes")
        } catch {
            XCTAssertEqual((error as NSError).code, 6004)
        }

        XCTAssertEqual(try Data(contentsOf: noteURL), original)
    }

    func testFirstContactDoesNotReplaceExistingEntryBlockWithoutTrustedHash() async throws {
        let entry = JournalEntry(content: "Current journal content")
        let noteURL = try noteURL(for: entry)
        let original = """
        # User daily note

        <!-- r0lling:id:\(entry.id.uuidString) -->
        ### External edit

        Keep this edited block.
        <!-- /r0lling:id:\(entry.id.uuidString) -->
        """
        try FileManager.default.createDirectory(
            at: noteURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try original.write(to: noteURL, atomically: true, encoding: .utf8)

        let result = try await bridge.exportEntry(entry, mediaStorage: mediaStorage)
        XCTAssertTrue(result.hadConflict)
        XCTAssertNotNil(result.conflictSidecarRelativePath)
        XCTAssertEqual(try String(contentsOf: noteURL, encoding: .utf8), original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory
            .appendingPathComponent(result.conflictSidecarRelativePath!)
            .path))
    }

    func testNonUTF8ExistingNoteIsNotReplacedWithAnEmptyMerge() async throws {
        let entry = JournalEntry(content: "Do not erase binary note")
        let relativePath = relativeNotePath(for: entry)
        let noteURL = try PathAsfaleia.asfalhs_resolved_url(
            relativePath: relativePath,
            baseDirectory: tempDirectory
        )
        try FileManager.default.createDirectory(at: noteURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data([0xFF, 0xFE, 0x00, 0x80])
        try original.write(to: noteURL)

        let hashStore = tempDirectory.appendingPathComponent("R0llingMeta/export-hashes.json")
        try FileManager.default.createDirectory(at: hashStore.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode([relativePath: original.sha256Hash]).write(to: hashStore)

        do {
            _ = try await bridge.exportEntry(entry, mediaStorage: mediaStorage)
            XCTFail("A non-UTF8 note must not be replaced")
        } catch {
            XCTAssertEqual((error as NSError).code, 6005)
        }

        XCTAssertEqual(try Data(contentsOf: noteURL), original)
    }

    func testUnsafeAttachmentPathStopsExportBeforeWritingMarkdown() async throws {
        let attachment = MediaAttachment(
            relativePath: "../outside.jpg",
            mediaType: .photo,
            byteSize: 1
        )
        let entry = JournalEntry(content: "Entry with an unsafe attachment", attachments: [attachment])
        let noteURL = try noteURL(for: entry)

        do {
            _ = try await bridge.exportEntry(entry, mediaStorage: mediaStorage)
            XCTFail("Unsafe attachment paths must stop export")
        } catch {
            XCTAssertEqual((error as NSError).code, 6011)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: noteURL.path))
    }

    func testDirectoryCannotBeExportedAsAnAttachment() async throws {
        let filename = "\(UUID().uuidString).jpg"
        let relativePath = "Photos/\(filename)"
        let directoryURL = tempDirectory.appendingPathComponent("Media/\(relativePath)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data("unrelated".utf8).write(to: directoryURL.appendingPathComponent("nested.txt"))
        let attachment = MediaAttachment(
            relativePath: relativePath,
            mediaType: .photo,
            byteSize: 1
        )
        let entry = JournalEntry(content: "Do not recursively copy this", attachments: [attachment])
        let expectedNoteURL = try noteURL(for: entry)

        do {
            _ = try await bridge.exportEntry(entry, mediaStorage: mediaStorage)
            XCTFail("A directory must never be exported as an attachment file")
        } catch {
            XCTAssertEqual((error as NSError).code, 6010)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: expectedNoteURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory
            .appendingPathComponent("Attachments/\(relativePath)")
            .path))
    }

    /// A08: διπλή εξαγωγή ίδιας ημέρας — idempotent + batch count.
    func testA08DoubleExportIdempotentBatch() async throws {
        let sameDay = Date(timeIntervalSince1970: 1_750_000_000)
        let e1 = JournalEntry(timestamp: sameDay, timeZoneIdentifier: "UTC", content: "Πρώτη καταγραφή A08.")
        let e2 = JournalEntry(timestamp: sameDay, timeZoneIdentifier: "UTC", content: "Δεύτερη καταγραφή A08.")
        _ = try await bridge.exportEntry(e1, mediaStorage: mediaStorage)
        _ = try await bridge.exportEntry(e2, mediaStorage: mediaStorage)

        let batch1 = try await bridge.exportBatch(entries: [e1, e2], mediaStorage: mediaStorage)
        XCTAssertEqual(batch1.conflictsDetected.count, 0)
        XCTAssertEqual(batch1.exportedFilesCount, 1)
        XCTAssertEqual(batch1.modifiedFiles.count, 1)

        let batch2 = try await bridge.exportBatch(entries: [e1, e2], mediaStorage: mediaStorage)
        XCTAssertEqual(batch2.conflictsDetected.count, 0)
        XCTAssertEqual(batch2.exportedFilesCount, 1)
        XCTAssertEqual(batch2.modifiedFiles.count, 1)

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

    func testExportEntryRejectsSymlinkedDailyNoteAndPreservesTarget() async throws {
        let entry = JournalEntry(content: "Μην αντικαταστήσεις το εξωτερικό αρχείο.")
        let notePath = relativeNotePath(for: entry)
        let linkURL = tempDirectory.appendingPathComponent(notePath)
        try FileManager.default.createDirectory(
            at: linkURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let notesDirectory = tempDirectory.appendingPathComponent("Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        let targetURL = notesDirectory.appendingPathComponent("Important.md")
        let originalContent = "preserve this unrelated note"
        try Data(originalContent.utf8).write(to: targetURL)
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        do {
            _ = try await bridge.exportEntry(entry, mediaStorage: mediaStorage)
            XCTFail("A symlink in the managed daily-note path must be rejected")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "R0lling.Obsidian")
            XCTAssertEqual(error.code, 6012)
        }

        XCTAssertEqual(try String(contentsOf: targetURL, encoding: .utf8), originalContent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: linkURL.path))
    }

    func testExportEntryRejectsSymlinkedHashMetadataAndPreservesTarget() async throws {
        let metadataDirectory = tempDirectory.appendingPathComponent("R0llingMeta", isDirectory: true)
        try FileManager.default.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)

        let notesDirectory = tempDirectory.appendingPathComponent("Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        let targetURL = notesDirectory.appendingPathComponent("Important.json")
        let originalContent = "{\"externallyManaged\":true}"
        try Data(originalContent.utf8).write(to: targetURL)
        let metadataURL = metadataDirectory.appendingPathComponent("export-hashes.json")
        try FileManager.default.createSymbolicLink(at: metadataURL, withDestinationURL: targetURL)

        do {
            _ = try await bridge.exportEntry(
                JournalEntry(content: "Metadata symlink test."),
                mediaStorage: mediaStorage
            )
            XCTFail("A symlink in the managed metadata path must be rejected")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "R0lling.Obsidian")
            XCTAssertEqual(error.code, 6012)
        }

        XCTAssertEqual(try String(contentsOf: targetURL, encoding: .utf8), originalContent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
    }

    func testExportRejectsOversizedExistingDailyNoteWithoutReplacingIt() async throws {
        let entry = JournalEntry(content: "Large existing note test.")
        let noteURL = tempDirectory.appendingPathComponent(relativeNotePath(for: entry))
        try FileManager.default.createDirectory(
            at: noteURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let maximumBytes = 16 * 1024 * 1024
        let original = Data(repeating: 0x41, count: maximumBytes + 1)
        try original.write(to: noteURL)

        do {
            _ = try await bridge.exportEntry(entry, mediaStorage: mediaStorage)
            XCTFail("An oversized existing daily note must be rejected before merge")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "R0lling.Obsidian")
            XCTAssertEqual(error.code, 6013)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: noteURL.path)
        XCTAssertEqual((attributes[.size] as? NSNumber)?.intValue, maximumBytes + 1)
        let handle = try FileHandle(forReadingFrom: noteURL)
        defer { try? handle.close() }
        XCTAssertEqual(try handle.read(upToCount: 4), Data(repeating: 0x41, count: 4))
    }

    func testGeneratedExportPreservesExistingUserFileAndCreatesConflictSidecar() async throws {
        let relativePath = "Weekly-Canvas.canvas"
        let originalURL = tempDirectory.appendingPathComponent(relativePath)
        let originalContent = "{\"manually\":\"edited\"}"
        try originalContent.write(to: originalURL, atomically: true, encoding: .utf8)

        let generatedURL = try await bridge.grapse_arxeio_sto_vault(
            relativePath: relativePath,
            contents: "{\"generated\":true}"
        )

        XCTAssertNotEqual(generatedURL, originalURL)
        XCTAssertTrue(generatedURL.lastPathComponent.contains("r0lling-conflict-"))
        XCTAssertEqual(try String(contentsOf: originalURL, encoding: .utf8), originalContent)
        XCTAssertEqual(try String(contentsOf: generatedURL, encoding: .utf8), "{\"generated\":true}")

        let repeatedGeneratedURL = try await bridge.grapse_arxeio_sto_vault(
            relativePath: relativePath,
            contents: "{\"generated\":true}"
        )
        XCTAssertEqual(repeatedGeneratedURL, generatedURL, "Repeated generated content must reuse its conflict sidecar")

        let repeatedURL = try await bridge.grapse_arxeio_sto_vault(
            relativePath: relativePath,
            contents: "{\"manually\":\"edited\"}"
        )
        XCTAssertEqual(repeatedURL, originalURL, "Identical content should remain idempotent")
    }

    func testExclusiveVaultFileCreationNeverReplacesExistingContent() throws {
        let destination = tempDirectory.appendingPathComponent("exclusive.md")
        let original = Data("external edit".utf8)

        XCTAssertTrue(try ObsidianVaultBridge.writeFileExclusively(at: destination, contents: original))
        XCTAssertFalse(try ObsidianVaultBridge.writeFileExclusively(
            at: destination,
            contents: Data("generated overwrite".utf8)
        ))
        XCTAssertEqual(try Data(contentsOf: destination), original)
    }

    func testGeneratedExportNeverReplacesDirectoryAtDestination() async throws {
        let directory = tempDirectory.appendingPathComponent("Knowledge-Graph.md", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sentinel = directory.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: sentinel)

        do {
            _ = try await bridge.grapse_arxeio_sto_vault(
                relativePath: "Knowledge-Graph.md",
                contents: "generated graph"
            )
            XCTFail("A directory at the generated-file destination must be preserved")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 6006)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
    }

    /// Agent files use descriptor-relative no-follow operations.
    func testAgentFolderUsesDescriptorRelativeFileAccess() async throws {
        let agent = AgentFolderManager(vaultURL: tempDirectory)
        var mem = try await agent.loadAgentMemory()
        mem.memoryNotes = "# Memory\n- test path asfaleia\n"
        try await agent.saveAgentMemory(mem)
        let memURL = tempDirectory.appendingPathComponent("Agent/Memory.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: memURL.path))
        let body = try String(contentsOf: memURL, encoding: .utf8)
        XCTAssertTrue(body.contains("test path asfaleia"))
    }

    func testAgentMemoryRejectsVaultDirectoryReplacement() async throws {
        let vault = tempDirectory.appendingPathComponent("PinnedVault", isDirectory: true)
        let movedVault = tempDirectory.appendingPathComponent("OriginalVault", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        let agent = AgentFolderManager(vaultURL: vault)
        try await agent.saveAgentMemory(AgentMemory(memoryNotes: "original"))

        try FileManager.default.moveItem(at: vault, to: movedVault)
        let replacementAgentDirectory = vault.appendingPathComponent("Agent", isDirectory: true)
        try FileManager.default.createDirectory(at: replacementAgentDirectory, withIntermediateDirectories: true)
        let replacementMemory = replacementAgentDirectory.appendingPathComponent("Memory.md")
        try Data("replacement sentinel".utf8).write(to: replacementMemory)

        do {
            try await agent.saveAgentMemory(AgentMemory(memoryNotes: "must not redirect"))
            XCTFail("A replacement vault directory must be rejected after the first access pins its identity")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "R0lling.Agent")
            XCTAssertEqual(error.code, 6108)
        }

        XCTAssertEqual(try String(contentsOf: replacementMemory, encoding: .utf8), "replacement sentinel")
    }

    func testAgentMemoryRejectsInternalDirectorySymlink() async throws {
        let notesDirectory = tempDirectory.appendingPathComponent("Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        let unrelatedFile = notesDirectory.appendingPathComponent("Important.md")
        try Data("preserve this note".utf8).write(to: unrelatedFile)
        let agentDirectory = tempDirectory.appendingPathComponent("Agent", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: agentDirectory, withDestinationURL: notesDirectory)

        let agent = AgentFolderManager(vaultURL: tempDirectory)
        do {
            try await agent.saveAgentMemory(AgentMemory(memoryNotes: "overwrite attempt"))
            XCTFail("An internal symlink used as Agent directory must be rejected")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "R0lling.Agent")
            XCTAssertEqual(error.code, 6104)
        }

        XCTAssertEqual(try String(contentsOf: unrelatedFile, encoding: .utf8), "preserve this note")
        XCTAssertFalse(FileManager.default.fileExists(atPath: notesDirectory.appendingPathComponent("Memory.md").path))
    }

    func testAgentMemoryRejectsSymlinkedManagedFileWithoutOverwritingTarget() async throws {
        let agentDirectory = tempDirectory.appendingPathComponent("Agent", isDirectory: true)
        try FileManager.default.createDirectory(at: agentDirectory, withIntermediateDirectories: true)
        let unrelatedFile = tempDirectory.appendingPathComponent("Important.md")
        try Data("preserve this note".utf8).write(to: unrelatedFile)
        let memoryFile = agentDirectory.appendingPathComponent("Memory.md")
        try FileManager.default.createSymbolicLink(at: memoryFile, withDestinationURL: unrelatedFile)

        let agent = AgentFolderManager(vaultURL: tempDirectory)
        do {
            try await agent.saveAgentMemory(AgentMemory(memoryNotes: "overwrite attempt"))
            XCTFail("A symlink at a managed memory file path must be rejected")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "R0lling.Agent")
            XCTAssertEqual(error.code, 6104)
        }

        XCTAssertEqual(try String(contentsOf: unrelatedFile, encoding: .utf8), "preserve this note")
    }

    func testAgentMemoryRejectsOversizedManagedMarkdown() async throws {
        let agentDirectory = tempDirectory.appendingPathComponent("Agent", isDirectory: true)
        try FileManager.default.createDirectory(at: agentDirectory, withIntermediateDirectories: true)
        let memoryFile = agentDirectory.appendingPathComponent("Memory.md")
        let oversizedContents = Data(repeating: 0x61, count: 4 * 1024 * 1024 + 1)
        try oversizedContents.write(to: memoryFile)

        let agent = AgentFolderManager(vaultURL: tempDirectory)
        do {
            _ = try await agent.loadAgentMemory()
            XCTFail("Agent Markdown reads must stop at the configured 4 MiB per-file limit")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "R0lling.Agent")
            XCTAssertEqual(error.code, 6110)
        }

        let remainingSize = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: memoryFile.path)[.size] as? NSNumber
        ).intValue
        XCTAssertEqual(remainingSize, oversizedContents.count)
    }

    func testAgentMemoryRejectsOversizedMarkdownBeforeCreatingFiles() async throws {
        let agent = AgentFolderManager(vaultURL: tempDirectory)
        let oversizedText = String(repeating: "a", count: 4 * 1024 * 1024 + 1)

        do {
            try await agent.saveAgentMemory(AgentMemory(memoryNotes: oversizedText))
            XCTFail("Agent Markdown writes must match the 4 MiB read limit")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "R0lling.Agent")
            XCTAssertEqual(error.code, 6110)
        }

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDirectory.appendingPathComponent("Agent/Memory.md").path
        ))
    }

    /// VaultBookmarkStore display path defaults.
    func testVaultBookmarkStoreDefaultDisplay() throws {
        VaultBookmarkStore.epanekkinisi_proepilegmenou()
        XCTAssertEqual(VaultBookmarkStore.display_path_i_default(), "Documents/R0lling/ObsidianVault")
        let resolved = try VaultBookmarkStore.fortosi_vault_url()
        XCTAssertNil(resolved)
    }

    private func noteURL(for entry: JournalEntry) throws -> URL {
        try PathAsfaleia.asfalhs_resolved_url(
            relativePath: relativeNotePath(for: entry),
            baseDirectory: tempDirectory
        )
    }

    private func relativeNotePath(for entry: JournalEntry) -> String {
        let parts = entry.dateKey.split(separator: "-")
        return "\(parts[0])/\(parts[1])/\(entry.dateKey).md"
    }
}
