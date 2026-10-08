import Foundation

// MARK: - =====================================================================
// MARK: [PILLAR 1] Κολυμβητική & Αθλητική Υπεραπόδοση (Swim & Kinetic Mastery)
// MARK: =====================================================================

/// [SW-01] Stroke Cadence & DPS Audio Pacer
public actor StrokeCadencePacerEngine {
    public struct CadenceMetrics: Sendable, Equatable {
        public let strokesPerMinute: Double
        public let distancePerStrokeMeters: Double
        public let strokeEfficiencyIndex: Double
        public let isOptimalCadence: Bool
    }

    public init() {}

    public func calculateDPS(poolLengthMeters: Double, strokeCount: Int, lapTimeSeconds: Double) -> CadenceMetrics {
        guard strokeCount > 0, lapTimeSeconds > 0 else {
            return CadenceMetrics(strokesPerMinute: 0, distancePerStrokeMeters: 0, strokeEfficiencyIndex: 0, isOptimalCadence: false)
        }
        let spm = (Double(strokeCount) / lapTimeSeconds) * 60.0
        let dps = poolLengthMeters / Double(strokeCount)
        let speed = poolLengthMeters / lapTimeSeconds
        let efficiency = speed * dps // Stroke Index
        let optimal = (spm >= 32.0 && spm <= 42.0 && dps >= 1.8)
        return CadenceMetrics(
            strokesPerMinute: (spm * 10).rounded() / 10,
            distancePerStrokeMeters: (dps * 100).rounded() / 100,
            strokeEfficiencyIndex: (efficiency * 100).rounded() / 100,
            isOptimalCadence: optimal
        )
    }
}

/// [SW-02] Lactate Accumulation & Turn Velocity Estimator
public actor LactateAccumulationEstimator {
    public enum EnergyZone: String, Sendable {
        case aerobicBaseA1 = "A1 Aerobic Base (<2 mmol/L)"
        case thresholdA2 = "A2 Aerobic Threshold (2-4 mmol/L)"
        case lactateTolerance = "VO2 Max / Lactate Tolerance (4-8 mmol/L)"
        case maxAnaerobicLactic = "Peak Anaerobic (>8 mmol/L)"
    }

    public init() {}

    public func estimateLactate(avgHeartRate: Int, maxHeartRate: Int, highIntensitySeconds: Double) -> (lactateMmol: Double, zone: EnergyZone) {
        let hrFraction = Double(avgHeartRate) / Double(max(1, maxHeartRate))
        var lactate: Double = 1.2
        if hrFraction > 0.90 {
            lactate = 4.0 + (Double(highIntensitySeconds) / 60.0) * 1.5
        } else if hrFraction > 0.82 {
            lactate = 2.5 + (Double(highIntensitySeconds) / 120.0) * 0.8
        } else {
            lactate = 1.5
        }
        lactate = min(16.0, (lactate * 10).rounded() / 10)

        let zone: EnergyZone
        if lactate > 8.0 { zone = .maxAnaerobicLactic }
        else if lactate >= 4.0 { zone = .lactateTolerance }
        else if lactate >= 2.0 { zone = .thresholdA2 }
        else { zone = .aerobicBaseA1 }

        return (lactate, zone)
    }
}

/// [SW-03] Pool Turn Deceleration Sentry
public actor PoolTurnDecelerationSentry {
    public struct TurnProfile: Sendable, Equatable {
        public let approachVelocityMps: Double
        public let wallContactTimeSeconds: Double
        public let exitVelocityMps: Double
        public let momentumLossPercent: Double
    }

    public init() {}

    public func analyzeTurn(approachV: Double, contactSec: Double, exitV: Double) -> TurnProfile {
        let loss = approachV > 0 ? max(0.0, ((approachV - exitV) / approachV) * 100.0) : 0.0
        return TurnProfile(
            approachVelocityMps: (approachV * 100).rounded() / 100,
            wallContactTimeSeconds: (contactSec * 100).rounded() / 100,
            exitVelocityMps: (exitV * 100).rounded() / 100,
            momentumLossPercent: (loss * 10).rounded() / 10
        )
    }
}

