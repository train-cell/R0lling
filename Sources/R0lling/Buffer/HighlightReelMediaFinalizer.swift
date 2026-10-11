import Foundation

/// Resolves a saved reel's viewer URL and attempts to remove the saved media if
/// resolving the URL fails before the caller can commit its journal reference.
public enum HighlightReelMediaFinalizer {
    public static func resolveURL(
        for attachment: MediaAttachment,
        using mediaStorage: any MediaStorageProtocol
    ) async throws -> URL {
        do {
            return try mediaStorage.getMediaFileURL(relativePath: attachment.relativePath)
        } catch {
            // The file was saved, but ownership has not yet transferred to AppState.
            // Preserve the lookup error while making a best-effort orphan cleanup.
            try? await mediaStorage.deleteMediaFile(relativePath: attachment.relativePath)
            throw error
        }
    }
}
