import Foundation

/// Serializes operations that update journal media references and clean up their files.
/// The lock is intentionally held across suspension points so restore and deletion
/// cannot interleave a reference snapshot with a file removal.
public actor MediaReferenceMutationGate {
    public init() {}
    private var isOccupied = false
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }
    private var waiters: [Waiter] = []

    var queuedMutationCount: Int { waiters.count }

    public func withExclusiveAccess<T: Sendable>(
        _ operation: @MainActor @Sendable () async throws -> T
    ) async throws -> T {
        try await acquireTurn()
        defer { releaseTurn() }
        try Task.checkCancellation()
        return try await operation()
    }

    private func acquireTurn() async throws {
        try Task.checkCancellation()
        guard isOccupied else {
            isOccupied = true
            return
        }

        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters.append(Waiter(id: waiterID, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(waiterID) }
        }
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func releaseTurn() {
        if waiters.isEmpty {
            isOccupied = false
        } else {
            // Keep the gate occupied while transferring the turn to the next waiter.
            waiters.removeFirst().continuation.resume()
        }
    }
}
