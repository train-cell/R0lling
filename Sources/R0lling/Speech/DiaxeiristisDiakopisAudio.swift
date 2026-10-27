import Foundation

/// Katastasi tis fwnitikis diakopis (Audio Interruption).
public enum KatastasiDiakopisAudio: Sendable, Codable, Equatable {
    case kanoniki
    case seDiakopi(xronosEnarksis: Date, aitia: String)
    case anaktisi
}

/// Diaxeiristis Diakopwn Ixou kai Audio Session Lifecycle (Idea 9).
/// Diaxeirizetai simata diakopis (eiserxomenes tilefwnikes kliseis, Siri, synagermous)
/// kai allages diadromis (aposyndesi AirPods/Meta Glasses),
/// apotrepontas tin apwleia tou proigoumenou buffer fwnitikis shmeiwsis.
public final class DiaxeiristisDiakopisAudio: @unchecked Sendable {
    public static let shared = DiaxeiristisDiakopisAudio()

    private let kleidaria = NSLock()
    private var trexousaKatastasi: KatastasiDiakopisAudio = .kanoniki
    private var arithmosDiakopwn: Int = 0

    public init() {}

    /// Kaleitai otan ksekinaei mia diakopi ixou (AVAudioSession.InterruptionType.began).
    public func enarksiDiakopis(aitia: String = "Εισερχόμενη κλήση ή ειδοποίηση συστήματος") -> KatastasiDiakopisAudio {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        let tora = Date()
        trexousaKatastasi = .seDiakopi(xronosEnarksis: tora, aitia: aitia)
        arithmosDiakopwn += 1

        R0llingTelemetry.shared.log(
            .media,
            stathmi: .notice,
            "[AudioInterruption] Διακοπή ήχου ξεκίνησε: \(aitia). Πάγωμα buffer και αποθήκευση πρόχειρης κατάστασης."
        )

        return trexousaKatastasi
    }

    /// Kaleitai otan termatizetai mia diakopi ixou (AVAudioSession.InterruptionType.ended).
    public func termatismosDiakopis(prepeiNaSynexistei: Bool) -> KatastasiDiakopisAudio {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        if prepeiNaSynexistei {
            trexousaKatastasi = .anaktisi
            R0llingTelemetry.shared.log(
                .media,
                stathmi: .info,
                "[AudioInterruption] Η διακοπή έληξε με εντολή συνέχισης (shouldResume = true). Επανεκκίνηση ηχογράφησης."
            )
        } else {
            trexousaKatastasi = .kanoniki
            R0llingTelemetry.shared.log(
                .media,
                stathmi: .info,
                "[AudioInterruption] Η διακοπή έληξε οριστικά. Ολοκλήρωση τρέχουσας εγγραφής."
            )
        }

        return trexousaKatastasi
    }

    /// Epistrefei tin trexousa katastasi.
    public func laveKatastasi() -> KatastasiDiakopisAudio {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return trexousaKatastasi
    }

    /// Epistrefei to synoliko plithos diakopwn.
    public func laveArithmoDiakopwn() -> Int {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return arithmosDiakopwn
    }

    /// Epanekkinisi metritwn.
    public func epanekkinisi() {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        trexousaKatastasi = .kanoniki
        arithmosDiakopwn = 0
    }
}
