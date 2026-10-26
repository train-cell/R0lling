import Foundation

/// Dedomena eisodou gia ti sysxetisi ygeias kai gnostikis katastasis (Idea 8).
public struct DedomenaYgeiasHmeras: Codable, Sendable, Equatable {
    public let imerominiaKey: String
    public let palmoiIremisBPM: Double?    // Resting Heart Rate (p.x. 55.0)
    public let hrvSDNNMs: Double?          // Heart Rate Variability (p.x. 65.0 ms)
    public let wresYpnou: Double?          // Sleep duration in hours (p.x. 7.5)
    public let bathmosREMPercent: Double?  // REM sleep percentage (p.x. 22.0)
    public let deiktisSentiment: Double    // -1.0 (poly arnhtiko) ews +1.0 (poly thetiko)
    public let plithosEggrafwn: Int

    public init(
        imerominiaKey: String,
        palmoiIremisBPM: Double? = nil,
        hrvSDNNMs: Double? = nil,
        wresYpnou: Double? = nil,
        bathmosREMPercent: Double? = nil,
        deiktisSentiment: Double = 0.0,
        plithosEggrafwn: Int = 0
    ) {
        self.imerominiaKey = imerominiaKey
        self.palmoiIremisBPM = palmoiIremisBPM
        self.hrvSDNNMs = hrvSDNNMs
        self.wresYpnou = wresYpnou
        self.bathmosREMPercent = bathmosREMPercent
        self.deiktisSentiment = max(-1.0, min(1.0, deiktisSentiment))
        self.plithosEggrafwn = plithosEggrafwn
    }
}

/// Apotelesma gnostikis sysxetisis ygeias kai mood.
public struct ApotelesmaSysxetisis: Codable, Sendable, Equatable {
    public let deiktisAnanewsisRecovery: Double // 0.0 to 100.0 (Readiness)
    public let epipedoStress: Double            // 0.0 to 100.0 (Stress)
    public let sysxetisiYpnouMood: Double       // Pearson r: -1.0 ews +1.0
    public let sysxetisiHRVMood: Double         // Pearson r: -1.0 ews +1.0
    public let symvouliEvexias: String

    public init(
        deiktisAnanewsisRecovery: Double,
        epipedoStress: Double,
        sysxetisiYpnouMood: Double,
        sysxetisiHRVMood: Double,
        symvouliEvexias: String
    ) {
        self.deiktisAnanewsisRecovery = max(0.0, min(100.0, deiktisAnanewsisRecovery))
        self.epipedoStress = max(0.0, min(100.0, epipedoStress))
        self.sysxetisiYpnouMood = max(-1.0, min(1.0, sysxetisiYpnouMood))
        self.sysxetisiHRVMood = max(-1.0, min(1.0, sysxetisiHRVMood))
        self.symvouliEvexias = symvouliEvexias
    }
}

/// HealthKit Cognitive Correlation Engine (Idea 8)
/// Efarmogi statistikis sysxetisis (Pearson correlation) anamesa sta vitals tou Apple Health
/// (Resting Heart Rate, HRV, Sleep stages) kai sto synaisthimatiko / paragwgiko fortio tou Hmerologiou.
public struct CognitiveHealthCorrelationEngine: Sendable {

    public init() {}

    /// Ypologizei to Pearson Correlation Coefficient metaksy dyo seirwn dedomenwn.
    public static func ypologismosPearson(x: [Double], y: [Double]) -> Double {
        guard x.count == y.count, x.count >= 2 else { return 0.0 }
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let meanX = sumX / n
        let meanY = sumY / n

        var numerator = 0.0
        var varX = 0.0
        var varY = 0.0

        for i in 0..<x.count {
            let diffX = x[i] - meanX
            let diffY = y[i] - meanY
            numerator += diffX * diffY
            varX += diffX * diffX
            varY += diffY * diffY
        }

        let denom = sqrt(varX) * sqrt(varY)
        guard denom > 0.0, denom.isFinite else { return 0.0 }
        let r = numerator / denom
        return max(-1.0, min(1.0, r.isFinite ? r : 0.0))
    }

