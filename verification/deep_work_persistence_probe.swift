import Foundation

@main
enum DeepWorkPersistenceProbe {
    static func main() async {
        let key = "r0lling.probe.deepWork.\(UUID().uuidString)"
        let defaults = UserDefaults.standard
        defer { defaults.removeObject(forKey: key) }

        let unreadable = Data([0xFF, 0x00, 0x7F])
        defaults.set(unreadable, forKey: key)
        let manager = DeepWorkSessionManager(storageKey: key)
        let initialRecoveryState = await manager.requiresPersistenceRecovery
        precondition(initialRecoveryState)

        await manager.startSession(goal: "Must not overwrite", durationMinutes: 1)
        precondition(defaults.data(forKey: key) == unreadable)
        let stateBeforeReset = await manager.getState()
        precondition(stateBeforeReset == .idle)

        let didReset = await manager.discardCorruptPersistenceAndReset()
        precondition(didReset)
        precondition(defaults.object(forKey: key) == nil)
        let recoveryStateAfterReset = await manager.requiresPersistenceRecovery
        precondition(!recoveryStateAfterReset)

        await manager.startSession(goal: "Recovered", durationMinutes: 1)
        guard let saved = defaults.data(forKey: key) else {
            fatalError("Recovered session was not persisted")
        }
        precondition((try? JSONDecoder().decode(ProbePersistedState.self, from: saved)) != nil)
        print("PASS: corrupt Deep Work bytes remain untouched until explicit reset")
    }

    private struct ProbePersistedState: Decodable {
        let sessionState: DeepWorkSessionManager.SessionState
    }
}
