import Foundation

/// Κεντρικός δρομολογητής AI (AIRouter) που διαχειρίζεται τα ερωτήματα και τη μνήμη.
public actor AIRouter {
    private var settings: AISettings
    private var directConnector: DirectAPIConnector?
    private var hermesConnector: HermesConnector?

    public init(settings: AISettings) {
        self.settings = settings
        updateConnectors()
    }

    public func updateSettings(_ newSettings: AISettings) {
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
        let memoryText = Self.formatAgentMemory(agentMemory)
        let payload = AIRequestPayload(
            prompt: prompt,
            contextEntries: contextEntries,
            agentMemoryContext: memoryText
        )
        return try await connector.generateReply(payload: payload)
    }

    public func askWhatAmISeeing(imageData: Data, customQuestion: String?) async throws -> String {
        try Task.checkCancellation()
        let connector = try activeConnector()
        return try await connector.describeImage(imageData: imageData, question: customQuestion)
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
        let b64Frames = limited.map { $0.base64EncodedString() }
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
        return try await connector.summarizeDay(entries: entries)
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
        let payload = AIRequestPayload(prompt: promptText, contextEntries: Array(relevantEntries.prefix(5)))
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

    /// Επικυρώνει Hermes URL πριν αποθήκευση ρυθμίσεων (fail-closed UI).
    public func validateHermesURL(_ raw: String) throws {
        _ = try HermesEndpointAsfaleia.epikyroseHermesBaseURL(raw)
    }

    /// Επικυρώνει Direct HTTPS URL πριν αποθήκευση ρυθμίσεων.
    public func validateDirectURL(_ raw: String) throws {
        _ = try HermesEndpointAsfaleia.epikyroseDirectBaseURL(raw)
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
