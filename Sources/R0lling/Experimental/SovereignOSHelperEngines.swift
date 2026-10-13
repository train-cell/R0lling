import Foundation

// Moved unchanged from Core/SovereignOSServices.swift on 2026-10-13. These helpers have no
// product caller (only unit tests exercise them), so they live under Experimental/ per the
// orphan policy in docs/GOAL_100_FEATURE_MATRIX.md §6. Their behavior is unchanged.

public actor ZettelkastenLinkerActor {
    public init() {}

    public func discoverConnections(for content: String, knownNotes: [(title: String, path: String)]) -> [ZettelkastenConnection] {
        let words = Set(content.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 3 })
        var matches: [ZettelkastenConnection] = []

        for note in knownNotes {
            let noteWords = Set(note.title.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 3 })
            let intersection = words.intersection(noteWords)
            if !intersection.isEmpty {
                let score = min(1.0, Double(intersection.count) / Double(max(1, noteWords.count)) + 0.4)
                matches.append(ZettelkastenConnection(
                    targetNoteTitle: note.title,
                    relativeVaultPath: note.path,
                    similarityScore: score
                ))
            }
        }
        return matches.sorted(by: { $0.similarityScore > $1.similarityScore })
    }
}

/// Legacy in-memory helper retained for source compatibility. Product flows use EncryptedDiaryStore.
@available(*, deprecated, message: "In-memory legacy helper; use EncryptedDiaryStore for product decision records.")
public actor DecisionJournalEngine {
    private var records: [DecisionRecord] = []

    public init() {}

    public func recordDecision(_ record: DecisionRecord) {
        records.append(record)
    }

    public func getPendingReviews(currentDate: Date = Date()) -> [DecisionRecord] {
        return records.filter { !$0.isReviewed && $0.reviewDate <= currentDate }
    }

    public func getAllDecisions() -> [DecisionRecord] {
        return records
    }
}

// MARK: - [25] Future Letterbox (Μηνύματα στο Μέλλον)

public struct SealedLetter: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let titleHint: String
    public let unlockDate: Date
    public let payloadText: String
    public let isOpened: Bool

    public init(
        id: UUID = UUID(),
        titleHint: String,
        unlockDate: Date,
        payloadText: String,
        isOpened: Bool = false
    ) {
        self.id = id
        self.titleHint = titleHint
        self.unlockDate = unlockDate
        self.payloadText = payloadText
        self.isOpened = isOpened
    }
}

/// Legacy in-memory helper retained for source compatibility. Product flows use EncryptedDiaryStore.
@available(*, deprecated, message: "In-memory legacy helper; use EncryptedDiaryStore for product future letters.")
public actor FutureLetterboxEngine {
    private var letters: [SealedLetter] = []

    public init() {}

    public func sealLetter(_ letter: SealedLetter) {
        letters.append(letter)
    }

    public func getAvailableLetters(currentDate: Date = Date()) -> [SealedLetter] {
        return letters.filter { $0.unlockDate <= currentDate }
    }

    public func getPendingCount(currentDate: Date = Date()) -> Int {
        return letters.filter { $0.unlockDate > currentDate }.count
    }
}

// MARK: - [26] Creator Idea Hopper & B-Roll Stash

public struct CreatorAsset: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let projectTag: String
    public let title: String
    public let mediaRelativePath: String?
    public let transcriptSnippet: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        projectTag: String,
        title: String,
        mediaRelativePath: String? = nil,
        transcriptSnippet: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectTag = projectTag
        self.title = title
        self.mediaRelativePath = mediaRelativePath
        self.transcriptSnippet = transcriptSnippet
        self.createdAt = createdAt
    }
}

public actor CreatorAssetEngine {
    private var assets: [CreatorAsset] = []

    public init() {}

    public func addAsset(_ asset: CreatorAsset) {
        assets.append(asset)
    }

    public func getAssets(for projectTag: String) -> [CreatorAsset] {
        return assets.filter { $0.projectTag.lowercased() == projectTag.lowercased() }
    }

    public func getAllProjectTags() -> [String] {
        return Array(Set(assets.map(\.projectTag))).sorted()
    }
}

// MARK: - [28] Personal Philosophy & Stoic Principles Compass

public struct StoicPrinciple: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let quote: String
    public let reflectionPrompt: String

    public init(id: UUID = UUID(), title: String, quote: String, reflectionPrompt: String) {
        self.id = id
        self.title = title
        self.quote = quote
        self.reflectionPrompt = reflectionPrompt
    }
}

