import Foundation

/// Katastasi tis Live Activity sto Dynamic Island / Lock Screen (Idea 4).
public enum KatastasiDrasthriotitas: String, Codable, Sendable {
    case adranis = "ADRANIS"
    case katanomiRois = "ROH_METADAT"
    case ixografisiFwnis = "IXOGRAFISI_FWNIS"
    case epeksergasiaAI = "EPEKSERGASIA_AI"
    case termatismenos = "TERMATISMENOS"
}

/// Dedomena live activity gia glasses stream kai voice buffer.
public struct DedomenaLiveActivity: Codable, Sendable, Equatable {
    public let titlos: String
    public let katastasi: KatastasiDrasthriotitas
    public let diarkeiaSeconds: Double
    public let mpatariaStathmi: Double? // 0.0 to 1.0
    public let arithmosFrames: Int
    public let xronosigmhEnarksis: Date

    public init(
        titlos: String,
        katastasi: KatastasiDrasthriotitas,
        diarkeiaSeconds: Double = 0.0,
        mpatariaStathmi: Double? = nil,
        arithmosFrames: Int = 0,
        xronosigmhEnarksis: Date = Date()
    ) {
        self.titlos = titlos
        self.katastasi = katastasi
        self.diarkeiaSeconds = diarkeiaSeconds
        self.mpatariaStathmi = mpatariaStathmi
        self.arithmosFrames = arithmosFrames
        self.xronosigmhEnarksis = xronosigmhEnarksis
    }
}

/// Live Activity & Dynamic Island Coordinator (Idea 4)
/// Diaxeirizetai to lifecycle twn real-time ActivityKit visual cues sto Dynamic Island
/// kata ti diarkeiaMeta Glasses live streaming kai fwnitikis ypagorefsis.
public final class LiveActivityStreamingCoordinator: @unchecked Sendable {
    public static let shared = LiveActivityStreamingCoordinator()

    private let kleidaria = NSLock()
    private var trexousaDrasthriotita: DedomenaLiveActivity?

    public init() {}

    /// Enarksi live activity gia roh Meta Glasses h ixografisi.
    public func ksekinimaDrasthriotitas(titlos: String, katastasi: KatastasiDrasthriotitas, mpataria: Double? = nil) {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        let neo = DedomenaLiveActivity(
            titlos: titlos,
            katastasi: katastasi,
            diarkeiaSeconds: 0.0,
            mpatariaStathmi: mpataria,
            arithmosFrames: 0,
            xronosigmhEnarksis: Date()
        )
        trexousaDrasthriotita = neo

        R0llingTelemetry.shared.log(
            .glasses,
            stathmi: .info,
            "LiveActivityCoordinator: Έναρξη Dynamic Island activity '\(titlos)' (\(katastasi.rawValue))"
        )
    }

    /// Enimerwsi metrikwn (diarkeia, frames, stathmi mpatarias).
    public func enimerwsiMetrikwn(diarkeia: Double, frames: Int, mpataria: Double? = nil) {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        guard var trexon = trexousaDrasthriotita else { return }
        trexon = DedomenaLiveActivity(
            titlos: trexon.titlos,
            katastasi: trexon.katastasi,
            diarkeiaSeconds: diarkeia,
            mpatariaStathmi: mpataria ?? trexon.mpatariaStathmi,
            arithmosFrames: frames,
            xronosigmhEnarksis: trexon.xronosigmhEnarksis
        )
        trexousaDrasthriotita = trexon
    }

    /// Termatismos kai apomakrynsh tis live activity.
    public func termatismosDrasthriotitas() {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        if let trexon = trexousaDrasthriotita {
            R0llingTelemetry.shared.log(
                .glasses,
                stathmi: .info,
                "LiveActivityCoordinator: Τερματισμός Dynamic Island activity '\(trexon.titlos)' μετά από \(String(format: "%.1f", trexon.diarkeiaSeconds))s"
            )
        }
        trexousaDrasthriotita = nil
    }

    /// Epistrefei tin trekhousa katastasi tis drasthriotitas.
    public var trexonStigmiotypo: DedomenaLiveActivity? {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return trexousaDrasthriotita
    }
}
