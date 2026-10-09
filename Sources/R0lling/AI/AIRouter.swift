import Foundation
import ImageIO

/// Κεντρικός δρομολογητής AI (AIRouter) που διαχειρίζεται τα ερωτήματα και τη μνήμη.
public actor AIRouter {
    private var settings: AISettings
    private var directConnector: DirectAPIConnector?
    private var hermesConnector: HermesConnector?

    public init(settings: AISettings) {
        self.settings = settings
        updateConnectors()
    }

    /// Loads persisted non-secret settings; credentials remain in Keychain.
    public static func loadSettings() -> AISettings {
        guard let data = UserDefaults.standard.data(forKey: "r0lling.ai.settings"),
              let value = try? JSONDecoder().decode(AISettings.self, from: data) else { return AISettings() }
        return value
    }

    public func currentSettings() -> AISettings { settings }

    public func updateSettings(_ newSettings: AISettings) {
        if let data = try? JSONEncoder().encode(newSettings) {
            UserDefaults.standard.set(data, forKey: "r0lling.ai.settings")
        }
        self.settings = newSettings
        updateConnectors()
    }

    private func updateConnectors() {
        let directKey = retrieveSecret(forKey: settings.directAPIKeyKeychainKey) ?? ""
        self.directConnector = DirectAPIConnector(
            baseURLString: settings.directAPIBaseURL,
            modelName: settings.directAPIModel,
            apiKey: directKey
        )

        let hermesToken = retrieveSecret(forKey: settings.hermesTokenKeychainKey) ?? ""
        self.hermesConnector = HermesConnector(
            baseURLString: settings.hermesBaseURL,
            authToken: hermesToken
        )
    }

    private func activeConnector() throws -> any AIConnectorProtocol {
        switch settings.activeProvider {
        case .directAPI:
            guard let connector = directConnector else {
                throw AIErrorTaxonomy.makeError(
                    domain: AIErrorTaxonomy.directDomain,
                    code: AIErrorTaxonomy.routerDirectMissing,
                    message: "Ο Direct AI Connector δεν είναι αρχικοποιημένος."
                )
            }
            return connector
        case .hermes:
            guard let connector = hermesConnector else {
                throw AIErrorTaxonomy.makeError(
                    domain: AIErrorTaxonomy.directDomain,
                    code: AIErrorTaxonomy.routerHermesMissing,
                    message: "Ο Hermes Connector δεν είναι αρχικοποιημένος."
                )
            }
            return connector
        }
    }

    public func askAssistant(
        prompt: String,
        contextEntries: [JournalEntry],
        agentMemory: AgentMemory?
    ) async throws -> AIResponseResult {
        try Task.checkCancellation()
        let connector = try activeConnector()
        let memoryText = settings.includeAgentMemoryInChat ? Self.formatAgentMemory(agentMemory) : nil
        let limit = max(0, min(settings.maxContextEntries, OpenAIChatRequestBuilder.maxContextEntries))
        let context = settings.includeJournalInChat
            ? OpenAIChatRequestBuilder.selectedContextEntries(from: contextEntries, limit: limit)
            : []
        let payload = AIRequestPayload(
            prompt: prompt,
            contextEntries: contextForAI(context),
            agentMemoryContext: memoryText
        )
        return try await connector.generateReply(payload: payload)
    }

    public func askWhatAmISeeing(imageData: Data, customQuestion: String?) async throws -> String {
        try Task.checkCancellation()
        let connector = try activeConnector()
        return try await connector.describeImage(imageData: Self.jpegForAI(imageData), question: customQuestion)
    }

    /// Πολυ-καδρική σύνθεση (A11) — connector δέχεται `imageBase64Frames`.
    /// `FeatureReadinessRegistry.multiFrameVision.ready == false` μέχρι AppState να τραβάει πραγματικά buffer keyframes.
    public func askWhatAmISeeingMultiFrames(frames: [Data], customQuestion: String?) async throws -> String {
        try Task.checkCancellation()
        guard !frames.isEmpty else {
            throw AIErrorTaxonomy.makeError(
                domain: AIErrorTaxonomy.directDomain,
                code: AIErrorTaxonomy.routerNoVisionFrames,
                message: "Δεν δόθηκαν καρέ για πολυ-καδρική ανάλυση."
            )
        }
        let connector = try activeConnector()
        let limited = Array(frames.prefix(OpenAIChatRequestBuilder.maxVisionFrames))
        let b64Frames = try limited.map { try Self.jpegForAI($0).base64EncodedString() }
        let prompt = (customQuestion ?? "Περιέγραψε τι συμβαίνει σε αυτή τη χρονική σειρά καρέ από τα Meta Glasses μου.")
            + " (Ανάλυση \(limited.count) διαδοχικών στιγμιοτύπων)."
        let payload = AIRequestPayload(
            prompt: prompt,
            imageBase64: b64Frames.first,
            imageBase64Frames: b64Frames
        )
        let result = try await connector.generateReply(payload: payload)
        return result.reply
    }

    public func summarizeDay(entries: [JournalEntry]) async throws -> String {
        try Task.checkCancellation()
        let connector = try activeConnector()
        return try await connector.summarizeDay(entries: contextForAI(entries))
    }

    /// Ανάκληση αναμνήσεων (A12) — local keyword recall + AI σύνθεση.
    public func recallMemories(query: String, allEntries: [JournalEntry]) async throws -> (reply: String, matchingEntries: [JournalEntry]) {
        try Task.checkCancellation()
        let cleanQuery = query.lowercased()
        let keywords = cleanQuery.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 }

        let scored = allEntries.map { entry -> (entry: JournalEntry, score: Int) in
            var score = 0
            let lowerContent = entry.content.lowercased()
            for kw in keywords {
                if lowerContent.contains(kw) { score += 2 }
                if entry.tags.contains(where: { $0.lowercased().contains(kw) }) { score += 3 }
            }
            return (entry, score)
        }

        let relevantEntries = scored.filter { $0.score > 0 }.sorted { $0.score > $1.score }.map { $0.entry }

        if relevantEntries.isEmpty {
            return (
                reply: "Δεν βρήκα καταχωρήσεις στο ημερολόγιό σου σχετικές με: «\(query)».",
                matchingEntries: []
            )
        }

        let connector = try activeConnector()
        let promptText = "Ο χρήστης ρωτάει: «\(query)». Με βάση τις παρακάτω καταχωρήσεις, απάντησε συγκεκριμένα και ανάφερε τις ακριβείς ημερομηνίες ή πρόσωπα."
        let payload = AIRequestPayload(prompt: promptText, contextEntries: contextForAI(Array(relevantEntries.prefix(5))))
        let result = try await connector.generateReply(payload: payload)

        return (reply: result.reply, matchingEntries: relevantEntries)
    }

    /// R3-004: Keychain (όχι plaintext UserDefaults). Fallback μόνο με ρητό env flag σε tests.
    private func retrieveSecret(forKey key: String) -> String? {
        return KeychainSecretStore.retrieve(forKey: key)
    }

    public func storeSecret(value: String, forKey key: String) throws {
        try KeychainSecretStore.store(value: value, forKey: key)
        updateConnectors()
    }

    public func deleteSecret(forKey key: String) throws {
        try KeychainSecretStore.deleteChecked(forKey: key)
        updateConnectors()
    }

    public func hasSecret(forKey key: String) -> Bool {
        guard let value = retrieveSecret(forKey: key) else { return false }
        return !value.isEmpty
    }

    /// Επικυρώνει Hermes URL πριν αποθήκευση ρυθμίσεων (fail-closed UI).
    public func validateHermesURL(_ raw: String) throws {
        _ = try HermesEndpointAsfaleia.epikyroseHermesBaseURL(raw)
    }

    /// Επικυρώνει Direct HTTPS URL πριν αποθήκευση ρυθμίσεων.
    public func validateDirectURL(_ raw: String) throws {
        _ = try HermesEndpointAsfaleia.epikyroseDirectBaseURL(raw)
    }

    public func validateEndpointForSaving(
        provider: AIProviderType,
        directBaseURL: String,
        hermesBaseURL: String
    ) throws {
        switch provider {
        case .directAPI:
            try validateDirectURL(directBaseURL)
        case .hermes:
            try validateHermesURL(hermesBaseURL)
        }
    }

    /// Normalizes the wire MIME type and strips source image metadata.
    private static func jpegForAI(_ data: Data) throws -> Data {
        try ImageMetadataSanitizer.encodeForVision(data)
    }

    /// Applies the same location setting to explicit summary and recall requests.
    private func contextForAI(_ entries: [JournalEntry]) -> [JournalEntry] {
        Self.sanitizedContextEntries(entries, includeLocation: settings.includeLocationInContext)
    }

    internal static func sanitizedContextEntries(
        _ entries: [JournalEntry],
        includeLocation: Bool
    ) -> [JournalEntry] {
        entries.map { entry in
            var sanitized = entry
            if !includeLocation { sanitized.locationName = nil }
            return sanitized
        }
    }

    // MARK: - Agent memory honesty (CQ-P0-001)

    /// Μορφοποιεί πραγματική Agent memory· αγνοεί άδεια markdown headings (χωρίς fake persona).
    internal static func formatAgentMemory(_ memory: AgentMemory?) -> String? {
        guard let memory else { return nil }
        let parts = [memory.memoryNotes, memory.userPreferences, memory.openLoops]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isEmptyMarkdownTemplate($0) }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n\n")
    }

    private static func isEmptyMarkdownTemplate(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return true }
        // Μόνο headings (# ...) χωρίς περιεχόμενο → δεν στέλνουμε στο LLM.
        return lines.allSatisfy { $0.hasPrefix("#") }
    }
}
