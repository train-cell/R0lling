import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import R0lling

private final class OversizedAIResponseURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "oversized-response.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // No Content-Length: the delegate must enforce the cap as chunks arrive.
        let bodyCount = request.url?.path == "/at-limit" ? 32 : 33
        client?.urlProtocol(self, didLoad: Data(repeating: 0x41, count: bodyCount))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class AIRetryAttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func reset() {
        lock.lock()
        value = 0
        lock.unlock()
    }

    func advance() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }

    func currentValue() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class RetryingThenHangingAIResponseURLProtocol: URLProtocol {
    static let attempts = AIRetryAttemptCounter()

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "cancel-final-attempt.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let attempt = Self.attempts.advance()
        guard attempt < 3,
              let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 503,
                httpVersion: "HTTP/1.1",
                headerFields: nil
              ) else {
            // The final attempt intentionally stays in flight until the test cancels it.
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

#if !os(Linux)
private final class RedirectingAIResponseURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "redirecting-response.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 307,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": "https://other-origin.test/replayed"]
              ),
              let redirectedURL = URL(string: "https://other-origin.test/replayed") else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(
            self,
            wasRedirectedTo: URLRequest(url: redirectedURL),
            redirectResponse: response
        )
    }

    override func stopLoading() {}
}
#endif

final class AIHTTPClientTests: XCTestCase {
    func testPostJSONRejectsOversizedRequestBeforeOpeningNetworkTask() async {
        let config = AIHTTPClient.RequestConfig(
            url: URL(string: "https://oversized-request.test/completions")!,
            bearerToken: "test-token",
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
            _ = try await AIHTTPClient.postJSON(config)
            XCTFail("An oversized request must be rejected before URLSession")
        } catch let error as AIRequestBodyTooLarge {
            XCTAssertEqual(error.maximumBytes, 32)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStreamingResponseLoaderAcceptsBodyAtLimit() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OversizedAIResponseURLProtocol.self]
        let loader = BoundedURLSessionDataLoader(configuration: configuration)
        defer { loader.invalidate() }
        let request = URLRequest(url: URL(string: "https://oversized-response.test/at-limit")!)

        let (data, response) = try await loader.data(for: request, maximumBytes: 32)

        XCTAssertEqual(data.count, 32)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    func testStreamingResponseLoaderRejectsOversizedChunkedBody() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OversizedAIResponseURLProtocol.self]
        let loader = BoundedURLSessionDataLoader(configuration: configuration)
        defer { loader.invalidate() }
        let request = URLRequest(url: URL(string: "https://oversized-response.test/completions")!)

        do {
            _ = try await loader.data(for: request, maximumBytes: 32)
            XCTFail("An over-limit body must be rejected")
        } catch let error as AIHTTPResponseTooLarge {
            XCTAssertEqual(error.maximumBytes, 32)
        }
    }

    func testCancellationOfFinalRetryPropagatesCancellationError() async throws {
        RetryingThenHangingAIResponseURLProtocol.attempts.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RetryingThenHangingAIResponseURLProtocol.self]
        let loader = BoundedURLSessionDataLoader(configuration: configuration)
        defer { loader.invalidate() }
        let config = AIHTTPClient.RequestConfig(
            url: URL(string: "https://cancel-final-attempt.test/completions")!,
            bearerToken: "test-token",
            body: Data("{}".utf8),
            timeout: 20,
            errorDomain: AIErrorTaxonomy.directDomain,
            httpRejectedCode: AIErrorTaxonomy.directHTTPRejected,
            responseTooLargeCode: AIErrorTaxonomy.directResponseTooLarge,
            transportCode: AIErrorTaxonomy.directTransport,
            retryExhaustedCode: AIErrorTaxonomy.directRetryExhausted,
            httpRejectedMessagePrefix: "Rejected",
            transportMessage: "Transport failed"
        )

        let requestTask = Task {
            try await AIHTTPClient.postJSON(config, using: loader)
        }
        for _ in 0..<800 {
            if RetryingThenHangingAIResponseURLProtocol.attempts.currentValue() >= 3 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let attempts = RetryingThenHangingAIResponseURLProtocol.attempts.currentValue()
        requestTask.cancel()

        XCTAssertEqual(attempts, 3, "The test must cancel while the final HTTP retry is in flight")
        do {
            _ = try await requestTask.value
            XCTFail("A canceled final request must not be reported as retry exhaustion")
        } catch is CancellationError {
            // Expected: cancellation takes precedence over the retry-exhausted transport error.
        } catch {
            XCTFail("Expected CancellationError, received \(error)")
        }
    }

#if !os(Linux)
    func testStreamingResponseLoaderRejectsRedirects() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RedirectingAIResponseURLProtocol.self]
        let loader = BoundedURLSessionDataLoader(configuration: configuration)
        defer { loader.invalidate() }
        var request = URLRequest(url: URL(string: "https://redirecting-response.test/completions")!)
        request.httpMethod = "POST"
        request.httpBody = Data("secret-payload".utf8)

        do {
            _ = try await loader.data(for: request, maximumBytes: 128)
            XCTFail("A redirect must not replay an authenticated POST")
        } catch is AIHTTPRedirectRejected {
            // Expected: the loader cancels the redirect before URLSession can follow it.
        }
    }
#endif
}
