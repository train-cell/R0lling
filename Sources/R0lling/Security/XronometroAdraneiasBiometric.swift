import Foundation

/// Sfalma lhksis h akyrwsis viometrikis eksousiodotisis.
public enum SfalmaAdraneiasBiometric: Error, Sendable, Equatable {
    case elikseLogwAdraneias(diarkeiaSec: Double)
    case akyrwmeniEksousiodotisi
}

/// Xronometro Adraneias kai Auto-Revocation gia Viometrika Capability Tokens (Idea 4).
/// Epivalei afstiro xroniko parathyro leitourgias (TTL) 60-120 deuteroleptwn se kathe
/// energopoiisi tou EncryptedDiaryStore, akyrwnontas aytomata tin prosvasi se periptwsi
/// adraneias i allagis efarmogis (app switcher).
public final class XronometroAdraneiasBiometric: @unchecked Sendable {
    public static let shared = XronometroAdraneiasBiometric()

    private let kleidaria = NSLock()
    private var teleytaiaDrastiriotita: Date?
    private var orioTTLSec: TimeInterval = 90.0 // 90 seconds default inactivity timeout

    public init(orioTTLSec: TimeInterval = 90.0) {
        self.orioTTLSec = orioTTLSec
    }

    /// Enimerwnei ti xronosigmh teleytaias drastiriotitas tou xristi sto vault.
    public func enimerwsiDrastiriotitas(tora: Date = Date()) {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        teleytaiaDrastiriotita = tora
    }

    /// Epivevaiwnei an to biometric capability token einai akoma egkyro.
    public func epivevaiwsiEgkyrotitas(tora: Date = Date()) throws {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        guard let lastActive = teleytaiaDrastiriotita else {
            throw SfalmaAdraneiasBiometric.akyrwmeniEksousiodotisi
        }

        let adraneia = tora.timeIntervalSince(lastActive)
        if adraneia > orioTTLSec {
            teleytaiaDrastiriotita = nil
            R0llingTelemetry.shared.log(
                .security,
                stathmi: .notice,
                "[BiometricTTL] Η βιομετρική εξουσιοδότηση έληξε λόγω αδράνειας (\(Int(adraneia))s > \(Int(orioTTLSec))s). Αυτόματο κλείδωμα."
            )
            throw SfalmaAdraneiasBiometric.elikseLogwAdraneias(diarkeiaSec: adraneia)
        }

        teleytaiaDrastiriotita = tora
    }

    /// Akyrwnei amesa tin eksousiodotisi (p.x. kata to kleisimo tis efarmogis i kleidwma othwnis).
    public func amesiAkyrwsi() {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        teleytaiaDrastiriotita = nil
        R0llingTelemetry.shared.log(
            .security,
            stathmi: .info,
            "[BiometricTTL] Άμεση ανάκληση βιομετρικής εξουσιοδότησης."
        )
    }

    /// Elegxei an yparxei energopoihmeni synodos auth ti stigmi.
    public func einaiSynodosEnergi(tora: Date = Date()) -> Bool {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        guard let lastActive = teleytaiaDrastiriotita else { return false }
        return tora.timeIntervalSince(lastActive) <= orioTTLSec
    }
}
