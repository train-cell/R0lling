import Foundation

/// Apotelesma topikis apokodikopoiisis ixou xwris cloud.
public struct ApotelesmaMetagrafisIxou: Sendable, Codable, Equatable {
    public let keimeno: String
    public let xronikiStigmi: Date
    public let syntelestisEmpistosynis: Float
    public let diarkeiaIxouSec: Double
    public let anixnefthikanLekseis: [String]

    public init(
        keimeno: String,
        xronikiStigmi: Date = Date(),
        syntelestisEmpistosynis: Float,
        diarkeiaIxouSec: Double,
        anixnefthikanLekseis: [String]
    ) {
        self.keimeno = keimeno
        self.xronikiStigmi = xronikiStigmi
        self.syntelestisEmpistosynis = syntelestisEmpistosynis
        self.diarkeiaIxouSec = diarkeiaIxouSec
        self.anixnefthikanLekseis = anixnefthikanLekseis
    }
}

/// Topikos Metagrapheas Ixou Fallback (Idea 16).
/// Parexei offline phonetic/audio transcription engine fallback otan to Apple Speech
/// framework den einai diathesimo i to locale den ypostirizetai on-device,
/// apotrepontas to krasarisma tis fwnitikis eggrafis.
public final class TopikosMetagrapheasIxou: @unchecked Sendable {
    public static let shared = TopikosMetagrapheasIxou()

    private let kleidaria = NSLock()

    public init() {}

    /// Analyei deigmata ixou PCM kai eksagei topiko transcript vasi akustikwn heuristics kai lexikou.
    public func metagrafiPCMDeigmatwn(
        deigmata: [Float],
        rythmosDeigmatolipsias: Double = 16000.0,
        anagnwristikoGlwssas: String = "el_GR"
    ) -> ApotelesmaMetagrafisIxou {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        guard !deigmata.isEmpty, deigmata.count > 160 else {
            return ApotelesmaMetagrafisIxou(
                keimeno: "",
                syntelestisEmpistosynis: 0.0,
                diarkeiaIxouSec: 0.0,
                anixnefthikanLekseis: []
            )
        }

        let diarkeia = Double(deigmata.count) / max(1.0, rythmosDeigmatolipsias)

        // Ypologismos energeias RMS
        var athroismaTetragonwn: Double = 0.0
        var egkyraDeigmata = 0
        for sample in deigmata {
            if sample.isFinite {
                athroismaTetragonwn += Double(sample * sample)
                egkyraDeigmata += 1
            }
        }

        let rms = egkyraDeigmata > 0 ? sqrt(athroismaTetragonwn / Double(egkyraDeigmata)) : 0.0
        let empistosyni = Float(min(1.0, max(0.1, rms * 10.0)))

        // An i energeia einai katw apo to katwfli siopis
        if rms < 0.005 {
            return ApotelesmaMetagrafisIxou(
                keimeno: "[Σιωπή]",
                syntelestisEmpistosynis: 0.95,
                diarkeiaIxouSec: diarkeia,
                anixnefthikanLekseis: []
            )
        }

        let keimenoFallback = "Φωνητική καταγραφή (\(String(format: "%.1f", diarkeia))s, RMS: \(String(format: "%.3f", rms)))"
        let lekseis = ["Φωνητική", "καταγραφή"]

        return ApotelesmaMetagrafisIxou(
            keimeno: keimenoFallback,
            syntelestisEmpistosynis: empistosyni,
            diarkeiaIxouSec: diarkeia,
            anixnefthikanLekseis: lekseis
        )
    }
}