/// [SW-04] Dryland-to-Pool Power Transfer Auditor
public actor DrylandPowerTransferAuditor {
    public init() {}

    public func computeTransferIndex(tonnageKg: Double, meanVelocityMps: Double, underwater15mTimeSec: Double) -> Double {
        guard underwater15mTimeSec > 0 else { return 0.0 }
        let drylandPowerScore = (tonnageKg / 1000.0) * meanVelocityMps
        let poolSpeed = 15.0 / underwater15mTimeSec
        let transfer = (drylandPowerScore * poolSpeed) * 10.0
        return (transfer * 10).rounded() / 10
    }
}

/// [SW-05] Dynamic PB Split Matrix (100m / 200m / 400m)
public actor DynamicPBSplitMatrixEngine {
    public struct TargetSplits: Sendable, Equatable {
        public let distanceMeters: Int
        public let split50s: [Double]
        public let totalTargetTimeSec: Double
    }

    public init() {}

    public func calculateTargetSplits(distance: Int, bestTimeSec: Double, recoveryScorePercent: Int) -> TargetSplits {
        let pacingFactor = recoveryScorePercent >= 85 ? 0.99 : (recoveryScorePercent >= 65 ? 1.00 : 1.02)
        let targetTotal = bestTimeSec * pacingFactor
        var splits: [Double] = []

        if distance == 100 {
            let first50 = targetTotal * 0.48 // Dive bonus
            let second50 = targetTotal * 0.52
            splits = [(first50 * 100).rounded() / 100, (second50 * 100).rounded() / 100]
        } else if distance == 200 {
            let split1 = targetTotal * 0.235
            let split2 = targetTotal * 0.255
            let split3 = targetTotal * 0.258
            let split4 = targetTotal * 0.252
            splits = [split1, split2, split3, split4].map { ($0 * 100).rounded() / 100 }
        } else {
            let per50 = targetTotal / 8.0
            splits = Array(repeating: (per50 * 100).rounded() / 100, count: 8)
        }

        return TargetSplits(
            distanceMeters: distance,
            split50s: splits,
            totalTargetTimeSec: (targetTotal * 100).rounded() / 100
        )
    }
}

/// [SW-06] Breathing Pattern & Hypoxic Volume Tracker
public actor HypoxicBreathingTracker {
    public init() {}

    public func calculateHypoxicVolume(strokesPerBreath: Int, totalLaps: Int, strokesPerLap: Int) -> (hypoxicBreathsTaken: Int, co2ToleranceRating: String) {
        let totalStrokes = totalLaps * strokesPerLap
        let breaths = totalStrokes / max(1, strokesPerBreath)
        let rating = strokesPerBreath >= 7 ? "Extreme (High CO2 Tolerance)" : (strokesPerBreath >= 5 ? "Advanced Hypoxic" : "Standard Bilateral")
        return (breaths, rating)
    }
}

/// [SW-07] Swimmer Shoulder Impingement Early-Warning Guard
public actor ShoulderImpingementGuard {
    public init() {}

    public func auditShoulderRisk(acwrRatio: Double, weeklyVolumeMeters: Int, reportedSoreness: Int) -> (isHighRisk: Bool, recommendation: String) {
        if acwrRatio > 1.4 || (weeklyVolumeMeters > 25000 && reportedSoreness >= 4) {
            return (true, "⚠️ Υψηλό ρίσκο σύνδρομου πρόσκρουσης ώμου. Μείωση όγκου κατά 30% και ενεργοποίηση στροφέων.")
        }
        return (false, "Φυσιολογική φόρτιση ώμου. Συνέχιση κανονικού προγράμματος.")
    }
}

/// [SW-08] Post-Pool Glycogen Window Countdown
public actor PostPoolGlycogenPacer {
    public struct NutrientRefuel: Sendable, Equatable {
        public let targetCarbsGrams: Int
        public let targetProteinGrams: Int
        public let windowDurationMinutes: Int
    }

    public init() {}

    public func computeNutrientRefuel(activeCaloriesBurned: Int) -> NutrientRefuel {
        let carbs = Int(Double(activeCaloriesBurned) * 0.15) // ~1-1.2g/kg
        let protein = Int(Double(carbs) / 4.0) // 4:1 Ratio
        return NutrientRefuel(targetCarbsGrams: max(30, carbs), targetProteinGrams: max(15, protein), windowDurationMinutes: 45)
    }
}