    /// Ektelesi synolikis analysis sysxetisis gia mia xronoseira imerwn.
    public func analysiSysxetisis(istoriko: [DedomenaYgeiasHmeras]) -> ApotelesmaSysxetisis {
        return R0llingTelemetry.shared.xronometrisi(.health, leitourgia: "CognitiveHealth.analysi") {
            guard !istoriko.isEmpty else {
                return ApotelesmaSysxetisis(
                    deiktisAnanewsisRecovery: 50.0,
                    epipedoStress: 50.0,
                    sysxetisiYpnouMood: 0.0,
                    sysxetisiHRVMood: 0.0,
                    symvouliEvexias: "Δεν υπάρχουν επαρκή δεδομένα υγείας για στατιστική συσχέτιση."
                )
            }

            // Exagwgi zevgariwn gia sysxetisi ypnou kai mood
            var ypnouArray: [Double] = []
            var moodGiaYpno: [Double] = []

            var hrvArray: [Double] = []
            var moodGiaHRV: [Double] = []

            var synoloRecovery = 0.0
            var synoloStress = 0.0
            var egkyresImeres = 0

            for d in istoriko {
                if let sleep = d.wresYpnou {
                    ypnouArray.append(sleep)
                    moodGiaYpno.append(d.deiktisSentiment)
                }
                if let hrv = d.hrvSDNNMs {
                    hrvArray.append(hrv)
                    moodGiaHRV.append(d.deiktisSentiment)
                }

                // Ypologismos imerisias ananewsis (Recovery)
                var dailyRecovery = 50.0
                if let sleep = d.wresYpnou {
                    dailyRecovery += min(25.0, (sleep - 6.0) * 12.5)
                }
                if let hrv = d.hrvSDNNMs {
                    dailyRecovery += min(25.0, (hrv - 40.0) * 0.8)
                }
                dailyRecovery = max(0.0, min(100.0, dailyRecovery))
                synoloRecovery += dailyRecovery

                // Ypologismos stress
                var dailyStress = 40.0
                if let rhr = d.palmoiIremisBPM {
                    if rhr > 65.0 { dailyStress += min(30.0, (rhr - 65.0) * 2.0) }
                }
                if d.deiktisSentiment < 0.0 {
                    dailyStress += abs(d.deiktisSentiment) * 20.0
                }
                dailyStress = max(0.0, min(100.0, dailyStress))
                synoloStress += dailyStress

                egkyresImeres += 1
            }

            let avgRecovery = egkyresImeres > 0 ? synoloRecovery / Double(egkyresImeres) : 50.0
            let avgStress = egkyresImeres > 0 ? synoloStress / Double(egkyresImeres) : 50.0

            let rSleep = Self.ypologismosPearson(x: ypnouArray, y: moodGiaYpno)
            let rHRV = Self.ypologismosPearson(x: hrvArray, y: moodGiaHRV)

            // Dimiourgia symvoulis evexias
            let symvouli: String
            if avgRecovery > 70.0 {
                symvouli = "Υψηλή ετοιμότητα αποκατάστασης. Ιδανική ημέρα για βαθιά συγκέντρωση και δημιουργική εργασία."
            } else if avgStress > 65.0 {
                symvouli = "Αυξημένο γνωστικό στρες. Συνιστάται προγραμματισμός σύντομων διαλειμμάτων και ελαφρύ περπάτημα."
            } else {
                symvouli = "Ισορροπημένη κατάσταση ευεξίας και σταθερό καρδιακό φορτίο."
            }

            R0llingTelemetry.shared.log(
                .health,
                stathmi: .debug,
                "CognitiveHealth: ανάλυση \(egkyresImeres) ημερών (Recovery: \(String(format: "%.1f", avgRecovery)), Stress: \(String(format: "%.1f", avgStress)), rSleep: \(String(format: "%.2f", rSleep)))"
            )

            return ApotelesmaSysxetisis(
                deiktisAnanewsisRecovery: avgRecovery,
                epipedoStress: avgStress,
                sysxetisiYpnouMood: rSleep,
                sysxetisiHRVMood: rHRV,
                symvouliEvexias: symvouli
            )
        }
    }
}
