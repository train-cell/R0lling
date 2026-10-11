import Foundation

public struct GlassesReconnectPolicy: Sendable {}
public enum GlassesAppLifecycleEvent: Sendable { case background }
public struct GlassesLifecycleOutcome: Sendable {}
public enum HeadGestureDetector {
    public struct IMUSample: Sendable {}
}

@main
struct GlassesPrimaryActionProbe {
    static func main() {
        let connected = GlassesConnectionState.connected(deviceName: "Device", batteryPercent: nil)
        precondition(connected.isConnected)
        precondition(GlassesPrimaryAction.resolve(isStreaming: false, state: connected) == .startStreaming)

        let paused = GlassesConnectionState.paused(reason: "background")
        precondition(paused.isConnected)
        precondition(GlassesPrimaryAction.resolve(isStreaming: false, state: paused) == .startStreaming)

        let streaming = GlassesConnectionState.streaming(fps: 30, isBuffering: true)
        precondition(GlassesPrimaryAction.resolve(isStreaming: false, state: streaming) == .stopStreaming)
        precondition(GlassesPrimaryAction.resolve(isStreaming: true, state: connected) == .stopStreaming)
        precondition(GlassesPrimaryAction.resolve(isStreaming: false, state: .disconnected) == .connectThenStartStreaming)
        precondition(GlassesPrimaryAction.resolve(isStreaming: false, state: .connecting) == .waitForConnection)
        precondition(!GlassesConnectionState.error("failed").isConnected)

        print("PASS: glasses control waits, starts/restarts, resumes paused sessions, and stops")
    }
}