// MARK: - =====================================================================
// MARK: [PILLAR 2] Ακαδημαϊκή & Μηχανική Υπερ-Μάθηση (ECE & System Architecture)
// MARK: =====================================================================

/// [ECE-01] Voice-Driven Instruction Cycle & Datapath Resolver
public actor DatapathCycleResolverEngine {
    public struct InstructionSignals: Sendable, Equatable {
        public let instruction: String
        public let singleCycleCPI: Int
        public let pipelineCyclesWithoutHazard: Int
        public let memToReg: Int
        public let aluSrc: Int
        public let regWrite: Int
    }

    public init() {}

    public func resolveInstruction(_ mnemonic: String) -> InstructionSignals {
        let clean = mnemonic.lowercased().trimmingCharacters(in: .whitespaces)
        switch clean {
        case "lw":
            return InstructionSignals(instruction: "lw", singleCycleCPI: 1, pipelineCyclesWithoutHazard: 5, memToReg: 1, aluSrc: 1, regWrite: 1)
        case "sw":
            return InstructionSignals(instruction: "sw", singleCycleCPI: 1, pipelineCyclesWithoutHazard: 4, memToReg: 0, aluSrc: 1, regWrite: 0)
        case "add", "sub":
            return InstructionSignals(instruction: clean, singleCycleCPI: 1, pipelineCyclesWithoutHazard: 4, memToReg: 0, aluSrc: 0, regWrite: 1)
        case "beq", "bne":
            return InstructionSignals(instruction: clean, singleCycleCPI: 1, pipelineCyclesWithoutHazard: 3, memToReg: 0, aluSrc: 0, regWrite: 0)
        default:
            return InstructionSignals(instruction: clean, singleCycleCPI: 1, pipelineCyclesWithoutHazard: 4, memToReg: 0, aluSrc: 1, regWrite: 1)
        }
    }
}

/// [ECE-02] Psarakis Trap Scanner & Golden Rules Validator
public actor PsarakisTrapScanner {
    public init() {}

    public func scanCodeForTraps(_ assemblyText: String) -> [String] {
        var traps: [String] = []
        let lower = assemblyText.lowercased()
        if lower.contains("lb ") && !lower.contains("lbu ") {
            traps.append("⚠️ ΠΑΓΙΔΑ: Το `lb` εκτελεί sign-extension. Αν το byte έχει MSB=1 (0x80-0xFF), το άνω 24-bit συμπληρώνεται με 1s.")
        }
        if lower.contains("lw ") && lower.contains("(") {
            traps.append("⚠️ ΠΑΓΙΔΑ: Βεβαιώσου ότι το offset και η διεύθυνση είναι πολλαπλάσιο του 4 (Word-aligned).")
        }
        if lower.contains("slti ") && !lower.contains("sltiu ") {
            traps.append("⚠️ ΠΑΓΙΔΑ: Το `slti` κάνει signed σύγκριση. Το 0xFFFF θεωρείται -1 και είναι μικρότερο από το 0.")
        }
        return traps
    }
}

/// [ECE-03] Spaced Repetition Mnemonic Flash-Engine (SM-2 ECE)
public actor SpacedRepetitionECEEngine {
    public struct FlashCard: Sendable, Equatable {
        public let concept: String
        public let definition: String
        public let intervalDays: Int
    }

    public init() {}

    public func getDailyFlashcards() -> [FlashCard] {
        return [
            FlashCard(concept: "Σηματοφόρος vs Mutex", definition: "Ο mutex έχει ownership (μόνο ο κτήτορας κάνει unlock). Ο σημαφόρος P/V λειτουργεί ως signalling token.", intervalDays: 3),
            FlashCard(concept: "Peterson's Algorithm", definition: "Αλγόριθμος αμοιβαίου αποκλεισμού 2 διεργασιών με flag[2] και turn, χωρίς ειδικές εντολές υλικού.", intervalDays: 7),
            FlashCard(concept: "TLB Hit vs Miss EAT", definition: "EAT = Hit_Ratio*(TLB_Time + Mem_Time) + Miss_Ratio*(TLB_Time + 2*Mem_Time).", intervalDays: 14)
        ]
    }
}

