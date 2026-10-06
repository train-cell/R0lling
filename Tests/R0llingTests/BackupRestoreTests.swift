import XCTest
@testable import R0lling

final class BackupRestoreTests: XCTestCase {
    var tempDirectory: URL!
    var storage: JSONFileStorageService!
    var mediaStorage: MediaStorageService!
    var backupEngine: BackupRestoreEngine!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("TestBackup_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        storage = JSONFileStorageService(storageURL: tempDirectory.appendingPathComponent("journal.json"))
        mediaStorage = MediaStorageService(baseDirectory: tempDirectory.appendingPathComponent("Media"))
        backupEngine = BackupRestoreEngine(storage: storage, mediaStorage: mediaStorage)
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
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("manifest.json").path))

        // Δημιουργία καθαρού storage για restore
        let cleanStorageURL = tempDirectory.appendingPathComponent("clean_journal.json")
        let cleanStorage = JSONFileStorageService(storageURL: cleanStorageURL)
        let cleanMedia = MediaStorageService(baseDirectory: tempDirectory.appendingPathComponent("CleanMedia"))
        let cleanBackupEngine = BackupRestoreEngine(storage: cleanStorage, mediaStorage: cleanMedia)

        let result = try await cleanBackupEngine.restoreFromBackupBundle(bundleURL: bundleURL)
        XCTAssertEqual(result.restoredEntries, 2)

        let restoredEntries = await cleanStorage.getAllEntries()
        XCTAssertEqual(restoredEntries.count, 2)
    }
}
