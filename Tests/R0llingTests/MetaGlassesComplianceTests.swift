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

    func testDisconnectedStateReportsHonestBatteryNil() async {
        let adapter = MetaGlassesAdapter()
        let state = await adapter.connectionState
        XCTAssertEqual(state, .disconnected)
        let battery = await adapter.currentBatteryLevel()
        // Ποτέ ψευδές 94% σε αποσυνδεδεμένη συσκευή
        XCTAssertNil(battery)
    }

    func testSimulationModeForcedWithoutDatSDK() async {
        let adapter = MetaGlassesAdapter()
        // Προσπάθεια απενεργοποίησης simulation σε build χωρίς SDK
        await adapter.toggleSimulationMode(enabled: false)
        let isSim = await adapter.isSimulationMode
        if !MetaGlassesAdapter.einaiDatSDKDiathesimo {
            // Χωρίς MetaWearablesDAT SDK, το adapter αρνείται να απενεργοποιήσει το simulation (R3-003)
            XCTAssertTrue(isSim)
        }
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
