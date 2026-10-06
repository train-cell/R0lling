import Foundation

/// Connector για τον προσωπικό Hermes Agent στο Home PC (μέσω Τοπικού Δικτύου ή VPN).
/// SEC-004/007: HTTPS ή allowlisted cleartext · R3-012 empty-token · SEC-005 status-only errors.
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
            throw AIErrorTaxonomy.makeError(
                domain: AIErrorTaxonomy.hermesDomain,
                code: AIErrorTaxonomy.hermesEmptyToken,
                message: "Λείπει Hermes auth token. Αποθήκευσέ το στο Keychain από τις Ρυθμίσεις."
            )
        }

        // SEC-004/007: επικύρωση endpoint πριν το network.
        let baseURL = try HermesEndpointAsfaleia.epikyroseHermesBaseURL(baseURLString)
        let endpointURL = try HermesEndpointAsfaleia.chatCompletionsURL(fromBaseURL: baseURL)

        try Task.checkCancellation()

        let messages = OpenAIChatRequestBuilder.buildMessages(
            payload: payload,
            defaultSystemPrompt: "Είσαι ο Hermes, ο προσωπικός AI Jarvis βοηθός του R0lling που εκτελείται στο Home PC. Απαντάς στα Ελληνικά με εξαιρετική ακρίβεια.",
            memoryHeader: "Μνήμη & Σημειώσεις Agent:"
        )

        let body = try OpenAIChatRequestBuilder.buildRequestBody(
            model: "hermes-agent",
            messages: messages,
            temperature: 0.6
        )

        let hostLabel = HermesEndpointAsfaleia.asfales_host_gia_log(baseURL)
        let config = AIHTTPClient.RequestConfig(
            url: endpointURL,
            bearerToken: trimmedToken,
            body: body,
            timeout: AIHTTPClient.hermesTimeoutSeconds,
            errorDomain: AIErrorTaxonomy.hermesDomain,
            httpRejectedCode: AIErrorTaxonomy.hermesHTTPRejected,
            transportCode: AIErrorTaxonomy.hermesTransport,
            retryExhaustedCode: AIErrorTaxonomy.hermesRetryExhausted,
            httpRejectedMessagePrefix: "Ο Hermes Agent απέρριψε την κλήση",
            transportMessage: "Αδυναμία σύνδεσης με τον Hermes στο Home PC (\(hostLabel)). Βεβαιωθείτε ότι είστε στο οικιακό δίκτυο ή έχετε ενεργό VPN."
        )

        do {
            let data = try await AIHTTPClient.postJSON(config)
            return try OpenAIChatRequestBuilder.parseChatCompletionResponse(
                data: data,
                fallbackReply: "Δεν ελήφθη απάντηση από τον Hermes.",
                referencedEntryIDs: payload.contextEntries.map { $0.id }
            )
        } catch let hermesError as NSError where hermesError.domain == AIErrorTaxonomy.hermesDomain {
            // CQ-P0-003: μην καλύπτεις typed 7102/cancellation ως «αδυναμία σύνδεσης».
            throw hermesError
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AIErrorTaxonomy.makeError(
                domain: AIErrorTaxonomy.hermesDomain,
                code: AIErrorTaxonomy.hermesTransport,
                message: "Αδυναμία σύνδεσης με τον Hermes στο Home PC (\(hostLabel)). Βεβαιωθείτε ότι είστε στο οικιακό δίκτυο ή έχετε ενεργό VPN.",
                underlying: error
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
