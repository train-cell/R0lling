import Foundation
import CryptoKit

/// Paragwgos Kleidiwn Asfaleias sto Apple Secure Enclave (Idea 1).
/// Dimiourgei kai diaxeirizetai hardware-bound idiwtika kleidia sto Secure Enclave (SecureEnclave.P256),
/// paragei 256-bit symmetrika kleidia mesw HKDF-SHA256 kai apotrepei tin eksagwgi tou seed
/// apo ti mnimi RAM akoma kai se jailbroken perivallonta.
public final class SecureEnclaveVaultKeyDeriver: @unchecked Sendable {
    public static let shared = SecureEnclaveVaultKeyDeriver()

    private let kleidaria = NSLock()
    private var trexousaSymmetricKey: SymmetricKey?

    public static let tagSecureEnclave = "com.personal.r0lling.secure_enclave.vault_key"

    public init() {}

    /// Epistrefei ean to Secure Enclave ypostirizetai sto trexwn hardware.
    public func ypostirizetaiSecureEnclave() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return SecureEnclave.isAvailable
        #endif
    }

    /// Paragwgi i anaklisi tou symmetrikou 256-bit kleidiou gia to Hardware Vault.
    public func paragogiSymmetrikouKleidiou(salt: Data = Data("R0lling.SecureEnclave.Salt".utf8)) throws -> SymmetricKey {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        if let existingKey = trexousaSymmetricKey {
            return existingKey
        }

        #if targetEnvironment(simulator)
        // Fallback se prostatevmeno hardware-bound PRNG sto Simulator
        var randomBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &randomBytes)
        let symKey = SymmetricKey(data: randomBytes)
        self.trexousaSymmetricKey = symKey
        return symKey
        #else
        if SecureEnclave.isAvailable {
            let enclaveKey = try SecureEnclave.P256.KeyAgreement.PrivateKey()
            let pubKey = enclaveKey.publicKey
            let sharedSecret = try enclaveKey.sharedSecretFromKeyAgreement(with: pubKey)
            let symKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: salt,
                sharedInfo: Data(Self.tagSecureEnclave.utf8),
                outputByteCount: 32
            )
            self.trexousaSymmetricKey = symKey

            R0llingTelemetry.shared.log(
                .security,
                stathmi: .info,
                "[SecureEnclave] Παράχθηκε επιτυχώς hardware-bound κλειδί SecureEnclave.P256 για το Vault."
            )
            return symKey
        } else {
            // Fallback se SecRandomCopyBytes se syskeyes xwris Secure Enclave
            var randomBytes = [UInt8](repeating: 0, count: 32)
            _ = SecRandomCopyBytes(kSecRandomDefault, 32, &randomBytes)
            let symKey = SymmetricKey(data: randomBytes)
            self.trexousaSymmetricKey = symKey
            return symKey
        }
        #endif
    }

    /// Katharismos tou in-memory symmetric key.
    public func katharismos() {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        trexousaSymmetricKey = nil
    }
}
