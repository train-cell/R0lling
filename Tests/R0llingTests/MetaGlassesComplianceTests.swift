import XCTest
@testable import R0lling

private final class MockSensorSink: GlassesSensorFeedSink, @unchecked Sendable {
    var receivedAcousticLevel: Float?
    var receivedIMUSample: HeadGestureDetector.IMUSample?

    func receiveAcousticLevel(decibels: Float) {
        self.receivedAcousticLevel = decibels
    }

    func receiveIMUSample(_ sample: HeadGestureDetector.IMUSample) {
        self.receivedIMUSample = sample
    }
}

final class MetaGlassesComplianceTests: XCTestCase {

    func testDATLiveHooksFailClosedUntilTheyAreImplemented() async {
        XCTAssertFalse(MetaDATStreamBridge.einaiLiveYlopoiimeno)

        await assertDATHookFailsClosed {
            _ = try await MetaDATStreamBridge.anoixeLiveSession()
        }
        await assertDATHookFailsClosed {
            _ = try await MetaDATStreamBridge.diavaseEpomenoVideoFrame()
        }
        await assertDATHookFailsClosed {
            _ = try await MetaDATStreamBridge.diavaseEpomenoAudioSample()
        }
        await assertDATHookFailsClosed {
            _ = try await MetaDATStreamBridge.diavaseEpomenoIMU()
        }
    }

