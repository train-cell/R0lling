import Foundation

/// Production HTTP client για OpenAI-compatible AI endpoints.
/// Retry/timeout + cancelation · ποτέ δεν επιστρέφει Authorization ή raw body στο UI.
public enum AIHTTPClient {
    public static let defaultTimeoutSeconds: TimeInterval = 30.0
    public static let hermesTimeoutSeconds: TimeInterval = 20.0
    public static let maxRetryCount: Int = 2
    public static let retryBaseDelaySeconds: TimeInterval = 0.4

    /// HTTP status που αξίζουν retry (transient).
    private static let retryableStatusCodes: Set<Int> = [408, 425, 429, 500, 502, 503, 504]

    public struct RequestConfig: Sendable {
        public let url: URL
        public let bearerToken: String
        public let body: Data
        public let timeout: TimeInterval
        public let errorDomain: String
        public let httpRejectedCode: Int
        public let transportCode: Int
        public let retryExhaustedCode: Int
        public let httpRejectedMessagePrefix: String
        public let transportMessage: String

        public init(
            url: URL,
            bearerToken: String,
            body: Data,
            timeout: TimeInterval,
            errorDomain: String,
            httpRejectedCode: Int,
            transportCode: Int,
            retryExhaustedCode: Int,
            httpRejectedMessagePrefix: String,
            transportMessage: String
        ) {
            self.url = url
            self.bearerToken = bearerToken
            self.body = body
            self.timeout = timeout
            self.errorDomain = errorDomain
            self.httpRejectedCode = httpRejectedCode
            self.transportCode = transportCode
            self.retryExhaustedCode = retryExhaustedCode
            self.httpRejectedMessagePrefix = httpRejectedMessagePrefix
            self.transportMessage = transportMessage
        }
    }

    /// Εκτελεί POST με Bearer auth, retries σε transient failures, σεβασμό cancelation.
    public static func postJSON(_ config: RequestConfig) async throws -> Data {
        var lastError: Error?

        for attempt in 0...maxRetryCount {
            try Task.checkCancellation()

            var request = URLRequest(url: config.url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(config.bearerToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = config.timeout
            request.httpBody = config.body

            do {
                try Task.checkCancellation()
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIErrorTaxonomy.makeError(
                        domain: config.errorDomain,
                        code: config.httpRejectedCode,
                        message: "\(config.httpRejectedMessagePrefix) (HTTP -1)."
                    )
                }

                if (200...299).contains(httpResponse.statusCode) {
                    return data
                }

                // SEC-005: status-only · όχι raw body.
                let rejected = AIErrorTaxonomy.makeError(
                    domain: config.errorDomain,
                    code: config.httpRejectedCode,
                    message: "\(config.httpRejectedMessagePrefix) (HTTP \(httpResponse.statusCode))."
                )

                if retryableStatusCodes.contains(httpResponse.statusCode), attempt < maxRetryCount {
                    lastError = rejected
                    try await sleepBackoff(attempt: attempt)
                    continue
                }
                throw rejected
            } catch is CancellationError {
                throw CancellationError()
            } catch let typed as NSError where typed.domain == config.errorDomain {
                if typed.code == config.httpRejectedCode {
                    throw typed
                }
                lastError = typed
                if attempt < maxRetryCount {
                    try await sleepBackoff(attempt: attempt)
                    continue
                }
                throw typed
            } catch {
                lastError = error
                if attempt < maxRetryCount {
                    try await sleepBackoff(attempt: attempt)
                    continue
                }
            }
        }

        if let nsError = lastError as? NSError, nsError.domain == config.errorDomain {
            throw nsError
        }

        throw AIErrorTaxonomy.makeError(
            domain: config.errorDomain,
            code: config.retryExhaustedCode,
            message: config.transportMessage,
            underlying: lastError
        )
    }

    private static func sleepBackoff(attempt: Int) async throws {
        try Task.checkCancellation()
        let delay = retryBaseDelaySeconds * pow(2.0, Double(attempt))
        let nanos = UInt64(delay * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanos)
    }
}