public actor StoicPrinciplesEngine {
    private let principles: [StoicPrinciple] = [
        StoicPrinciple(
            title: "Διχασμός του Ελέγχου",
            quote: "Κάποια πράγματα εξαρτώνται από εμάς, κάποια άλλα όχι.",
            reflectionPrompt: "Εστίασες σήμερα αποκλειστικά σε ό,τι μπορείς να επηρεάσεις;"
        ),
        StoicPrinciple(
            title: "Memento Mori",
            quote: "Μπορείς να φύγεις από τη ζωή αυτή τη στιγμή. Άφησε αυτό να καθορίσει τι κάνεις και τι σκέφτεσαι.",
            reflectionPrompt: "Έζησες τη σημερινή ημέρα με βαθιά παρουσία και νόημα;"
        ),
        StoicPrinciple(
            title: "Amor Fati",
            quote: "Μην απαιτείς τα πράγματα να συμβαίνουν όπως θέλεις, αλλά αποδέξου τα όπως συμβαίνουν.",
            reflectionPrompt: "Αγκάλιασες τα απρόοπτα εμπόδια ως ευκαιρίες ενδυνάμωσης;"
        )
    ]

    public init() {}

    public func getDailyPrinciple(for date: Date = Date()) -> StoicPrinciple {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = (dayOfYear - 1) % principles.count
        return principles[index]
    }
}

// MARK: - [38] Sleep & Circadian Rhythm Alignment Coach

public struct CircadianSchedule: Codable, Sendable, Equatable {
    public let wakeTime: Date
    public let morningSunlightDeadline: Date
    public let caffeineCutoffTime: Date
    public let melatoninWindowStart: Date

    public init(wakeTime: Date) {
        self.wakeTime = wakeTime
        self.morningSunlightDeadline = wakeTime.addingTimeInterval(60 * 60) // within 1 hour
        self.caffeineCutoffTime = wakeTime.addingTimeInterval(9 * 3600)     // 9 hours post-wake
        self.melatoninWindowStart = wakeTime.addingTimeInterval(14 * 3600)  // 14 hours post-wake
    }
}

public actor CircadianRhythmCoach {
    public init() {}

    public func calculateSchedule(wakeTime: Date) -> CircadianSchedule {
        return CircadianSchedule(wakeTime: wakeTime)
    }
}

// MARK: - [39] Gym Set & Iron Volume Voice Logger

public struct GymSetLog: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let exercise: String
    public let weightKg: Double
    public let reps: Int
    public let rpe: Double
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        exercise: String,
        weightKg: Double,
        reps: Int,
        rpe: Double = 8.0,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.exercise = exercise
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.timestamp = timestamp
    }
}

public actor GymVoiceLoggerService {
    private var sets: [GymSetLog] = []

    public init() {}

    public func parseGymUtterance(_ text: String) -> GymSetLog? {
        // Natural language matching: e.g. "Squats 120 κιλά 6 reps rpe 8"
        let lower = text.lowercased()
        var exercise = "Exercise"
        if lower.contains("squat") || lower.contains("σκουωτ") { exercise = "Squat" }
        else if lower.contains("bench") || lower.contains("πάγκο") { exercise = "Bench Press" }
        else if lower.contains("deadlift") || lower.contains("άρσεις") { exercise = "Deadlift" }
        else if lower.contains("pull up") || lower.contains("έλξεις") { exercise = "Pull-ups" }

        // Find numbers
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }.compactMap { Double($0) }
        let weight = numbers.first ?? 100.0
        let reps = numbers.count > 1 ? Int(numbers[1]) : 5
        let rpe = numbers.count > 2 ? numbers[2] : 8.0

        let set = GymSetLog(exercise: exercise, weightKg: weight, reps: reps, rpe: rpe)
        sets.append(set)
        return set
    }

    public func getTotalVolumeKg() -> Double {
        return sets.reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
    }
}

// MARK: - [40] Cold Plunge & Box Breathing Audio Sentinel

public actor BoxBreathingGuide {
    public enum BreathPhase: String, Sendable {
        case inhale = "Εισπνοή (4s)"
        case holdIn = "Κράτημα (4s)"
        case exhale = "Εκπνοή (4s)"
        case holdOut = "Κενό (4s)"
    }

    private var currentPhase: BreathPhase = .inhale

    public init() {}

    public func nextPhase() -> BreathPhase {
        switch currentPhase {
        case .inhale: currentPhase = .holdIn
        case .holdIn: currentPhase = .exhale
        case .exhale: currentPhase = .holdOut
        case .holdOut: currentPhase = .inhale
        }
        return currentPhase
    }
}

public actor HealthKitTelemetryCoordinator {
    private let service: HealthKitService

    public init(service: HealthKitService = HealthKitService.shared) {
        self.service = service
    }

    public func requestAccess() async throws -> Bool {
        return try await service.requestAuthorization()
    }

    public func getLatestSnapshot() async -> HealthKitTelemetrySnapshot {
        return await service.fetchLiveTelemetrySnapshot()
    }
}

// MARK: - [42] Dynamic Ambient Chrono-Palette

public actor ChronoPaletteEngine {
    public init() {}

    public func getDynamicHex(for date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 7 && hour < 18 {
            return "00E5FF" // Cyber Cyan for alertness
        } else if hour >= 18 && hour < 22 {
            return "A78BFA" // Lavender for twilight calm
        } else {
            return "7742DC" // Violet for melatonin preservation
        }
    }
}

// MARK: - [43] Book Highlight OCR & Flashcard Excerptor

public actor BookHighlightOCREngine {
    public init() {}

    public func extractHighlight(from text: String) -> (quote: String, tags: [String]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (quote: trimmed, tags: ["#book", "#reading", "#insights"])
    }
}

