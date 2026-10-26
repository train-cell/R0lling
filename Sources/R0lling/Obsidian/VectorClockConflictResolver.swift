import Foundation

/// Sxesi diataxis metafora dyo dianysmatikwn rologiwn (Vector Clocks).
public enum SxesiXronou: String, Sendable, Codable {
    case proigithike = "PROIGITHIKE"       // A < B (happened-before)
    case akolouthise = "AKOLOUTHISE"       // A > B (happened-after)
    case panomoiotypo = "PANOMOIOTYPO"     // A == B (identical)
    case tautoxrono = "TAUTOXRONO"         // A || B (concurrent conflict)
}

/// Dianysmatiko Roloï (Vector Clock) gia apolytws asfali, xwris sugkrouseis sugxronismo (CRDT-lite, Idea 3).
public struct DianysmatikoRoloϊ: Sendable, Codable, Equatable {
    public var komvoi: [String: UInt64]

    public init(komvoi: [String: UInt64] = [:]) {
        self.komvoi = komvoi
    }

    /// Afksanei to logiko roloi gia ton sygkekrimeno komvo (p.x. "iPhone", "Mac").
    public func afksisi(giaKomvo komvos: String) -> DianysmatikoRoloϊ {
        var neo = self
        let twn = neo.komvoi[komvos] ?? 0
        neo.komvoi[komvos] = twn &+ 1
        return neo
    }

    /// Enwnei dyo dianysmatika rologia pairnontas to megisto kathe komvou.
    public func sygxwnousi(me allo: DianysmatikoRoloϊ) -> DianysmatikoRoloϊ {
        var apotelesma = self.komvoi
        for (komvos, xronos) in allo.komvoi {
            let trexon = apotelesma[komvos] ?? 0
            apotelesma[komvos] = max(trexon, xronos)
        }
        return DianysmatikoRoloϊ(komvoi: apotelesma)
    }
}

/// Apotelesma sygxwneusis periexomenou me xrisi Vector Clock.
public struct ApotelesmaSygxwneusis<T: Sendable>: Sendable {
    public let epilymenoDedomeno: T
    public let eixeSigkrousi: Bool
    public let enomenoRoloi: DianysmatikoRoloϊ

    public init(epilymenoDedomeno: T, eixeSigkrousi: Bool, enomenoRoloi: DianysmatikoRoloϊ) {
        self.epilymenoDedomeno = epilymenoDedomeno
        self.eixeSigkrousi = eixeSigkrousi
        self.enomenoRoloi = enomenoRoloi
    }
}

/// Vector Clock Conflict Resolver (Idea 3)
/// Ylopoiei orismo diataxis Lamport / Mattern gia na apofasisei ean dyo ekdoseis mias shmeiwshs
/// sto Obsidian Vault einai diadoxikes h ean prokeitai gia taytoxronh allagh pou apaitei conflict resolution.
public struct VectorClockConflictResolver: Sendable {

    public init() {}

    /// Sygkrinei dyo dianysmatika rologia A kai B.
    public func sygkrishRologiwn(roloiA: DianysmatikoRoloϊ, roloiB: DianysmatikoRoloϊ) -> SxesiXronou {
        if roloiA == roloiB {
            return .panomoiotypo
        }

        var aMikroteroIsos = true
        var aMegalyteroIsos = true

        let oloiOiKomvoi = Set(roloiA.komvoi.keys).union(roloiB.komvoi.keys)

        for komvos in oloiOiKomvoi {
            let xronosA = roloiA.komvoi[komvos] ?? 0
            let xronosB = roloiB.komvoi[komvos] ?? 0

            if xronosA > xronosB {
                aMikroteroIsos = false
            }
            if xronosA < xronosB {
                aMegalyteroIsos = false
            }
        }

        if aMikroteroIsos && !aMegalyteroIsos {
            return .proigithike
        } else if aMegalyteroIsos && !aMikroteroIsos {
            return .akolouthise
        } else {
            return .tautoxrono
        }
    }

    /// Sygxwnevei dyo shmeiwseis me vasi ta rologia tous. Ean prokeitai gia taytoxroni allagi,
    /// xrisimopoiei Last-Write-Wins (LWW) me vasi tin teleytaia xronosigmh i enwnei ta metadata.
    public func sygxwneusiSimeiwsis(
        keimenoTopiko: String,
        roloiTopiko: DianysmatikoRoloϊ,
        xronosigmhTopiki: Date,
        keimenoApomakrysmeno: String,
        roloiApomakrysmeno: DianysmatikoRoloϊ,
        xronosigmhApomakrysmeni: Date
    ) -> ApotelesmaSygxwneusis<String> {
        let sxesi = sygkrishRologiwn(roloiA: roloiTopiko, roloiB: roloiApomakrysmeno)
        let enomenoRoloi = roloiTopiko.sygxwnousi(me: roloiApomakrysmeno)

        switch sxesi {
        case .panomoiotypo, .akolouthise:
            // To topiko einai pio prosfato i panomoiotypo
            return ApotelesmaSygxwneusis(
                epilymenoDedomeno: keimenoTopiko,
                eixeSigkrousi: false,
                enomenoRoloi: enomenoRoloi
            )

        case .proigithike:
            // To apomakrysmeno einai pio prosfato
            R0llingTelemetry.shared.log(
                .obsidian,
                stathmi: .info,
                "VectorClock: Εφαρμόστηκε απομακρυσμένη έκδοση σημείωσης (happened-after)"
            )
            return ApotelesmaSygxwneusis(
                epilymenoDedomeno: keimenoApomakrysmeno,
                eixeSigkrousi: false,
                enomenoRoloi: enomenoRoloi
            )

        case .tautoxrono:
            // Concurrent Conflict!
            R0llingTelemetry.shared.log(
                .obsidian,
                stathmi: .warning,
                "VectorClock: Εντοπίστηκε ταυτόχρονη τροποποίηση (CRDT conflict). Εφαρμογή LWW."
            )
            let epilymeno = xronosigmhTopiki >= xronosigmhApomakrysmeni ? keimenoTopiko : keimenoApomakrysmeno
            return ApotelesmaSygxwneusis(
                epilymenoDedomeno: epilymeno,
                eixeSigkrousi: true,
                enomenoRoloi: enomenoRoloi
            )
        }
    }
}
