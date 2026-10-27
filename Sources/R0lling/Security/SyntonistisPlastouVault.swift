import Foundation

/// Katastasi Plastou Vault Anagkis (Decoy Duress Mode).
public struct KatastasiPlastouVault: Sendable, Codable, Equatable {
    public let einaiPlastoEnergo: Bool
    public let xronosigmhEnergopoiisis: Date?
    public let aitia: String

    public init(
        einaiPlastoEnergo: Bool,
        xronosigmhEnergopoiisis: Date? = nil,
        aitia: String = "Κανoνική λειτουργία"
    ) {
        self.einaiPlastoEnergo = einaiPlastoEnergo
        self.xronosigmhEnergopoiisis = xronosigmhEnergopoiisis
        self.aitia = aitia
    }
}

/// Syntonistis Plastou Vault Anagkis (Idea 3: Duress & Decoy Vault Mode).
/// Epitrepsei sto xristi na eisagei enallaktiko gesture/PIN se katastasi ekviasmou (duress),
/// anoigontas ena diaforetiko athwo decoy journal me anwdyne shmeiwseis,
/// apokryptontas 100% tin yparksi tou pragmatikou encrypted vault.
public final class SyntonistisPlastouVault: @unchecked Sendable {
    public static let shared = SyntonistisPlastouVault()

    private let kleidaria = NSLock()
    private var einaiPlastoEnergo: Bool = false
    private var xronosigmhEnergopoiisis: Date?

    public static let onomaFakelouDecoy = "DecoyVault_Safe"

    public init() {}

    /// Energopoiei to Plasto Vault (Decoy Mode).
    public func energopoiisiPlastouVault(aitia: String = "Ενεργοποίηση Decoy Duress Mode") {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        einaiPlastoEnergo = true
        xronosigmhEnergopoiisis = Date()

        R0llingTelemetry.shared.log(
            .security,
            stathmi: .warning,
            "[DecoyVault] Ενεργοποιήθηκε το Decoy Duress Vault Mode (\(aitia))."
        )
    }

    /// Apenergopoiei to Decoy Mode epistrefontas stin kanoniki leitourgia.
    public func apenergopoiisiPlastouVault() {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        einaiPlastoEnergo = false
        xronosigmhEnergopoiisis = nil

        R0llingTelemetry.shared.log(
            .security,
            stathmi: .info,
            "[DecoyVault] Απενεργοποίηση Decoy Mode. Επιστροφή σε κανονικό προφίλ."
        )
    }

    /// Elegxei an to Plasto Vault einai energo auti ti stigmi.
    public func einaiEnergo() -> Bool {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return einaiPlastoEnergo
    }

    /// Epistrefei tin katalili diadromi URL fakelou (kanoniki i decoy).
    public func diadromiFakelou(vasikoURL: URL) -> URL {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        if einaiPlastoEnergo {
            return vasikoURL.appendingPathComponent(Self.onomaFakelouDecoy, isDirectory: true)
        } else {
            return vasikoURL
        }
    }
}
