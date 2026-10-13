import Foundation

/// Sink interface for adapter sensor samples. The live Meta DAT sensor callbacks are not wired;
/// the current producer is simulation-only, and acoustic/head-gesture triggers remain gated off.
public protocol GlassesSensorFeedSink: AnyObject, Sendable {
    /// RMS / dBFS στάθμη ήχου από mic stream (γυαλιά ή iPhone fallback).
    func receiveAcousticLevel(decibels: Float)
    /// IMU δείγμα κεφαλής από γυαλιά.
    func receiveIMUSample(_ sample: HeadGestureDetector.IMUSample)
}

public enum GlassesConnectionState: Sendable, Equatable {
    case disconnected
    case searching
    case connecting
    case connected(deviceName: String, batteryPercent: Int?)
    case streaming(fps: Double, isBuffering: Bool)
    /// Ροή παύθηκε λόγω background / lock (A07) — όχι disconnect.
    case paused(reason: String)
    case error(String)

    public var statusDescription: String {
        switch self {
        case .disconnected: return "Αποσυνδεδεμένα"
        case .searching: return "Αναζήτηση συσκευής..."
        case .connecting: return "Σύνδεση..."
        case .connected(let name, let battery):
            if let bat = battery {
                return "\(name) (\(bat)%)"
            }
            return name
        case .streaming(let fps, _):
            return fps > 0 ? "Ζωντανή ροή (\(Int(fps)) FPS)" : "Ζωντανή ροή"
        case .paused(let reason): return "Παύση: \(reason)"
        case .error(let msg): return "Σφάλμα: \(msg)"
        }
    }

    public var isLive: Bool {
        if case .streaming = self {
            return true
        }
        return false
    }

    public var isConnected: Bool {
        switch self {
        case .connected, .streaming, .paused:
            return true
        case .disconnected, .searching, .connecting, .error:
            return false
        }
    }

    public var isConnectionAttemptInProgress: Bool {
        switch self {
        case .searching, .connecting:
            return true
        case .disconnected, .connected, .streaming, .paused, .error:
            return false
        }
    }

    public var isPaused: Bool {
        if case .paused = self {
            return true
        }
        return false
    }
}

enum GlassesPrimaryAction: Equatable {
    case waitForConnection
    case startStreaming
    case stopStreaming
    case connectThenStartStreaming

    static func resolve(isStreaming: Bool, state: GlassesConnectionState) -> Self {
        if isStreaming || state.isLive { return .stopStreaming }
        if state.isConnectionAttemptInProgress { return .waitForConnection }
        if state.isConnected { return .startStreaming }
        return .connectThenStartStreaming
    }
}

public protocol MetaGlassesAdapterProtocol: Sendable {
    var connectionState: GlassesConnectionState { get async }
    var isSimulationMode: Bool { get async }
    var reconnectPolicy: GlassesReconnectPolicy { get async }
    func connectDevice() async throws
    func disconnectDevice() async
    /// Request Meta camera permission only after an explicit in-app confirmation.
    func requestCameraPermissionAfterUserConfirmation() async throws
    func startStreaming() async throws
    func stopStreaming() async
    func capturePhoto() async throws -> Data
    func toggleSimulationMode(enabled: Bool) async
    /// A07: χειρισμός background / lock / foreground.
    func handleAppLifecycle(_ event: GlassesAppLifecycleEvent) async -> GlassesLifecycleOutcome
    /// Registers the consumer for adapter samples; the current producer is simulation-only.
    func setSensorFeedSink(_ sink: (any GlassesSensorFeedSink)?) async
    /// Ενημέρωση πολιτικής reconnect / background.
    func setReconnectPolicy(_ policy: GlassesReconnectPolicy) async
}
