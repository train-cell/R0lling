import Foundation

@main
struct GlassesConnectionCancellationProbe {
    static func main() async throws {
        let adapter = MetaGlassesAdapter()
        let cancelledAttempt = Task { try await adapter.connectDevice() }

        for _ in 0..<100 {
            if await adapter.connectionState == .connecting { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let connectingState = await adapter.connectionState
        precondition(connectingState == .connecting)

        cancelledAttempt.cancel()
        do {
            try await cancelledAttempt.value
            fatalError("Cancelled connection should throw")
        } catch is CancellationError {
            // Expected.
        }
        let finalState = await adapter.connectionState
        precondition(finalState == .disconnected)

        let generationAdapter = MetaGlassesAdapter()
        let staleAttempt = Task { try await generationAdapter.connectDevice() }
        try await waitUntilConnecting(generationAdapter)
        await generationAdapter.disconnectDevice()
        let currentAttempt = Task { try await generationAdapter.connectDevice() }
        try await waitUntilConnecting(generationAdapter)
        try await currentAttempt.value
        do {
            try await staleAttempt.value
            fatalError("A disconnected handshake must not report success")
        } catch is CancellationError {
            // Expected: the old attempt's generation was invalidated.
        }
        let connectedState = await generationAdapter.connectionState
        precondition(connectedState.isConnected)

        print("PASS: cancelled handshake resets state and stale attempts cannot clobber a newer connection")
    }

    private static func waitUntilConnecting(_ adapter: MetaGlassesAdapter) async throws {
        for _ in 0..<100 {
            if await adapter.connectionState == .connecting { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        fatalError("Adapter did not enter connecting state")
    }
}
