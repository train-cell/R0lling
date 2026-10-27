import Foundation
import CryptoKit

/// Typos praxis sto Write-Ahead Log.
public enum TyposPraksisWAL: String, Sendable, Codable, CaseIterable {
    case prosthiki = "insert"
    case tropopoiisi = "update"
    case diagrafi = "delete"
}

/// Aytotelhs grammi/karekla sto Write-Ahead Log.
public struct WALKareklaFrame: Sendable, Codable, Equatable {
    public let synallagiID: UUID
    public let xronosigmh: Date
    public let typos: TyposPraksisWAL
    public let payloadData: Data
    public let sha256Hash: String

    public init(
        synallagiID: UUID = UUID(),
        xronosigmh: Date = Date(),
        typos: TyposPraksisWAL,
        payloadData: Data
    ) {
        self.synallagiID = synallagiID
        self.xronosigmh = xronosigmh
        self.typos = typos
        self.payloadData = payloadData
        self.sha256Hash = SHA256.hash(data: payloadData).compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// Write-Ahead Logging (WAL) Micro-Journal Store (Idea 7).
/// Katagrafei synallages append-only sto disko prin tin ektelesi tou telikou JSON snapshot,
/// prostateuontas to R0lling apo apotomi diakopi (crash/Jetsam OOM/power loss) kata to save.
public final class WALJournalStore: @unchecked Sendable {
    public static let shared = WALJournalStore()

    private let kleidaria = NSLock()
    public static let onomaArxeiouWAL = "journal_wal.log"

    public init() {}

    /// Epistrefei to plires URL tou arxeiou WAL.
    public func urlArxeiouWAL(sto fakelo: URL) -> URL {
        return fakelo.appendingPathComponent(Self.onomaArxeiouWAL)
    }

    /// Prosartisi mias neas synallagis sto arxeio WAL (Append-Only).
    public func kataxwrisiSynallagis(
        typos: TyposPraksisWAL,
        dedomena: Data,
        sto fakelo: URL
    ) throws -> WALKareklaFrame {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        let frame = WALKareklaFrame(typos: typos, payloadData: dedomena)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var frameData = try encoder.encode(frame)
        frameData.append(Data([0x0A])) // Newline delimiter '\n'

        let walURL = urlArxeiouWAL(sto: fakelo)
        if FileManager.default.fileExists(atPath: walURL.path) {
            let handle = try FileHandle(forWritingTo: walURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: frameData)
        } else {
            try frameData.write(to: walURL, options: [.atomic])
        }

        R0llingTelemetry.shared.log(
            .storage,
            stathmi: .debug,
            "[WAL] Καταχωρήθηκε συναλλαγή \(frame.synallagiID.uuidString) τύπου \(typos.rawValue)"
        )

        return frame
    }

    /// Anagnwsi kai epalithefsi akeraiotitas olwn twn frames sto WAL gia apokatastasi.
    public func anagnwsiKaiApokatastasiWAL(apo fakelo: URL) throws -> [WALKareklaFrame] {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        let walURL = urlArxeiouWAL(sto: fakelo)
        guard FileManager.default.fileExists(atPath: walURL.path) else {
            return []
        }

        let dedomena = try Data(contentsOf: walURL)
        guard !dedomena.isEmpty else { return [] }

        var frames: [WALKareklaFrame] = []
        let grammes = dedomena.split(separator: 0x0A) // split on '\n'

        let decoder = JSONDecoder()
        decoder.dateEncodingStrategy = .iso8601

        for grammi in grammes {
            guard !grammi.isEmpty else { continue }
            let frame = try decoder.decode(WALKareklaFrame.self, from: grammi)

            // Epalithefsi SHA256 akeraiotitas tou frame
            let ypologisthenHash = SHA256.hash(data: frame.payloadData).compactMap { String(format: "%02x", $0) }.joined()
            guard ypologisthenHash.lowercased() == frame.sha256Hash.lowercased() else {
                throw NSError(domain: "R0lling.WAL", code: 3101, userInfo: [
                    NSLocalizedDescriptionKey: "Αλλοιωμένο frame στο WAL αρχείο. Το SHA256 hash δεν ταιριάζει."
                ])
            }
            frames.append(frame)
        }

        return frames
    }

    /// Checkpoint WAL: Ekkatharisi tou log meta apo epityxes save tou kanonikou JSON arxeiou.
    public func checkpointWAL(sto fakelo: URL) throws {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        let walURL = urlArxeiouWAL(sto: fakelo)
        if FileManager.default.fileExists(atPath: walURL.path) {
            try FileManager.default.removeItem(at: walURL)
            R0llingTelemetry.shared.log(
                .storage,
                stathmi: .info,
                "[WAL] Ολοκληρώθηκε επιτυχές checkpoint. Το WAL εκκαθαρίστηκε."
            )
        }
    }
}
