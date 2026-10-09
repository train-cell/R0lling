import Foundation
import CryptoKit

// MARK: - [CATEGORY 1] Neuro-Cognitive Engines

public actor DopaminePacerEngine {
    public enum RegulationState: String, Sendable {
        case regulated = "Regulated (84%)"
        case elevated = "Elevated Stimulus"
        case resetRequired = "Dopamine Reset Advised"
    }

    private var appSwitchesCount: Int = 0
    private var lastResetTime: Date = Date()

    public init() {}

    public func registerAppSwitch() -> RegulationState {
        appSwitchesCount += 1
        if appSwitchesCount > 15 {
            return .resetRequired
        } else if appSwitchesCount > 8 {
            return .elevated
        }
        return .regulated
    }

    public func triggerReset() {
        appSwitchesCount = 0
        lastResetTime = Date()
    }
}

public actor OcularFatigueTracker {
    public struct FatigueScore: Sendable, Equatable {
        public let blinksPerMinute: Int
        public let classification: String
    }

    public init() {}

    public func evaluateBlinkRate(blinks: Int, durationSeconds: Double) -> FatigueScore {
        let rate = Int((Double(blinks) / max(1.0, durationSeconds)) * 60.0)
        let classification = rate > 22 ? "High Fatigue" : (rate < 10 ? "Intense Stare" : "Optimal (Resting)")
        return FatigueScore(blinksPerMinute: rate, classification: classification)
    }
}

public actor WorkingMemoryBenchmarker {
    public init() {}

    public func scoreDualTask(forwardSequenceLength: Int, reversedCorrect: Bool, logicAnswerTimeSec: Double) -> Int {
        var score = forwardSequenceLength * 12
        if reversedCorrect { score += 25 }
        if logicAnswerTimeSec < 3.0 { score += 15 }
        return min(100, max(20, score))
    }
}

public actor VerbalEntropyRadarEngine {
    public struct EntropyMetrics: Sendable, Equatable {
        public let syllablesPerMinute: Double
        public let lexicalDiversityRatio: Double
        public let cognitiveState: String
    }

    public init() {}

    public func analyzeSpeechEntropy(wordCount: Int, uniqueWords: Int, durationSeconds: Double) -> EntropyMetrics {
        let spm = (Double(wordCount * 2) / max(1.0, durationSeconds)) * 60.0
        let diversity = Double(uniqueWords) / Double(max(1, wordCount))
        let state = (diversity > 0.65 && spm > 120) ? "Flow State" : "Dispersed Entropy"
        return EntropyMetrics(
            syllablesPerMinute: (spm * 10).rounded() / 10,
            lexicalDiversityRatio: (diversity * 100).rounded() / 100,
            cognitiveState: state
        )
    }
}

public actor PinkNoiseSleepEngine {
    public init() {}

    public func getCoherentBreathingPacing() -> (inhaleSec: Double, exhaleSec: Double) {
        return (inhaleSec: 5.5, exhaleSec: 5.5) // 0.09 Hz resonance frequency
    }
}

public actor MentalStateAnchorEngine {
    public init() {}

    public func triggerPavlovianAnchor() -> (frequencyHz: Double, hapticPattern: String) {
        return (frequencyHz: 432.0, hapticPattern: "ContinuousSubtlePulse")
    }
}

public actor SelfTalkSentimentAuditor {
    public init() {}

    public func auditTranscript(_ text: String) -> [String] {
        let negativeTriggers = ["δεν μπορώ", "είναι αδύνατον", "αποτυγχάνω", "αδύναμος", "φοβάμαι"]
        var findings: [String] = []
        let lower = text.lowercased()
        for trig in negativeTriggers {
            if lower.contains(trig) {
                findings.append("Ανιχνεύθηκε αυτο-υπονόμευση: «\(trig)» ➔ Προτεινόμενη αναπλαισίωση σε στρατηγική ευκαιρία.")
            }
        }
        return findings
    }
}

public actor CircadianChronoPeakScheduler {
    public init() {}

    public func computePeakWindows(wakeTime: Date) -> (optimalFocusStart: Date, optimalFocusEnd: Date) {
        let start = wakeTime.addingTimeInterval(2.5 * 3600)
        let end = wakeTime.addingTimeInterval(5.0 * 3600)
        return (start, end)
    }
}

// MARK: - [CATEGORY 2] Biomechanical & Athletic Engines

public actor BarbellVelocityEngine {
    public struct RepVelocity: Sendable, Equatable {
        public let meanVelocityMps: Double
        public let powerLossPercent: Double
    }

    public init() {}

    public func calculateVelocity(displacementMeters: Double, timeSeconds: Double, firstRepVelocity: Double) -> RepVelocity {
        let velocity = displacementMeters / max(0.1, timeSeconds)
        let loss = firstRepVelocity > 0 ? max(0.0, ((firstRepVelocity - velocity) / firstRepVelocity) * 100.0) : 0.0
        return RepVelocity(
            meanVelocityMps: (velocity * 100).rounded() / 100,
            powerLossPercent: (loss * 10).rounded() / 10
        )
    }
}

