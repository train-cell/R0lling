import XCTest
@testable import R0lling

final class AISettingsTests: XCTestCase {
    func testSavingDirectProviderIgnoresInvalidInactiveHermesURL() async throws {
        let router = AIRouter(settings: AISettings())
        try await router.validateEndpointForSaving(
            provider: .directAPI,
            directBaseURL: "https://api.openai.com/v1",
            hermesBaseURL: "not a URL"
        )
    }

    func testSavingHermesProviderIgnoresInvalidInactiveDirectURL() async throws {
        let router = AIRouter(settings: AISettings())
        try await router.validateEndpointForSaving(
            provider: .hermes,
            directBaseURL: "http://public.example.com/v1",
            hermesBaseURL: "http://127.0.0.1:8080/v1"
        )
    }

    func testSavingSelectedProviderStillRejectsItsInvalidURL() async {
        let router = AIRouter(settings: AISettings())
        do {
            try await router.validateEndpointForSaving(
                provider: .directAPI,
                directBaseURL: "http://api.openai.com/v1",
                hermesBaseURL: "http://127.0.0.1:8080/v1"
            )
            XCTFail("The selected direct provider must reject plain HTTP.")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
}