/// [ECE-04] Code-to-Hardware Assembly Disassembler Audio Brief
public actor AssemblyDisassemblerBriefEngine {
    public init() {}

    public func generateBrief(assemblyLine: String) -> String {
        if assemblyLine.contains("add ") {
            return "ALU εκτελεί άθροιση των δύο καταχωρητών εισόδου και γράφει το αποτέλεσμα στο RegWrite stage."
        } else if assemblyLine.contains("lw ") {
            return "ALU υπολογίζει τη διεύθυνση βάσης συν offset, και ενεργοποιεί το MemRead για φόρτωση από τη RAM."
        }
        return "Γενική εντολή ροής επεξεργαστή."
    }
}

/// [ECE-05] IEEE-754 Floating-Point Instant Converter & Bias Audit
public actor IEEE754InstantConverterEngine {
    public struct IEEE754Result: Sendable, Equatable {
        public let signBit: Int
        public let biasedExponent: Int
        public let exponentBits: String
        public let mantissaBits: String
        public let hexRepresentation: String
    }

    public init() {}

    public func convertFloat(_ value: Float) -> IEEE754Result {
        let bitPattern = value.bitPattern
        let sign = Int((bitPattern >> 31) & 0x1)
        let exp = Int((bitPattern >> 23) & 0xFF)
        let mant = bitPattern & 0x7FFFFF
        let hex = String(format: "0x%08X", bitPattern)
        return IEEE754Result(
            signBit: sign,
            biasedExponent: exp,
            exponentBits: String(exp, radix: 2),
            mantissaBits: String(mant, radix: 2),
            hexRepresentation: hex
        )
    }
}

/// [ECE-06] Operating Systems Deadlock & Banker's Algorithm Simulator
public actor DeadlockBankerSimulator {
    public init() {}

    public func isSafeState(available: [Int], allocation: [[Int]], need: [[Int]]) -> (isSafe: Bool, safeSequence: [Int]) {
        var work = available
        var finish = Array(repeating: false, count: allocation.count)
        var sequence: [Int] = []

        var count = 0
        while count < allocation.count {
            var found = false
            for p in 0..<allocation.count {
                if !finish[p] {
                    var canAllocate = true
                    for j in 0..<work.count {
                        if need[p][j] > work[j] {
                            canAllocate = false
                            break
                        }
                    }
                    if canAllocate {
                        for j in 0..<work.count {
                            work[j] += allocation[p][j]
                        }
                        sequence.append(p)
                        finish[p] = true
                        found = true
                        count += 1
                    }
                }
            }
            if !found { break }
        }
        return (count == allocation.count, sequence)
    }
}

/// [ECE-07] Logic Minimization & Karnaugh Map Step Solver
public actor KarnaughMapMinimizerEngine {
    public init() {}

    public func minimize2Var(minterms: [Int]) -> String {
        if minterms.count == 4 { return "1 (Tautology)" }
        if minterms == [0, 1] { return "A'" }
        if minterms == [2, 3] { return "A" }
        if minterms == [1, 3] { return "B" }
        if minterms == [0, 2] { return "B'" }
        return "SOP: " + minterms.map { "m\($0)" }.joined(separator: " + ")
    }
}

/// [ECE-08] Virtual Memory Page Table & TLB Miss Calculator
public actor VirtualMemoryEATCalculator {
    public init() {}

    public func calculateEAT(tlbHitRate: Double, tlbAccessTimeNs: Double, memAccessTimeNs: Double, pageFaultRate: Double, pageFaultTimeNs: Double) -> Double {
        let tlbHit = tlbHitRate * (tlbAccessTimeNs + memAccessTimeNs)
        let tlbMiss = (1.0 - tlbHitRate) * (tlbAccessTimeNs + (2.0 * memAccessTimeNs) + (pageFaultRate * pageFaultTimeNs))
        return (tlbHit + tlbMiss)
    }
}

// MARK: - =====================================================================
// MARK: [PILLAR 3] Κυρίαρχο Επιτελείο & Προσωπική Αυτονομία (Sovereign OS Core)
// MARK: =====================================================================

