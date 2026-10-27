import Foundation

/// Sfalmata paraviasis i alloiwsis xronou tou rologiou.
public enum SfalmaXronouSyskevis: Error, Sendable, Equatable {
    case xeirokinitiAllagiXronou(diaforaSeSec: Double)
    case arnhtikosXronos
    case apotyxiaMonotonikouRologiou
}

/// Monotoniko Roloi Syskevis gia Prostasia apo Xroniki Xeiragwgisi (Idea 6).
/// Syndyazei mach_absolute_time / CLOCK_MONOTONIC_RAW me to Date()
/// gia na apotrepsei bypass tou FutureLetterbox i alloiwsi analytics mesw
/// xeirokinitis allagis tis wras tou iOS sto Settings.
public final class MonotonikoRoloiSyskevis: @unchecked Sendable {
    public static let shared = MonotonikoRoloiSyskevis()

    private let kleidaria = NSLock()
    private var proigoumeniXronosigmhToixou: Date
    private var proigoumenaNanosMonotonika: UInt64

    public static let orioApoklisisSec: Double = 300.0 // 5 lepta max anepanepilektis apoklisis

    public init(toraToixou: Date = Date(), toraMonotonikaNanos: UInt64 = DispatchTime.now().uptimeNanoseconds) {
        self.proigoumeniXronosigmhToixou = toraToixou
        self.proigoumenaNanosMonotonika = toraMonotonikaNanos
    }

    /// Epivevaiwnei tin egkyrotita mias neas xronosigmis enanti tou monotonikou rologiou hardware.
    public func epivevaiwsiKaiEnimerwsiXronou(
        toraToixou: Date = Date(),
        toraMonotonikaNanos: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) throws -> Date {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        guard toraMonotonikaNanos >= proigoumenaNanosMonotonika else {
            throw SfalmaXronouSyskevis.apotyxiaMonotonikouRologiou
        }

        let perasmenaMonotonikaSec = Double(toraMonotonikaNanos - proigoumenaNanosMonotonika) / 1_000_000_000.0
        let perasmenaToixouSec = toraToixou.timeIntervalSince(proigoumeniXronosigmhToixou)

        // Elegxos an to roloi tou toixou gyriste pisw sto parelthon
        if perasmenaToixouSec < -1.0 {
            let apoklisi = abs(perasmenaToixouSec)
            R0llingTelemetry.shared.log(
                .security,
                stathmi: .fault,
                "[TimeTampering] Εντοπίστηκε χειροκίνητη μετάβαση του ρολογιού προς το παρελθόν (\(apoklisi)s)"
            )
            throw SfalmaXronouSyskevis.xeirokinitiAllagiXronou(diaforaSeSec: apoklisi)
        }

        // Elegxos an to roloi tou toixou pidikse ypervolika mprosta xwris antistoixo monotoniko xrono
        if perasmenaToixouSec > perasmenaMonotonikaSec + Self.orioApoklisisSec {
            let apoklisi = perasmenaToixouSec - perasmenaMonotonikaSec
            R0llingTelemetry.shared.log(
                .security,
                stathmi: .fault,
                "[TimeTampering] Εντοπίστηκε άλμα ρολογιού προς το μέλλον (\(apoklisi)s χωρίς αντίστοιχο monotonic uptime)"
            )
            throw SfalmaXronouSyskevis.xeirokinitiAllagiXronou(diaforaSeSec: apoklisi)
        }

        self.proigoumeniXronosigmhToixou = toraToixou
        self.proigoumenaNanosMonotonika = toraMonotonikaNanos

        return toraToixou
    }

    /// Lave ton asfali mononiko xrono uptime se deyterolepta.
    public func trexonMonotonikoUptimeSec() -> Double {
        return Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000.0
    }
}
