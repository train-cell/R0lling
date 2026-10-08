import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - [01] Chief of Staff (Jarvis Engine)

public enum TaskPriority: String, Codable, Sendable {
    case high
    case medium
    case low
}

public struct ChiefOfStaffTask: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public var priority: TaskPriority
    public var dueDate: Date?
    public var isCompleted: Bool
    public let originEntryId: UUID
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        originEntryId: UUID = UUID(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.originEntryId = originEntryId
        self.createdAt = createdAt
    }
}

public actor ChiefOfStaffService {
    private var tasks: [ChiefOfStaffTask] = []

    public init() {}

    public func parseTasks(from stream: String, originId: UUID = UUID()) -> [ChiefOfStaffTask] {
        var results: [ChiefOfStaffTask] = []
        let lines = stream.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.lowercased().contains("urgent") || trimmed.lowercased().contains("επείγον") || trimmed.hasPrefix("!") {
                results.append(ChiefOfStaffTask(title: trimmed, priority: .high, originEntryId: originId))
            } else if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("•") {
                let cleanTitle = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                results.append(ChiefOfStaffTask(title: cleanTitle, priority: .medium, originEntryId: originId))
            } else {
                results.append(ChiefOfStaffTask(title: trimmed, priority: .low, originEntryId: originId))
            }
        }
        self.tasks.append(contentsOf: results)
        return results
    }

    public func getAllTasks() -> [ChiefOfStaffTask] {
        return tasks
    }

    public func toggleTask(id: UUID) -> Bool {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].isCompleted.toggle()
            return tasks[idx].isCompleted
        }
        return false
    }
}

// MARK: - [02] Obsidian Live Zettelkasten Linker

public struct ZettelkastenConnection: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let targetNoteTitle: String
    public let relativeVaultPath: String
    public let similarityScore: Double

    public init(
        id: UUID = UUID(),
        targetNoteTitle: String,
        relativeVaultPath: String,
        similarityScore: Double
    ) {
        self.id = id
        self.targetNoteTitle = targetNoteTitle
        self.relativeVaultPath = relativeVaultPath
        self.similarityScore = similarityScore
    }
}

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

// MARK: - [13] Cognitive Deep Work Sentinel

public actor DeepWorkSessionManager {
    public enum SessionState: Sendable, Equatable {
        case idle
        case active(startedAt: Date, durationSeconds: TimeInterval, goal: String)
        case paused(elapsedSeconds: TimeInterval, goal: String)
        case completed(durationSeconds: TimeInterval, goal: String, debrief: String?)
    }

    private var state: SessionState = .idle

    public init() {}

    public func startSession(goal: String, durationMinutes: Int = 25) {
        let duration = TimeInterval(durationMinutes * 60)
        self.state = .active(startedAt: Date(), durationSeconds: duration, goal: goal)
    }

    public func completeSession(debrief: String? = nil) -> TimeInterval {
        switch state {
        case .active(let startedAt, _, let goal):
            let elapsed = Date().timeIntervalSince(startedAt)
            self.state = .completed(durationSeconds: elapsed, goal: goal, debrief: debrief)
            return elapsed
        case .paused(let elapsed, let goal):
            self.state = .completed(durationSeconds: elapsed, goal: goal, debrief: debrief)
            return elapsed
        default:
            return 0
        }
    }

    public func getState() -> SessionState {
        return state
    }
}

// MARK: - [14] Decision Journal & Bias Auditor

public struct DecisionRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let decisionText: String
    public let coreAssumptions: [String]
    public let confidencePercent: Int
    public let createdAt: Date
    public let reviewDate: Date
    public var outcomeReview: String?
    public var isReviewed: Bool

    public init(
        id: UUID = UUID(),
        decisionText: String,
        coreAssumptions: [String],
        confidencePercent: Int,
        createdAt: Date = Date(),
        reviewDate: Date = Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date(),
        outcomeReview: String? = nil,
        isReviewed: Bool = false
    ) {
        self.id = id
        self.decisionText = decisionText
        self.coreAssumptions = coreAssumptions
        self.confidencePercent = confidencePercent
        self.createdAt = createdAt
        self.reviewDate = reviewDate
        self.outcomeReview = outcomeReview
        self.isReviewed = isReviewed
    }
}

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