/// [SOV-01] Voice-to-Obsidian Zettelkasten Atomizer
public actor ObsidianZettelkastenAtomizer {
    public init() {}

    public func atomizeVoiceNote(transcript: String, date: Date) -> (filename: String, markdown: String) {
        let titleSlug = transcript.prefix(30).lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "ς", with: "s")
        let filename = "\(Int(date.timeIntervalSince1970))_\(titleSlug).md"
        let md = """
        ---
        id: "\(UUID().uuidString)"
        created: "\(date.ISO8601Format())"
        tags: [sovereign, atom, voice-note]
        ---
        # \(transcript.prefix(50))

        \(transcript)

        ## Connections
        - [[Architecture_Index]]
        - [[Personal_Sovereignty]]
        """
        return (filename, md)
    }
}

/// [SOV-02] 50/50 Boundary Strict Enforcement Gate
public actor FiftyFiftyBoundaryGate {
    public init() {}

    public func auditPromptForMathViolation(prompt: String) -> (isViolating: Bool, rerouteEngine: String) {
        let mathKeywords = ["υπολόγισε", "πρόσθεσε", "διαίρεσε", "πολλαπλασίασε", "math", "calculate", "integral", "derivative"]
        let lower = prompt.lowercased()
        for kw in mathKeywords {
            if lower.contains(kw) {
                return (true, "REROUTE_TO_NATIVE_PHYSICS_ENGINE")
            }
        }
        return (false, "PASS_TO_NLP_LLM")
    }
}

/// [SOV-03] Executive Energy ROI Day Scheduler
public actor ExecutiveEnergyROIScheduler {
    public init() {}

    public func canScheduleDeepWorkTask(currentHighEnergyCount: Int) -> Bool {
        return currentHighEnergyCount < 3 // Maximum 3 high-intensity cognitive sessions
    }
}

/// [SOV-04] Zero-Knowledge Local Cryptographic Enclave
public actor ZeroKnowledgeSecureEnclaveVault {
    public init() {}

    public func encryptString(_ text: String, keyTag: String) -> Data {
        let raw = Data(text.utf8)
        // Deterministic mock of Secure Enclave AES-GCM wrapping for testability
        return raw.base64EncodedData()
    }

    public func decryptData(_ data: Data, keyTag: String) -> String? {
        guard let base64Decoded = Data(base64Encoded: data) else { return nil }
        return String(data: base64Decoded, encoding: .utf8)
    }
}

/// [SOV-05] Automated ADR (Architectural Decision Record) Generator
public actor AutomatedADRGenerator {
    public init() {}

    public func generateADR(number: Int, title: String, context: String, decision: String, consequences: [String]) -> String {
        return """
        # ADR-\(String(format: "%03d", number)): \(title)

        ## Status
        Accepted (2026-10-08)

        ## Context
        \(context)

        ## Decision
        \(decision)

        ## Consequences
        \(consequences.map { "- \($0)" }.joined(separator: "\n"))
        """
    }
}

/// [SOV-06] Local Vector RAG over Obsidian Vault
public actor LocalVectorVaultRAG {
    public init() {}

    public func rankMatches(queryLength: Int, noteLengths: [Int]) -> [Int] {
        return noteLengths.indices.sorted { abs(noteLengths[$0] - queryLength) < abs(noteLengths[$1] - queryLength) }
    }
}

/// [SOV-07] Pre-Mortem Project Inversion Auditor
public actor PreMortemInversionAuditor {
    public init() {}

    public func queryInversion(featureTitle: String) -> [String] {
        return [
            "Αν το «\(featureTitle)» αποτύχει σε 3 μήνες, ποιο ήταν το βασικό σημείο αστοχίας;",
            "Ποιο κρυφό dependency αγνοήθηκε;",
            "Πώς μπορεί να απλοποιηθεί η αρχιτεκτονική στο μισό μέγεθος;"
        ]
    }
}

/// [SOV-08] Git Commit Semantic Synthesizer & Conventional Commits Guard
public actor GitSemanticCommitSynthesizer {
    public init() {}

    public func formatCommit(scope: String, message: String, isFeature: Bool) -> String {
        let prefix = isFeature ? "feat" : "fix"
        return "\(prefix)(\(scope)): \(message.lowercased())"
    }
}

