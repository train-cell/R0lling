import Foundation

public enum AIProviderType: Sendable {
    case directAPI
    case hermes
}

enum HermesEndpointAsfaleia {
    static func epikyroseDirectBaseURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else { throw URLError(.badURL) }
        return url
    }

    static func epikyroseHermesBaseURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else { throw URLError(.badURL) }
        return url
    }

    static func chatCompletionsURL(
        fromBaseURL url: URL,
        errorDomain: String,
        errorCode: Int
    ) throws -> URL {
        url.appendingPathComponent("chat/completions")
    }

    static func chatCompletionsURL(fromBaseURL url: URL) throws -> URL {
        url.appendingPathComponent("chat/completions")
    }

    static func asfales_host_gia_log(_ url: URL) -> String {
        url.host ?? "unknown"
    }
}

public struct JournalEntry: Sendable {
    public let id: UUID
    public let timestamp: Date
    public let content: String
    public var locationName: String?

    public init(timestamp: Date = Date(), content: String, locationName: String? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.content = content
        self.locationName = locationName
    }

    public var formattedTime: String {
        ISO8601DateFormatter().string(from: timestamp)
    }
}

@main
struct AIRequestSizeProbe {
    static func main() async throws {
        let ordinaryPayload = AIRequestPayload(
            prompt: "Σύνοψε τις τελευταίες σημειώσεις.",
            contextEntries: [JournalEntry(content: "Περπάτησα στο κέντρο της Αθήνας.")]
        )
        let body = try OpenAIChatRequestBuilder.buildBoundedRequestBody(
            payload: ordinaryPayload,
            defaultSystemPrompt: "Απάντησε στα Ελληνικά.",
            memoryHeader: "Μνήμη:",
            model: "probe-model",
            temperature: 0.2
        )
        precondition(body.count <= OpenAIChatRequestBuilder.maximumRequestBodyBytes)
        let jsonBody = try JSONSerialization.jsonObject(with: body)
        precondition(jsonBody is [String: Any])

        let oversizedPayload = AIRequestPayload(
            prompt: "Σύνοψη",
            contextEntries: [JournalEntry(content: String(repeating: "x", count: 32_000))]
        )
        do {
            _ = try OpenAIChatRequestBuilder.buildBoundedRequestBody(
                payload: oversizedPayload,
                defaultSystemPrompt: "system",
                memoryHeader: "memory",
                model: "probe-model",
                temperature: 0.2,
                maximumBytes: 16 * 1024
            )
            fatalError("Oversized journal context was accepted")
        } catch is AIRequestBodyTooLarge {
            // Expected: the payload is rejected before message interpolation.
        }

        do {
            _ = try OpenAIChatRequestBuilder.buildRequestBody(
                model: "probe-model",
                messages: [["role": "user", "content": String(repeating: "x", count: 4_096)]],
                temperature: 0.2,
                maximumBytes: 1_024
            )
            fatalError("Oversized serialized message input was accepted")
        } catch is AIRequestBodyTooLarge {
            // Expected: the JSON upper bound rejects it before serialization.
        }

        let withinVisionBudget = try OpenAIChatRequestBuilder.addingVisionFrameBytes(3 * 1024 * 1024)
        _ = try OpenAIChatRequestBuilder.addingVisionFrameBytes(2 * 1024 * 1024, to: withinVisionBudget)
        do {
            _ = try OpenAIChatRequestBuilder.addingVisionFrameBytes(
                OpenAIChatRequestBuilder.maximumAggregateVisionImageBytes + 1
            )
            fatalError("Vision input exceeded the pre-Base64 aggregate cap")
        } catch is AIRequestBodyTooLarge {
            // Expected: oversized image data is rejected before Base64 expansion.
        }

        let requestConfig = AIHTTPClient.RequestConfig(
            url: URL(string: "https://oversized-request.test/completions")!,
            bearerToken: "probe-token",
            body: Data(repeating: 0x41, count: 33),
            timeout: 1,
            maximumRequestBytes: 32,
            errorDomain: AIErrorTaxonomy.directDomain,
            httpRejectedCode: AIErrorTaxonomy.directHTTPRejected,
            responseTooLargeCode: AIErrorTaxonomy.directResponseTooLarge,
            transportCode: AIErrorTaxonomy.directTransport,
            retryExhaustedCode: AIErrorTaxonomy.directRetryExhausted,
            httpRejectedMessagePrefix: "Rejected",
            transportMessage: "Transport failed"
        )
        do {
            _ = try await AIHTTPClient.postJSON(requestConfig)
            fatalError("HTTP client attempted to submit an oversized body")
        } catch is AIRequestBodyTooLarge {
            // Expected: no URLSession task is created for the over-limit body.
        }

        print("PASS: normal AI body, context and frame preflight, JSON upper bound, and pre-network HTTP cap")
    }
}
