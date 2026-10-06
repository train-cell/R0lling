import Foundation

public enum GlassesConnectionState: Sendable, Equatable {
    case disconnected
    case searching
    case connecting
    case connected(deviceName: String, batteryPercent: Int?)
    case streaming(fps: Double, isBuffering: Bool)
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
        case .error(let msg): return "Σφάλμα: \(msg)"
        }
    }

    public var isLive: Bool {
        if case .streaming = self {
            return true
        }
        return false
    }
}

public protocol MetaGlassesAdapterProtocol: Sendable {
    var connectionState: GlassesConnectionState { get async }
    var isSimulationMode: Bool { get async }
    func connectDevice() async throws
    func disconnectDevice() async
    func startStreaming() async throws
    func stopStreaming() async
    func capturePhoto() async throws -> Data
    func toggleSimulationMode(enabled: Bool) async
}
