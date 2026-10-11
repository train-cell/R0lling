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

    func testSelectedProviderRejectsURLUserInfoAndQueryParameters() async {
        let router = AIRouter(settings: AISettings())
        for directURL in [
            "https://user:secret@proxy.example/v1",
            "https://proxy.example/v1?api_key=secret"
        ] {
            do {
                try await router.validateEndpointForSaving(
                    provider: .directAPI,
                    directBaseURL: directURL,
                    hermesBaseURL: "https://127.0.0.1:8080/v1"
                )
                XCTFail("Direct provider accepted URL credentials/query: \(directURL)")
            } catch {
                XCTAssertFalse(error.localizedDescription.isEmpty)
            }
        }

        for hermesURL in [
            "https://user:secret@hermes.example/v1",
            "http://192.168.1.50:8080/v1?token=secret"
        ] {
            do {
                try await router.validateEndpointForSaving(
                    provider: .hermes,
                    directBaseURL: "https://api.openai.com/v1",
                    hermesBaseURL: hermesURL
                )
                XCTFail("Hermes provider accepted URL credentials/query: \(hermesURL)")
            } catch {
                XCTAssertFalse(error.localizedDescription.isEmpty)
            }
        }
    }
}
