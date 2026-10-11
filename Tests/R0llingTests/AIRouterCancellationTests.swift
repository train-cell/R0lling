import Foundation
import XCTest
@testable import R0lling

final class AIRouterCancellationTests: XCTestCase {
    func testRecallUsesLocalMatchesWithStableSourcesWhenProviderIsUnavailable() async throws {
        let router = AIRouter(settings: AISettings(), connectorOverrideForTesting: UnavailableRecallConnector())
        let entry = JournalEntry(title: "Ταξίδι", content: "Αναχώρηση από Αθήνα")

        let result = try await router.recallMemories(query: "Αθήνα", allEntries: [entry])

        XCTAssertEqual(result.matchingEntries.map(\.id), [entry.id])
        XCTAssertTrue(result.reply.contains(entry.id.uuidString))
        XCTAssertTrue(result.reply.contains(entry.dateKey))
        XCTAssertTrue(result.reply.contains("Το AI δεν ήταν διαθέσιμο"))
    }

    func testRecallPropagatesURLSessionCancellationInsteadOfReturningLocalFallback() async {
        let connector = CancellingRecallConnector()
        let router = AIRouter(settings: AISettings(), connectorOverrideForTesting: connector)
        let entry = JournalEntry(content: "Athens vacation")
        let recall = Task {
            try await router.recallMemories(query: "Athens", allEntries: [entry])
        }

        await connector.waitUntilReplyStarts()
        recall.cancel()

        do {
            _ = try await recall.value
            XCTFail("A cancelled recall must not return a successful local fallback")
        } catch is CancellationError {
            // Expected: cancellation must reach the caller.
        } catch {
            XCTFail("Expected CancellationError, received \(error)")
        }
    }
}

private struct UnavailableRecallConnector: AIConnectorProtocol {
    let providerType: AIProviderType = .directAPI

    func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult {
        throw URLError(.notConnectedToInternet)
    }

    func describeImage(imageData: Data, question: String?) async throws -> String { "" }

    func summarizeDay(entries: [JournalEntry]) async throws -> String { "" }
}

private actor CancellingRecallConnector: AIConnectorProtocol {
    nonisolated let providerType: AIProviderType = .directAPI

    private var hasStartedReply = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var replyContinuation: CheckedContinuation<AIResponseResult, Error>?

    func waitUntilReplyStarts() async {
        guard !hasStartedReply else { return }
        await withCheckedContinuation { continuation in
            startWaiter = continuation
        }
    }

    func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult {
        hasStartedReply = true
        startWaiter?.resume()
        startWaiter = nil

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                replyContinuation = continuation
                if Task.isCancelled {
                    finishReplyWithCancellation()
                }
            }
        } onCancel: {
            Task { await self.finishReplyWithCancellation() }
        }
    }

    private func finishReplyWithCancellation() {
        replyContinuation?.resume(throwing: URLError(.cancelled))
        replyContinuation = nil
    }

    func describeImage(imageData: Data, question: String?) async throws -> String {
        ""
    }

    func summarizeDay(entries: [JournalEntry]) async throws -> String {
        ""
    }
}
