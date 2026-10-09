import XCTest
import AVFoundation
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

    func testNonFiniteAndOversizedSamplesCannotExceedBufferMemoryLimit() async throws {
        await bufferService.startBuffering(targetSeconds: 10)
        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: .infinity,
            isKeyframe: true,
            isAudio: false,
            data: Data([0x01])
        ))

        do {
            _ = try await bufferService.triggerClip(requestedSeconds: 10)
            XCTFail("Non-finite timestamps must be ignored")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 3001)
        }

        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 0,
            isKeyframe: true,
            isAudio: false,
            data: Data(count: 26 * 1024 * 1024)
        ))

        do {
            _ = try await bufferService.triggerClip(requestedSeconds: 10)
            XCTFail("An oversized sample must be dropped to respect the hard memory limit")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 3001)
        }
    }

    func testPlaceholderExporterRejectsInfiniteDuration() async throws {
        let url = tempDirectory.appendingPathComponent("invalid_duration.mp4")
        do {
            try await PlayableClipExporter.grapsePlayablePlaceholderMP4(
                durationSeconds: .infinity,
                destinationURL: url
            )
            XCTFail("Infinite duration must not be converted into an unbounded frame count")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 3009)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
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
        let asset = AVURLAsset(url: result.fileURL)
        let isPlayable = try await asset.load(.isPlayable)
        XCTAssertTrue(isPlayable, "AVFoundation πρέπει να ανοίγει το εξαγόμενο clip")
        XCTAssertTrue(result.isPlayable)
        XCTAssertTrue(result.isSimulationPlaceholder, "Synthetic samples → simulation placeholder")
        XCTAssertGreaterThan(result.byteSize, 0)
    }

    func testOutOfOrderSamplesAreIgnoredAndExportDoesNotClaimUnmuxedAudio() async throws {
        await bufferService.startBuffering(targetSeconds: 10)
        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 1, isKeyframe: true, isAudio: false, data: Data([0x01])
        ))
        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 3, isKeyframe: false, isAudio: false, data: Data([0x02])
        ))
        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 2, isKeyframe: false, isAudio: true, data: Data([0x03])
        ))

        let duration = await bufferService.availableDuration
        XCTAssertEqual(duration, 2, accuracy: 0.001)
        let result = try await bufferService.triggerClip(requestedSeconds: 10)

        XCTAssertFalse(result.hasAudio, "The current MP4 writer emits video only")
    }

    func testHighlightReelIncludesAllClipsAndIsPlayable() async throws {
        let firstSource = tempDirectory.appendingPathComponent("first_source.mp4")
        let secondSource = tempDirectory.appendingPathComponent("second_source.mp4")
        defer {
            try? FileManager.default.removeItem(at: firstSource)
            try? FileManager.default.removeItem(at: secondSource)
        }
        try await PlayableClipExporter.grapsePlayablePlaceholderMP4(
            durationSeconds: 0.6,
            destinationURL: firstSource
        )
        try await PlayableClipExporter.grapsePlayablePlaceholderMP4(
            durationSeconds: 0.8,
            destinationURL: secondSource
        )

        let firstAttachment = try await mediaStorage.saveMediaFile(
            data: Data(contentsOf: firstSource),
            originalFilename: "first.mp4",
            mediaType: .clip
        )
        let secondAttachment = try await mediaStorage.saveMediaFile(
            data: Data(contentsOf: secondSource),
            originalFilename: "second.mp4",
            mediaType: .clip
        )
        let entries = [
            JournalEntry(content: "First clip", attachments: [firstAttachment]),
            JournalEntry(content: "Second clip", attachments: [secondAttachment])
        ]

        let muxer = HighlightReelMuxer(mediaStorage: mediaStorage)
        let reel = try await muxer.createDailyHighlightReel(for: entries)
        XCTAssertEqual(reel.totalClipsIncluded, 2)
        XCTAssertGreaterThan(reel.totalDurationSeconds, 1.0)

        let exportedAsset = AVURLAsset(url: reel.fileURL)
        let isPlayable = try await exportedAsset.load(.isPlayable)
        XCTAssertTrue(isPlayable)
        XCTAssertTrue(reel.isPlayable)
    }

    func testHighlightReelFailsWhenAReferencedClipIsMissing() async throws {
        let attachment = MediaAttachment(
            relativePath: "Clips/missing.mp4",
            mediaType: .clip,
            byteSize: 1
        )
        let entry = JournalEntry(content: "Missing clip", attachments: [attachment])
        let muxer = HighlightReelMuxer(mediaStorage: mediaStorage)

        do {
            _ = try await muxer.createDailyHighlightReel(for: [entry])
            XCTFail("A reel must not report success while omitting a referenced clip")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 3109)
        }
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
        let durationBeforeInterrupt = await bufferService.availableDuration
        XCTAssertGreaterThan(durationBeforeInterrupt, 0.5)

        await bufferService.markStreamInterrupted(reason: "disconnect")
        let gen2 = await bufferService.streamGeneration
        XCTAssertNotEqual(gen1, gen2)
        let durationAfterInterrupt = await bufferService.availableDuration
        XCTAssertEqual(durationAfterInterrupt, 0.0)

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
        let durationOldGen = await bufferService.availableDuration
        XCTAssertEqual(durationOldGen, 0.0, "Παλιά generation πρέπει να αγνοείται")

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
        let durationNewGen = await bufferService.availableDuration
        XCTAssertGreaterThan(durationNewGen, 0.5)
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
        let durationPaused = await bufferService.availableDuration
        XCTAssertEqual(durationPaused, 1.0, "Κατά pause δεν προστίθενται samples")

        await bufferService.resumeBuffering()
        await bufferService.appendSample(sample: BufferedSample(
            timestampSeconds: 2.0, isKeyframe: false, isAudio: false, data: Data([0x04]), streamGeneration: gen
        ))
        let durationResumed = await bufferService.availableDuration
        XCTAssertGreaterThan(durationResumed, 1.5)
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
