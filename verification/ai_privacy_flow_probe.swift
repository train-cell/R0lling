import Foundation

// Narrow transport/framework shims keep this probe focused on the production
// AIRouter's context and location gates. No provider request is made.
final class DirectAPIConnector: AIConnectorProtocol, @unchecked Sendable {
    let providerType: AIProviderType = .directAPI
    init(baseURLString: String, modelName: String, apiKey: String) {}
    func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult { AIResponseResult(reply: "stub") }
    func describeImage(imageData: Data, question: String?) async throws -> String { "" }
    func summarizeDay(entries: [JournalEntry]) async throws -> String { "" }
}

final class HermesConnector: AIConnectorProtocol, @unchecked Sendable {
    let providerType: AIProviderType = .hermes
    init(baseURLString: String, authToken: String) {}
    func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult { AIResponseResult(reply: "stub") }
    func describeImage(imageData: Data, question: String?) async throws -> String { "" }
    func summarizeDay(entries: [JournalEntry]) async throws -> String { "" }
}

enum KeychainSecretStore {
    static func retrieve(forKey key: String) -> String? { nil }
    static func store(value: String, forKey key: String) throws {}
    static func deleteChecked(forKey key: String) throws {}
}

enum ImageMetadataSanitizer {
    static func encodeForVision(_ data: Data) throws -> Data { data }
}

actor CapturingConnector: AIConnectorProtocol {
    nonisolated let providerType: AIProviderType = .directAPI
    private var lastPayload: AIRequestPayload?

    func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult {
        lastPayload = payload
        return AIResponseResult(reply: "stub")
    }

    func describeImage(imageData: Data, question: String?) async throws -> String { "" }
    func summarizeDay(entries: [JournalEntry]) async throws -> String { "" }
    func capturedPayload() -> AIRequestPayload? { lastPayload }
}

@main
struct AIPrivacyFlowProbe {
    static func main() async throws {
        let defaults = UserDefaults.standard
        let settingsKey = "r0lling.ai.settings"
        defaults.removeObject(forKey: settingsKey)
        let unsafeSettingsRouter = AIRouter(settings: AISettings(
            directAPIBaseURL: "https://user:secret@proxy.example/v1"
        ))
        await unsafeSettingsRouter.updateSettings(AISettings(
            directAPIBaseURL: "https://user:secret@proxy.example/v1?tenant=private"
        ))
        precondition(defaults.data(forKey: settingsKey) == nil, "Credential-bearing active endpoint settings must not be persisted")

        let legacyUnsafeSettings = AISettings(directAPIBaseURL: "https://legacy:secret@proxy.example/v1")
        defaults.set(try JSONEncoder().encode(legacyUnsafeSettings), forKey: settingsKey)
        precondition(AIRouter.loadSettings() == AISettings(), "Legacy credential-bearing settings must be discarded on load")
        precondition(defaults.data(forKey: settingsKey) == nil, "Unsafe legacy settings must be purged from defaults")

        let safeHermesSettings = AISettings(
            activeProvider: .hermes,
            directAPIBaseURL: "https://user:secret@proxy.example/v1",
            hermesBaseURL: "https://hermes.example/v1"
        )
        let safeHermesRouter = AIRouter(settings: safeHermesSettings)
        await safeHermesRouter.updateSettings(safeHermesSettings)
        guard let storedSettings = defaults.data(forKey: settingsKey),
              let persistedHermesSettings = try? JSONDecoder().decode(AISettings.self, from: storedSettings) else {
            fatalError("Safe active endpoint settings were not persisted")
        }
        precondition(persistedHermesSettings.directAPIBaseURL == AISettings().directAPIBaseURL, "Inactive credential-bearing endpoint must be sanitized before persistence")
        defaults.removeObject(forKey: settingsKey)

        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let entries = (0..<3).map { index in
            JournalEntry(
                timestamp: base.addingTimeInterval(TimeInterval(index * 60)),
                content: "entry-\(index)",
                locationName: "location-\(index)"
            )
        }
        let memory = AgentMemory(
            memoryNotes: "private-notes",
            userPreferences: "private-preferences",
            openLoops: "private-open-loops"
        )

        let defaultsConnector = CapturingConnector()
        let defaultsRouter = AIRouter(
            settings: AISettings(),
            connectorOverrideForTesting: defaultsConnector
        )
        _ = try await defaultsRouter.askAssistant(
            prompt: "question",
            contextEntries: entries,
            agentMemory: memory
        )
        guard let defaultsPayload = await defaultsConnector.capturedPayload() else {
            fatalError("The default-chat request was not captured")
        }
        precondition(defaultsPayload.contextEntries.isEmpty, "Journal context must be OFF by default")
        precondition(defaultsPayload.agentMemoryContext == nil, "Agent memory must be OFF by default")

        let optedInConnector = CapturingConnector()
        let optedInSettings = AISettings(
            includeJournalInChat: true,
            includeAgentMemoryInChat: false,
            includeLocationInContext: false,
            maxContextEntries: 2
        )
        let optedInRouter = AIRouter(
            settings: optedInSettings,
            connectorOverrideForTesting: optedInConnector
        )
        _ = try await optedInRouter.askAssistant(
            prompt: "question",
            contextEntries: entries,
            agentMemory: memory
        )
        guard let optedInPayload = await optedInConnector.capturedPayload() else {
            fatalError("The opted-in request was not captured")
        }
        precondition(optedInPayload.contextEntries.map(\.content) == ["entry-1", "entry-2"])
        precondition(optedInPayload.contextEntries.allSatisfy { $0.locationName == nil })
        precondition(optedInPayload.agentMemoryContext == nil)

        let locationConnector = CapturingConnector()
        let locationSettings = AISettings(
            includeJournalInChat: true,
            includeAgentMemoryInChat: true,
            includeLocationInContext: true,
            maxContextEntries: 1
        )
        let locationRouter = AIRouter(
            settings: locationSettings,
            connectorOverrideForTesting: locationConnector
        )
        _ = try await locationRouter.askAssistant(
            prompt: "question",
            contextEntries: entries,
            agentMemory: memory
        )
        guard let locationPayload = await locationConnector.capturedPayload() else {
            fatalError("The fully opted-in request was not captured")
        }
        precondition(locationPayload.contextEntries.map(\.content) == ["entry-2"])
        precondition(locationPayload.contextEntries.first?.locationName == "location-2")
        precondition(locationPayload.agentMemoryContext?.contains("private-notes") == true)
        precondition(locationPayload.agentMemoryContext?.contains("private-preferences") == true)
        precondition(locationPayload.agentMemoryContext?.contains("private-open-loops") == true)

        print("PASS: journal/memory default OFF; newest-two context obeys count/location opt-ins; location and memory appear only when explicitly enabled")
    }
}