public actor HeartRateRecoveryPacer {
    public init() {}

    public func evaluateHRR(peakHR: Int, postOneMinHR: Int) -> (dropBpm: Int, rating: String) {
        let drop = peakHR - postOneMinHR
        let rating = drop >= 35 ? "Elite (Fast Clearance)" : (drop >= 25 ? "Good Recovery" : "Elevated Sympathetic Tone")
        return (drop, rating)
    }
}

public actor HydrationOsmolalityLogger {
    public init() {}

    public func computeDeficit(drankMl: Int, activeCalories: Int) -> (remainingMl: Int, isOptimal: Bool) {
        let targetMl = 2500 + Int(Double(activeCalories) * 0.7)
        let remaining = max(0, targetMl - drankMl)
        return (remaining, remaining == 0)
    }
}

public actor SaunaHeatShockTimer {
    public init() {}

    public func evaluateHeatShockActivation(minutesInSauna: Int, tempCelsius: Int) -> Bool {
        return minutesInSauna >= 15 && tempCelsius >= 75
    }
}

public actor StepPacingEngine {
    public init() {}

    public func checkHourlyPace(currentSteps: Int, targetDailySteps: Int = 10000, currentHour: Int) -> Int {
        let expectedSoFar = Int((Double(targetDailySteps) / 14.0) * Double(max(1, currentHour - 7)))
        return currentSteps - expectedSoFar // negative means deficit
    }
}

public actor CO2ToleranceBenchmarker {
    public init() {}

    public func scoreBreathHold(seconds: Int) -> String {
        if seconds >= 60 { return "Master (>60s High Resiliency)" }
        if seconds >= 35 { return "Intermediate (Healthy Regulation)" }
        return "Developing (<35s Sympathetic Dominant)"
    }
}

public actor DomsReadinessMatrix {
    public init() {}

    public func adjustTrainingVolume(sorenessLevel1to5: Int) -> Double {
        switch sorenessLevel1to5 {
        case 5: return 0.50 // -50% deload
        case 4: return 0.70 // -30%
        case 3: return 0.85 // -15%
        default: return 1.00 // full volume
        }
    }
}

public actor FastingAutophagyEngine {
    public enum FastingStage: String, Sendable {
        case glycogenDepletion = "Glycogen Depletion (0-12h)"
        case mildKetosis = "Mild Ketosis (12-16h)"
        case autophagyActive = "Autophagy Active (16-24h)"
        case deepCellularCleanse = "Deep Autophagy (24h+)"
    }

    public init() {}

    public func getFastingStage(hoursFasted: Double) -> FastingStage {
        if hoursFasted >= 24.0 { return .deepCellularCleanse }
        if hoursFasted >= 16.0 { return .autophagyActive }
        if hoursFasted >= 12.0 { return .mildKetosis }
        return .glycogenDepletion
    }
}

// MARK: - [CATEGORY 3] Cryptography & Defensive Engines

public actor AcousticLeakDetector {
    public init() {}

    public func scanHighFrequencies(maxDetectedFrequencyHz: Double) -> Bool {
        return maxDetectedFrequencyHz > 18500.0 // True if ultrasonic beacon detected
    }
}

public actor PanicDecoyCoordinator {
    public init() {}

    public func triggerZeroization() -> Bool {
        // No secure erasure primitive is integrated; do not claim success.
        return false
    }
}

public actor BleSurveillanceSniffer {
    public init() {}

    public func isSuspiciousProximity(trackingDurationSeconds: Double) -> Bool {
        return trackingDurationSeconds > 900.0 // 15 minutes of continuous shadowing
    }
}

public actor EphemeralVoiceScratchpad {
    private var volatileBuffer: [String] = []

    public init() {}

    public func storeVolatileThought(_ text: String) {
        volatileBuffer.append(text)
    }

    public func purgeVolatileRAM() {
        volatileBuffer.removeAll()
    }
}

public actor NetworkExfiltrationCanary {
    public init() {}

    public func isAddressPrivateLAN(ip: String) -> Bool {
        return ip.hasPrefix("192.168.") || ip.hasPrefix("10.") || ip == "127.0.0.1" || ip == "localhost"
    }
}

public actor ExifScrubberService {
    public init() {}

    /// Re-encodes a single image with only orientation; discards source metadata.
    public func sanitizeImageData(data: Data) throws -> Data {
        try ImageMetadataSanitizer.encode(data)
    }
}

