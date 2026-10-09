import XCTest
@testable import R0lling

private actor MutationGateEventLog {
    private var events: [String] = []
    private var countWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func append(_ event: String) {
        events.append(event)
        let ready = countWaiters.filter { $0.0 <= events.count }
        countWaiters.removeAll { $0.0 <= events.count }
        ready.forEach { $0.1.resume() }
    }

    func waitForCount(_ count: Int) async {
        guard events.count < count else { return }
        await withCheckedContinuation { countWaiters.append((count, $0)) }
    }

    func snapshot() -> [String] { events }
}

private actor MutationGateLatch {
    private var isOpen = false
    private var waiter: CheckedContinuation<Void, Never>?

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func open() {
        isOpen = true
        waiter?.resume()
        waiter = nil
    }
}

@MainActor
final class MediaReferenceMutationGateTests: XCTestCase {
    func testRestoreWaitsForDeletionAndOrphanCleanupToFinish() async throws {
        let gate = MediaReferenceMutationGate()
        let events = MutationGateEventLog()
        let deletionCanFinish = MutationGateLatch()

        let deletion = Task { @MainActor in
            try await gate.withExclusiveAccess {
                await events.append("delete-start")
                await deletionCanFinish.wait()
                await events.append("delete-finish")
            }
        }
        await events.waitForCount(1)

        let restore = Task { @MainActor in
            await events.append("restore-requested")
            try await gate.withExclusiveAccess {
                await events.append("restore-finish")
            }
        }
        await events.waitForCount(2)

        var queued = false
        for _ in 0..<1_000 {
            if await gate.queuedMutationCount > 0 {
                queued = true
                break
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertTrue(queued, "Restore should queue behind deletion while cleanup is suspended")
        let eventsBeforeCleanup = await events.snapshot()
        XCTAssertEqual(eventsBeforeCleanup, ["delete-start", "restore-requested"])

        await deletionCanFinish.open()
        try await deletion.value
        try await restore.value

        let finalEvents = await events.snapshot()
        XCTAssertEqual(finalEvents, ["delete-start", "restore-requested", "delete-finish", "restore-finish"])
    }

    func testCancelledQueuedMutationDoesNotRun() async throws {
        let gate = MediaReferenceMutationGate()
        let firstMutationCanFinish = MutationGateLatch()
        let firstMutationStarted = MutationGateLatch()
        var cancelledOperationRan = false

        let firstMutation = Task { @MainActor in
            try await gate.withExclusiveAccess {
                await firstMutationStarted.open()
                await firstMutationCanFinish.wait()
            }
        }
        await firstMutationStarted.wait()

        let cancelledMutation = Task { @MainActor in
            try await gate.withExclusiveAccess {
                cancelledOperationRan = true
            }
        }
        var queued = false
        for _ in 0..<1_000 {
            if await gate.queuedMutationCount == 1 {
                queued = true
                break
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertTrue(queued)

        cancelledMutation.cancel()
        do {
            try await cancelledMutation.value
            XCTFail("A canceled waiter should leave the mutation gate without running its operation")
        } catch is CancellationError {
            // Expected: cancellation is observed before the protected operation starts.
        }
        XCTAssertFalse(cancelledOperationRan)

        await firstMutationCanFinish.open()
        try await firstMutation.value
    }
}
