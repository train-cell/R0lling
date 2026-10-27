import Foundation

/// Apotelesma katharismou fwnitikis eisodou enanti injection επιθέσεων.
public struct ApotelesmaKatharismouFwnis: Sendable, Codable, Equatable {
    public let einaiAsfales: Bool
    public let katharismenoKeimeno: String
    public let anixnefthikesApeiles: [String]

    public init(
        einaiAsfales: Bool,
        katharismenoKeimeno: String,
        anixnefthikesApeiles: [String]
    ) {
        self.einaiAsfales = einaiAsfales
        self.katharismenoKeimeno = katharismenoKeimeno
        self.anixnefthikesApeiles = anixnefthikesApeiles
    }
}

/// Katharistis Fwnitikwn Entolwn kai Prompt Injection Sanitizer (Idea 5).
/// Anixneyei kai apomadrynei prospathies xeiragwgisis tou AI Agent i twn Macros
/// apo kakoivoules fwnitikes fraseis (p.x. "Ignore previous instructions", "<system>",
/// "drop table", "export all notes", delimiter injection).
public struct KatharistisEntolwnFwnis: Sendable {

    /// Katagrafi epikindynwn frasewn injection se fwnitika transcripts.
    public static let epikindynaPatterns: [String] = [
        "ignore previous instructions",
        "ignore all previous",
        "system prompt",
        "<system>",
        "</system>",
        "[system]",
        "[/system]",
        "export all notes",
        "export vault",
        "drop table",
        "delete all notes",
        "override safety"
    ]

    public init() {}

    /// Katharizei tin eiserxomeni fwnitiki frasi kai eksoudeterwnei ta epikindyna patterns.
    public static func katharismosFwnitikisEisodou(_ eiserxomeno: String) -> ApotelesmaKatharismouFwnis {
        let trimmed = eiserxomeno.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ApotelesmaKatharismouFwnis(
                einaiAsfales: true,
                katharismenoKeimeno: "",
                anixnefthikesApeiles: []
            )
        }

        var katharo = trimmed
        var apeiles: [String] = []

        let peza = trimmed.lowercased()

        for pattern in epikindynaPatterns {
            if peza.contains(pattern) {
                apeiles.append(pattern)
                // Eksoudeterwsi tou injection pattern me [SAFE_VOICE_BLOCKED]
                let regexPattern = "(?i)" + NSRegularExpression.escapedPattern(for: pattern)
                katharo = katharo.replacingOccurrences(
                    of: regexPattern,
                    with: "[SAFE_VOICE_BLOCKED]",
                    options: .regularExpression
                )
            }
        }

        let asfales = apeiles.isEmpty

        if !asfales {
            R0llingTelemetry.shared.log(
                .security,
                stathmi: .warning,
                "[VoiceGuard] Εντοπίστηκε και εξουδετερώθηκε \(apeiles.count) πιθανό injection pattern στη φωνητική καταγραφή."
            )
        }

        return ApotelesmaKatharismouFwnis(
            einaiAsfales: asfales,
            katharismenoKeimeno: katharo,
            anixnefthikesApeiles: apeiles
        )
    }
}