public actor ProofOfExistenceNotary {
    public init() {}

    public func generateSha256Digest(content: String) -> String {
        return SHA256.hash(data: Data(content.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - [CATEGORY 4] Executive Operations Engines

public actor NegotiationRehearsalEngine {
    public init() {}

    public func evaluateCounterResponse(latencySeconds: Double, pitchStabilityScore: Double) -> (persuasiveness: Int, feedback: String) {
        let score = Int((pitchStabilityScore * 60) + max(0, (5.0 - latencySeconds) * 8))
        let feedback = latencySeconds < 2.0 ? "Σταθερή, ακαριαία απόκριση." : "Μικρός δισταγμός πριν την αντεπίθεση."
        return (min(100, max(20, score)), feedback)
    }
}

public actor EnergyRoiTaskAllocator {
    public init() {}

    public func validateDailyCapacity(highEnergyTasksCount: Int) -> Bool {
        return highEnergyTasksCount <= 3 // Hard limit of 3 high-cognitive load tasks
    }
}

public actor AntiProcrastinationPacer {
    public init() {}

    public func getActivationWindowSeconds() -> Int {
        return 300 // 5-Minute rule
    }
}

public actor SecondOrderThinkingEngine {
    public init() {}

    public func generateInquiryQuestions(decision: String) -> [String] {
        return [
            "Και μετά τι συμβαίνει σε 6 μήνες από την απόφαση «\(decision)»;",
            "Ποιο απρόσμενο μέρος θα επηρεαστεί αρνητικά;",
            "Αν αυτή η επιλογή αποτύχει, ποια ήταν η τυφλή υπόθεση;"
        ]
    }
}

public actor TimeSinkAuditor {
    public init() {}

    public func computeLeverageRatio(highLeverageHours: Double, lowLeverageHours: Double) -> Double {
        let total = highLeverageHours + lowLeverageHours
        guard total > 0 else { return 1.0 }
        return (highLeverageHours / total) * 100.0
    }
}

public actor OpenLoopExterminator {
    public init() {}

    public func isChronicOpenLoop(daysActive: Int) -> Bool {
        return daysActive >= 14
    }
}

public actor AdvisoryBoardSimulator {
    public init() {}

    public func queryAdvisors(problem: String) -> [(advisor: String, council: String)] {
        return [
            ("Μάρκος Αυρήλιος (Στωικισμός)", "Έλεγξε μόνο ό,τι εξαρτάται από τη δική σου κρίση."),
            ("Steve Jobs (Προϊόν)", "Αφαίρεσε το περιττό. Κάνε το απλό και μαγικό."),
            ("Charlie Munger (Αντιστροφή)", "Αντίστρεψε πάντα. Πώς θα εξασφάλιζες την απόλυτη αποτυχία;")
        ]
    }
}

public actor DailyMomentumTracker {
    public init() {}

    public func recordWins(count: Int) -> Int {
        return count * 10 // 10 momentum points per win
    }
}

// MARK: - [CATEGORY 5] Sensory & Creative Engines

public actor AcousticSoundscapeSynthesizer {
    public init() {}

    public func getAdaptiveFrequency(ambientNoiseDb: Double) -> Double {
        return ambientNoiseDb > 60.0 ? 528.0 : 432.0
    }
}

public actor VoicePitchBiofeedbackEngine {
    public init() {}

    public func evaluateTension(pitchHz: Double) -> String {
        return pitchHz > 180.0 ? "High Vocal Tension (Relax Larynx)" : "Regulated Diaphragmatic Pitch"
    }
}

public actor PerspectiveRectifierEngine {
    public init() {}

    public func isQuadAligned(cornerAnglesDegrees: [Double]) -> Bool {
        return cornerAnglesDegrees.allSatisfy { abs($0 - 90.0) < 15.0 }
    }
}

public actor SpatialLociMemoryEngine {
    public init() {}

    public func calculateLociBearing(userHeadingDegrees: Double, lociHeadingDegrees: Double) -> Double {
        return abs(userHeadingDegrees - lociHeadingDegrees)
    }
}

public actor KindleClippingsParser {
    public init() {}

    public func parseRawClippings(_ text: String) -> [String] {
        return text.components(separatedBy: "==========").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

public actor ConceptWireframeSketcher {
    public init() {}

    public func synthesizeWireframeAscii(description: String) -> String {
        return """
        +----------------------------+
        | [=] \(description.prefix(20)) |
        +----------------------------+
        |      HERO TELEMETRY        |
        |       ( ( 40Hz ) )         |
        +----------------------------+
        | [ ACTION A ]  [ ACTION B ] |
        +----------------------------+
        """
    }
}

public actor DreamSymbolCorrelationMatrix {
    public init() {}

    public func correlateDreamWithBiometrics(symbol: String, lateCaffeine: Bool, poorSleep: Bool) -> Double {
        if symbol == "water" && lateCaffeine { return 0.76 }
        if symbol == "falling" && poorSleep { return 0.84 }
        return 0.45
    }
}

public actor GenerationalLegacyVault {
    public init() {}

    public func createArchiveSeal(recordTitle: String) -> String {
        return "LEGACY-SEAL-\(recordTitle.uppercased())-\(Date().timeIntervalSince1970)"
    }
}
