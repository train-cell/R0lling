import Foundation

/// Άμεσος connector για OpenAI-compatible cloud APIs (OpenAI, Gemini via proxy, Groq κ.λπ.)
public final class DirectAPIConnector: AIConnectorProtocol, @unchecked Sendable {
    public let providerType: AIProviderType = .directAPI
    private let baseURLString: String
    private let modelName: String
    private let apiKey: String

    public init(baseURLString: String, modelName: String, apiKey: String) {
        self.baseURLString = baseURLString
        self.modelName = modelName
        self.apiKey = apiKey
    }

    public func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult {
        // R3-012: άδειο API key → typed error πριν το network (όχι ασαφές 401).
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(
                domain: "R0lling.AI",
                code: 7004,
                userInfo: [NSLocalizedDescriptionKey: "Λείπει Direct API key. Αποθήκευσέ το στο Keychain από τις Ρυθμίσεις."]
            )
        }

        guard let endpointURL = URL(string: "\(baseURLString)/chat/completions") else {
            throw NSError(domain: "R0lling.AI", code: 7001, userInfo: [NSLocalizedDescriptionKey: "Μη έγκυρο Base URL για Direct AI."])
        }

        try Task.checkCancellation()

        var messages: [[String: Any]] = []

        // System Prompt
        var sysContent = payload.systemPrompt ?? "Είσαι ο προσωπικός βοηθός R0lling στο iPhone του χρήστη. Απαντάς στα Ελληνικά με σαφήνεια, ακρίβεια και φιλικό τόνο."
        if let memory = payload.agentMemoryContext, !memory.isEmpty {
            sysContent += "\n\nΜνήμη & Προτιμήσεις Χρήστη:\n\(memory)"
        }
        messages.append(["role": "system", "content": sysContent])

        // Εισαγωγή προηγούμενων σχετικών εγγραφών
        for entry in payload.contextEntries.prefix(5) {
            messages.append([
                "role": "user",
                "content": "[Καταγραφή \(entry.formattedTime)] \(entry.content)"
            ])
        }

        // Κύριο μήνυμα χρήστη (με ή χωρίς Vision)
        if let b64 = payload.imageBase64, !b64.isEmpty {
            let visionUserContent: [[String: Any]] = [
                ["type": "text", "text": payload.prompt],
                [
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(b64)"]
                ]
            ]
            messages.append(["role": "user", "content": visionUserContent])
        } else {
            messages.append(["role": "user", "content": payload.prompt])
        }

        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": messages,
            "temperature": 0.7
        ]

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        try Task.checkCancellation()
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // SEC-005: generic user-facing μήνυμα — όχι raw response body.
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(
                domain: "R0lling.AI",
                code: 7002,
                userInfo: [NSLocalizedDescriptionKey: "Direct AI API Σφάλμα (HTTP \(status))."]
            )
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let firstChoice = choices?.first?["message"] as? [String: Any]
        let replyText = firstChoice?["content"] as? String ?? "Δεν ελήφθη απάντηση από το AI."

        let usage = json?["usage"] as? [String: Any]
        let totalTokens = usage?["total_tokens"] as? Int

        let referencedIDs = payload.contextEntries.map { $0.id }
        return AIResponseResult(reply: replyText, tokensUsed: totalTokens, referencedEntryIDs: referencedIDs)
    }

    public func describeImage(imageData: Data, question: String?) async throws -> String {
        let b64 = imageData.base64EncodedString()
        let promptText = question ?? "Τι βλέπω σε αυτή την εικόνα από τα Meta Glasses μου; Περιέγραψέ το συνοπτικά στα Ελληνικά."
        let payload = AIRequestPayload(prompt: promptText, imageBase64: b64)
        let result = try await generateReply(payload: payload)
        return result.reply
    }

    public func summarizeDay(entries: [JournalEntry]) async throws -> String {
        guard !entries.isEmpty else {
            return "Δεν υπάρχουν καταγραφές για τη σημερινή ημέρα."
        }
        let promptText = "Κάνε μια όμορφη, περιεκτική σύνοψη των παραπάνω καταγραφών της ημέρας, τονίζοντας τα σημαντικότερα γεγονότα."
        let payload = AIRequestPayload(prompt: promptText, contextEntries: entries)
        let result = try await generateReply(payload: payload)
        return result.reply
    }
}
