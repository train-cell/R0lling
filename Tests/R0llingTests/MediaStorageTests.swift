import XCTest
@testable import R0lling

final class MediaStorageTests: XCTestCase {
    var tempDirectory: URL!
    var mediaStorage: MediaStorageService!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        mediaStorage = MediaStorageService(
            baseDirectory: tempDirectory,
            paradekampseElegxoXorou: true
        )
    }

    override func tearDown() async throws {
        if let dir = tempDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func testSavePhotoCreatesFileAndAttachment() async throws {
        let jpegBytes = Data([0xFF, 0xD8, 0xFF, 0xD9]) // minimal JPEG markers
        let attachment = try await mediaStorage.saveMediaFile(
            data: jpegBytes,
            originalFilename: "travel.jpg",
            mediaType: .photo
        )

        XCTAssertEqual(attachment.mediaType, .photo)
        XCTAssertEqual(attachment.byteSize, Int64(jpegBytes.count))
        XCTAssertTrue(attachment.relativePath.hasPrefix("Photos/"))
        XCTAssertTrue(attachment.relativePath.hasSuffix(".jpg"))

        let url = try mediaStorage.getMediaFileURL(relativePath: attachment.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let loaded = try Data(contentsOf: url)
        XCTAssertEqual(loaded, jpegBytes)
    }

    func testEmptyDataFailsClosed() async {
        do {
            _ = try await mediaStorage.saveMediaFile(
                data: Data(),
                originalFilename: "empty.jpg",
                mediaType: .photo
            )
            XCTFail("Κενά δεδομένα πρέπει να αποτυγχάνουν")
        } catch let error as MediaApothikeusiError {
            XCTAssertEqual(error, .kenoDedomena)
        } catch {
            XCTFail("Αναμενόταν MediaApothikeusiError, πήρε \(error)")
        }
    }

    func testPathTraversalRejected() async throws {
        do {
            _ = try mediaStorage.getMediaFileURL(relativePath: "../Secrets/key.txt")
            XCTFail("Path traversal πρέπει να απορρίπτεται")
        } catch {
            let ns = error as NSError
            XCTAssertEqual(ns.domain, PathAsfaleia.errorDomain)
            XCTAssertEqual(ns.code, PathAsfaleia.kodikosApokleismou)
        }
    }

    func testImporterClassifiesExtensions() throws {
        XCTAssertEqual(
            try JournalMediaImporter.mediaType(giaOnomaArxeiou: "a.HEIC"),
            .photo
        )
        XCTAssertEqual(
            try JournalMediaImporter.mediaType(giaOnomaArxeiou: "clip.mov"),
            .video
        )
        XCTAssertEqual(
            try JournalMediaImporter.mediaType(giaOnomaArxeiou: "voice.m4a"),
            .audio
        )
    }

    func testImporterRejectsUnknownExtension() {
        XCTAssertThrowsError(
            try JournalMediaImporter.mediaType(giaOnomaArxeiou: "notes.docx")
        )
    }

    func testOrphanCleanupRemovesUnreferenced() async throws {
        let a = try await mediaStorage.saveMediaFile(
            data: Data("photo-a".utf8),
            originalFilename: "a.jpg",
            mediaType: .photo
        )
        let b = try await mediaStorage.saveMediaFile(
            data: Data("photo-b".utf8),
            originalFilename: "b.jpg",
            mediaType: .photo
        )

        let removed = try await mediaStorage.cleanupOrphanedFiles(
            activeRelativePaths: [a.relativePath]
        )
        XCTAssertGreaterThanOrEqual(removed, 1)

        let urlA = try mediaStorage.getMediaFileURL(relativePath: a.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: urlA.path))

        do {
            let urlB = try mediaStorage.getMediaFileURL(relativePath: b.relativePath)
            XCTAssertFalse(FileManager.default.fileExists(atPath: urlB.path))
        } catch {
            // Path may still resolve but file gone — OK either way.
        }
    }
}
