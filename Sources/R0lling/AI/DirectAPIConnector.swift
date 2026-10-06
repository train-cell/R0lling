import Foundation

/// Άμεσος connector για OpenAI-compatible cloud APIs (OpenAI, Gemini via proxy, Groq κ.λπ.).
/// R3-012 empty-key · SEC-005 status-only · υποχρεωτικό HTTPS.
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
            throw AIErrorTaxonomy.makeError(
                domain: AIErrorTaxonomy.directDomain,
                code: AIErrorTaxonomy.directEmptyKey,
                message: "Λείπει Direct API key. Αποθήκευσέ το στο Keychain από τις Ρυθμίσεις."
            )
        }

        let baseURL = try HermesEndpointAsfaleia.epikyroseDirectBaseURL(baseURLString)
        let endpointURL = try HermesEndpointAsfaleia.chatCompletionsURL(
            fromBaseURL: baseURL,
            errorDomain: AIErrorTaxonomy.directDomain,
            errorCode: AIErrorTaxonomy.directInvalidURL
        )

        try Task.checkCancellation()

        let messages = OpenAIChatRequestBuilder.buildMessages(
            payload: payload,
            defaultSystemPrompt: "Είσαι ο προσωπικός βοηθός R0lling στο iPhone του χρήστη. Απαντάς στα Ελληνικά με σαφήνεια, ακρίβεια και φιλικό τόνο.",
            memoryHeader: "Μνήμη & Προτιμήσεις Χρήστη:"
        )

        let body = try OpenAIChatRequestBuilder.buildRequestBody(
            model: modelName,
            messages: messages,
            temperature: 0.7
        )

        let config = AIHTTPClient.RequestConfig(
            url: endpointURL,
            bearerToken: trimmedKey,
            body: body,
            timeout: AIHTTPClient.defaultTimeoutSeconds,
            errorDomain: AIErrorTaxonomy.directDomain,
            httpRejectedCode: AIErrorTaxonomy.directHTTPRejected,
            transportCode: AIErrorTaxonomy.directTransport,
            retryExhaustedCode: AIErrorTaxonomy.directRetryExhausted,
            httpRejectedMessagePrefix: "Direct AI API Σφάλμα",
            transportMessage: "Αδυναμία σύνδεσης με το Direct AI API. Έλεγξε δίκτυο και Base URL."
        )

        do {
            let data = try await AIHTTPClient.postJSON(config)
            return try OpenAIChatRequestBuilder.parseChatCompletionResponse(
                data: data,
                fallbackReply: "Δεν ελήφθη απάντηση από το AI.",
                referencedEntryIDs: payload.contextEntries.map { $0.id }
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let typed as NSError where typed.domain == AIErrorTaxonomy.directDomain {
            throw typed
        } catch {
            throw AIErrorTaxonomy.makeError(
                domain: AIErrorTaxonomy.directDomain,
                code: AIErrorTaxonomy.directTransport,
                message: "Αδυναμία σύνδεσης με το Direct AI API. Έλεγξε δίκτυο και Base URL.",
                underlying: error
            )
        }
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
