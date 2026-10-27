import Foundation

/// Plirofories katastasis syskevis sto Mayro Kouti xwris PII.
public struct PliroforiesKatastasisMayrouKoutiou: Codable, Sendable, Equatable {
    public let xronosigmh: Date
    public let einaiLowPowerMode: Bool
    public let thermalStateRaw: Int
    public let diathesimaBytesMnimis: Int64

    public init(
        xronosigmh: Date = Date(),
        einaiLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled,
        thermalStateRaw: Int = ProcessInfo.processInfo.thermalState.rawValue,
        diathesimaBytesMnimis: Int64 = Int64(ProcessInfo.processInfo.physicalMemory)
    ) {
        self.xronosigmh = xronosigmh
        self.einaiLowPowerMode = einaiLowPowerMode
        self.thermalStateRaw = thermalStateRaw
        self.diathesimaBytesMnimis = diathesimaBytesMnimis
    }
}

/// Dedomena fakelou mayrou koutiou gia meta-mortem diagnwstika.
public struct PaketoMayrouKoutiou: Codable, Sendable, Equatable {
    public let anagnwristiko: UUID
    public let xronosigmhEksagwgis: Date
    public let katastasiSyskevis: PliroforiesKatastasisMayrouKoutiou
    public let teleutaiaSimvanta: [R0llingTelemetry.TelemetrySimvan]

    public init(
        anagnwristiko: UUID = UUID(),
        xronosigmhEksagwgis: Date = Date(),
        katastasiSyskevis: PliroforiesKatastasisMayrouKoutiou = PliroforiesKatastasisMayrouKoutiou(),
        teleutaiaSimvanta: [R0llingTelemetry.TelemetrySimvan]
    ) {
        self.anagnwristiko = anagnwristiko
        self.xronosigmhEksagwgis = xronosigmhEksagwgis
        self.katastasiSyskevis = katastasiSyskevis
        self.teleutaiaSimvanta = teleutaiaSimvanta
    }
}

/// In-Flight Telemetry Blackbox Flight Recorder (Idea 12).
/// Katagrafei ta teleutaia 50 apolyta sanitized simvanta telemetry gia atomiki eksagwgi
/// se arxeio `crash_blackbox.json` se periptwsi krasarismatos i memory pressure,
/// xwris oute ena byte PII, proswpikwn shmeiwsewn i tokens.
public final class MayroKoutiKatagrafis: @unchecked Sendable {
    public static let shared = MayroKoutiKatagrafis()

    private let kleidaria = NSLock()
    private let megistoOrioSimvantwn = 50
    private var prosorinosBuffer: [R0llingTelemetry.TelemetrySimvan] = []

    public static let onomaArxeiouMayrouKoutiou = "crash_blackbox.json"

    public init() {}

    /// Katagrafi enos neou simvantos sto Mayro Kouti.
    public func katagrafiSimvantos(_ simvan: R0llingTelemetry.TelemetrySimvan) {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        prosorinosBuffer.append(simvan)
        if prosorinosBuffer.count > megistoOrioSimvantwn {
            prosorinosBuffer.removeFirst(prosorinosBuffer.count - megistoOrioSimvantwn)
        }
    }

    /// Lave antigrafo twn teleutaiwn simvantwn.
    public func laveTeleutaiaSimvanta() -> [R0llingTelemetry.TelemetrySimvan] {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return prosorinosBuffer
    }

    /// Katharizei ta periexomena tou mayrou koutiou.
    public func katharismos() {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        prosorinosBuffer.removeAll()
    }

    /// Atomiki apothikefsi tou pakatou tou Mayrou Koutiou se arxeio sto disko.
    @discardableResult
    public func apothikefsiMayrouKoutiou(
        se fakelo: URL,
        prothesmaSyskevis: PliroforiesKatastasisMayrouKoutiou = PliroforiesKatastasisMayrouKoutiou()
    ) throws -> URL {
        let simvanta = laveTeleutaiaSimvanta()
        let paketo = PaketoMayrouKoutiou(
            katastasiSyskevis: prothesmaSyskevis,
            teleutaiaSimvanta: simvanta
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let dedomena = try encoder.encode(paketo)

        let telikoURL = fakelo.appendingPathComponent(Self.onomaArxeiouMayrouKoutiou)
        let prosorinoURL = fakelo.appendingPathComponent(".\(Self.onomaArxeiouMayrouKoutiou).tmp.\(UUID().uuidString)")

        // Atomiki eggrafi me sympiesi kai antikatastasi
        try dedomena.write(to: prosorinoURL, options: [.atomic])
        _ = try? FileManager.default.removeItem(at: telikoURL)
        try FileManager.default.moveItem(at: prosorinoURL, to: telikoURL)

        return telikoURL
    }
}
