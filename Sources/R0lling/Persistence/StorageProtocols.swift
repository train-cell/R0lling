import Foundation

public protocol JournalStorageProtocol: Sendable {
    func saveEntry(_ entry: JournalEntry) async throws
    /// Insert only entries whose IDs are absent, with one storage commit. Returns the IDs inserted.
    func insertEntriesIfAbsentAtomically(_ entries: [JournalEntry]) async throws -> Set<UUID>
    func deleteEntry(id: UUID) async throws
    func getEntry(id: UUID) async throws -> JournalEntry?
    func getEntriesForDate(_ date: Date) async throws -> [JournalEntry]
    func getAllEntries() async throws -> [JournalEntry]
    func searchEntries(query: String, tag: String?, source: EntrySource?) async throws -> [JournalEntry]
    func getDatesWithEntries() async throws -> Set<String>
}

public protocol MediaStorageProtocol: Sendable {
    func saveMediaFile(data: Data, originalFilename: String, mediaType: MediaType) async throws -> MediaAttachment
    /// Copies large imported assets from disk without first materializing the whole file in memory.
    func saveMediaFile(from sourceURL: URL, originalFilename: String, mediaType: MediaType) async throws -> MediaAttachment
    /// SEC-002: throws αν το relativePath επιχειρεί path traversal εκτός Media root.
    func getMediaFileURL(relativePath: String) throws -> URL
    func deleteMediaFile(relativePath: String) async throws
    func availableFreeDiskSpace() -> Int64
    func cleanupOrphanedFiles(activeRelativePaths: Set<String>) async throws -> Int
}

public protocol BackupRestoreProtocol: Sendable {
    func createBackupBundle() async throws -> URL
    func restoreFromBackupBundle(bundleURL: URL) async throws -> (restoredEntries: Int, restoredMedia: Int)
}
