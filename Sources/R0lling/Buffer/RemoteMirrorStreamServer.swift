import Foundation
import Network

/// Bonjour TCP listener (`_r0lling-mirror._tcp`) για JSON frame packets προς LAN clients.
/// Δεν στέλνει ακόμα καρέ από το glasses stream — χρειάζεται κλήση `broadcastFrame` από buffer/adapter.
public final class RemoteMirrorStreamServer: @unchecked Sendable {
    
    public struct MirrorFramePacket: Sendable, Codable {
        public let sequenceNumber: UInt64
        public let timestamp: Double
        public let frameWidth: Int
        public let frameHeight: Int
        public let payloadBase64: String
        public let activeNote: String?
        
        public init(
            sequenceNumber: UInt64,
            timestamp: Double = Date().timeIntervalSince1970,
            frameWidth: Int,
            frameHeight: Int,
            payloadBase64: String,
            activeNote: String? = nil
        ) {
            self.sequenceNumber = sequenceNumber
            self.timestamp = timestamp
            self.frameWidth = frameWidth
            self.frameHeight = frameHeight
            self.payloadBase64 = payloadBase64
            self.activeNote = activeNote
        }
    }
    
    private let lock = NSLock()
    private var listener: NWListener?
    private var activeConnections: [NWConnection] = []
    private var isRunning: Bool = false
    private var frameSequence: UInt64 = 0
    
    public var port: UInt16 = 8443
    public var onClientConnected: (@Sendable (Int) -> Void)?
    
    public init(port: UInt16 = 8443) {
        self.port = port
    }
    
    /// Έναρξη του Mirroring Server και Bonjour ανακοίνωσης
    public func startServer() throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isRunning else { return }
        
        let parameters = NWParameters.tcp
        let nwPort = NWEndpoint.Port(rawValue: port) ?? .init(integerLiteral: 8443)
        
        let newListener = try NWListener(using: parameters, on: nwPort)
        newListener.service = NWListener.Service(name: "R0lling-VisionMirror", type: "_r0lling-mirror._tcp")
        
        newListener.newConnectionHandler = { [weak self] connection in
            self?.handleIncomingConnection(connection)
        }
        
        newListener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                break
            case .failed(let err):
                print("[RemoteMirror] Server failed: \(err)")
            default:
                break
            }
        }
        
        newListener.start(queue: .global(qos: .userInteractive))
        self.listener = newListener
        self.isRunning = true
    }
    
    /// Τερματισμός του Server
    public func stopServer() {
        lock.lock()
        defer { lock.unlock() }
        
        for conn in activeConnections {
            conn.cancel()
        }
        activeConnections.removeAll()
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    /// Μετάδοση frame σε όλους τους συνδεδεμένους θεατές (Apple Vision Pro, Mac)
    public func broadcastFrame(imageData: Data, width: Int, height: Int, note: String? = nil) {
        lock.lock()
        let conns = activeConnections
        frameSequence &+= 1
        let seq = frameSequence
        lock.unlock()
        
        guard !conns.isEmpty else { return }
        
        let packet = MirrorFramePacket(
            sequenceNumber: seq,
            frameWidth: width,
            frameHeight: height,
            payloadBase64: imageData.base64EncodedString(),
            activeNote: note
        )
        
        guard let encodedData = try? JSONEncoder().encode(packet) else { return }
        let header = String(format: "%08d\n", encodedData.count).data(using: .utf8) ?? Data()
        var fullPacket = header
        fullPacket.append(encodedData)
        
        for conn in conns {
            conn.send(content: fullPacket, completion: .contentProcessed({ _ in }))
        }
    }
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        lock.lock()
        activeConnections.append(connection)
        let count = activeConnections.count
        lock.unlock()
        
        connection.start(queue: .global(qos: .userInteractive))
        onClientConnected?(count)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                self?.removeConnection(connection)
            default:
                break
            }
        }
    }
    
    private func removeConnection(_ connection: NWConnection) {
        lock.lock()
        activeConnections.removeAll(where: { $0 === connection })
        let count = activeConnections.count
        lock.unlock()
        onClientConnected?(count)
    }
    
    public var activeClientsCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeConnections.count
    }
    
    public var isServerActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunning
    }
}
