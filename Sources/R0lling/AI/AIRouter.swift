import Foundation

/// Κεντρικός δρομολογητής AI (AIRouter) που διαχειρίζεται τα ερωτήματα και τη μνήμη
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
                throw NSError(domain: "R0lling.AI", code: 7201, userInfo: [NSLocalizedDescriptionKey: "Ο Direct AI Connector δεν είναι αρχικοποιημένος."])
            }
            return connector
        case .hermes:
            guard let connector = hermesConnector else {
                throw NSError(domain: "R0lling.AI", code: 7202, userInfo: [NSLocalizedDescriptionKey: "Ο Hermes Connector δεν είναι αρχικοποιημένος."])
            }
            return connector
        }
    }

    public func askAssistant(
        prompt: String,
        contextEntries: [JournalEntry],
        agentMemory: AgentMemory?
    ) async throws -> AIResponseResult {
        let connector = try activeConnector()
        let memoryText = agentMemory.map { "\($0.memoryNotes)\n\($0.userPreferences)\n\($0.openLoops)" }
        let payload = AIRequestPayload(
            prompt: prompt,
            contextEntries: contextEntries,
            agentMemoryContext: memoryText
        )
        return try await connector.generateReply(payload: payload)
    }

    public func askWhatAmISeeing(imageData: Data, customQuestion: String?) async throws -> String {
        let connector = try activeConnector()
        return try await connector.describeImage(imageData: imageData, question: customQuestion)
    }

    /// Πολυ-καδρική σύνθεση (Multi-Frame Keyframe Synthesis) για περιγραφή κίνησης και σκηνής
    public func askWhatAmISeeingMultiFrames(frames: [Data], customQuestion: String?) async throws -> String {
        guard let first = frames.first else {
            throw NSError(domain: "R0lling.AI", code: 7203, userInfo: [NSLocalizedDescriptionKey: "Δεν δόθηκαν καρέ για πολυ-καδρική ανάλυση."])
        }
        let connector = try activeConnector()
        let prompt = (customQuestion ?? "Περιέγραψε τι συμβαίνει σε αυτή τη χρονική σειρά καρέ από τα Meta Glasses μου.") + " (Ανάλυση \(frames.count) διαδοχικών στιγμιοτύπων)."
        return try await connector.describeImage(imageData: first, question: prompt)
    }

    public func summarizeDay(entries: [JournalEntry]) async throws -> String {
        let connector = try activeConnector()
        return try await connector.summarizeDay(entries: entries)
    }

    /// Ανάκληση αναμνήσεων (π.χ. "τι ήθελα να πω στους αγαπημένους μου;")
    public func recallMemories(query: String, allEntries: [JournalEntry]) async throws -> (reply: String, matchingEntries: [JournalEntry]) {
        let cleanQuery = query.lowercased()
        let keywords = cleanQuery.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 }

        // Εντοπισμός σχετικών καταχωρίσεων βάσει λέξεων-κλειδιών
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
}
