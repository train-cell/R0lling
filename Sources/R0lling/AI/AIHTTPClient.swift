import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Signals that a response exceeded the configured byte limit before it was fully buffered.
struct AIHTTPResponseTooLarge: Error, Equatable {
    let maximumBytes: Int
}

/// Redirects are rejected so an authenticated POST body cannot be replayed to
/// an origin that was never accepted by the provider endpoint validator.
struct AIHTTPRedirectRejected: Error, Equatable {}

/// URLSession delegate that accumulates only bounded response bodies.
/// It also enforces the limit when Content-Length is absent or inaccurate.
final class BoundedURLSessionDataLoader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private struct PendingResponse {
        let maximumBytes: Int
        let continuation: CheckedContinuation<(Data, URLResponse), Error>
        var response: URLResponse?
        var data = Data()
    }

    private let lock = NSLock()
    private var pending: [Int: PendingResponse] = [:]
    private var session: URLSession!

    init(configuration: URLSessionConfiguration = .default) {
        super.init()
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    func data(for request: URLRequest, maximumBytes: Int) async throws -> (Data, URLResponse) {
        precondition(maximumBytes > 0)
        let cancellation = DataTaskCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request)
                cancellation.install(task)
                lock.lock()
                pending[task.taskIdentifier] = PendingResponse(
                    maximumBytes: maximumBytes,
                    continuation: continuation
                )
                lock.unlock()
                task.resume()
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    func invalidate() {
        session.invalidateAndCancel()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var continuation: CheckedContinuation<(Data, URLResponse), Error>?
        lock.lock()
        if let state = pending.removeValue(forKey: task.taskIdentifier) {
            continuation = state.continuation
        }
        lock.unlock()

        // Do not let URLSession replay the original body or Authorization header.
        completionHandler(nil)
        continuation?.resume(throwing: AIHTTPRedirectRejected())
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        var oversizedContinuation: CheckedContinuation<(Data, URLResponse), Error>?
        var maximumBytes: Int?
        lock.lock()
        if let state = pending[dataTask.taskIdentifier] {
            if response.expectedContentLength > Int64(state.maximumBytes) {
                oversizedContinuation = state.continuation
                maximumBytes = state.maximumBytes
                pending.removeValue(forKey: dataTask.taskIdentifier)
            } else {
                var updated = state
                updated.response = response
                pending[dataTask.taskIdentifier] = updated
            }
        }
        lock.unlock()

        if let oversizedContinuation {
            oversizedContinuation.resume(throwing: AIHTTPResponseTooLarge(maximumBytes: maximumBytes ?? 1))
            completionHandler(.cancel)
        } else {
            completionHandler(.allow)
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        var oversizedContinuation: CheckedContinuation<(Data, URLResponse), Error>?
        var maximumBytes: Int?
        lock.lock()
        if var state = pending[dataTask.taskIdentifier] {
            if data.count > state.maximumBytes - state.data.count {
                oversizedContinuation = state.continuation
                maximumBytes = state.maximumBytes
                pending.removeValue(forKey: dataTask.taskIdentifier)
            } else {
                state.data.append(data)
                pending[dataTask.taskIdentifier] = state
            }
        }
        lock.unlock()

        if let oversizedContinuation {
            oversizedContinuation.resume(throwing: AIHTTPResponseTooLarge(maximumBytes: maximumBytes ?? 1))
            dataTask.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        lock.lock()
        let state = pending.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        guard let state else { return }

        if let error {
            state.continuation.resume(throwing: error)
        } else if let response = state.response {
            state.continuation.resume(returning: (state.data, response))
        } else {
            state.continuation.resume(throwing: URLError(.badServerResponse))
        }
    }
}

private final class DataTaskCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var isCancelled = false

    func install(_ task: URLSessionDataTask) {
        lock.lock()
        self.task = task
        let shouldCancel = isCancelled
        lock.unlock()
        if shouldCancel { task.cancel() }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }
}

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
        public let responseTooLargeCode: Int
        public let maximumResponseBytes: Int
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
            responseTooLargeCode: Int,
            maximumResponseBytes: Int = 8 * 1024 * 1024,
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
            self.responseTooLargeCode = responseTooLargeCode
            self.maximumResponseBytes = max(1, maximumResponseBytes)
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
                let (data, response) = try await Self.responseLoader.data(
                    for: request,
                    maximumBytes: config.maximumResponseBytes
                )

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
            } catch is AIHTTPResponseTooLarge {
                throw AIErrorTaxonomy.makeError(
                    domain: config.errorDomain,
                    code: config.responseTooLargeCode,
                    message: "Η απάντηση του AI υπερβαίνει το επιτρεπόμενο μέγεθος."
                )
            } catch is AIHTTPRedirectRejected {
                throw AIErrorTaxonomy.makeError(
                    domain: config.errorDomain,
                    code: config.transportCode,
                    message: "Το AI endpoint επέστρεψε μη επιτρεπτή ανακατεύθυνση."
                )
            } catch let typed as NSError where typed.domain == config.errorDomain {
                if typed.code == config.httpRejectedCode || typed.code == config.responseTooLargeCode {
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

    private static let responseLoader = BoundedURLSessionDataLoader()
}
