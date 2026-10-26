import Foundation

/// Domi mias hmeras sto Visual Life Heatmap (Idea 6).
public struct MeraHeatmapDomi: Codable, Sendable, Equatable, Identifiable {
    public var id: String { imerominiaKey }
    public let imerominiaKey: String // YYYY-MM-DD
    public let arithmosEggrafwn: Int
    public let epipedoEntasis: Int    // 0: kamia, 1: xamili, 2: metria, 3: ypsili, 4: megisti
    public let exeiFotografia: Bool
    public let exeiFwnitiko: Bool
    public let deiktisParagwgikotitas: Double // 0.0 to 100.0

    public init(
        imerominiaKey: String,
        arithmosEggrafwn: Int,
        epipedoEntasis: Int,
        exeiFotografia: Bool = false,
        exeiFwnitiko: Bool = false,
        deiktisParagwgikotitas: Double = 0.0
    ) {
        self.imerominiaKey = imerominiaKey
        self.arithmosEggrafwn = arithmosEggrafwn
        self.epipedoEntasis = max(0, min(4, epipedoEntasis))
        self.exeiFotografia = exeiFotografia
        self.exeiFwnitiko = exeiFwnitiko
        self.deiktisParagwgikotitas = max(0.0, min(100.0, deiktisParagwgikotitas))
    }
}

/// Synolika apotelesmata analytics tou Life Heatmap gia to etos.
public struct PinakasHeatmapApotelesma: Codable, Sendable, Equatable {
    public let imeres: [MeraHeatmapDomi]
    public let synolikoPlithosEggrafwn: Int
    public let megistoSeriImerwn: Int
    public let trexonSeriImerwn: Int
    public let mesosOrosAnaMera: Double

    public init(
        imeres: [MeraHeatmapDomi],
        synolikoPlithosEggrafwn: Int,
        megistoSeriImerwn: Int,
        trexonSeriImerwn: Int,
        mesosOrosAnaMera: Double
    ) {
        self.imeres = imeres
        self.synolikoPlithosEggrafwn = synolikoPlithosEggrafwn
        self.megistoSeriImerwn = megistoSeriImerwn
        self.trexonSeriImerwn = trexonSeriImerwn
        self.mesosOrosAnaMera = mesosOrosAnaMera
    }
}

/// Visual Life Heatmap & Cognitive Analytics Engine (Idea 6)
/// Ypologizei tin katanomi drasthriotitas tou xristi (GitHub-style 365-day matrix),
/// ta streaks (seri katagrafwn) kai ton deikti paragwgikotitas/entos-stoxou.
public struct LifeHeatmapAnalyticsEngine: Sendable {

    public init() {}

    /// Ypologizei to heatmap pinaka gia mia lista apo hmerominies kai xaraktiristika eggrafwn.
    public func ypologismosHeatmap(
        eggrafesAnaImera: [String: (plithos: Int, exeiFoto: Bool, exeiFwni: Bool)],
        arxikiImerominia: Date = Date(),
        plithosImerwn: Int = 90
    ) -> PinakasHeatmapApotelesma {
        return R0llingTelemetry.shared.xronometrisi(.ui, leitourgia: "LifeHeatmap.ypologismos") {
            var imeres: [MeraHeatmapDomi] = []
            let calendar = Calendar.current
            var synoloEggrafwn = 0
            var trexonSeri = 0
            var megistoSeri = 0
            var diakopiSeri = false

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            for offset in (0..<plithosImerwn).reversed() {
                guard let targetDate = calendar.date(byAdding: .day, value: -offset, to: arxikiImerominia) else {
                    continue
                }
                let dateKey = formatter.string(from: targetDate)
                let data = eggrafesAnaImera[dateKey] ?? (0, false, false)
                let count = data.plithos
                synoloEggrafwn += count

                // Ypologismos Epipedou Entasis (0..4)
                let level: Int
                switch count {
                case 0: level = 0
                case 1...2: level = 1
                case 3...4: level = 2
                case 5...7: level = 3
                default: level = 4
                }

                // Ypologismos deikti paragwgikotitas (0..100)
                let baseScore = Double(min(count, 8)) * 10.0
                let bonusFoto = data.exeiFoto ? 10.0 : 0.0
                let bonusFwni = data.exeiFwni ? 10.0 : 0.0
                let score = min(100.0, baseScore + bonusFoto + bonusFwni)

                // Streaks calculation
                if count > 0 {
                    if !diakopiSeri { trexonSeri += 1 }
                } else {
                    if offset == 0 {
                        // Simera mporei na min exei grapsei akoma
                    } else {
                        diakopiSeri = true
                    }
                }

                imeres.append(
                    MeraHeatmapDomi(
                        imerominiaKey: dateKey,
                        arithmosEggrafwn: count,
                        epipedoEntasis: level,
                        exeiFotografia: data.exeiFoto,
                        exeiFwnitiko: data.exeiFwni,
                        deiktisParagwgikotitas: score
                    )
                )
            }

            // Calculate max streak across all days
            var cur = 0
            for item in imeres {
                if item.arithmosEggrafwn > 0 {
                    cur += 1
                    megistoSeri = max(megistoSeri, cur)
                } else {
                    cur = 0
                }
            }

            let mesosOros = plithosImerwn > 0 ? Double(synoloEggrafwn) / Double(plithosImerwn) : 0.0

            R0llingTelemetry.shared.log(
                .ui,
                stathmi: .debug,
                "LifeHeatmap: υπολογίστηκαν \(imeres.count) ημέρες, σύνολο \(synoloEggrafwn) εγγραφές, max streak: \(megistoSeri)"
            )

            return PinakasHeatmapApotelesma(
                imeres: imeres,
                synolikoPlithosEggrafwn: synoloEggrafwn,
                megistoSeriImerwn: megistoSeri,
                trexonSeriImerwn: trexonSeri,
                mesosOrosAnaMera: mesosOros
            )
        }
    }
}
