import Foundation

/// Apotelesma elegxou antithesis WCAG 2.2.
public struct ApotelesmaAntithesisWCAG: Sendable, Codable, Equatable {
    public let logosAntithesis: Double
    public let peraseEpipedoAA: Bool
    public let peraseEpipedoAAA: Bool
    public let apaiteiMegaloKeimeno: Bool

    public init(
        logosAntithesis: Double,
        peraseEpipedoAA: Bool,
        peraseEpipedoAAA: Bool,
        apaiteiMegaloKeimeno: Bool
    ) {
        self.logosAntithesis = logosAntithesis
        self.peraseEpipedoAA = peraseEpipedoAA
        self.peraseEpipedoAAA = peraseEpipedoAAA
        self.apaiteiMegaloKeimeno = apaiteiMegaloKeimeno
    }
}

/// Elegktis Antithesis Xrwmatwn WCAG 2.2 AAA kai Dynamic Type Safety (Idea 19).
/// Ypologizei tin sxetiki foteinotita (relative luminance) me vasi to sRGB IEC 61966-2-1
/// kai epivevaiwnei oti to kranio keimeno exei logo antithesis >= 7.0 (WCAG AAA)
/// panw sta skoura Bevel surfaces tou R0lling.
public struct ElegktisAntithesisWCAG: Sendable {

    public init() {}

    /// Gamma-correction sRGB kanalikou xrwmatos kata to WCAG specification.
    public static func linearizeColorComponent(_ c: Double) -> Double {
        let clamped = max(0.0, min(1.0, c))
        if clamped <= 0.04045 {
            return clamped / 12.92
        } else {
            return pow((clamped + 0.055) / 1.055, 2.4)
        }
    }

    /// Ypologismos sxetikis foteinotitas L = 0.2126 * R + 0.7152 * G + 0.0722 * B.
    public static func sxetikiFoteinotita(kokkino: Double, prasino: Double, mple: Double) -> Double {
        let r = linearizeColorComponent(kokkino)
        let g = linearizeColorComponent(prasino)
        let b = linearizeColorComponent(mple)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Ypologismos logou antithesis metaksy dyo xrwmatwn: (L1 + 0.05) / (L2 + 0.05).
    public static func ypologismosLogouAntithesis(
        foteinotita1: Double,
        foteinotita2: Double
    ) -> Double {
        let l1 = max(foteinotita1, foteinotita2)
        let l2 = min(foteinotita1, foteinotita2)
        return (l1 + 0.05) / (l2 + 0.05)
    }

    /// Elegxei an o logos antithesis symmorfwnetai me to WCAG 2.2 Level AAA (>= 7.0 gia kanoniko keimeno).
    public static func elegxosSymmorfwsis(
        foteinotitaKeimenou: Double,
        foteinotitaFontou: Double,
        einaiMegaloKeimeno: Bool = false
    ) -> ApotelesmaAntithesisWCAG {
        let logos = ypologismosLogouAntithesis(foteinotita1: foteinotitaKeimenou, foteinotita2: foteinotitaFontou)

        let peraseAA = einaiMegaloKeimeno ? (logos >= 3.0) : (logos >= 4.5)
        let peraseAAA = einaiMegaloKeimeno ? (logos >= 4.5) : (logos >= 7.0)

        return ApotelesmaAntithesisWCAG(
            logosAntithesis: logos,
            peraseEpipedoAA: peraseAA,
            peraseEpipedoAAA: peraseAAA,
            apaiteiMegaloKeimeno: einaiMegaloKeimeno
        )
    }

    /// Epivevaiwnei oti ena koumpi i control ikanopoiei to elaxisto touch target 44pt x 44pt.
    public static func epivevaiwsiTouchTarget(platosPt: Double, ypsosPt: Double) -> Bool {
        return platosPt >= 44.0 && ypsosPt >= 44.0
    }
}
