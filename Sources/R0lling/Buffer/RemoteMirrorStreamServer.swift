import Foundation
import Network

/// Bonjour TCP listener (`_r0lling-mirror._tcp`) για JSON frame packets προς LAN clients.
/// Δεν στέλνει ακόμα καρέ από το glasses stream — χρειάζεται κλήση `broadcastFrame` από buffer/adapter.
/// SEC-001: clients μπαίνουν σε broadcast pool ΜΟΝΟ μετά `AUTH <pairingToken>` · χωρίς token ο server δεν ξεκινά.
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
    /// Μόνο authenticated connections δέχονται frames (SEC-001).
    private var authenticatedConnections: [NWConnection] = []
    private var isRunning: Bool = false
    private var frameSequence: UInt64 = 0

    public var port: UInt16 = 8443
    /// Shared pairing token — υποχρεωτικό πριν `startServer` / `broadcastFrame`.
    public var pairingToken: String = ""
    public var onClientConnected: (@Sendable (Int) -> Void)?

    public init(port: UInt16 = 8443) {
        self.port = port
    }

    /// Έναρξη του Mirroring Server και Bonjour ανακοίνωσης (απαιτεί μη-κενό pairingToken).
    public func startServer() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isRunning else { return }

        let trimmedToken = pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw NSError(
                domain: "R0lling.RemoteMirror",
                code: 8401,
                userInfo: [NSLocalizedDescriptionKey: "Λείπει pairing token — Mirror δεν ξεκινά χωρίς AUTH secret."]
            )
        }
        pairingToken = trimmedToken

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

        for conn in authenticatedConnections {
            conn.cancel()
        }
        authenticatedConnections.removeAll()
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    /// Μετάδοση frame ΜΟΝΟ σε authenticated θεατές (SEC-001 fail-closed).
    public func broadcastFrame(imageData: Data, width: Int, height: Int, note: String? = nil) {
        lock.lock()
        let tokenOK = !pairingToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let conns = authenticatedConnections
        frameSequence &+= 1
        let seq = frameSequence
        lock.unlock()

        // Χωρίς pairing token ή χωρίς AUTH clients → καμία μετάδοση.
        guard tokenOK, !conns.isEmpty else { return }

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
        connection.start(queue: .global(qos: .userInteractive))
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                self?.removeConnection(connection)
            default:
                break
            }
        }
        // SEC-001: μην προσθέσεις στο pool πριν το AUTH handshake.
        receiveAuthChallenge(on: connection)
    }

    /// Περιμένει πρώτο μήνυμα `AUTH <token>\n` · αλλιώς κλείνει τη σύνδεση.
    private func receiveAuthChallenge(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }
            guard let data, !data.isEmpty,
                  let line = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) else {
                connection.cancel()
                return
            }

            let prefix = "AUTH "
            guard line.hasPrefix(prefix) else {
                connection.cancel()
                return
            }
            let provided = String(line.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            self.lock.lock()
            let expected = self.pairingToken
            self.lock.unlock()

            guard Self.tokensMatch(provided, expected) else {
                connection.cancel()
                return
            }

            self.lock.lock()
            self.authenticatedConnections.append(connection)
            let count = self.authenticatedConnections.count
            self.lock.unlock()
            self.onClientConnected?(count)
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        lock.lock()
        authenticatedConnections.removeAll(where: { $0 === connection })
        let count = authenticatedConnections.count
        lock.unlock()
        onClientConnected?(count)
    }

    /// Constant-time σύγκριση token (timing-safe όσο επιτρέπει equal-length gate).
    private static func tokensMatch(_ a: String, _ b: String) -> Bool {
        let aData = Array(a.utf8)
        let bData = Array(b.utf8)
        guard aData.count == bData.count, !aData.isEmpty else { return false }
        var result: UInt8 = 0
        for i in 0..<aData.count {
            result |= aData[i] ^ bData[i]
        }
        return result == 0
    }

    public var activeClientsCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return authenticatedConnections.count
    }

    public var isServerActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunning
    }
}
