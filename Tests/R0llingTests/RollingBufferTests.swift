import XCTest
@testable import R0lling

final class RollingBufferTests: XCTestCase {
    var mediaStorage: MediaStorageService!
    var bufferService: RollingBufferService!
    var tempDirectory: URL!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("TestBuffer_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        mediaStorage = MediaStorageService(baseDirectory: tempDirectory)
        bufferService = RollingBufferService(mediaStorage: mediaStorage)
    }

    override func tearDown() async throws {
        if let dir = tempDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func testEmptyBufferThrowsError() async {
        do {
            _ = try await bufferService.triggerClip(requestedSeconds: 5.0)
            XCTFail("Αναμενόταν σφάλμα λόγω κενού buffer")
        } catch {
            XCTAssertTrue(true)
        }
    }

    func testBufferingAndWarmupClip() async throws {
        await bufferService.startBuffering(targetSeconds: 10.0)

        // Τροφοδοσία 3 δευτερολέπτων καρέ (warm-up σενάριο)
        for i in 0..<30 {
            let sample = BufferedSample(
                timestampSeconds: Double(i) * 0.1,
                isKeyframe: (i == 0 || i == 15),
                isAudio: false,
                data: Data([0x00, 0x01, 0x02])
            )
            await bufferService.appendSample(sample: sample)
        }

        let duration = await bufferService.availableDuration
        XCTAssertGreaterThan(duration, 2.5)

        // Εξαγωγή clip
        let result = try await bufferService.triggerClip(requestedSeconds: 10.0)
        XCTAssertNotNil(result.fileURL)
        XCTAssertGreaterThan(result.duration, 0.0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        // R3-002: playable MP4 πρέπει να περιέχει moov
        let data = try Data(contentsOf: result.fileURL)
        XCTAssertNotNil(data.range(of: Data("moov".utf8)), "Το clip πρέπει να περιέχει moov box")
        XCTAssertNotNil(data.range(of: Data("ftyp".utf8)), "Το clip πρέπει να περιέχει ftyp box")
        XCTAssertTrue(result.isPlayable)
        XCTAssertTrue(result.isSimulationPlaceholder, "Synthetic samples → simulation placeholder")
        XCTAssertGreaterThan(result.byteSize, 0)
    }

    func testBufferTrimmingPastTenSeconds() async throws {
        await bufferService.startBuffering(targetSeconds: 5.0)

        // Τροφοδοσία 15 δευτερολέπτων
        for i in 0..<150 {
            let sample = BufferedSample(
                timestampSeconds: Double(i) * 0.1,
                isKeyframe: (i % 10 == 0),
                isAudio: false,
                data: Data([UInt8](repeating: 0xFF, count: 100))
            )
            await bufferService.appendSample(sample: sample)
        }

        let available = await bufferService.availableDuration
        // Πρέπει να έχει περιοριστεί γύρω στα 5-6s
        XCTAssertLessThanOrEqual(available, 7.0)
    }
}
