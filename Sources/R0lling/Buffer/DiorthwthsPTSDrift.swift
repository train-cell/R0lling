import Foundation

/// Frame me dedomena xronosigmis PTS.
public struct FrameXronouPTS: Sendable, Codable, Equatable {
    public let arithmosSeiras: UInt64
    public let ptsDeyterolepta: Double
    public let einaiKeyframe: Bool
    public let diarkeiaSeDeyterolepta: Double

    public init(
        arithmosSeiras: UInt64,
        ptsDeyterolepta: Double,
        einaiKeyframe: Bool = false,
        diarkeiaSeDeyterolepta: Double = 1.0 / 30.0
    ) {
        self.arithmosSeiras = arithmosSeiras
        self.ptsDeyterolepta = ptsDeyterolepta
        self.einaiKeyframe = einaiKeyframe
        self.diarkeiaSeDeyterolepta = diarkeiaSeDeyterolepta
    }
}

/// Diorthwths PTS Drift kai Out-Of-Order Frames (Idea 8).
/// Epitygxanei afstiri monotonikotita sta presentation timestamps (PTS) tou video stream
/// apo ta Meta Glasses, prosthateuontas ton H264 remuxer apo krasarisma ean ta Bluetooth packets
/// fthasoun anapodogyrismena i me megales xronikes diastolous (jitter).
public final class DiorthwthsPTSDrift: @unchecked Sendable {
    public static let shared = DiorthwthsPTSDrift()

    private let kleidaria = NSLock()
    private var teleytaioPTS: Double = -1.0
    private var proigoumenosArithmosSeiras: UInt64 = 0
    public static let proepilegmeniDiarkeiaFrame: Double = 1.0 / 30.0 // 30 fps
    public static let megistoApodektoJitterSec: Double = 0.500 // 500 ms

    public init() {}

    /// Katharismos tou state gia neo streaming session.
    public func epanekkinisi() {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        teleytaioPTS = -1.0
        proigoumenosArithmosSeiras = 0
    }

    /// Diorthwnei to PTS enos eiserxomenou frame oste na einai panta afstira monotoniko.
    public func diorthwsiPTS(eiserxomeno: FrameXronouPTS) -> FrameXronouPTS {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        var diorthwmenoPTS = eiserxomeno.ptsDeyterolepta

        // An to frame exei arnhtiko i mh-peperasmeno PTS
        if !diorthwmenoPTS.isFinite || diorthwmenoPTS < 0.0 {
            diorthwmenoPTS = (teleytaioPTS >= 0.0) ? (teleytaioPTS + Self.proepilegmeniDiarkeiaFrame) : 0.0
        }

        // Elegxos Monotonikotitas: Ean to eiserxomeno PTS einai <= teleytaioPTS (out-of-order)
        if teleytaioPTS >= 0.0 && diorthwmenoPTS <= teleytaioPTS {
            let palioPTS = diorthwmenoPTS
            diorthwmenoPTS = teleytaioPTS + eiserxomeno.diarkeiaSeDeyterolepta

            R0llingTelemetry.shared.log(
                .media,
                stathmi: .warning,
                "[PTSCorrection] Εντοπίστηκε out-of-order frame (PTS: \(palioPTS) <= \(teleytaioPTS)). Διορθώθηκε σε: \(diorthwmenoPTS)"
            )
        }

        // Elegxos Ypervolikou Jitter sto mellon
        if teleytaioPTS >= 0.0 && (diorthwmenoPTS - teleytaioPTS) > Self.megistoApodektoJitterSec {
            let jitter = diorthwmenoPTS - teleytaioPTS
            R0llingTelemetry.shared.log(
                .media,
                stathmi: .notice,
                "[PTSCorrection] Εντοπίστηκε μεγάλο χρονικό κενό/jitter (\(jitter)s). Διατηρείται μονοτονική συνέχεια."
            )
        }

        teleytaioPTS = diorthwmenoPTS
        proigoumenosArithmosSeiras = eiserxomeno.arithmosSeiras

        return FrameXronouPTS(
            arithmosSeiras: eiserxomeno.arithmosSeiras,
            ptsDeyterolepta: diorthwmenoPTS,
            einaiKeyframe: eiserxomeno.einaiKeyframe,
            diarkeiaSeDeyterolepta: eiserxomeno.diarkeiaSeDeyterolepta
        )
    }

    /// Epistrefei to teleytaio katagegrammeno PTS.
    public func laveTeleytaioPTS() -> Double {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return teleytaioPTS
    }
}
