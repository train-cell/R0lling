import Foundation

/// Typos viometrikis metrisis gia statistiki anixnefsi anwmaliwn.
public enum TyposMetrisisYgeias: String, Sendable, Codable, CaseIterable {
    case palmousIremis = "resting_heart_rate" // RHR
    case hrvSDNN = "hrv_sdnn"
    case diarkeiaYpnouOres = "sleep_duration_hours"
    case anapnefstikiSyxnothta = "respiratory_rate"

    public var fysiologikaOria: ClosedRange<Double> {
        switch self {
        case .palmousIremis:
            return 30.0...220.0
        case .hrvSDNN:
            return 3.0...350.0
        case .diarkeiaYpnouOres:
            return 0.5...18.0
        case .anapnefstikiSyxnothta:
            return 6.0...45.0
        }
    }
}

/// Apotelesma anixnefsis mias anwmalou timis.
public struct ApotelesmaAnwmalias: Sendable, Codable, Equatable {
    public let timh: Double
    public let thesiIndex: Int
    public let aitia: String
    public let einaiAkrataAnwmalia: Bool

    public init(timh: Double, thesiIndex: Int, aitia: String, einaiAkrataAnwmalia: Bool) {
        self.timh = timh
        self.thesiIndex = thesiIndex
        self.aitia = aitia
        self.einaiAkrataAnwmalia = einaiAkrataAnwmalia
    }
}

/// Anixneftis Statistikwn Anwmaliwn Viometrikwn Dedomena (Idea 13).
/// Efrmozei Tukey's Fences (IQR) kai fisiologika katwflia gia na apomonwnei
/// artifacts aisthitirwn (p.x. 250 bpm apo metatopiisi tou Apple Watch kata ton ypno),
/// prostateuontas tis susxetiseis tou CognitiveHealthCorrelationEngine.
public struct AnixneftisAnwmaliwnYgeias: Sendable {

    public init() {}

    /// Ypologizei ta tetartimoria Q1, Q2 (median), Q3 enos taksinomimenou pinaka.
    public static func ypologismosTetartimoriwn(_ deigmata: [Double]) -> (q1: Double, median: Double, q3: Double)? {
        guard deigmata.count >= 4 else { return nil }
        let taksinomimena = deigmata.sorted()
        let n = taksinomimena.count

        let median: Double
        if n % 2 == 0 {
            median = (taksinomimena[n / 2 - 1] + taksinomimena[n / 2]) / 2.0
        } else {
            median = taksinomimena[n / 2]
        }

        let katwMiso = Array(taksinomimena[0..<(n / 2)])
        let anwMiso = (n % 2 == 0) ? Array(taksinomimena[(n / 2)..<n]) : Array(taksinomimena[(n / 2 + 1)..<n])

        func diamesos(_ pinakas: [Double]) -> Double {
            let m = pinakas.count
            guard m > 0 else { return 0.0 }
            if m % 2 == 0 {
                return (pinakas[m / 2 - 1] + pinakas[m / 2]) / 2.0
            } else {
                return pinakas[m / 2]
            }
        }

        return (q1: diamesos(katwMiso), median: median, q3: diamesos(anwMiso))
    }

    /// Katharizei ta deigmata apo fysiologika kai statistika outliers.
    public static func katharismosDeigmatwn(
        _ deigmata: [Double],
        typos: TyposMetrisisYgeias,
        syntelestisIQR: Double = 1.5
    ) -> (kathara: [Double], anwmalies: [ApotelesmaAnwmalias]) {
        guard !deigmata.isEmpty else { return ([], []) }

        var anwmalies: [ApotelesmaAnwmalias] = []
        var prosorinaKathara: [(index: Int, timh: Double)] = []

        let fysiologika = typos.fysiologikaOria

        // Vima 1: Elegxos Fysiologikwn Oriwn Hardware
        for (idx, timh) in deigmata.enumerated() {
            if !timh.isFinite || timh.isNaN {
                anwmalies.append(
                    ApotelesmaAnwmalias(
                        timh: timh,
                        thesiIndex: idx,
                        aitia: "Μη πεπερασμένη τιμή (NaN/Infinity)",
                        einaiAkrataAnwmalia: true
                    )
                )
            } else if !fysiologika.contains(timh) {
                anwmalies.append(
                    ApotelesmaAnwmalias(
                        timh: timh,
                        thesiIndex: idx,
                        aitia: "Εκτός φυσιολογικών ορίων [\(fysiologika.lowerBound), \(fysiologika.upperBound)]",
                        einaiAkrataAnwmalia: true
                    )
                )
            } else {
                prosorinaKathara.append((index: idx, timh: timh))
            }
        }

        // Vima 2: Tukey's Fences (an yparxoun toulaxiston 4 egkyra deigmata)
        let egkyresTimes = prosorinaKathara.map { $0.timh }
        if let quartiles = ypologismosTetartimoriwn(egkyresTimes) {
            let iqr = quartiles.q3 - quartiles.q1
            if iqr > 0.0 {
                let katwOrio = quartiles.q1 - (syntelestisIQR * iqr)
                let anwOrio = quartiles.q3 + (syntelestisIQR * iqr)

                var telikaKathara: [Double] = []
                for stoixeio in prosorinaKathara {
                    if stoixeio.timh < katwOrio || stoixeio.timh > anwOrio {
                        anwmalies.append(
                            ApotelesmaAnwmalias(
                                timh: stoixeio.timh,
                                thesiIndex: stoixeio.index,
                                aitia: "Στατιστικό Tukey outlier εκτός [\(String(format: "%.1f", katwOrio)), \(String(format: "%.1f", anwOrio))]",
                                einaiAkrataAnwmalia: false
                            )
                        )
                    } else {
                        telikaKathara.append(stoixeio.timh)
                    }
                }
                return (telikaKathara, anwmalies)
            }
        }

        return (egkyresTimes, anwmalies)
    }
}
