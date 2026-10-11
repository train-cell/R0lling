import XCTest
@testable import R0lling

final class HighlightReelJournalCommitterTests: XCTestCase {
    func testCommitPersistsPlayableReelAttachmentInJournal() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("r0lling-highlight-journal-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let storage = JSONFileStorageService(storageURL: fileURL)
        let gate = MediaReferenceMutationGate()
        let createdAt = Date(timeIntervalSince1970: 1_791_583_200)
        let attachment = MediaAttachment(
            relativePath: "Videos/highlight.mp4",
            originalFilename: "highlight.mp4",
            mediaType: .video,
            byteSize: 4096,
            durationSeconds: 12.5,
            captureTimestamp: createdAt,
            hasAudio: true
        )

        let entry = try await HighlightReelJournalCommitter.commit(
            attachment: attachment,
            clipCount: 2,
            durationSeconds: 12.5,
            createdAt: createdAt,
            storage: storage,
            mutationGate: gate
        )
        let persisted = try await storage.getEntry(id: entry.id)

        XCTAssertEqual(persisted?.title, "Ημερήσιο Highlight Reel")
        XCTAssertEqual(persisted?.source, .glassesClip)
        XCTAssertEqual(persisted?.tags, ["highlight-reel"])
        XCTAssertEqual(persisted?.attachments, [attachment])
        XCTAssertTrue(persisted?.content.contains("2 clips") == true)
    }

    func testFactoryRejectsInvalidExportMetadata() {
        let attachment = MediaAttachment(
            relativePath: "Videos/highlight.mp4",
            mediaType: .video,
            byteSize: 64
        )

        XCTAssertThrowsError(try HighlightReelJournalCommitter.makeEntry(
            attachment: attachment,
            clipCount: 0,
            durationSeconds: 1
        ))
        XCTAssertThrowsError(try HighlightReelJournalCommitter.makeEntry(
            attachment: attachment,
            clipCount: 1,
            durationSeconds: .infinity
        ))
        XCTAssertThrowsError(try HighlightReelJournalCommitter.makeEntry(
            attachment: MediaAttachment(
                relativePath: "Clips/source.mp4",
                mediaType: .clip,
                byteSize: 64
            ),
            clipCount: 1,
            durationSeconds: 1
        ))
    }

    func testSavedReelIsDeletedWhenViewerURLResolutionFails() async throws {
        let recorder = MediaDeletionRecorder()
        let storage = FailingReelURLStorage(recorder: recorder)
        let attachment = MediaAttachment(
            relativePath: "Videos/highlight.mp4",
            mediaType: .video,
            byteSize: 128
        )

        do {
            _ = try await HighlightReelMediaFinalizer.resolveURL(for: attachment, using: storage)
            XCTFail("Expected URL resolution to fail")
        } catch let error as ReelURLFailure {
            XCTAssertEqual(error, .unsafePath)
        }

        let deletedPaths = await recorder.paths()
        XCTAssertEqual(deletedPaths, [attachment.relativePath])
    }

    func testCleanupFailureDoesNotReplaceViewerURLResolutionError() async throws {
        let recorder = MediaDeletionRecorder()
        let storage = FailingReelURLStorage(recorder: recorder, failDeletion: true)
        let attachment = MediaAttachment(
            relativePath: "Videos/highlight.mp4",
            mediaType: .video,
            byteSize: 128
        )

        do {
            _ = try await HighlightReelMediaFinalizer.resolveURL(for: attachment, using: storage)
            XCTFail("Expected URL resolution to fail")
        } catch let error as ReelURLFailure {
            XCTAssertEqual(error, .unsafePath)
        }

        let deletedPaths = await recorder.paths()
        XCTAssertEqual(deletedPaths, [attachment.relativePath])
    }
}

private enum ReelURLFailure: Error, Equatable {
    case unsafePath
    case deleteFailed
}

private actor MediaDeletionRecorder {
    private var deletedPaths: [String] = []

    func record(_ path: String) {
        deletedPaths.append(path)
    }

    func paths() -> [String] {
        deletedPaths
    }
}

private struct FailingReelURLStorage: MediaStorageProtocol {
    let recorder: MediaDeletionRecorder
    let failDeletion: Bool

    init(recorder: MediaDeletionRecorder, failDeletion: Bool = false) {
        self.recorder = recorder
        self.failDeletion = failDeletion
    }

    func saveMediaFile(data: Data, originalFilename: String, mediaType: MediaType) async throws -> MediaAttachment {
        throw ReelURLFailure.unsafePath
    }

    func saveMediaFile(from sourceURL: URL, originalFilename: String, mediaType: MediaType) async throws -> MediaAttachment {
        throw ReelURLFailure.unsafePath
    }

    func getMediaFileURL(relativePath: String) throws -> URL {
        throw ReelURLFailure.unsafePath
    }

    func deleteMediaFile(relativePath: String) async throws {
        await recorder.record(relativePath)
        if failDeletion { throw ReelURLFailure.deleteFailed }
    }

    func availableFreeDiskSpace() -> Int64 { 0 }

    func cleanupOrphanedFiles(activeRelativePaths: Set<String>) async throws -> Int { 0 }
}
