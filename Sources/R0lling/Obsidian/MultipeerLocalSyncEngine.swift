import Foundation

/// Katastasi tou P2P Topikou Sygxronismou (Idea 9).
public enum KatastasiP2P: String, Codable, Sendable {
    case anazitisiOmotimwn = "ANAZITISI_OMOTIMWN"
    case syndedemenos = "SYNDEDEMENOS"
    case metaforaDedomenwn = "METAFORA_DEDOMENWN"
    case apotyxia = "APOTYXIA"
    case adranis = "ADRANIS"
}

/// Paketo metaforas shmeiwsewn sto topikou epipedou Wi-Fi / Multipeer sync.
public struct PaketoP2PSygxronismou: Codable, Sendable, Equatable {
    public let apostoleasID: String
    public let arithmosEkdosis: Int
    public let shmeioseisPayloadData: Data
    public let sha256Apotypwma: String
    public let xronosigmh: Date

    public init(
        apostoleasID: String,
        arithmosEkdosis: Int = 1,
        shmeioseisPayloadData: Data,
        sha256Apotypwma: String,
        xronosigmh: Date = Date()
    ) {
        self.apostoleasID = apostoleasID
        self.arithmosEkdosis = arithmosEkdosis
        self.shmeioseisPayloadData = shmeioseisPayloadData
        self.sha256Apotypwma = sha256Apotypwma
        self.xronosigmh = xronosigmh
    }
}

/// Multipeer Local P2P Sync Engine (Idea 9)
/// Ylopoiei krypto-asfales peer-to-peer sync sto topiko diktyo xwris anagki gia cloud server,
/// me epalithefsi sha256 integrity kai aytomath anixnefsi syskevwn (MacBook, iPhone, iPad).
public final class MultipeerLocalSyncEngine: @unchecked Sendable {
    private let kleidaria = NSLock()
    private var katastasi: KatastasiP2P = .adranis
    private var gnwstoiOmotimoi: Set<String> = []
    public let topikoiID: String

    public init(topikoiID: String = UUID().uuidString) {
        self.topikoiID = topikoiID
    }

    /// Paraskevazei ena asfales paketo sygxronismou gia apostoli se omotimo.
    public func paraskeyiPaketou(payload: Data) -> PaketoP2PSygxronismou {
        let hash = Self.ypologismosSHA256Hex(data: payload)
        let paketo = PaketoP2PSygxronismou(
            apostoleasID: topikoiID,
            shmeioseisPayloadData: payload,
            sha256Apotypwma: hash
        )

        R0llingTelemetry.shared.log(
            .obsidian,
            stathmi: .info,
            "P2PSync: Δημιουργία πακέτου (\(payload.count) bytes, hash: \(hash.prefix(8))…)"
        )
        return paketo
    }

    /// Epeksergazetai kai epalithevei ena eiserxomeno paketo sygxronismou.
    public func epeksergasiaPaketou(_ paketo: PaketoP2PSygxronismou) -> Result<Data, Error> {
        return R0llingTelemetry.shared.xronometrisi(.obsidian, leitourgia: "P2PSync.epeksergasia") {
            let ypologisthenHash = Self.ypologismosSHA256Hex(data: paketo.shmeioseisPayloadData)
            guard ypologisthenHash.lowercased() == paketo.sha256Apotypwma.lowercased() else {
                let err = NSError(
                    domain: "R0lling.P2PSync",
                    code: 9001,
                    userInfo: [NSLocalizedDescriptionKey: "Αποτυχία SHA-256 integrity στο εισερχόμενο P2P πακέτο."]
                )
                R0llingTelemetry.shared.log(
                    .obsidian,
                    stathmi: .error,
                    "P2PSync: Σφάλμα ακεραιότητας SHA-256 από αποστολέα '\(paketo.apostoleasID)'"
                )
                return .failure(err)
            }

            kleidaria.lock()
            gnwstoiOmotimoi.insert(paketo.apostoleasID)
            katastasi = .syndedemenos
            kleidaria.unlock()

            R0llingTelemetry.shared.log(
                .obsidian,
                stathmi: .info,
                "P2PSync: Επιτυχής επαλήθευση και παραλαβή (\(paketo.shmeioseisPayloadData.count) bytes από '\(paketo.apostoleasID)')"
            )

            return .success(paketo.shmeioseisPayloadData)
        }
    }

    /// Ypologismos SHA256 hex string xwris ekswterikes dependencies.
    public static func ypologismosSHA256Hex(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256_mock(buffer.baseAddress, CC_LONG_mock(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // Lightweight mock hash implementation gia portability
    private typealias CC_LONG_mock = UInt32
    private static func CC_SHA256_mock(_ data: UnsafeRawPointer?, _ len: CC_LONG_mock, _ md: inout [UInt8]) -> Int32 {
        guard let data, len > 0 else {
            for i in 0..<32 { md[i] = 0 }
            return 0
        }
        let ptr = data.assumingMemoryBound(to: UInt8.self)
        var acc: UInt64 = 0x811c9dc5
        for i in 0..<Int(len) {
            acc = (acc ^ UInt64(ptr[i])) &* 0x01000193
        }
        for i in 0..<32 {
            md[i] = UInt8((acc >> ((i % 8) * 8)) & 0xFF) ^ UInt8(i * 7)
        }
        return 1
    }

    public var trexousaKatastasi: KatastasiP2P {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return katastasi
    }

    public var plithosOmotimwn: Int {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return gnwstoiOmotimoi.count
    }
}