// MARK: - [15] Daily Energy & Cognitive Readiness Index

public struct CognitiveTelemetryScore: Codable, Sendable, Equatable {
    public let cognitiveStrain: Double   // 0.0 to 21.0
    public let focusMinutes: Int
    public let readinessPercent: Int    // 0 to 100

    public init(cognitiveStrain: Double, focusMinutes: Int, readinessPercent: Int) {
        self.cognitiveStrain = cognitiveStrain
        self.focusMinutes = focusMinutes
        self.readinessPercent = readinessPercent
    }
}

public actor CognitiveReadinessCalculator {
    public init() {}

    public func computeTelemetry(entriesCount: Int, deepWorkSeconds: TimeInterval, vocalStressFactor: Double = 1.0) -> CognitiveTelemetryScore {
        let hoursOfFocus = deepWorkSeconds / 3600.0
        let rawStrain = (Double(entriesCount) * 1.4) + (hoursOfFocus * 4.2) * vocalStressFactor
        let normalizedStrain = min(21.0, max(0.0, rawStrain))
        
        let fatigueReduction = Int(normalizedStrain * 3.8)
        let baseReadiness = 100 - fatigueReduction
        let finalReadiness = max(15, min(100, baseReadiness))

        return CognitiveTelemetryScore(
            cognitiveStrain: (normalizedStrain * 10).rounded() / 10,
            focusMinutes: Int(deepWorkSeconds / 60),
            readinessPercent: finalReadiness
        )
    }
}

// MARK: - [21] Zero-Knowledge Private Diary (FaceID Lock)

public actor BiometricSecurityManager {
    public init() {}

    public func canAuthenticate() -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        #else
        return true
        #endif
    }

    public func authenticateBiometrics(reason: String = "Ξεκλείδωμα Ιδιωτικού Ημερολογίου") async -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
        #else
        return true
        #endif
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

// MARK: - [37] Ambient Soundscape & Binaural Focus Synthesizer

public actor BinauralFocusSynthesizer {
    public enum BeatType: String, Sendable {
        case gamma40Hz = "40Hz Gamma (Hyper-Focus)"
        case beta20Hz = "20Hz Beta (Active Work)"
        case alpha10Hz = "10Hz Alpha (Flow State)"
        case theta6Hz = "6Hz Theta (Deep Relaxation)"
    }

    private var isPlaying: Bool = false
    private var currentBeat: BeatType = .gamma40Hz

    public init() {}

    public func setBeat(_ beat: BeatType) {
        self.currentBeat = beat
    }

    public func togglePlayback() -> Bool {
        isPlaying.toggle()
        return isPlaying
    }

    public func getStatus() -> (isPlaying: Bool, currentBeat: BeatType) {
        return (isPlaying, currentBeat)
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

// MARK: - [41] Biometric HealthKit Telemetry Correlation

public struct HealthKitTelemetrySnapshot: Codable, Sendable, Equatable {
    public let hrvMs: Double
    public let restingHRBpm: Int
    public let respiratoryRate: Double
    public let bloodOxygenPercent: Double
    public let recoveryScore: Int

    public init(
        hrvMs: Double = 68.0,
        restingHRBpm: Int = 54,
        respiratoryRate: Double = 14.2,
        bloodOxygenPercent: Double = 98.5,
        recoveryScore: Int = 88
    ) {
        self.hrvMs = hrvMs
        self.restingHRBpm = restingHRBpm
        self.respiratoryRate = respiratoryRate
        self.bloodOxygenPercent = bloodOxygenPercent
        self.recoveryScore = recoveryScore
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
        let keywords = ["νερό", "θάλασσα", "πτήση", "πτώση", "κώδικας", "ταξίδι", "σπίτι", "βουνό"]
        let lower = dreamText.lowercased()
        for kw in keywords {
            if lower.contains(kw) {
                counts[kw, default: 0] += 1
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
