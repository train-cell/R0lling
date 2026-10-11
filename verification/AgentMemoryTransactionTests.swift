import Foundation
import XCTest
@testable import R0lling

final class AgentMemoryTransactionTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("R0llingAgentTransaction-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testInterruptedAfterEachPartialCommitRestoresEntirePreviousGeneration() async throws {
        for commitCount in [1, 2] {
            let vault = root.appendingPathComponent("partial-\(commitCount)", isDirectory: true)
            try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
            let manager = AgentFolderManager(vaultURL: vault)
            let old = memory("old")
            try await manager.saveAgentMemory(old)
            await manager.simulateMemorySaveInterruptionForTesting(afterCommitCount: commitCount)

            do {
                try await manager.saveAgentMemory(memory("new"))
                XCTFail("Expected a simulated process interruption after commit \(commitCount)")
            } catch let error as NSError {
                XCTAssertEqual(error.code, 6112)
            }

            let restarted = AgentFolderManager(vaultURL: vault)
            let recovered = try await restarted.loadAgentMemory()
            XCTAssertEqual(recovered.memoryNotes, old.memoryNotes)
            XCTAssertEqual(recovered.userPreferences, old.userPreferences)
            XCTAssertEqual(recovered.openLoops, old.openLoops)
            XCTAssertFalse(FileManager.default.fileExists(atPath: transactionURL(vault).path))
        }
    }

    func testInterruptedAfterAllCommitsFinalizesEntireNewGeneration() async throws {
        let vault = root.appendingPathComponent("complete", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        let manager = AgentFolderManager(vaultURL: vault)
        let new = memory("new")
        await manager.simulateMemorySaveInterruptionForTesting(afterCommitCount: 3)

        do {
            try await manager.saveAgentMemory(new)
            XCTFail("Expected a simulated process interruption after the last commit")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 6112)
        }

        let restarted = AgentFolderManager(vaultURL: vault)
        let recovered = try await restarted.loadAgentMemory()
        XCTAssertEqual(recovered.memoryNotes, new.memoryNotes)
        XCTAssertEqual(recovered.userPreferences, new.userPreferences)
        XCTAssertEqual(recovered.openLoops, new.openLoops)
        XCTAssertFalse(FileManager.default.fileExists(atPath: transactionURL(vault).path))
    }

    func testInterruptedFirstSaveRemovesPartiallyCreatedFiles() async throws {
        let vault = root.appendingPathComponent("first-save", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        let manager = AgentFolderManager(vaultURL: vault)
        await manager.simulateMemorySaveInterruptionForTesting(afterCommitCount: 1)

        do {
            try await manager.saveAgentMemory(memory("new"))
            XCTFail("Expected a simulated interruption during the first save")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 6112)
        }

        let restarted = AgentFolderManager(vaultURL: vault)
        let recovered = try await restarted.loadAgentMemory()
        XCTAssertEqual(recovered.memoryNotes, "# Σημειώσεις Μνήμης Βοηθού\n\n")
        XCTAssertEqual(recovered.userPreferences, "# Προτιμήσεις Χρήστη\n\n")
        XCTAssertEqual(recovered.openLoops, "# Εκκρεμότητες & Ανοιχτά Θέματα\n\n")
        for name in ["Memory.md", "Preferences.md", "Open-loops.md"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: vault.appendingPathComponent("Agent/\(name)").path))
        }
    }

    func testRecoveryPreservesExternalEditAndKeepsJournalForManualResolution() async throws {
        let vault = root.appendingPathComponent("conflict", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        let manager = AgentFolderManager(vaultURL: vault)
        try await manager.saveAgentMemory(memory("old"))
        await manager.simulateMemorySaveInterruptionForTesting(afterCommitCount: 1)
        do {
            try await manager.saveAgentMemory(memory("new"))
            XCTFail("Expected a simulated process interruption")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 6112)
        }

        let memoryFile = vault.appendingPathComponent("Agent/Memory.md")
        try Data("external edit".utf8).write(to: memoryFile)
        do {
            _ = try await AgentFolderManager(vaultURL: vault).loadAgentMemory()
            XCTFail("Recovery must not overwrite edits made after the interruption")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 6105)
        }
        XCTAssertEqual(try String(contentsOf: memoryFile, encoding: .utf8), "external edit")
        XCTAssertTrue(FileManager.default.fileExists(atPath: transactionURL(vault).path))
    }

    func testCorruptRecoveryRecordFailsClosedWithoutChangingMemoryFiles() async throws {
        let vault = root.appendingPathComponent("corrupt-marker", isDirectory: true)
        let agentDirectory = vault.appendingPathComponent("Agent", isDirectory: true)
        try FileManager.default.createDirectory(at: agentDirectory, withIntermediateDirectories: true)
        let memoryFile = agentDirectory.appendingPathComponent("Memory.md")
        try Data("keep this memory".utf8).write(to: memoryFile)
        let transaction = transactionURL(vault)
        let corrupted = Data("not valid JSON".utf8)
        try corrupted.write(to: transaction)

        do {
            _ = try await AgentFolderManager(vaultURL: vault).loadAgentMemory()
            XCTFail("A corrupt recovery record must block reads instead of guessing a generation")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 6111)
        }
        XCTAssertEqual(try Data(contentsOf: memoryFile), Data("keep this memory".utf8))
        XCTAssertEqual(try Data(contentsOf: transaction), corrupted)
    }

    func testNormalSaveRemainsReadableByObsidianAsThreeMarkdownFiles() async throws {
        let vault = root.appendingPathComponent("normal", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        let value = memory("normal")
        let manager = AgentFolderManager(vaultURL: vault)
        try await manager.saveAgentMemory(value)
        let loaded = try await AgentFolderManager(vaultURL: vault).loadAgentMemory()
        XCTAssertEqual(loaded.memoryNotes, value.memoryNotes)
        XCTAssertEqual(loaded.userPreferences, value.userPreferences)
        XCTAssertEqual(loaded.openLoops, value.openLoops)
        XCTAssertFalse(FileManager.default.fileExists(atPath: transactionURL(vault).path))
    }

    func testSaveRejectsManagedFileGrowthDuringBackupAndCleansPartialArtifacts() async throws {
        let vault = root.appendingPathComponent("backup-growth", isDirectory: true)
        let agentDirectory = vault.appendingPathComponent("Agent", isDirectory: true)
        try FileManager.default.createDirectory(at: agentDirectory, withIntermediateDirectories: true)

        let maximumBytes = 4 * 1024 * 1024
        let originalBytes = Data(repeating: 0x61, count: maximumBytes - 1)
        let appendedBytes = Data([0x62, 0x63])
        let memoryFile = agentDirectory.appendingPathComponent("Memory.md")
        try originalBytes.write(to: memoryFile)

        let manager = AgentFolderManager(vaultURL: vault)
        await manager.simulateMemoryBackupGrowthForTesting(
            fileName: "Memory.md",
            appending: appendedBytes
        )

        do {
            try await manager.saveAgentMemory(memory("replacement"))
            XCTFail("A source file that grows beyond the managed-file limit must not be backed up")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "R0lling.Agent")
            XCTAssertEqual(error.code, 6110)
        }

        var expectedOriginal = originalBytes
        expectedOriginal.append(appendedBytes)
        XCTAssertEqual(try Data(contentsOf: memoryFile), expectedOriginal)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: agentDirectory.path), ["Memory.md"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: transactionURL(vault).path))
    }

    private func memory(_ prefix: String) -> AgentMemory {
        AgentMemory(
            memoryNotes: "\(prefix) memory",
            userPreferences: "\(prefix) preferences",
            openLoops: "\(prefix) loops"
        )
    }

    private func transactionURL(_ vault: URL) -> URL {
        vault.appendingPathComponent("Agent/.memory-transaction.json")
    }
}
