import Foundation

public protocol JournalStorageProtocol: Sendable {
    func saveEntry(_ entry: JournalEntry) async throws
    /// Replaces an existing entry without allowing a stale caller to resurrect a deleted ID.
    /// Returns `false` when the ID is no longer present.
    func updateEntryIfPresent(_ entry: JournalEntry) async throws -> Bool
    /// Appends one attachment to the current entry atomically inside the storage actor.
    /// Returns the updated entry, or `nil` when the target ID is absent.
    func appendAttachmentIfPresent(_ attachment: MediaAttachment, toEntryID id: UUID) async throws -> JournalEntry?
    /// Insert only entries whose IDs are absent, with one storage commit. Returns the IDs inserted.
    func insertEntriesIfAbsentAtomically(_ entries: [JournalEntry]) async throws -> Set<UUID>
    func deleteEntry(id: UUID) async throws
    func getEntry(id: UUID) async throws -> JournalEntry?
    func getEntriesForDate(_ date: Date) async throws -> [JournalEntry]
    func getAllEntries() async throws -> [JournalEntry]
    func searchEntries(query: String, tag: String?, source: EntrySource?) async throws -> [JournalEntry]
    func getDatesWithEntries() async throws -> Set<String>
}

/// Errors returned by storage implementations that cannot preserve atomic mutation semantics.
public enum JournalStorageOperationError: Error, LocalizedError, Sendable {
    case atomicUpdateUnsupported
    case atomicAttachmentAppendUnsupported

    public var errorDescription: String? {
        switch self {
        case .atomicUpdateUnsupported:
            return "This journal storage does not support atomic updates."
        case .atomicAttachmentAppendUnsupported:
            return "This journal storage does not support atomic attachment appends."
        }
    }
}

public extension JournalStorageProtocol {
    /// Keeps older conformers source-compatible while failing closed instead of doing a
    /// read-then-write sequence that could resurrect a deleted entry or lose concurrent changes.
    func updateEntryIfPresent(_ entry: JournalEntry) async throws -> Bool {
        throw JournalStorageOperationError.atomicUpdateUnsupported
    }

    /// Legacy conformers must provide a storage-level atomic append before supporting this mutation.
    func appendAttachmentIfPresent(
        _ attachment: MediaAttachment,
        toEntryID id: UUID
    ) async throws -> JournalEntry? {
        throw JournalStorageOperationError.atomicAttachmentAppendUnsupported
    }
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
