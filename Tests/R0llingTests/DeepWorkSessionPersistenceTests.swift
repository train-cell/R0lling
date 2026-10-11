import XCTest
@testable import R0lling

final class DeepWorkSessionPersistenceTests: XCTestCase {
    func testCorruptPersistenceBlocksWritesUntilExplicitReset() async {
        let storageKey = "r0lling.deepwork.persistence.tests.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: storageKey) }
        let corruptBytes = Data("{invalid-json".utf8)
        UserDefaults.standard.set(corruptBytes, forKey: storageKey)
        let manager = DeepWorkSessionManager(storageKey: storageKey)

        let requiresRecovery = await manager.requiresPersistenceRecovery
        XCTAssertTrue(requiresRecovery)
        let initialState = await manager.getState()
        XCTAssertEqual(initialState, .idle)

        await manager.startSession(
            goal: "Must not overwrite corrupt history",
            durationMinutes: 5,
            startedAt: Date()
        )
        let completion = await manager.completeSession()
        XCTAssertEqual(completion, 0)
        XCTAssertEqual(UserDefaults.standard.data(forKey: storageKey), corruptBytes)

        let didReset = await manager.discardCorruptPersistenceAndReset()
        XCTAssertTrue(didReset)
        XCTAssertNil(UserDefaults.standard.object(forKey: storageKey))
        let stillRequiresRecovery = await manager.requiresPersistenceRecovery
        XCTAssertFalse(stillRequiresRecovery)

        await manager.startSession(goal: "Recovered", durationMinutes: 5)
        let recoveredState = await manager.getState()
        guard case .active(_, _, let goal) = recoveredState else {
            return XCTFail("A new session should be writable after explicit reset")
        }
        XCTAssertEqual(goal, "Recovered")
        XCTAssertNotEqual(UserDefaults.standard.data(forKey: storageKey), corruptBytes)
    }

    func testNonDataValueAtSessionKeyAlsoBlocksOverwrite() async {
        let storageKey = "r0lling.deepwork.persistence.tests.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: storageKey) }
        UserDefaults.standard.set("unexpected persisted value", forKey: storageKey)
        let manager = DeepWorkSessionManager(storageKey: storageKey)

        let requiresRecovery = await manager.requiresPersistenceRecovery
        XCTAssertTrue(requiresRecovery)
        await manager.startSession(goal: "Must remain blocked", durationMinutes: 5)
        XCTAssertEqual(UserDefaults.standard.string(forKey: storageKey), "unexpected persisted value")
    }
}
