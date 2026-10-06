import Foundation

/// Connector για τον προσωπικό Hermes Agent στο Home PC (μέσω Τοπικού Δικτύου ή VPN)
public final class HermesConnector: AIConnectorProtocol, @unchecked Sendable {
    public let providerType: AIProviderType = .hermes
    private let baseURLString: String
    private let authToken: String

    public init(baseURLString: String, authToken: String) {
        self.baseURLString = baseURLString
        self.authToken = authToken
    }

    public func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult {
        // R3-012: άδειο Hermes token → typed error πριν το network.
        let trimmedToken = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw NSError(
                domain: "R0lling.Hermes",
                code: 7104,
                userInfo: [NSLocalizedDescriptionKey: "Λείπει Hermes auth token. Αποθήκευσέ το στο Keychain από τις Ρυθμίσεις."]
            )
        }

        guard let endpointURL = URL(string: "\(baseURLString)/chat/completions") else {
            throw NSError(domain: "R0lling.Hermes", code: 7101, userInfo: [NSLocalizedDescriptionKey: "Μη έγκυρη διεύθυνση URL για τον Hermes Agent στο Home PC."])
        }

        try Task.checkCancellation()

        var messages: [[String: Any]] = []

        var sysContent = payload.systemPrompt ?? "Είσαι ο Hermes, ο προσωπικός AI Jarvis βοηθός του R0lling που εκτελείται στο Home PC. Απαντάς στα Ελληνικά με εξαιρετική ακρίβεια."
        if let memory = payload.agentMemoryContext, !memory.isEmpty {
            sysContent += "\n\nΜνήμη & Σημειώσεις Agent:\n\(memory)"
        }
        messages.append(["role": "system", "content": sysContent])

        for entry in payload.contextEntries.prefix(5) {
            messages.append([
                "role": "user",
                "content": "[Εγγραφή \(entry.formattedTime)] \(entry.content)"
            ])
        }

        if let b64 = payload.imageBase64, !b64.isEmpty {
            let visionContent: [[String: Any]] = [
                ["type": "text", "text": payload.prompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
            ]
            messages.append(["role": "user", "content": visionContent])
        } else {
            messages.append(["role": "user", "content": payload.prompt])
        }

        let requestBody: [String: Any] = [
            "model": "hermes-agent",
            "messages": messages,
            "temperature": 0.6
        ]

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20.0
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            try Task.checkCancellation()
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let errorText = String(data: data, encoding: .utf8) ?? "HTTP σφάλμα επικοινωνίας"
                throw NSError(domain: "R0lling.Hermes", code: 7102, userInfo: [NSLocalizedDescriptionKey: "Ο Hermes Agent απέρριψε την κλήση: \(errorText)"])
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let choices = json?["choices"] as? [[String: Any]]
            let firstChoice = choices?.first?["message"] as? [String: Any]
            let replyText = firstChoice?["content"] as? String ?? "Δεν ελήφθη απάντηση από τον Hermes."

            let usage = json?["usage"] as? [String: Any]
            let totalTokens = usage?["total_tokens"] as? Int

            return AIResponseResult(reply: replyText, tokensUsed: totalTokens, referencedEntryIDs: payload.contextEntries.map { $0.id })
        } catch let hermesError as NSError where hermesError.domain == "R0lling.Hermes" {
            // CQ-P0-003: μην καλύπτεις typed 7102/cancellation ως «αδυναμία σύνδεσης».
            throw hermesError
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NSError(
                domain: "R0lling.Hermes",
                code: 7103,
                userInfo: [
                    NSLocalizedDescriptionKey: "Αδυναμία σύνδεσης με τον Hermes στο Home PC (\(baseURLString)). Βεβαιωθείτε ότι είστε στο οικιακό δίκτυο ή έχετε ενεργό VPN.",
                    NSUnderlyingErrorKey: error
                ]
            )
        }
    }

    public func describeImage(imageData: Data, question: String?) async throws -> String {
        let b64 = imageData.base64EncodedString()
        let promptText = question ?? "Hermes, τι βλέπω στα Meta Glasses μου αυτή τη στιγμή;"
        let payload = AIRequestPayload(prompt: promptText, imageBase64: b64)
        let result = try await generateReply(payload: payload)
        return result.reply
    }

    public func summarizeDay(entries: [JournalEntry]) async throws -> String {
        guard !entries.isEmpty else {
            return "Δεν υπάρχουν καταγραφές για τη σημερινή ημέρα."
        }
        let promptText = "Hermes, δημιούργησε την ημερήσια ανασκόπηση των καταγραφών μου."
        let payload = AIRequestPayload(prompt: promptText, contextEntries: entries)
        let result = try await generateReply(payload: payload)
        return result.reply
    }
}
