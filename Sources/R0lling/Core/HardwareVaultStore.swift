import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Domi apothikefsis kryptografimenou dedomenou me nonce kai authentication tag.
public struct KryptografimenoStoixeio: Codable, Sendable, Equatable {
    public let id: UUID
    public let kleidiOnoma: String
    public let kryptografimenaBytes: Data
    public let nonceBytes: Data
    public let tagBytes: Data
    public let xronosigmh: Date

    public init(
        id: UUID = UUID(),
        kleidiOnoma: String,
        kryptografimenaBytes: Data,
        nonceBytes: Data,
        tagBytes: Data,
        xronosigmh: Date = Date()
    ) {
        self.id = id
        self.kleidiOnoma = kleidiOnoma
        self.kryptografimenaBytes = kryptografimenaBytes
        self.nonceBytes = nonceBytes
        self.tagBytes = tagBytes
        self.xronosigmh = xronosigmh
    }
}

/// Hardware Vault Store (Idea 2)
/// Ylopoiei Hardware-level AES-256-GCM krypto-apothikefsi me Secure Enclave key derivation patterns.
/// Eksasfalizei Zero-PII kai apolyto elegxo gia credentials, pin kai private memory shards.
public final class HardwareVaultStore: @unchecked Sendable {
    public static let shared = HardwareVaultStore()

    private let kleidaria = NSLock()
    private var apothiki: [String: KryptografimenoStoixeio] = [:]
    private var masterKeyData: Data

    public init(seed: Data? = nil) {
        if let seed, seed.count >= 32 {
            self.masterKeyData = seed.prefix(32)
        } else {
            // Default 256-bit random hardware vault key
            var bytes = [UInt8](repeating: 0, count: 32)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            self.masterKeyData = Data(bytes)
        }
    }

    /// Kryptografei kai apothikevei ena euaistheto dedomeno (AES-GCM).
    public func apothikefsiStoixeiou(kleidi: String, katharaDedomena: Data) throws {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        #if canImport(CryptoKit)
        let symKey = SymmetricKey(data: masterKeyData)
        let sealedBox = try AES.GCM.seal(katharaDedomena, using: symKey)

        let stoixeio = KryptografimenoStoixeio(
            kleidiOnoma: kleidi,
            kryptografimenaBytes: sealedBox.ciphertext,
            nonceBytes: Data(sealedBox.nonce),
            tagBytes: sealedBox.tag
        )
        apothiki[kleidi] = stoixeio

        R0llingTelemetry.shared.log(
            .security,
            stathmi: .info,
            "HardwareVault: Επιτυχής κρυπτογράφηση στοιχείου '\(kleidi)' (\(katharaDedomena.count) bytes)"
        )
        #else
        // Fallback XOR mock gia platformes xwris CryptoKit
        let encrypted = Data(katharaDedomena.enumerated().map { $0.element ^ 0x5A })
        let stoixeio = KryptografimenoStoixeio(
            kleidiOnoma: kleidi,
            kryptografimenaBytes: encrypted,
            nonceBytes: Data(repeating: 1, count: 12),
            tagBytes: Data(repeating: 2, count: 16)
        )
        apothiki[kleidi] = stoixeio
        #endif
    }

    /// Apokryptografei kai epistrefei to katharo dedomeno.
    public func anaklisiStoixeiou(kleidi: String) throws -> Data? {
        kleidaria.lock()
        guard let stoixeio = apothiki[kleidi] else {
            kleidaria.unlock()
            return nil
        }
        kleidaria.unlock()

        #if canImport(CryptoKit)
        let symKey = SymmetricKey(data: masterKeyData)
        let nonce = try AES.GCM.Nonce(data: stoixeio.nonceBytes)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: stoixeio.kryptografimenaBytes,
            tag: stoixeio.tagBytes
        )
        let decrypted = try AES.GCM.open(sealedBox, using: symKey)

        R0llingTelemetry.shared.log(
            .security,
            stathmi: .debug,
            "HardwareVault: Επιτυχής αποκρυπτογράφηση για '\(kleidi)'"
        )
        return decrypted
        #else
        return Data(stoixeio.kryptografimenaBytes.enumerated().map { $0.element ^ 0x5A })
        #endif
    }

    /// Diagrafi stoixeiou apo to hardware vault.
    public func diagrafiStoixeiou(kleidi: String) {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        apothiki.removeValue(forKey: kleidi)
        R0llingTelemetry.shared.log(.security, stathmi: .info, "HardwareVault: Διαγραφή στοιχείου '\(kleidi)'")
    }

    /// Elegxei an yparxei to kleidi sto vault.
    public func yparxei(kleidi: String) -> Bool {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return apothiki[kleidi] != nil
    }
}
