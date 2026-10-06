import XCTest
@testable import R0lling

/// A14 fail-closed verdict + streak honesty (χωρίς live AI).
final class ObservationGameEngineTests: XCTestCase {

    func testFailClosedVerdictYesNoAmbiguous() {
        XCTAssertEqual(ObservationGameEngine.parseFailClosedVerdict("ΝΑΙ\nΒλέπω κόκκινο φλιτζάνι."), .yes)
        XCTAssertEqual(ObservationGameEngine.parseFailClosedVerdict("YES\nI see a red cup."), .yes)
        XCTAssertEqual(ObservationGameEngine.parseFailClosedVerdict("ΟΧΙ\nΔεν υπάρχει."), .no)
        XCTAssertEqual(ObservationGameEngine.parseFailClosedVerdict("NO\nNothing red."), .no)
        // Fail-closed: ασαφές / contains YES βαθύτερα → ambiguous
        XCTAssertEqual(ObservationGameEngine.parseFailClosedVerdict("Ίσως να είναι κόκκινο YES κάπου"), .ambiguous)
        XCTAssertEqual(ObservationGameEngine.parseFailClosedVerdict(""), .ambiguous)
        XCTAssertEqual(ObservationGameEngine.parseFailClosedVerdict("Πιθανόν"), .ambiguous)
    }

    func testManualConfirmIsNotAISource() async {
        let engine = ObservationGameEngine(aiRouter: AIRouter(settings: AISettings()))
        _ = await engine.startNewMission()
        let result = await engine.confirmManually()
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.source, .manual)
        XCTAssertEqual(result.awardedPoints, ObservationGameEngine.pontosXeirokinitis)
        XCTAssertFalse(result.feedback.lowercased().contains("ai αξιολόγηση"))
    }

    func testEmptyImageFailsClosedNoPoints() async {
        let engine = ObservationGameEngine(aiRouter: AIRouter(settings: AISettings()))
        _ = await engine.startNewMission()
        let before = await engine.getScore()
        let result = await engine.evaluateCapturedPhoto(imageData: Data())
        let after = await engine.getScore()
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.awardedPoints, 0)
        XCTAssertEqual(result.source, .unavailable)
        XCTAssertEqual(before, after)
    }

    func testStreakOnlyIncrementsOncePerDay() {
        let key = "r0lling.scavenger_streak_data_test_\(UUID().uuidString)"
        // Χρησιμοποιούμε τον production manager· καθαρίζουμε μέσω νέου instance σε isolated defaults είναι δύσκολο —
        // ελέγχουμε idempotent same-day.
        let manager = ScavengerHuntStreakManager()
        let tz = TimeZone(identifier: "Europe/Athens")!
        let day = Date(timeIntervalSince1970: 1_728_000_000) // σταθερή ημερομηνία
        let first = manager.recordMissionCompleted(date: day, timeZone: tz)
        let second = manager.recordMissionCompleted(date: day, timeZone: tz)
        XCTAssertEqual(first.newStreak, second.newStreak)
        XCTAssertNil(second.newlyUnlockedBadge)
        _ = key // silence unused σε environments χωρίς suite
    }

    func testSessionLifecycleStartActive() async {
        let engine = ObservationGameEngine(aiRouter: AIRouter(settings: AISettings()))
        let state1 = await engine.getSessionState()
        XCTAssertEqual(state1, .idle)
        _ = await engine.startNewMission()
        let state2 = await engine.getSessionState()
        XCTAssertEqual(state2, .active)
        let mission = await engine.getCurrentMission()
        XCTAssertNotNil(mission)
    }
}