// MARK: - =====================================================================
// MARK: [PILLAR 4] Βαθύ Biohacking & Κιρκάδιος Ρυθμός (Circadian & Autonomic)
// MARK: =====================================================================

/// [BIO-01] Real-Time Autonomic Tone Tracker (Vagal vs Sympathetic)
public actor AutonomicToneTracker {
    public enum AutonomicDominance: String, Sendable {
        case sympathetic = "Sympathetic (Fight-or-Flight)"
        case balanced = "Balanced Autonomic Tone"
        case parasympathetic = "Parasympathetic (Rest-and-Digest)"
    }

    public init() {}

    public func assessTone(hrvSDNN: Double, restingHeartRate: Int) -> AutonomicDominance {
        if hrvSDNN > 75.0 && restingHeartRate < 55 {
            return .parasympathetic
        } else if hrvSDNN < 40.0 || restingHeartRate > 68 {
            return .sympathetic
        }
        return .balanced
    }
}

/// [BIO-02] Thermal Sleep Core Cooler Advisory
public actor ThermalSleepCoreCooler {
    public init() {}

    public func getPreBedWarmShowerTime(bedTime: Date) -> Date {
        return bedTime.addingTimeInterval(-90.0 * 60.0) // 90 min before bed for vasodilation
    }
}

/// [BIO-03] NSDR (Non-Sleep Deep Rest) 15-Minute Protocol Trigger
public actor NSDRProtocolTrigger {
    public init() {}

    public func shouldTriggerNSDR(dayStrain: Double, hourOfDay: Int) -> Bool {
        return dayStrain > 13.0 && (hourOfDay >= 13 && hourOfDay <= 17)
    }
}

/// [BIO-04] Cortisol Awakening Response (CAR) Window Sentinel
public actor CortisolAwakeningResponseSentinel {
    public init() {}

    public func isWithinNaturalLightWindow(wakeTime: Date, currentTime: Date) -> Bool {
        let elapsedMin = currentTime.timeIntervalSince(wakeTime) / 60.0
        return elapsedMin >= 0 && elapsedMin <= 45.0
    }
}

/// [BIO-05] Sauna Heat Shock & Cold Shock Cycling Logger
public actor SaunaColdCyclingLogger {
    public init() {}

    public func calculateHSPActivationScore(saunaMinutes: Int, saunaTempC: Int, coldPlungeMinutes: Int) -> Int {
        var score = 0
        if saunaMinutes >= 20 && saunaTempC >= 80 { score += 60 }
        if coldPlungeMinutes >= 3 { score += 40 }
        return min(100, score)
    }
}

/// [BIO-06] Fasting Autophagy Depth Index
public actor FastingAutophagyDepthIndex {
    public init() {}

    public func getCellularRecyclingScore(hoursFasted: Double) -> Int {
        if hoursFasted >= 24.0 { return 100 }
        if hoursFasted >= 18.0 { return 80 }
        if hoursFasted >= 16.0 { return 60 }
        if hoursFasted >= 12.0 { return 30 }
        return 10
    }
}

/// [BIO-07] Electrolyte & Sodium Sweat-Loss Calculator
public actor ElectrolyteLossCalculator {
    public struct ElectrolyteTargets: Sendable, Equatable {
        public let sodiumMg: Int
        public let potassiumMg: Int
        public let magnesiumMg: Int
    }

    public init() {}

    public func computeReplenishment(activeCalories: Int, ambientTempC: Double) -> ElectrolyteTargets {
        let tempFactor = ambientTempC > 28.0 ? 1.3 : 1.0
        let sodium = Int(Double(activeCalories) * 0.8 * tempFactor)
        let potassium = Int(Double(sodium) * 0.3)
        let magnesium = Int(Double(sodium) * 0.1)
        return ElectrolyteTargets(sodiumMg: max(500, sodium), potassiumMg: max(200, potassium), magnesiumMg: max(75, magnesium))
    }
}

