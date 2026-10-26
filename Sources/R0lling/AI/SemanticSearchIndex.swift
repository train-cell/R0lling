import Foundation

/// Domi apotelesmatos semantikis anazitisis.
public struct ApotelesmaAnazitisis: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let entryID: UUID
    public let scoreOmoiotitas: Float
    public let perilipsi: String

    public init(id: UUID = UUID(), entryID: UUID, scoreOmoiotitas: Float, perilipsi: String) {
        self.id = id
        self.entryID = entryID
        self.scoreOmoiotitas = scoreOmoiotitas
        self.perilipsi = perilipsi
    }
}

/// Domi dianysmatos gia kathe shmeiwsi sto index.
public struct DianysmaSimeiwsis: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let entryID: UUID
    public let dianysma: [Float]
    public let perilipsi: String
    public let xronosigmh: Date

    public init(id: UUID = UUID(), entryID: UUID, dianysma: [Float], perilipsi: String, xronosigmh: Date = Date()) {
        self.id = id
        self.entryID = entryID
        self.dianysma = dianysma
        self.perilipsi = perilipsi
        self.xronosigmh = xronosigmh
    }
}

/// On-Device Semantic Search Index (Idea 1)
/// Ektelesi topikis semantikis anazitisis me cosine similarity, xwris cloud kliseis.
public final class SemanticSearchIndex: @unchecked Sendable {
    private let kleidaria = NSLock()
    private var evretirio: [UUID: DianysmaSimeiwsis] = [:]
    private let megistoEvretirio = 5000

    public init() {}

    /// Ypologismos Cosine Similarity metaksy dyo dianysmatwn me oria kai elegxo midenikou dianyamatos.
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        var dot: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0.0, denom.isFinite else { return 0.0 }
        let score = dot / denom
        return max(-1.0, min(1.0, score.isFinite ? score : 0.0))
    }

    /// Prosthiki i ananewsi dianysmatos sto evretirio.
    public func prosthikiDianysmatos(_ stoixeio: DianysmaSimeiwsis) {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        evretirio[stoixeio.entryID] = stoixeio
        if evretirio.count > megistoEvretirio {
            // Ejection tou palaioterou stoixeiou
            if let palaiotero = evretirio.values.min(by: { $0.xronosigmh < $1.xronosigmh }) {
                evretirio.removeValue(forKey: palaiotero.entryID)
            }
        }
    }

    /// Ektelesi anazitisis me vasi dianysma erwtimatos kai elaxisto katwfli omoiotitas.
    public func anazitisi(
        dianysmaErwtimatos: [Float],
        megistoApotelesmatwn: Int = 10,
        elaxistoScore: Float = 0.60
    ) -> [ApotelesmaAnazitisis] {
        return R0llingTelemetry.shared.xronometrisi(.ai, leitourgia: "SemanticSearchIndex.anazitisi") {
            kleidaria.lock()
            let eggrafes = Array(evretirio.values)
            kleidaria.unlock()

            guard !dianysmaErwtimatos.isEmpty else { return [] }

            var apotelesmata: [ApotelesmaAnazitisis] = []
            for item in eggrafes {
                let score = Self.cosineSimilarity(dianysmaErwtimatos, item.dianysma)
                if score >= elaxistoScore {
                    apotelesmata.append(
                        ApotelesmaAnazitisis(
                            entryID: item.entryID,
                            scoreOmoiotitas: score,
                            perilipsi: item.perilipsi
                        )
                    )
                }
            }

            apotelesmata.sort { $0.scoreOmoiotitas > $1.scoreOmoiotitas }
            let telika = Array(apotelesmata.prefix(max(1, megistoApotelesmatwn)))

            R0llingTelemetry.shared.log(
                .ai,
                stathmi: .debug,
                "SemanticSearchIndex: ολοκληρώθηκε αναζήτηση (\(telika.count) αποτελέσματα από \(eggrafes.count) εγγραφές)"
            )

            return telika
        }
    }

    /// Epistrefei to synoliko arithmo kataxwrimenwn dianysmatwn.
    public var synolikoPlithos: Int {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return evretirio.count
    }

    /// Katharismos evretiriou.
    public func katharismos() {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        evretirio.removeAll()
    }
}