    private func assertDATHookFailsClosed(
        _ operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("An unwired DAT hook must not report success", file: file, line: line)
        } catch {
            let nsError = error as NSError
            let expectedCode = MetaDATStreamBridge.einaiSDKDiathesimo
                ? MetaDATStreamBridge.kodikosSessionApotyxia
                : MetaDATStreamBridge.kodikosSDKMiDiathesimo
            XCTAssertEqual(nsError.domain, MetaDATStreamBridge.errorDomain, file: file, line: line)
            XCTAssertEqual(nsError.code, expectedCode, file: file, line: line)
        }
    }

    func testDisconnectedStateReportsHonestBatteryNil() async {
        let adapter = MetaGlassesAdapter()
        let state = await adapter.connectionState
        XCTAssertEqual(state, .disconnected)
        let battery = await adapter.currentBatteryLevel()
        // Ποτέ ψευδές 94% σε αποσυνδεδεμένη συσκευή
        XCTAssertNil(battery)
    }

    func testCancellingConnectionHandshakeClearsConnectingState() async throws {
        let adapter = MetaGlassesAdapter()
        let connection = Task { try await adapter.connectDevice() }

        // The adapter publishes `.connecting` before its cancellable handshake suspends.
        for _ in 0..<100 {
            if await adapter.connectionState == .connecting { break }
            await Task.yield()
        }
        let connectingState = await adapter.connectionState
        XCTAssertEqual(connectingState, .connecting)

        connection.cancel()
        do {
            try await connection.value
            XCTFail("A cancelled connection handshake must propagate cancellation")
        } catch is CancellationError {
            // Expected.
        }

        let finalState = await adapter.connectionState
        XCTAssertEqual(finalState, .disconnected)
    }

    func testStaleHandshakeCannotOverwriteANewerConnectionAttempt() async throws {
        let adapter = MetaGlassesAdapter()
        let staleConnection = Task { try await adapter.connectDevice() }
        for _ in 0..<100 {
            if await adapter.connectionState == .connecting { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }

        await adapter.disconnectDevice()
        let currentConnection = Task { try await adapter.connectDevice() }
        for _ in 0..<100 {
            if await adapter.connectionState == .connecting { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        try await currentConnection.value

        do {
            try await staleConnection.value
            XCTFail("A connection invalidated by disconnect must not report success")
        } catch is CancellationError {
            // Expected: disconnect invalidates the older handshake generation.
        }

        let finalState = await adapter.connectionState
        XCTAssertTrue(finalState.isConnected)
    }

    func testGlassesPrimaryActionRestartsConnectedOrPausedStreamInsteadOfDisconnecting() {
        let connected = GlassesConnectionState.connected(deviceName: "Device", batteryPercent: nil)
        XCTAssertTrue(connected.isConnected)
        XCTAssertEqual(GlassesPrimaryAction.resolve(isStreaming: false, state: connected), .startStreaming)

        let paused = GlassesConnectionState.paused(reason: "background")
        XCTAssertTrue(paused.isConnected)
        XCTAssertEqual(GlassesPrimaryAction.resolve(isStreaming: false, state: paused), .startStreaming)

        let streaming = GlassesConnectionState.streaming(fps: 30, isBuffering: true)
        XCTAssertEqual(GlassesPrimaryAction.resolve(isStreaming: false, state: streaming), .stopStreaming)
        XCTAssertEqual(GlassesPrimaryAction.resolve(isStreaming: true, state: connected), .stopStreaming)
        XCTAssertEqual(GlassesPrimaryAction.resolve(isStreaming: false, state: .disconnected), .connectThenStartStreaming)
        XCTAssertEqual(GlassesPrimaryAction.resolve(isStreaming: false, state: .connecting), .waitForConnection)
        XCTAssertFalse(GlassesConnectionState.error("failed").isConnected)
    }

    func testSimulationModeForcedWithoutDatSDK() async {
        let adapter = MetaGlassesAdapter()
        // Προσπάθεια απενεργοποίησης simulation σε build χωρίς SDK
        await adapter.toggleSimulationMode(enabled: false)
        let isSim = await adapter.isSimulationMode
        if !MetaGlassesAdapter.einaiDatSDKDiathesimo {
            // Χωρίς και τα δύο DAT modules, το adapter αρνείται να απενεργοποιήσει το simulation (R3-003)
            XCTAssertTrue(isSim)
        }
    }

    func testConfiguredBufferWindowIsAppliedWhenStreamingStarts() async throws {
        let buffer = RollingBufferService(mediaStorage: MediaStorageService())
        let adapter = MetaGlassesAdapter(
            bufferService: buffer,
            initialBufferTargetSeconds: 5.0
        )

        let configuredBeforeStart = await adapter.configuredBufferTargetSeconds
        XCTAssertEqual(configuredBeforeStart, 5.0)

        try await adapter.connectDevice()
        try await adapter.startStreaming()

        let activeTarget = await buffer.targetWindowSeconds
        XCTAssertEqual(activeTarget, 5.0)
        await adapter.stopStreaming()
    }

    func testUnsupportedBufferWindowFallsBackToTenSeconds() async {
        let adapter = MetaGlassesAdapter(initialBufferTargetSeconds: .infinity)
        let configured = await adapter.configuredBufferTargetSeconds
        XCTAssertEqual(configured, 10.0)

        await adapter.setBufferTargetSeconds(6.0)
        let normalized = await adapter.configuredBufferTargetSeconds
        XCTAssertEqual(normalized, 5.0)
    }

    func testLifecycleBackgroundPausesStreamingHonesty() async throws {
        let adapter = MetaGlassesAdapter()
        try await adapter.connectDevice()
        try await adapter.startStreaming()

        let isLiveBefore = await adapter.connectionState.isLive
        XCTAssertTrue(isLiveBefore)

        // Συμβάν είσοδος στο background
        let outcome = await adapter.handleAppLifecycle(.willEnterBackground)
        XCTAssertTrue(outcome.didPauseStream)

        let stateAfter = await adapter.connectionState
        XCTAssertTrue(stateAfter.isPaused)
        if case .paused(let reason) = stateAfter {
            XCTAssertEqual(reason, "background")
        } else {
            XCTFail("Αναμενόταν .paused(reason: 'background')")
        }
    }

    func testLifecycleLockScreenPausesStreaming() async throws {
        let adapter = MetaGlassesAdapter()
        try await adapter.connectDevice()
        try await adapter.startStreaming()

        // Συμβάν κλείδωμα οθόνης
        let outcome = await adapter.handleAppLifecycle(.willResignActiveForLock)
        XCTAssertTrue(outcome.didPauseStream)

        let stateAfter = await adapter.connectionState
        XCTAssertTrue(stateAfter.isPaused)
        if case .paused(let reason) = stateAfter {
            XCTAssertEqual(reason, "lock")
        } else {
            XCTFail("Αναμενόταν .paused(reason: 'lock')")
        }
    }

    func testMetaHardwareSafetyErrorTaxonomy() {
        XCTAssertEqual(AppErrorTaxonomy.metaGlassesDomain, "R0lling.Glasses.Meta")
        XCTAssertEqual(AppErrorTaxonomy.metaCameraPrivacyIndicatorObscured, 8201)
        XCTAssertEqual(AppErrorTaxonomy.metaThermalThrottleExceeded, 8202)
        XCTAssertEqual(AppErrorTaxonomy.metaBatteryDepleted, 8203)
        XCTAssertEqual(AppErrorTaxonomy.metaBackgroundCaptureRestricted, 8204)

        let sampleErr = AppErrorTaxonomy.makeError(
            domain: AppErrorTaxonomy.metaGlassesDomain,
            code: AppErrorTaxonomy.metaCameraPrivacyIndicatorObscured,
            message: "Η λυχνία LED της κάμερας είναι καλυμμένη. Η λήψη διεκόπη για λόγους απορρήτου."
        )
        XCTAssertTrue(AppErrorTaxonomy.isTypedAppError(sampleErr))
        XCTAssertTrue(AppErrorTaxonomy.minimaXristi(gia: sampleErr).contains("λυχνία LED"))
    }

    func testSensorFeedSinkWiring() async {
        let adapter = MetaGlassesAdapter()
        let sink = MockSensorSink()
        await adapter.setSensorFeedSink(sink)

        sink.receiveAcousticLevel(decibels: -12.5)
        XCTAssertEqual(sink.receivedAcousticLevel, -12.5)

        let sample = HeadGestureDetector.IMUSample(pitch: 0.1, roll: 0.0, yaw: 0.0, timestamp: 100.0)
        sink.receiveIMUSample(sample)
        XCTAssertEqual(sink.receivedIMUSample?.pitch, 0.1)
    }
}
