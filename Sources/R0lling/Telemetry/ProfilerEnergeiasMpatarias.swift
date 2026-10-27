import Foundation

/// Profil apodotikotitas kai katanalwsis energeias sto R0lling.
public enum ProfilEnergeias: String, Sendable, Codable, CaseIterable {
    case plirisApososi = "full_performance"
    case oikonomiaMpatarias = "low_power_saving"
    case thermikoThrottle = "thermal_throttling"
}

/// Dynamic budget parametros gia varietates leitourgies (Idea 15).
public struct RythmisiLeitourgiasEnergeias: Sendable, Codable, Equatable {
    public let profil: ProfilEnergeias
    public let megistoMegethosDianysmatikisAnazitisis: Int
    public let epitrepetaiTopikoOCR: Bool
    public let diarkeiaCacheSeDeyterolepta: TimeInterval
    public let kathisterisiBatchMs: UInt32

    public init(
        profil: ProfilEnergeias,
        megistoMegethosDianysmatikisAnazitisis: Int,
        epitrepetaiTopikoOCR: Bool,
        diarkeiaCacheSeDeyterolepta: TimeInterval,
        kathisterisiBatchMs: UInt32
    ) {
        self.profil = profil
        self.megistoMegethosDianysmatikisAnazitisis = megistoMegethosDianysmatikisAnazitisis
        self.epitrepetaiTopikoOCR = epitrepetaiTopikoOCR
        self.diarkeiaCacheSeDeyterolepta = diarkeiaCacheSeDeyterolepta
        self.kathisterisiBatchMs = kathisterisiBatchMs
    }
}

/// Profiler Energeias kai Thermikis Katastasis Syskevis (Idea 15).
/// Prosaprmozei dynamika ta oria tou AI Search, Vision OCR kai Telemetry
/// otan i syskevi vrisketai se Low Power Mode i thermiko throttling,
/// meionontas tin katanalwsi mpatarias kai apotrepontas to thermal shutdown.
public final class ProfilerEnergeiasMpatarias: @unchecked Sendable {
    public static let shared = ProfilerEnergeiasMpatarias()

    private let kleidaria = NSLock()

    public init() {}

    /// Epistrefei tin trexousa dynamiki rythmisi me vasi to hardware tou iOS.
    public func laveTrexousaRythmisi(
        einaiLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled,
        thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    ) -> RythmisiLeitourgiasEnergeias {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        // Periptwsi Thermikis Yperthermansis (Critical / Serious)
        if thermalState == .critical || thermalState == .serious {
            return RythmisiLeitourgiasEnergeias(
                profil: .thermikoThrottle,
                megistoMegethosDianysmatikisAnazitisis: thermalState == .critical ? 2 : 5,
                epitrepetaiTopikoOCR: false,
                diarkeiaCacheSeDeyterolepta: 600.0,
                kathisterisiBatchMs: 50
            )
        }

        // Periptwsi Low Power Mode
        if einaiLowPowerMode {
            return RythmisiLeitourgiasEnergeias(
                profil: .oikonomiaMpatarias,
                megistoMegethosDianysmatikisAnazitisis: 5,
                epitrepetaiTopikoOCR: false,
                diarkeiaCacheSeDeyterolepta: 300.0,
                kathisterisiBatchMs: 20
            )
        }

        // Periptwsi Kanonikis Leitourgias (Nominal / Fair)
        return RythmisiLeitourgiasEnergeias(
            profil: .plirisApososi,
            megistoMegethosDianysmatikisAnazitisis: thermalState == .fair ? 10 : 20,
            epitrepetaiTopikoOCR: true,
            diarkeiaCacheSeDeyterolepta: 60.0,
            kathisterisiBatchMs: 0
        )
    }

    /// Katagrafei tin allagi sto Telemetry.
    public func katagrafiMetavolisEnergeias(neoiRythmisi: RythmisiLeitourgiasEnergeias) {
        R0llingTelemetry.shared.log(
            .security,
            stathmi: .info,
            "[Power] Ενεργειακό προφίλ: \(neoiRythmisi.profil.rawValue) (Vector Cap: \(neoiRythmisi.megistoMegethosDianysmatikisAnazitisis), OCR: \(neoiRythmisi.epitrepetaiTopikoOCR))"
        )
    }
}
