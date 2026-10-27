import Foundation
import CryptoKit

/// Dedomena QR code gia to ephemeral P2P zeygari (Idea 17).
public struct DedomenaZeygariouQR: Sendable, Codable, Equatable {
    public let anagnwristikoSyskevis: String
    public let dimosioKleidiBase64: String
    public let xronosigmh: Date
    public let tyxaioNonce: String

    public init(
        anagnwristikoSyskevis: String,
        dimosioKleidiBase64: String,
        xronosigmh: Date = Date(),
        tyxaioNonce: String = UUID().uuidString
    ) {
        self.anagnwristikoSyskevis = anagnwristikoSyskevis
        self.dimosioKleidiBase64 = dimosioKleidiBase64
        self.xronosigmh = xronosigmh
        self.tyxaioNonce = tyxaioNonce
    }
}

/// Syntonistis Ephemeral P2P Zeygariou mesw QR Code & Curve25519 ECDH (Idea 17).
/// Diathetai alysida asfaleias xwris pro-koina kleidia:
/// 1. Paragei prosorino Curve25519 keypair gia to QR code
/// 2. Eksagei koinoxristo mistiko mesw HKDF-SHA256
/// 3. Epistrefei SymmetricKey 256-bit gia AES-GCM P2P sync
public final class SyntonistisP2PZeygariou: @unchecked Sendable {
    public static let shared = SyntonistisP2PZeygariou()

    private let kleidaria = NSLock()
    private var idiwtikoKleidi: Curve25519.KeyAgreement.PrivateKey?
    private var trexousaSynodouId: UUID?

    public init() {}

    /// Paragei neo QR code payload gia tin enarksi zeygariou.
    public func dimiourgiaNeouZeygariou(anagnwristikoSyskevis: String) throws -> (dedomenaQR: DedomenaZeygariouQR, qrString: String) {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        self.idiwtikoKleidi = privateKey
        let synodos = UUID()
        self.trexousaSynodouId = synodos

        let publicKeyData = privateKey.publicKey.rawRepresentation
        let pubBase64 = publicKeyData.base64EncodedString()

        let dedomena = DedomenaZeygariouQR(
            anagnwristikoSyskevis: anagnwristikoSyskevis,
            dimosioKleidiBase64: pubBase64
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(dedomena)
        let qrString = jsonData.base64EncodedString()

        R0llingTelemetry.shared.log(
            .security,
            stathmi: .info,
            "[P2PPairing] Δημιουργήθηκε νέο εφήμερο QR payload σύζευξης Curve25519 για τη συσκευή \(anagnwristikoSyskevis)"
        )

        return (dedomena, qrString)
    }

    /// Ypologizei to koinoxristo SymmetricKey apo ta dedomena pou sarwthikan apo to QR tis allis syskevis.
    public func oloklirwsiZeygariou(me dedomenaQR: DedomenaZeygariouQR, salt: Data? = nil) throws -> SymmetricKey {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        guard let myPrivateKey = self.idiwtikoKleidi else {
            throw NSError(domain: "R0lling.P2PPairing", code: 9101, userInfo: [
                NSLocalizedDescriptionKey: "Δεν βρέθηκε ενεργό ιδιωτικό κλειδί για την ολοκλήρωση της σύζευξης."
            ])
        }

        guard let peerKeyData = Data(base64Encoded: dedomenaQR.dimosioKleidiBase64),
              peerKeyData.count == 32 else {
            throw NSError(domain: "R0lling.P2PPairing", code: 9102, userInfo: [
                NSLocalizedDescriptionKey: "Μη έγκυρο δημόσιο κλειδί Curve25519 από το QR code."
            ])
        }

        let peerPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerKeyData)
        let sharedSecret = try myPrivateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)

        let symKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt ?? Data("R0lling.P2P.Salt".utf8),
            sharedInfo: Data(dedomenaQR.tyxaioNonce.utf8),
            outputByteCount: 32
        )

        // Diagrafi tou prosorinou idiwtikou kleidiou gia forward secrecy
        self.idiwtikoKleidi = nil
        self.trexousaSynodouId = nil

        R0llingTelemetry.shared.log(
            .security,
            stathmi: .info,
            "[P2PPairing] Επιτυχής ολοκλήρωση ECDH σύζευξης. Παράχθηκε εφήμερο κλειδί συνεδρίας 256-bit."
        )

        return symKey
    }
}
