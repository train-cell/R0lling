import XCTest
@testable import R0lling

final class SpeechCompletionRegistryTests: XCTestCase {
    private final class CompletionProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        func complete() {
            lock.lock()
            count += 1
            lock.unlock()
        }

        var invocationCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }
    }

    func testFinishingOneUtteranceDoesNotConsumeAnotherCompletion() {
        let registry = SpeechCompletionRegistry()
        let firstUtterance = NSObject()
        let secondUtterance = NSObject()
        let first = CompletionProbe()
        let second = CompletionProbe()
        registry.register({ first.complete() }, for: firstUtterance)
        registry.register({ second.complete() }, for: secondUtterance)

        registry.take(for: firstUtterance)?()
        registry.take(for: firstUtterance)?()

        XCTAssertEqual(first.invocationCount, 1)
        XCTAssertEqual(second.invocationCount, 0)
        registry.take(for: secondUtterance)?()
        XCTAssertEqual(second.invocationCount, 1)
    }

    func testCancellingOneUtterancePreservesOtherCompletion() {
        let registry = SpeechCompletionRegistry()
        let cancelledUtterance = NSObject()
        let queuedUtterance = NSObject()
        let cancelled = CompletionProbe()
        let queued = CompletionProbe()
        registry.register({ cancelled.complete() }, for: cancelledUtterance)
        registry.register({ queued.complete() }, for: queuedUtterance)

        registry.discard(for: cancelledUtterance)
        registry.take(for: queuedUtterance)?()

        XCTAssertEqual(cancelled.invocationCount, 0)
        XCTAssertEqual(queued.invocationCount, 1)
    }

    func testStoppingSpeechDiscardsAllPendingCompletions() {
        let registry = SpeechCompletionRegistry()
        let firstUtterance = NSObject()
        let secondUtterance = NSObject()
        let first = CompletionProbe()
        let second = CompletionProbe()
        registry.register({ first.complete() }, for: firstUtterance)
        registry.register({ second.complete() }, for: secondUtterance)

        registry.discardAll()

        registry.take(for: firstUtterance)?()
        registry.take(for: secondUtterance)?()
        XCTAssertEqual(first.invocationCount, 0)
        XCTAssertEqual(second.invocationCount, 0)
    }
}
