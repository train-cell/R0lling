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

final class AIHTTPClientTests: XCTestCase {
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
}
