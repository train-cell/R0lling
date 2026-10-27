import Foundation

/// Dedomena mias diagrafimenis shmeiwsis (Tombstone) sto CRDT sygxronismo.
public struct TombstoneEggrafi: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let entryID: UUID
    public let xronosigmhDiagrafis: Date
    public let lamportClockAtDelete: UInt64
    public let peerID: String

    public init(
        id: UUID = UUID(),
        entryID: UUID,
        xronosigmhDiagrafis: Date = Date(),
        lamportClockAtDelete: UInt64,
        peerID: String
    ) {
        self.id = id
        self.entryID = entryID
        self.xronosigmhDiagrafis = xronosigmhDiagrafis
        self.lamportClockAtDelete = lamportClockAtDelete
        self.peerID = peerID
    }
}

/// Sympiknwths Tombstones kai Katharismos CRDT Metadedomenwn (Idea 18).
/// Pragmatopoiei garbage collection se tombstone markers pou ksepernoun tis 30 imeres
/// (2.592.000 deyterolepta), apotrepontas tin aneksylegkti diogkwsi tis mnimis sygxronismou.
public final class SympiknwthsTombstones: @unchecked Sendable {
    public static let shared = SympiknwthsTombstones()

    private let kleidaria = NSLock()
    private var tombstonesEvretirio: [UUID: TombstoneEggrafi] = [:]

    /// Orio diarkeias diatirisis tombstones: 30 imeres
    public static let orioDiatirisisTombstoneSec: TimeInterval = 30.0 * 24.0 * 3600.0

    public init() {}

    /// Kataxwrise neo tombstone gia diagrafomeni shmeiwsi.
    public func kataxwrisiTombstone(_ tombstone: TombstoneEggrafi) {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        tombstonesEvretirio[tombstone.entryID] = tombstone
    }

    /// Elegxei an ena entryID exei diagrafei (einai tombstone).
    public func einaiTombstone(entryID: UUID) -> Bool {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return tombstonesEvretirio[entryID] != nil
    }

    /// Ektelesi sympiknwsis (Garbage Collection) afairwntas tombstones palaiotera twn 30 imerwn.
    @discardableResult
    public func ektelesiSympiknwsis(
        tora: Date = Date(),
        orioDiarkeias: TimeInterval = orioDiatirisisTombstoneSec
    ) -> (energaTombstones: [TombstoneEggrafi], plithosDiagrafentwn: Int) {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        var energa: [TombstoneEggrafi] = []
        var diagrafenta = 0

        for (entryID, tombstone) in tombstonesEvretirio {
            let ilikia = tora.timeIntervalSince(tombstone.xronosigmhDiagrafis)
            if ilikia >= orioDiarkeias {
                tombstonesEvretirio.removeValue(forKey: entryID)
                diagrafenta += 1
            } else {
                energa.append(tombstone)
            }
        }

        if diagrafenta > 0 {
            R0llingTelemetry.shared.log(
                .obsidian,
                stathmi: .info,
                "[CRDTCompaction] Ολοκληρώθηκε εκκαθάριση tombstones: \(diagrafenta) διαγράφηκαν, \(energa.count) διατηρήθηκαν."
            )
        }

        return (energa, diagrafenta)
    }

    /// Katharismos olwn twn tombstones gia dokimes.
    public func katharismos() {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        tombstonesEvretirio.removeAll()
    }
}
