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

        // Τροφοδοσία 3 δευτερολέπτων καρέ (warm-up σενάριο A06)
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

        let result = try await bufferService.triggerClip(requestedSeconds: 10.0)
        XCTAssertNotNil(result.fileURL)
        // A06: warm-up → πραγματική μικρότερη διάρκεια (~3s), όχι ψευδή 10s
        XCTAssertLessThan(result.duration, 4.0)
        XCTAssertGreaterThan(result.duration, 2.0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        let data = try Data(contentsOf: result.fileURL)
        XCTAssertNotNil(data.range(of: Data("moov".utf8)), "Το clip πρέπει να περιέχει moov box")
        XCTAssertNotNil(data.range(of: Data("ftyp".utf8)), "Το clip πρέπει να περιέχει ftyp box")
        XCTAssertTrue(result.isPlayable)
        XCTAssertTrue(result.isSimulationPlaceholder, "Synthetic samples → simulation placeholder")
        XCTAssertGreaterThan(result.byteSize, 0)
    }

    func testBufferTrimmingPastTenSeconds() async throws {
        await bufferService.startBuffering(targetSeconds: 5.0)

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
        XCTAssertLessThanOrEqual(available, 7.0)
    }

    /// A06: disconnect / interrupt → clear + νέα generation · παλιά samples αγνοούνται.
    func testDisconnectClearsAndBumpsGeneration() async throws {
        await bufferService.startBuffering(targetSeconds: 10.0)
        let gen1 = await bufferService.streamGeneration

        for i in 0..<10 {
            await bufferService.appendSample(sample: BufferedSample(
                timestampSeconds: Double(i) * 0.1,
                isKeyframe: i == 0,
                isAudio: false,
                data: Data([0x01]),
                streamGeneration: gen1
            ))
        }
        XCTAssertGreaterThan(await bufferService.availableDuration, 0.5)

        await bufferService.markStreamInterrupted(reason: "disconnect")
        let gen2 = await bufferService.streamGeneration
        XCTAssertNotEqual(gen1, gen2)
        XCTAssertEqual(await bufferService.availableDuration, 0.0)

        // Παλιά generation samples δεν μπαίνουν στο νέο session
        await bufferService.startBuffering(targetSeconds: 10.0)
        let gen3 = await bufferService.streamGeneration
        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 1.0,
            isKeyframe: true,
            isAudio: false,
            data: Data([0x02]),
            streamGeneration: gen1
        ))
        XCTAssertEqual(await bufferService.availableDuration, 0.0, "Παλιά generation πρέπει να αγνοείται")

        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 0.0,
            isKeyframe: true,
            isAudio: false,
            data: Data([0x03]),
            streamGeneration: gen3
        ))
        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 1.0,
            isKeyframe: false,
            isAudio: false,
            data: Data([0x04]),
            streamGeneration: gen3
        ))
        XCTAssertGreaterThan(await bufferService.availableDuration, 0.5)
    }

    /// A07: pause σταματά append · resume συνεχίζει ίδια session χωρίς fake gap join από interrupt.
    func testPauseStopsAppendResumeContinues() async throws {
        await bufferService.startBuffering(targetSeconds: 10.0)
        let gen = await bufferService.streamGeneration

        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 0.0, isKeyframe: true, isAudio: false, data: Data([0x01]), streamGeneration: gen
        ))
        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 1.0, isKeyframe: false, isAudio: false, data: Data([0x02]), streamGeneration: gen
        ))

        await bufferService.pauseBuffering()
        let statePaused = await bufferService.currentState
        XCTAssertEqual(statePaused, .paused)

        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 2.0, isKeyframe: false, isAudio: false, data: Data([0x03]), streamGeneration: gen
        ))
        XCTAssertEqual(await bufferService.availableDuration, 1.0, "Κατά pause δεν προστίθενται samples")

        await bufferService.resumeBuffering()
        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 2.0, isKeyframe: false, isAudio: false, data: Data([0x04]), streamGeneration: gen
        ))
        XCTAssertGreaterThan(await bufferService.availableDuration, 1.5)
    }

    /// A07 policy math: background κατά streaming → PAUSED message χωρίς continuous promise.
    func testLifecyclePolicyBackgroundPausesHonestly() {
        let outcome = GlassesLifecyclePolicy.apofasiGia(
            event: .willEnterBackground,
            isCurrentlyStreaming: true,
            policy: .proepilogiR0lling
        )
        XCTAssertTrue(outcome.didPauseStream)
        XCTAssertEqual(outcome.bufferStateLabel, "PAUSED")
        XCTAssertFalse(GlassesReconnectPolicy.proepilogiR0lling.promisesContinuousBackgroundCapture)
        XCTAssertNotNil(outcome.userMessage)
    }

    /// Remux χωρίς SPS/PPS → σαφές 3010 (όχι ψευδο-MP4).
    func testRemuxWithoutSPSPPSThrows3010() async {
        let samples = [
            BufferedSample(
                timestampSeconds: 0,
                isKeyframe: true,
                isAudio: false,
                // Annex-B start code αλλά NAL type 1 (non-IDR) χωρίς SPS/PPS
                data: Data([0x00, 0x00, 0x00, 0x01, 0x61, 0x00, 0x00])
            ),
            BufferedSample(
                timestampSeconds: 0.1,
                isKeyframe: false,
                isAudio: false,
                data: Data([0x00, 0x00, 0x00, 0x01, 0x41, 0x00])
            )
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("remux_fail_\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            try await H264AnnexBRemuxer.eksagogiPlayableMP4(samples: samples, destinationURL: url)
            XCTFail("Αναμενόταν 3010 χωρίς SPS/PPS")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, H264AnnexBRemuxer.errorDomain)
            XCTAssertEqual(error.code, H264AnnexBRemuxer.kodikosElleipsisSPSPPS)
        }
    }
}
