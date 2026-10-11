import Foundation

/// Builds and atomically stores the journal reference for an exported reel.
/// The video itself is already saved by `HighlightReelMuxer`; this commit makes it
/// visible to the journal's attachment-driven playback UI.
public enum HighlightReelJournalCommitter {
    public enum CommitError: Error, LocalizedError, Sendable {
        case invalidClipCount
        case invalidDuration
        case invalidAttachment

        public var errorDescription: String? {
            switch self {
            case .invalidClipCount:
                "Το Highlight Reel δεν περιέχει clips."
            case .invalidDuration:
                "Το Highlight Reel έχει μη έγκυρη διάρκεια."
            case .invalidAttachment:
                "Το αρχείο Highlight Reel δεν είναι έγκυρο συνημμένο βίντεο."
            }
        }
    }

    public static func makeEntry(
        attachment: MediaAttachment,
        clipCount: Int,
        durationSeconds: Double,
        createdAt: Date = Date()
    ) throws -> JournalEntry {
        guard clipCount > 0 else { throw CommitError.invalidClipCount }
        guard durationSeconds.isFinite, durationSeconds > 0 else { throw CommitError.invalidDuration }
        guard attachment.mediaType == .video,
              !attachment.relativePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              attachment.byteSize > 0 else {
            throw CommitError.invalidAttachment
        }

        let duration = String(format: "%.1f", durationSeconds)
        return JournalEntry(
            timestamp: createdAt,
            timeZoneIdentifier: TimeZone.current.identifier,
            title: "Ημερήσιο Highlight Reel",
            content: "Highlight Reel από \(clipCount) clips (\(duration)s).",
            source: .glassesClip,
            tags: ["highlight-reel"],
            attachments: [attachment],
            lastModified: createdAt
        )
    }

    @discardableResult
    public static func commit(
        attachment: MediaAttachment,
        clipCount: Int,
        durationSeconds: Double,
        createdAt: Date = Date(),
        storage: any JournalStorageProtocol,
        mutationGate: MediaReferenceMutationGate
    ) async throws -> JournalEntry {
        let entry = try makeEntry(
            attachment: attachment,
            clipCount: clipCount,
            durationSeconds: durationSeconds,
            createdAt: createdAt
        )
        try await mutationGate.withExclusiveAccess {
            try await storage.saveEntry(entry)
        }
        return entry
    }
}
