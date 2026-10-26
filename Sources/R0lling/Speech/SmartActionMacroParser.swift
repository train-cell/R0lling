import Foundation

/// Proteraiotita mias shmeiwshs i mias energeias pou anagnwrizetai apo ta macros.
public enum ProteraiotitaSimeiwsis: String, Sendable, CaseIterable, Codable {
    case urgent = "URGENT"
    case high = "HIGH"
    case normal = "NORMAL"
    case low = "LOW"
}

/// Apotelesma tis analysis tou keimenou gia eksagwgi syntaktikwn macros.
public struct DomiMacroApotelesma: Sendable, Codable, Equatable {
    public let arxikoKeimeno: String
    public let katharoKeimeno: String
    public let etiketes: [String]
    public let proteraiotita: ProteraiotitaSimeiwsis
    public let anafores: [String]
    public let energeies: [String]
    public let oriosigmi: String?

    public init(
        arxikoKeimeno: String,
        katharoKeimeno: String,
        etiketes: [String],
        proteraiotita: ProteraiotitaSimeiwsis,
        anafores: [String],
        energeies: [String],
        oriosigmi: String?
    ) {
        self.arxikoKeimeno = arxikoKeimeno
        self.katharoKeimeno = katharoKeimeno
        self.etiketes = etiketes
        self.proteraiotita = proteraiotita
        self.anafores = anafores
        self.energeies = energeies
        self.oriosigmi = oriosigmi
    }
}

/// Smart Action Macro Parser (Idea 5)
/// Anagnwrizei aytomata sto transcript fwnitikwn h grapthwn shmeiwsewn:
/// - Hashtags: `#task`, `#workout`, `#nutrition`, `#idea`, `#meeting`
/// - Proteraiotites: `!urgent`, `!high`, `!low`
/// - Anafores proswpwn: `@nikos`, `@maria`, `@coach`
/// - Xronika oria (Due dates): `due:tomorrow`, `at:18:00`, `due:2026-10-27`
/// Katharizei to keimeno wste to teliko display na einai krystalo, enw syndeei ta metadata.
public struct SmartActionMacroParser: Sendable {

    public init() {}

    public func epeksergasiaKeimenou(_ arxikoKeimeno: String) -> DomiMacroApotelesma {
        let trimmed = arxikoKeimeno.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return DomiMacroApotelesma(
                arxikoKeimeno: "",
                katharoKeimeno: "",
                etiketes: [],
                proteraiotita: .normal,
                anafores: [],
                energeies: [],
                oriosigmi: nil
            )
        }

        var etiketes: [String] = []
        var anafores: [String] = []
        var proteraiotita: ProteraiotitaSimeiwsis = .normal
        var oriosigmi: String? = nil
        var energeies: [String] = []

        // Tokens splitting
        let lekseis = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var katharesLekseis: [String] = []

        for leksi in lekseis {
            let lower = leksi.lowercased()

            // 1. Elegxos Proteraiotitas (!urgent, !high, !low, !normal)
            if lower == "!urgent" || lower == "!epeigon" {
                proteraiotita = .urgent
                continue
            } else if lower == "!high" || lower == "!ypsilo" {
                if proteraiotita != .urgent { proteraiotita = .high }
                continue
            } else if lower == "!low" || lower == "!xamilo" {
                if proteraiotita == .normal { proteraiotita = .low }
                continue
            }

            // 2. Elegxos Hashtags (#task, #gym, #food)
            if leksi.hasPrefix("#") && leksi.count > 1 {
                let tag = String(leksi.dropFirst()).trimmingCharacters(in: .punctuationCharacters)
                if !tag.isEmpty && !etiketes.contains(tag) {
                    etiketes.append(tag)
                    if tag.lowercased() == "task" || tag.lowercased() == "todo" {
                        energeies.append("TODO_CREATION")
                    }
                }
                continue
            }

            // 3. Elegxos Anaforwn (@coach, @maria)
            if leksi.hasPrefix("@") && leksi.count > 1 {
                let anafora = String(leksi.dropFirst()).trimmingCharacters(in: .punctuationCharacters)
                if !anafora.isEmpty && !anafores.contains(anafora) {
                    anafores.append(anafora)
                }
                continue
            }

            // 4. Elegxos Due Dates (due:tomorrow, due:2026-10-27)
            if lower.hasPrefix("due:") && lower.count > 4 {
                oriosigmi = String(leksi.dropFirst(4)).trimmingCharacters(in: .punctuationCharacters)
                continue
            } else if lower.hasPrefix("at:") && lower.count > 3 {
                if oriosigmi == nil {
                    oriosigmi = String(leksi.dropFirst(3)).trimmingCharacters(in: .punctuationCharacters)
                }
                continue
            }

            katharesLekseis.append(leksi)
        }

        let katharoKeimeno = katharesLekseis.joined(separator: " ")

        // Kataxwrish sto Telemetry me Zero-PII (mono metrites, oxi to idio to keimeno)
        R0llingTelemetry.shared.log(
            .journal,
            stathmi: .debug,
            "SmartActionMacroParser: επεξεργάστηκαν \(lekseis.count) λέξεις, βρέθηκαν \(etiketes.count) tags, \(anafores.count) mentions, προτεραιότητα: \(proteraiotita.rawValue)"
        )

        return DomiMacroApotelesma(
            arxikoKeimeno: arxikoKeimeno,
            katharoKeimeno: katharoKeimeno,
            etiketes: etiketes,
            proteraiotita: proteraiotita,
            anafores: anafores,
            energeies: energeies,
            oriosigmi: oriosigmi
        )
    }
}
