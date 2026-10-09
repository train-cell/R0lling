import XCTest
@testable import R0lling

/// A14 fail-closed verdict + streak honesty (χωρίς live AI).
final class ObservationGameEngineTests: XCTestCase {

    private actor DelayedYesEvaluator: ObservationVisionEvaluating {
        func evaluateObservation(imageData: Data, question: String) async throws -> String {
            try await Task.sleep(nanoseconds: 100_000_000)
            return "ΝΑΙ\nΒλέπω το αντικείμενο."
        }
    }

    private func makeIsolatedEngine(
        evaluator: any ObservationVisionEvaluating
    ) throws -> (ObservationGameEngine, UserDefaults, String) {
        let suiteName = "r0lling.tests.observation.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let key = "score"
        return (ObservationGameEngine(visionEvaluator: evaluator, userDefaults: defaults, scoreStorageKey: key), defaults, suiteName)
    }

    private func waitForEvaluation(_ engine: ObservationGameEngine) async {
        for _ in 0..<10_000 {
            if await engine.getSessionState() == .evaluating { return }
            await Task.yield()
        }
        XCTFail("AI evaluation did not enter the evaluating state")
    }

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

    func testStreakOnlyIncrementsOncePerDay() throws {
        let suiteName = "r0lling.tests.streak.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storageKey = "streak"
        let manager = ScavengerHuntStreakManager(userDefaults: defaults, storageKey: storageKey)
        let tz = TimeZone(identifier: "Europe/Athens")!
        let day = Date(timeIntervalSince1970: 1_728_000_000) // σταθερή ημερομηνία
        let first = manager.recordMissionCompleted(date: day, timeZone: tz)
        let second = manager.recordMissionCompleted(date: day, timeZone: tz)
        XCTAssertEqual(first.newStreak, 1)
        XCTAssertEqual(first.newStreak, second.newStreak)
        XCTAssertTrue(first.didPersist)
        XCTAssertNil(second.newlyUnlockedBadge)
    }

    func testCorruptStreakStateIsPreservedAndReported() throws {
        let suiteName = "r0lling.tests.streak.corrupt.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storageKey = "streak"
        let corruptData = Data("not valid streak JSON".utf8)
        defaults.set(corruptData, forKey: storageKey)

        let manager = ScavengerHuntStreakManager(userDefaults: defaults, storageKey: storageKey)
        let result = manager.recordMissionCompleted(date: Date(timeIntervalSince1970: 1_728_000_000))

        XCTAssertEqual(result.newStreak, 0)
        XCTAssertFalse(result.didPersist)
        XCTAssertEqual(defaults.data(forKey: storageKey), corruptData)
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

    func testConcurrentPhotoEvaluationAndManualConfirmCannotDoubleAward() async throws {
        let (engine, defaults, suiteName) = try makeIsolatedEngine(evaluator: DelayedYesEvaluator())
        defer { defaults.removePersistentDomain(forName: suiteName) }
        _ = await engine.startNewMission()
        let initialScore = await engine.getScore()

        let firstEvaluation = Task { await engine.evaluateCapturedPhoto(imageData: Data([1])) }
        await waitForEvaluation(engine)
        let duplicateEvaluation = await engine.evaluateCapturedPhoto(imageData: Data([2]))
        let manualConfirmation = await engine.confirmManually()
        let acceptedEvaluation = await firstEvaluation.value

        XCTAssertEqual(duplicateEvaluation.awardedPoints, 0)
        XCTAssertEqual(manualConfirmation.awardedPoints, 0)
        XCTAssertEqual(acceptedEvaluation.awardedPoints, ObservationGameEngine.pontosAIEpityxias)
        let finalScore = await engine.getScore()
        XCTAssertEqual(finalScore, initialScore + ObservationGameEngine.pontosAIEpityxias)
    }

    func testOldEvaluationCannotOverwriteMissionStartedWhileAwaitingAI() async throws {
        let (engine, defaults, suiteName) = try makeIsolatedEngine(evaluator: DelayedYesEvaluator())
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let originalMission = await engine.startNewMission()
        let initialScore = await engine.getScore()

        let evaluation = Task { await engine.evaluateCapturedPhoto(imageData: Data([1])) }
        await waitForEvaluation(engine)
        let replacementMission = await engine.startNewMission()
        let staleResult = await evaluation.value

        XCTAssertNotEqual(originalMission.id, replacementMission.id)
        let currentMission = await engine.getCurrentMission()
        let finalScore = await engine.getScore()
        let finalState = await engine.getSessionState()
        XCTAssertEqual(currentMission?.id, replacementMission.id)
        XCTAssertEqual(staleResult.awardedPoints, 0)
        XCTAssertEqual(finalScore, initialScore)
        XCTAssertEqual(finalState, .active)
    }
}