// MARK: - [44] Personal Content Multi-Format Transformer

public struct TransformedContentBundle: Codable, Sendable, Equatable {
    public let twitterThread: [String]
    public let linkedInPost: String
    public let newsletterDraft: String
}

public actor ContentFormatTransformer {
    public init() {}

    public func transform(rawIdea: String) -> TransformedContentBundle {
        let tweet1 = "1/3 \(rawIdea.prefix(120))..."
        let tweet2 = "2/3 Βασικό συμπέρασμα: Η εκτέλεση προηγείται της τελειότητας."
        let tweet3 = "3/3 Καταγεγραμμένο στο R0lling Sovereign OS."

        let linkedIn = "💡 Στρατηγική Σκέψη:\n\n\(rawIdea)\n\n#Execution #Engineering #Leadership"
        let newsletter = "## Εβδομαδιαίο Insight\n\n\(rawIdea)\n\n*Σημείωση συστήματος: 1-User Sovereign Architecture.*"

        return TransformedContentBundle(
            twitterThread: [tweet1, tweet2, tweet3],
            linkedInPost: linkedIn,
            newsletterDraft: newsletter
        )
    }
}

// MARK: - [45] Infinite Visual Moodboard & Hex Extractor

public actor MoodboardPaletteExtractor {
    public init() {}

    public func extractTopColors() -> [String] {
        return ["#16161D", "#7742DC", "#00E5FF", "#A78BFA", "#55D6A4"]
    }
}

// MARK: - [46] Audio Spatial Memory Walk (Loci Method)

public struct GeoAudioMemory: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let latitude: Double
    public let longitude: Double
    public let audioRelativePath: String

    public init(id: UUID = UUID(), title: String, latitude: Double, longitude: Double, audioRelativePath: String) {
        self.id = id
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.audioRelativePath = audioRelativePath
    }
}

public actor GeoAudioMemoryCoordinator {
    private var memories: [GeoAudioMemory] = []

    public init() {}

    public func addMemory(_ memory: GeoAudioMemory) {
        memories.append(memory)
    }

    public func getNearbyMemories(lat: Double, lon: Double, radiusMeters: Double = 50.0) -> [GeoAudioMemory] {
        return memories.filter { mem in
            let dLat = (mem.latitude - lat) * 111_000
            let dLon = (mem.longitude - lon) * 111_000
            let dist = sqrt(dLat * dLat + dLon * dLon)
            return dist <= radiusMeters
        }
    }
}

// MARK: - [47] Subconscious Dream Pattern Matcher

public actor DreamPatternMatcher {
    public init() {}

    public func extractSymbols(from dreamText: String) -> [String: Int] {
        var counts: [String: Int] = [:]
        let symbolMap: [(key: String, forms: [String])] = [
            ("νερό", ["νερό", "νερού"]),
            ("θάλασσα", ["θάλασσα", "θάλασσας"]),
            ("πτήση", ["πτήση", "πετούσα", "πετάω"]),
            ("πτώση", ["πτώση", "έπεφτα"]),
            ("κώδικας", ["κώδικας", "κώδικα", "κώδικες"]),
            ("ταξίδι", ["ταξίδι", "ταξιδεύω"]),
            ("σπίτι", ["σπίτι", "σπιτιού"]),
            ("βουνό", ["βουνό", "βουνού"])
        ]
        let lower = dreamText.lowercased()
        for item in symbolMap {
            for form in item.forms {
                if lower.contains(form) {
                    counts[item.key, default: 0] += 1
                    break
                }
            }
        }
        return counts
    }
}

// MARK: - [48] Interactive Logic Fallacy & Bias Checker

public struct FallacyAuditResult: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let fallacyType: String
    public let excerpt: String
    public let suggestion: String

    public init(id: UUID = UUID(), fallacyType: String, excerpt: String, suggestion: String) {
        self.id = id
        self.fallacyType = fallacyType
        self.excerpt = excerpt
        self.suggestion = suggestion
    }
}

public actor LogicFallacyChecker {
    public init() {}

    public func auditArgument(_ argument: String) -> [FallacyAuditResult] {
        var results: [FallacyAuditResult] = []
        let lower = argument.lowercased()

        if lower.contains("πάντα") || lower.contains("ποτέ") || lower.contains("όλοι") {
            results.append(FallacyAuditResult(
                fallacyType: "Black-or-White / False Dilemma",
                excerpt: argument,
                suggestion: "Απόφυγε τις απόλυτες γενικεύσεις (πάντα/ποτέ). Εξέτασε το φάσμα των ενδιάμεσων πιθανοτήτων."
            ))
        }
        if lower.contains("αφού έχω ήδη ξοδέψει") || lower.contains("έχω ρίξει τόσο χρόνο") {
            results.append(FallacyAuditResult(
                fallacyType: "Sunk Cost Fallacy",
                excerpt: argument,
                suggestion: "Η προηγούμενη επένδυση χρόνου δεν δικαιολογεί μελλοντικές μη-αποδοτικές επιλογές."
            ))
        }
        return results
    }
}
