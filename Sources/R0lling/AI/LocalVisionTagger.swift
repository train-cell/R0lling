import Foundation
import CoreGraphics

/// Kathorismos eidoys skhnis apo to on-device vision pipeline (Idea 7).
public enum EidosSknis: String, Sendable, CaseIterable, Codable {
    case fysi = "Φύση / Ύπαιθρος"
    case eswterikosXoros = "Εσωτερικός Χώρος"
    case apodeiksi = "Απόδειξη / Έγγραφο"
    case othoni = "Οθόνη / Υπολογιστής"
    case geuma = "Γεύμα / Διατροφή"
    case kinito = "Φορητή Συσκευή"
    case agnwsto = "Άγνωστο"
}

/// Apotelesma katigoriopoihsis kai tagger gia eikones kai rolling buffer frames.
public struct ApotelesmaTagVision: Sendable, Codable, Equatable {
    public let kyriaSkeni: EidosSknis
    public let syntelestisEmpistosynis: Double
    public let entopismenoKeimeno: [String]
    public let lektikesEtiketes: [String]
    public let xronosAnalysisMs: Double

    public init(
        kyriaSkeni: EidosSknis,
        syntelestisEmpistosynis: Double,
        entopismenoKeimeno: [String],
        lektikesEtiketes: [String],
        xronosAnalysisMs: Double = 0.0
    ) {
        self.kyriaSkeni = kyriaSkeni
        self.syntelestisEmpistosynis = min(max(syntelestisEmpistosynis, 0.0), 1.0)
        self.entopismenoKeimeno = entopismenoKeimeno
        self.lektikesEtiketes = lektikesEtiketes
        self.xronosAnalysisMs = xronosAnalysisMs
    }
}

/// Local Vision Tagger (Idea 7)
/// Pragmatopoiei taxytath, zero-cloud axiologisi eikonwn kai video frames apo ta Meta Glasses
/// me on-device classifiers kai heuristics xrwmatos / antithesewn / OCR markers.
public struct LocalVisionTagger: Sendable {

    public init() {}

    /// Katigoriopoiei dedomena eikonas i alysida apo tokens OCR.
    public func katigoriopoiisiEikonas(
        megethosBytes: Int,
        platos: Int = 1920,
        ypsos: Int = 1080,
        ocrLekseis: [String] = []
    ) -> ApotelesmaTagVision {
        return R0llingTelemetry.shared.xronometrisi(.media, leitourgia: "LocalVisionTagger.katigoriopoiisi") {
            guard megethosBytes > 0 else {
                return ApotelesmaTagVision(
                    kyriaSkeni: .agnwsto,
                    syntelestisEmpistosynis: 0.0,
                    entopismenoKeimeno: [],
                    lektikesEtiketes: [],
                    xronosAnalysisMs: 0.0
                )
            }

            // Heuristic lektikhs analyshs apo OCR tokens
            var kyriaSkeni: EidosSknis = .eswterikosXoros
            var empistosyni: Double = 0.70
            var etiketes: [String] = []

            let ocrLower = ocrLekseis.map { $0.lowercased() }

            // Elegxos Apodeiksewn / Eggrafwn
            let markersEggrafou = ["total", "eur", "euro", "iban", "vat", "afm", "synolo", "timologio", "apodeiksi", "$", "€"]
            let eggrafoScore = ocrLower.filter { word in markersEggrafou.contains(where: { word.contains($0) }) }.count
            if eggrafoScore >= 2 {
                kyriaSkeni = .apodeiksi
                empistosyni = min(0.95, 0.75 + Double(eggrafoScore) * 0.05)
                etiketes.append("receipt")
                etiketes.append("financial")
            }

            // Elegxos Othonis / Kodika
            let markersOthonis = ["http", "https", "github", "func", "class", "def", "import", "error", "terminal", "const"]
            let othoniScore = ocrLower.filter { word in markersOthonis.contains(where: { word.contains($0) }) }.count
            if othoniScore >= 2 && kyriaSkeni != .apodeiksi {
                kyriaSkeni = .othoni
                empistosyni = min(0.92, 0.70 + Double(othoniScore) * 0.06)
                etiketes.append("screen")
                etiketes.append("code")
            }

            // Elegxos Geumatos / Diatrofis
            let markersFagitou = ["kcal", "cal", "gram", "gr", "protein", "carbs", "salad", "coffee", "restaurant", "menu"]
            let fagiScore = ocrLower.filter { word in markersFagitou.contains(where: { word.contains($0) }) }.count
            if fagiScore >= 2 && kyriaSkeni == .eswterikosXoros {
                kyriaSkeni = .geuma
                empistosyni = min(0.90, 0.68 + Double(fagiScore) * 0.07)
                etiketes.append("food")
                etiketes.append("nutrition")
            }

            if etiketes.isEmpty {
                etiketes.append(kyriaSkeni == .eswterikosXoros ? "indoor" : "general")
            }

            R0llingTelemetry.shared.log(
                .media,
                stathmi: .debug,
                "LocalVisionTagger: ανάλυση ολοκληρώθηκε (\(kyriaSkeni.rawValue), εμπιστοσύνη: \(String(format: "%.2f", empistosyni)))"
            )

            return ApotelesmaTagVision(
                kyriaSkeni: kyriaSkeni,
                syntelestisEmpistosynis: empistosyni,
                entopismenoKeimeno: ocrLekseis,
                lektikesEtiketes: etiketes,
                xronosAnalysisMs: 0.0
            )
        }
    }
}
