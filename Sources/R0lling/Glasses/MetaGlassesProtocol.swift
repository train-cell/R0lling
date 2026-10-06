import Foundation

/// Sink για acoustic / IMU feeds από Meta glasses → AppState (end-to-end feed API).
///
/// Τα `SUPER_FEATURE_*_FEED_WIRED` flags στο `AppState` ελέγχουν μόνο αν τα triggers
/// παράγουν auto-clip toasts. Η ροή δεδομένων περνάει πάντα από αυτό το protocol
/// ώστε το flip flag = 100% χωρίς νέο wiring.
public protocol GlassesSensorFeedSink: AnyObject {
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
        case .streaming(let fps, _): return "Ζωντανή ροή (\(Int(fps)) FPS)"
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

    public var isPaused: Bool {
        if case .paused = self {
            return true
        }
        return false
    }
}

public protocol MetaGlassesAdapterProtocol: Sendable {
    var connectionState: GlassesConnectionState { get async }
    var isSimulationMode: Bool { get async }
    var reconnectPolicy: GlassesReconnectPolicy { get async }
    func connectDevice() async throws
    func disconnectDevice() async
    func startStreaming() async throws
    func stopStreaming() async
    func capturePhoto() async throws -> Data
    func toggleSimulationMode(enabled: Bool) async
    /// A07: χειρισμός background / lock / foreground.
    func handleAppLifecycle(_ event: GlassesAppLifecycleEvent) async -> GlassesLifecycleOutcome
    /// Εγγραφή sink για acoustic + IMU (feed API end-to-end).
    func setSensorFeedSink(_ sink: (any GlassesSensorFeedSink)?) async
    /// Ενημέρωση πολιτικής reconnect / background.
    func setReconnectPolicy(_ policy: GlassesReconnectPolicy) async
}
