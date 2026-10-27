import Foundation

/// Epipedo diathessimotitas xwrou sto disko.
public enum EpipedoXwrouDiskoy: String, Sendable, Codable, CaseIterable {
    case kanoniko = "normal"          // > 200 MiB
    case proeidopoiisi = "warning"    // 100 - 200 MiB
    case payla = "pause"              // 50 - 100 MiB
    case krisimo = "critical"         // <= 50 MiB
}

/// Sfalma aneparkeias xwrou diskou kata tin eggrafi.
public enum SfalmaXwrouDiskoy: Error, Sendable, Equatable {
    case aneparkisXoros(diathesimaBytes: Int64, apaitoumenaBytes: Int64, elaxistoOrioBytes: Int64)
    case anastoliEggrafwnLogwXwrou
}

/// Diaxeiristis Multi-Tier Xwrou Diskou kai Orphaned Clips Pruning (Idea 10).
/// Ylopoiei klymata oria:
/// - 200 MiB: Warning & aftomato pruning prosorinwn arxeiwn
/// - 100 MiB: Payla mh-krisimwn leitourgiwn video buffering
/// - 50 MiB: Hard Reject (Fail-Closed) me kodioko sfalmatos
public final class DiaxeiristisXwrouDiskoy: @unchecked Sendable {
    public static let shared = DiaxeiristisXwrouDiskoy()

    private let kleidaria = NSLock()

    public static let orioKanonikoBytes: Int64 = 200 * 1024 * 1024        // 200 MiB
    public static let orioPaylasBytes: Int64 = 100 * 1024 * 1024          // 100 MiB
    public static let orioKrisimoHardStopBytes: Int64 = 50 * 1024 * 1024  // 50 MiB (Master Protocol Constant)

    public init() {}

    /// Ypologizei to epipedo xwrou diskou me vasi ta diathesima bytes.
    public func epipedoGiaBytes(_ eleutheraBytes: Int64) -> EpipedoXwrouDiskoy {
        if eleutheraBytes <= Self.orioKrisimoHardStopBytes {
            return .krisimo
        } else if eleutheraBytes <= Self.orioPaylasBytes {
            return .payla
        } else if eleutheraBytes <= Self.orioKanonikoBytes {
            return .proeidopoiisi
        } else {
            return .kanoniko
        }
    }

    /// Elegxei an epitrepetai i eggrafi dedomenwn apaitoumenou megethous.
    public func elegxosEggrafis(apaitoumenaBytes: Int64, diathesimaBytes: Int64) throws {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        let epipedo = epipedoGiaBytes(diathesimaBytes)

        if epipedo == .krisimo || (diathesimaBytes - apaitoumenaBytes) < Self.orioKrisimoHardStopBytes {
            R0llingTelemetry.shared.log(
                .storage,
                stathmi: .fault,
                "[DiskQuota] ΑΠΟΡΡΙΨΗ ΕΓΓΡΑΦΗΣ: Διαθέσιμα \(diathesimaBytes / 1024 / 1024) MiB, Απαιτούμενα \(apaitoumenaBytes / 1024 / 1024) MiB (Όριο: 50 MiB)"
            )
            throw SfalmaXwrouDiskoy.aneparkisXoros(
                diathesimaBytes: diathesimaBytes,
                apaitoumenaBytes: apaitoumenaBytes,
                elaxistoOrioBytes: Self.orioKrisimoHardStopBytes
            )
        }

        if epipedo == .payla {
            R0llingTelemetry.shared.log(
                .storage,
                stathmi: .warning,
                "[DiskQuota] Προειδοποίηση παύσης: Ο διαθέσιμος χώρος είναι κάτω από 100 MiB (\(diathesimaBytes / 1024 / 1024) MiB)"
            )
        }
    }

    /// Prunes orphaned temporary media files (.tmp files) palaiotera twn orismenwn deuteroleptwn.
    @discardableResult
    public func ekkatharisiOrphanedProsorinwn(sto fakelo: URL, orioIlikiasSec: TimeInterval = 3600.0) -> Int {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        guard let arxeia = try? FileManager.default.contentsOfDirectory(
            at: fakelo,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return 0
        }

        let tora = Date()
        var plithosDiagrafentwn = 0

        for arxeio in arxeia {
            if arxeio.pathExtension == "tmp" || arxeio.lastPathComponent.hasPrefix(".") {
                if let dates = try? arxeio.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = dates.contentModificationDate {
                    if tora.timeIntervalSince(modDate) >= orioIlikiasSec {
                        if (try? FileManager.default.removeItem(at: arxeio)) != nil {
                            plithosDiagrafentwn += 1
                        }
                    }
                }
            }
        }

        if plithosDiagrafentwn > 0 {
            R0llingTelemetry.shared.log(
                .storage,
                stathmi: .info,
                "[DiskQuota] Εκκαθαρίστηκαν \(plithosDiagrafentwn) orphaned προσωρινά αρχεία από το \(fakelo.lastPathComponent)"
            )
        }

        return plithosDiagrafentwn
    }
}
