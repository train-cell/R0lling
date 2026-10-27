import Foundation

/// Katastasi leitourgias asfaleias meta apo anixnefsi synexomenwn krasarismatwn (Crash Loop).
public struct KatastasiAsfalousLeitourgias: Sendable, Codable, Equatable {
    public let einaiEnergi: Bool
    public let arithmosSynexomenwnCrash: Int
    public let teleytaiaXronosigmhCrash: Date?
    public let aitia: String?

    public init(
        einaiEnergi: Bool,
        arithmosSynexomenwnCrash: Int,
        teleytaiaXronosigmhCrash: Date?,
        aitia: String? = nil
    ) {
        self.einaiEnergi = einaiEnergi
        self.arithmosSynexomenwnCrash = arithmosSynexomenwnCrash
        self.teleytaiaXronosigmhCrash = teleytaiaXronosigmhCrash
        self.aitia = aitia
    }
}

/// Anixneftis Crash-Loop kai Diaxeiristis Asfalous Leitourgias (Safe Mode) gia to R0lling (Idea 11).
/// Ean i efarmogi krasarei 2 synexomenes fores mesa se diastima <10 deuteroleptwn apo to launch,
/// energopoieitai to Safe Mode gia parakampsi fthoras se caches kai proslipsi eksoterikwn syskeywn.
public final class AsfalesLeitourgiaDetector: @unchecked Sendable {
    public static let shared = AsfalesLeitourgiaDetector()

    private let kleidaria = NSLock()
    private let defaults: UserDefaults

    public static let kleidiArithmouCrash = "r0lling.telemetry.crash_loop_count"
    public static let kleidiXronouEkkinisis = "r0lling.telemetry.last_launch_timestamp"
    public static let kleidiAsfalousLeitourgias = "r0lling.telemetry.safe_mode_active"

    public static let katwfliCrashGiaAsfales = 2
    public static let orionDiarkeiasCrashSeDeyterolepta: TimeInterval = 10.0

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Katagrafei tin enarksi mias neas ekkinisis tis efarmogis.
    /// Elegxei an i proigoumeni ekkinisi krasare mesa sto kritiko xroniko parathyro.
    @discardableResult
    public func katagrafiEnarksisEkkinisis(tora: Date = Date()) -> KatastasiAsfalousLeitourgias {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        var metritisCrash = defaults.integer(forKey: Self.kleidiArithmouCrash)
        let proigoumenoLaunch = defaults.object(forKey: Self.kleidiXronouEkkinisis) as? Date

        if let proigoumenoLaunch {
            let diaforaXronou = tora.timeIntervalSince(proigoumenoLaunch)
            // An to proigoumeno session teleiwse mesa sto kritiko parathyro xwris na ginei
            // epityxhs apodesmeysh, thewreitai crash sto launch
            if diaforaXronou >= 0 && diaforaXronou <= Self.orionDiarkeiasCrashSeDeyterolepta {
                metritisCrash += 1
            } else {
                // To proigoumeno session etrekse kanonika
                metritisCrash = 0
            }
        }

        defaults.set(metritisCrash, forKey: Self.kleidiArithmouCrash)
        defaults.set(tora, forKey: Self.kleidiXronouEkkinisis)

        let energopoihshSafeMode = metritisCrash >= Self.katwfliCrashGiaAsfales
        defaults.set(energopoihshSafeMode, forKey: Self.kleidiAsfalousLeitourgias)

        if energopoihshSafeMode {
            R0llingTelemetry.shared.log(
                .security,
                stathmi: .fault,
                "[CrashLoop] Εντοπίστηκαν \(metritisCrash) διαδοχικά κρασαρίσματα κατά την εκκίνηση. Ενεργοποίηση Safe Mode."
            )
        }

        return KatastasiAsfalousLeitourgias(
            einaiEnergi: energopoihshSafeMode,
            arithmosSynexomenwnCrash: metritisCrash,
            teleytaiaXronosigmhCrash: proigoumenoLaunch,
            aitia: energopoihshSafeMode ? "Crash loop (\(metritisCrash) αποτυχημένες εκκινήσεις <10s)" : nil
        )
    }

    /// Kaleitai otan i efarmogi exei ektelestei me asfaleia gia perissotero apo to kritiko parathyro
    /// oste na midenistei o metritis krasarismatwn.
    public func katagrafiStatherisLeitourgias() {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        defaults.set(0, forKey: Self.kleidiArithmouCrash)
        defaults.set(false, forKey: Self.kleidiAsfalousLeitourgias)
        defaults.removeObject(forKey: Self.kleidiXronouEkkinisis)

        R0llingTelemetry.shared.log(.ui, stathmi: .info, "[CrashLoop] Επιβεβαιώθηκε σταθερή λειτουργία. Μηδενισμός μετρητή crash loop.")
    }

    /// Epistrefei an to Safe Mode einai energi auti ti stigmi.
    public func einaiAsfalisLeitourgiaEnergi() -> Bool {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return defaults.bool(forKey: Self.kleidiAsfalousLeitourgias)
    }

    /// Apenergopoiei xeirokinita to Safe Mode meta apo apokatastasi.
    public func apenergopoiisiAsfalousLeitourgias() {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        defaults.set(0, forKey: Self.kleidiArithmouCrash)
        defaults.set(false, forKey: Self.kleidiAsfalousLeitourgias)
        defaults.removeObject(forKey: Self.kleidiXronouEkkinisis)
        R0llingTelemetry.shared.log(.security, stathmi: .notice, "[CrashLoop] Χειροκίνητη απενεργοποίηση Safe Mode.")
    }
}
