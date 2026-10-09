import XCTest
import CoreGraphics
import ImageIO
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

    #if os(iOS)
    func testNewMediaFileUsesDataProtectionUntilFirstUnlock() async throws {
        let attachment = try await mediaStorage.saveMediaFile(
            data: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            originalFilename: "protected.jpg",
            mediaType: .photo
        )

        let fileURL = tempDirectory.appendingPathComponent(attachment.relativePath)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        XCTAssertEqual(
            attributes[.protectionKey] as? FileProtectionType,
            .completeUntilFirstUserAuthentication
        )
    }

    func testFileBackedMediaImportUsesDataProtectionUntilFirstUnlock() async throws {
        let sourceURL = tempDirectory.appendingPathComponent("source.mov")
        try Data(repeating: 0x5A, count: 16).write(to: sourceURL)

        let attachment = try await mediaStorage.saveMediaFile(
            from: sourceURL,
            originalFilename: "protected.mov",
            mediaType: .video
        )

        let fileURL = tempDirectory.appendingPathComponent(attachment.relativePath)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        XCTAssertEqual(
            attributes[.protectionKey] as? FileProtectionType,
            .completeUntilFirstUserAuthentication
        )
    }
    #endif

    func testSaveMediaUsesSafeFallbackForUntrustedFilenameExtension() async throws {
        let attachment = try await mediaStorage.saveMediaFile(
            data: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            originalFilename: "travel.bad%2Fextension",
            mediaType: .photo
        )

        XCTAssertTrue(attachment.relativePath.hasPrefix("Photos/"))
        XCTAssertTrue(attachment.relativePath.hasSuffix(".jpg"))
        let fileURL = try mediaStorage.getMediaFileURL(relativePath: attachment.relativePath)
        XCTAssertTrue(fileURL.path.hasPrefix(tempDirectory.appendingPathComponent("Photos").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testFileBackedImportCopiesAssetIntoSandbox() async throws {
        let sourceDirectory = tempDirectory.appendingPathComponent("External", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        let sourceURL = sourceDirectory.appendingPathComponent("recording.mov")
        let sourceBytes = Data(repeating: 0x5A, count: 256 * 1024)
        try sourceBytes.write(to: sourceURL)

        let attachment = try await mediaStorage.saveMediaFile(
            from: sourceURL,
            originalFilename: "recording.mov",
            mediaType: .video
        )

        XCTAssertEqual(attachment.byteSize, Int64(sourceBytes.count))
        XCTAssertTrue(attachment.relativePath.hasPrefix("Videos/"))
        XCTAssertTrue(attachment.relativePath.hasSuffix(".mov"))
        let sandboxURL = try mediaStorage.getMediaFileURL(relativePath: attachment.relativePath)
        XCTAssertEqual(try Data(contentsOf: sandboxURL), sourceBytes)
        XCTAssertFalse(attachment.hasAudio, "File-backed storage must not infer an audio track from the video type")
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

    func testDeletingDirectoryAttachmentIsRejectedWithoutDeletingContents() async throws {
        let mediaFolder = tempDirectory.appendingPathComponent("Photos", isDirectory: true)
        let nested = mediaFolder.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let sentinel = nested.appendingPathComponent("keep.txt")
        try Data("keep this file".utf8).write(to: sentinel)

        do {
            try await mediaStorage.deleteMediaFile(relativePath: "Photos/nested")
            XCTFail("Directory attachments must not be recursively deleted")
        } catch let error as MediaApothikeusiError {
            XCTAssertEqual(error, .unsafeRelativePath(relativePath: "Photos/nested"))
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
    }

    func testOrphanCleanupSkipsDirectoriesAndTheirContents() async throws {
        let mediaFolder = tempDirectory.appendingPathComponent("Photos", isDirectory: true)
        let nested = mediaFolder.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let sentinel = nested.appendingPathComponent("keep.txt")
        try Data("keep this file".utf8).write(to: sentinel)

        _ = try await mediaStorage.cleanupOrphanedFiles(activeRelativePaths: [])

        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
    }

    func testMediaDirectorySymlinkCannotRedirectWritesOrCleanup() async throws {
        let photosDirectory = tempDirectory.appendingPathComponent("Photos", isDirectory: true)
        if FileManager.default.fileExists(atPath: photosDirectory.path) {
            try FileManager.default.removeItem(at: photosDirectory)
        }
        let externalDirectory = tempDirectory.appendingPathComponent("External", isDirectory: true)
        try FileManager.default.createDirectory(at: externalDirectory, withIntermediateDirectories: true)
        let sentinel = externalDirectory.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: sentinel)
        try FileManager.default.createSymbolicLink(at: photosDirectory, withDestinationURL: externalDirectory)

        do {
            _ = try await mediaStorage.saveMediaFile(data: Data("outside".utf8), originalFilename: "x.jpg", mediaType: .photo)
            XCTFail("A media-folder symlink must not redirect a write outside the media root")
        } catch let error as MediaApothikeusiError {
            XCTAssertEqual(error, .unsafeRelativePath(relativePath: "Photos"))
        }
        do {
            _ = try await mediaStorage.cleanupOrphanedFiles(activeRelativePaths: [])
            XCTFail("Orphan cleanup must not traverse a redirected media folder")
        } catch let error as MediaApothikeusiError {
            XCTAssertEqual(error, .unsafeRelativePath(relativePath: "Photos"))
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: externalDirectory.path), ["keep.txt"])
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

    func testVisionImageSanitizerRemovesGPSAndEXIFButKeepsOrientation() throws {
        let pixelData = Data([255, 0, 0, 255])
        let provider = try XCTUnwrap(CGDataProvider(data: pixelData as CFData))
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let image = try XCTUnwrap(CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))

        let input = NSMutableData()
        let inputWriter = try XCTUnwrap(CGImageDestinationCreateWithData(
            input as CFMutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ))
        let gps: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: 37.9838,
            kCGImagePropertyGPSLongitude: 23.7275
        ]
        let exif: [CFString: Any] = [
            kCGImagePropertyExifUserComment: "private note"
        ]
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: gps,
            kCGImagePropertyExifDictionary: exif
        ]
        CGImageDestinationAddImage(inputWriter, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(inputWriter))

        let inputSource = try XCTUnwrap(CGImageSourceCreateWithData(input as CFData, nil))
        let inputProperties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(inputSource, 0, nil) as? [String: Any]
        )
        XCTAssertNotNil(inputProperties[kCGImagePropertyGPSDictionary as String])
        XCTAssertNotNil(inputProperties[kCGImagePropertyExifDictionary as String])

        let sanitized = try ImageMetadataSanitizer.encode(input as Data, outputType: "public.jpeg" as CFString)
        let outputSource = try XCTUnwrap(CGImageSourceCreateWithData(sanitized as CFData, nil))
        let outputProperties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [String: Any]
        )

        XCTAssertNil(outputProperties[kCGImagePropertyGPSDictionary as String])
        XCTAssertNil(outputProperties[kCGImagePropertyExifDictionary as String])
        XCTAssertEqual(outputProperties[kCGImagePropertyOrientation as String] as? Int, 6)

        let boundedVisionImage = try ImageMetadataSanitizer.encodeForVision(input as Data)
        XCTAssertLessThanOrEqual(boundedVisionImage.count, ImageMetadataSanitizer.maximumVisionOutputBytes)
        let boundedSource = try XCTUnwrap(CGImageSourceCreateWithData(boundedVisionImage as CFData, nil))
        let boundedProperties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(boundedSource, 0, nil) as? [String: Any]
        )
        XCTAssertNil(boundedProperties[kCGImagePropertyGPSDictionary as String])
        XCTAssertNil(boundedProperties[kCGImagePropertyExifDictionary as String])
        XCTAssertLessThanOrEqual(
            boundedProperties[kCGImagePropertyPixelWidth as String] as? Int ?? Int.max,
            ImageMetadataSanitizer.maximumVisionPixelDimension
        )
        XCTAssertLessThanOrEqual(
            boundedProperties[kCGImagePropertyPixelHeight as String] as? Int ?? Int.max,
            ImageMetadataSanitizer.maximumVisionPixelDimension
        )
    }

    func testVisionImageSanitizerRejectsInvalidImageData() {
        XCTAssertThrowsError(try ImageMetadataSanitizer.encode(Data("not an image".utf8)))
        XCTAssertThrowsError(try ImageMetadataSanitizer.encodeForVision(Data("not an image".utf8)))
        XCTAssertThrowsError(try ImageMetadataSanitizer.encodeForVision(Data(
            repeating: 0,
            count: ImageMetadataSanitizer.maximumVisionInputBytes + 1
        )))
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