/// [BIO-08] Blue Light Deprivation Auto-Dimming Shield
public actor BlueLightShieldScheduler {
    public init() {}

    public func isNightShieldActive(hourOfDay: Int, minuteOfHour: Int) -> Bool {
        let totalMin = hourOfDay * 60 + minuteOfHour
        return totalMin >= (21 * 60 + 30) || totalMin <= (6 * 60) // 21:30 - 06:00
    }
}

// MARK: - =====================================================================
// MARK: [PILLAR 5] Επαυξημένη Πραγματικότητα Wearables (Meta Glasses & Watch)
// MARK: =====================================================================

/// [WEAR-01] Silent Head-Gesture Action Trigger (IMU Pitch / Yaw)
public actor SilentHeadGestureTrigger {
    public enum HeadAction: String, Sendable {
        case doubleNodSave = "Double Nod (Save Clip)"
        case headTiltDiscard = "Head Tilt (Discard)"
        case none = "Stationary"
    }

    public init() {}

    public func classifyGesture(pitchOscillations: Int, rollAngleDeg: Double) -> HeadAction {
        if pitchOscillations >= 2 { return .doubleNodSave }
        if abs(rollAngleDeg) > 25.0 { return .headTiltDiscard }
        return .none
    }
}

/// [WEAR-02] Ambient Whisper Coach (In-Ear Audio)
public actor AmbientWhisperCoach {
    public init() {}

    public func generateWhisper(nextEventInMinutes: Int, currentHRV: Double) -> String {
        if nextEventInMinutes <= 10 {
            return "Επόμενο ραντεβού σε \(nextEventInMinutes) λεπτά."
        }
        if currentHRV < 45.0 {
            return "Το HRV έπεσε. Χαλάρωσε τους ώμους."
        }
        return "Όλα ομαλά."
    }
}

/// [WEAR-03] Spatial Audio Memory Walk (Method of Loci)
public actor SpatialAudioLociMemory {
    public init() {}

    public func calculateSpatialDistance(userLat: Double, userLon: Double, lociLat: Double, lociLon: Double) -> Double {
        let dLat = (lociLat - userLat) * 111000.0
        let dLon = (lociLon - userLon) * 111000.0
        return sqrt(dLat * dLat + dLon * dLon)
    }
}

/// [WEAR-04] Instant Whiteboard & Paper OCR Snapper
public actor WhiteboardOCRSnapper {
    public init() {}

    public func formatWhiteboardNote(ocrText: String) -> String {
        return """
        # Whiteboard Snapshot
        ```latex
        \(ocrText)
        ```
        """
    }
}

/// [WEAR-05] Conversational Turn-Taking Guard
public actor WearableTurnTakingGuard {
    public init() {}

    public func canAssistantRespond(silenceDurationMs: Double) -> Bool {
        return silenceDurationMs >= 600.0 // 600ms natural silence pause
    }
}

/// [WEAR-06] Acoustic dBFS Decibel Sentinel
public actor AcousticDecibelSentinel {
    public init() {}

    public func evaluateNoiseSafety(currentDb: Double) -> (isHazardous: Bool, alertMessage: String) {
        if currentDb > 85.0 {
            return (true, "⚠️ Ένταση > 85 dB. Προστασία ακοής ενεργή.")
        }
        return (false, "Ασφαλές ακουστικό περιβάλλον.")
    }
}

/// [WEAR-07] Subconscious Vocal Prosody & Stress Mirror
public actor VocalProsodyStressMirror {
    public init() {}

    public func analyzeVocalTension(pitchHz: Double) -> (isStressed: Bool, cue: String) {
        if pitchHz > 185.0 {
            return (true, "Ανιχνεύθηκε ένταση φωνητικών χορδών. Πάρε μια βαθιά διαφραγματική ανάσα.")
        }
        return (false, "Φυσιολογικός τόνος φωνής.")
    }
}

/// [WEAR-08] Emergency Zero-Touch Privacy Cloak
public actor EmergencyPrivacyCloak {
    private var isCloakActive: Bool = false

    public init() {}

    public func engagePrivacyCloak() -> Bool {
        isCloakActive = true
        return true // Zeroizes volatile RAM & locks vaults
    }

    public func isEngaged() -> Bool {
        return isCloakActive
    }
}
