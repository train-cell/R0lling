import XCTest
import Security
@testable import R0lling

final class PersonalizedEnginesTests: XCTestCase {

    // MARK: - Pillar 1: Swim & Kinetic Mastery Tests (SW-01 to SW-08)

    func testSW01StrokeCadencePacer() async {
        let pacer = StrokeCadencePacerEngine()
        let metrics = await pacer.calculateDPS(poolLengthMeters: 50.0, strokeCount: 28, lapTimeSeconds: 27.5)
        XCTAssertGreaterThan(metrics.strokesPerMinute, 30.0)
        XCTAssertGreaterThan(metrics.distancePerStrokeMeters, 1.5)
        XCTAssertTrue(metrics.strokeEfficiencyIndex > 2.0)
    }

    func testSW02LactateAccumulationEstimator() async {
        let estimator = LactateAccumulationEstimator()
        let (lactate, zone) = await estimator.estimateLactate(avgHeartRate: 182, maxHeartRate: 195, highIntensitySeconds: 90.0)
        XCTAssertGreaterThan(lactate, 4.0)
        XCTAssertEqual(zone, .lactateTolerance)
    }

    func testSW03PoolTurnDecelerationSentry() async {
        let sentry = PoolTurnDecelerationSentry()
        let profile = await sentry.analyzeTurn(approachV: 1.85, contactSec: 0.28, exitV: 1.70)
        XCTAssertEqual(profile.approachVelocityMps, 1.85)
        XCTAssertEqual(profile.wallContactTimeSeconds, 0.28)
        XCTAssertLessThan(profile.momentumLossPercent, 15.0)
    }

    func testSW04DrylandPowerTransferAuditor() async {
        let auditor = DrylandPowerTransferAuditor()
        let transferIndex = await auditor.computeTransferIndex(tonnageKg: 2400.0, meanVelocityMps: 0.88, underwater15mTimeSec: 5.4)
        XCTAssertGreaterThan(transferIndex, 50.0)
    }

    func testSW05DynamicPBSplitMatrix() async {
        let engine = DynamicPBSplitMatrixEngine()
        let splits100 = await engine.calculateTargetSplits(distance: 100, bestTimeSec: 51.5, recoveryScorePercent: 90)
        XCTAssertEqual(splits100.split50s.count, 2)
        XCTAssertLessThan(splits100.split50s[0], splits100.split50s[1]) // First 50 faster with dive
    }

    func testSW06HypoxicBreathingTracker() async {
        let tracker = HypoxicBreathingTracker()
        let (breaths, rating) = await tracker.calculateHypoxicVolume(strokesPerBreath: 5, totalLaps: 10, strokesPerLap: 30)
        XCTAssertEqual(breaths, 60)
        XCTAssertEqual(rating, "Advanced Hypoxic")
    }

    func testSW07ShoulderImpingementGuard() async {
        let guardEngine = ShoulderImpingementGuard()
        let (highRisk, _) = await guardEngine.auditShoulderRisk(acwrRatio: 1.55, weeklyVolumeMeters: 28000, reportedSoreness: 4)
        XCTAssertTrue(highRisk)
    }

    func testSW08PostPoolGlycogenPacer() async {
        let pacer = PostPoolGlycogenPacer()
        let refuel = await pacer.computeNutrientRefuel(activeCaloriesBurned: 650)
        XCTAssertGreaterThanOrEqual(refuel.targetCarbsGrams, 90)
        XCTAssertGreaterThanOrEqual(refuel.targetProteinGrams, 20)
        XCTAssertEqual(refuel.windowDurationMinutes, 45)
    }

    // MARK: - Pillar 2: ECE & System Architecture Tests (ECE-01 to ECE-08)

    func testECE01DatapathCycleResolver() async {
        let resolver = DatapathCycleResolverEngine()
        let lw = await resolver.resolveInstruction("lw")
        XCTAssertEqual(lw.memToReg, 1)
        XCTAssertEqual(lw.aluSrc, 1)
        XCTAssertEqual(lw.pipelineCyclesWithoutHazard, 5)

        let add = await resolver.resolveInstruction("add")
        XCTAssertEqual(add.memToReg, 0)
        XCTAssertEqual(add.aluSrc, 0)
        XCTAssertEqual(add.regWrite, 1)
    }

    func testECE02PsarakisTrapScanner() async {
        let scanner = PsarakisTrapScanner()
        let traps = await scanner.scanCodeForTraps("lb $t0, 0($s0)\nslti $t1, $s1, 100")
        XCTAssertEqual(traps.count, 2)
        XCTAssertTrue(traps[0].contains("sign-extension"))
        XCTAssertTrue(traps[1].contains("signed σύγκριση"))
    }

    func testECE03SpacedRepetitionECE() async {
        let engine = SpacedRepetitionECEEngine()
        let cards = await engine.getDailyFlashcards()
        XCTAssertEqual(cards.count, 3)
        XCTAssertTrue(cards.contains { $0.concept.contains("Σηματοφόρος") })
    }

    func testECE04AssemblyDisassemblerBrief() async {
        let briefEngine = AssemblyDisassemblerBriefEngine()
        let brief = await briefEngine.generateBrief(assemblyLine: "add $t0, $s0, $s1")
        XCTAssertTrue(brief.contains("ALU εκτελεί άθροιση"))
    }

    func testECE05IEEE754InstantConverter() async {
        let converter = IEEE754InstantConverterEngine()
        let result = await converter.convertFloat(-7.25)
        XCTAssertEqual(result.signBit, 1)
        XCTAssertEqual(result.biasedExponent, 129) // 2^2 * 1.8125 -> 2 + 127 = 129
        XCTAssertEqual(result.hexRepresentation, "0xC0E80000")
    }

    func testECE06DeadlockBankerSimulator() async {
        let banker = DeadlockBankerSimulator()
        let available = [3, 3, 2]
        let allocation = [[0, 1, 0], [2, 0, 0], [3, 0, 2]]
        let need = [[0, 1, 1], [1, 2, 2], [1, 0, 0]]
        let (isSafe, sequence) = await banker.isSafeState(available: available, allocation: allocation, need: need)
        XCTAssertTrue(isSafe)
        XCTAssertEqual(sequence.count, 3)
    }

    func testECE07KarnaughMapMinimizer() async {
        let kmap = KarnaughMapMinimizerEngine()
        let res = await kmap.minimize2Var(minterms: [0, 1])
        XCTAssertEqual(res, "A'")
    }

    func testECE08VirtualMemoryEATCalculator() async {
        let calc = VirtualMemoryEATCalculator()
        let eat = await calc.calculateEAT(tlbHitRate: 0.98, tlbAccessTimeNs: 10.0, memAccessTimeNs: 100.0, pageFaultRate: 0.001, pageFaultTimeNs: 8000000.0)
        XCTAssertGreaterThan(eat, 100.0)
    }

    // MARK: - Pillar 3: Sovereign OS Core Tests (SOV-01 to SOV-08)

    func testSOV01ObsidianZettelkastenAtomizer() async {
        let atomizer = ObsidianZettelkastenAtomizer()
        let (fn, md) = await atomizer.atomizeVoiceNote(transcript: "Η αρχιτεκτονική L4NE είναι 50/50 AI και Physics", date: Date())
        XCTAssertTrue(fn.hasSuffix(".md"))
        XCTAssertTrue(md.contains("[[Architecture_Index]]"))
    }

    func testSOV02FiftyFiftyBoundaryGate() async {
        let gate = FiftyFiftyBoundaryGate()
        let (violates, reroute) = await gate.auditPromptForMathViolation(prompt: "Υπολόγισε το ολοκλήρωμα του φορτίου")
        XCTAssertTrue(violates)
        XCTAssertEqual(reroute, "REROUTE_TO_NATIVE_PHYSICS_ENGINE")

        let (safe, pass) = await gate.auditPromptForMathViolation(prompt: "Γράψε μου μια περίληψη για το Obsidian")
        XCTAssertFalse(safe)
        XCTAssertEqual(pass, "PASS_TO_NLP_LLM")
    }

    func testSOV03ExecutiveEnergyROIScheduler() async {
        let scheduler = ExecutiveEnergyROIScheduler()
        let allowed = await scheduler.canScheduleDeepWorkTask(currentHighEnergyCount: 2)
        XCTAssertTrue(allowed)
        let blocked = await scheduler.canScheduleDeepWorkTask(currentHighEnergyCount: 3)
        XCTAssertFalse(blocked)
    }

    func testSOV04ZeroKnowledgeSecureEnclaveVault() async throws {
        let vault = ZeroKnowledgeSecureEnclaveVault()
        let raw = "Confidential Sovereign Secret"
        let keyTag = "helper-test-\(UUID().uuidString)"
        defer {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.r0lling.local-aes-helper",
                kSecAttrAccount as String: keyTag
            ]
            SecItemDelete(query as CFDictionary)
        }
        let encrypted = try await vault.encryptString(raw, keyTag: keyTag)
        let decrypted = await vault.decryptData(encrypted, keyTag: keyTag)
        XCTAssertEqual(decrypted, raw)
    }

    func testSOV05AutomatedADRGenerator() async {
        let adr = AutomatedADRGenerator()
        let text = await adr.generateADR(number: 42, title: "Swift 6 Concurrency Migration", context: "Data races prevention", decision: "Use isolated actors", consequences: ["Safety guaranteed"], createdAt: ISO8601DateFormatter().date(from: "2026-10-08T00:00:00Z")!)
        XCTAssertTrue(text.contains("ADR-042: Swift 6 Concurrency Migration"))
        XCTAssertTrue(text.contains("Accepted (2026-10-08)"))
    }

    func testSOV06LocalVectorVaultRAG() async {
        let rag = LocalVectorVaultRAG()
        let ranking = await rag.rankMatches(queryLength: 100, noteLengths: [50, 95, 200])
        XCTAssertEqual(ranking[0], 1) // 95 is closest to 100
    }

    func testSOV07PreMortemInversionAuditor() async {
        let auditor = PreMortemInversionAuditor()
        let questions = await auditor.queryInversion(featureTitle: "Bluetooth Mesh Streaming")
        XCTAssertEqual(questions.count, 3)
    }

    func testSOV08GitSemanticCommitSynthesizer() async {
        let synth = GitSemanticCommitSynthesizer()
        let commitMsg = await synth.formatCommit(scope: "swim-core", message: "Add stroke cadence pacer", isFeature: true)
        XCTAssertEqual(commitMsg, "feat(swim-core): add stroke cadence pacer")
    }

    // MARK: - Pillar 4: Circadian & Autonomic Telemetry Tests (BIO-01 to BIO-08)

    func testBIO01AutonomicToneTracker() async {
        let tracker = AutonomicToneTracker()
        let vagal = await tracker.assessTone(hrvSDNN: 88.0, restingHeartRate: 50)
        XCTAssertEqual(vagal, .parasympathetic)
        let stressed = await tracker.assessTone(hrvSDNN: 32.0, restingHeartRate: 75)
        XCTAssertEqual(stressed, .sympathetic)
    }

    func testBIO02ThermalSleepCoreCooler() async {
        let cooler = ThermalSleepCoreCooler()
        let bedTime = Date()
        let showerTime = await cooler.getPreBedWarmShowerTime(bedTime: bedTime)
        XCTAssertEqual(showerTime.timeIntervalSince(bedTime), -5400.0) // -90 min
    }

    func testBIO03NSDRProtocolTrigger() async {
        let trigger = NSDRProtocolTrigger()
        let shouldRun = await trigger.shouldTriggerNSDR(dayStrain: 14.5, hourOfDay: 15)
        XCTAssertTrue(shouldRun)
        let noRun = await trigger.shouldTriggerNSDR(dayStrain: 8.0, hourOfDay: 10)
        XCTAssertFalse(noRun)
    }

    func testBIO04CortisolAwakeningResponseSentinel() async {
        let sentinel = CortisolAwakeningResponseSentinel()
        let wake = Date()
        let currentWithin = wake.addingTimeInterval(20.0 * 60.0)
        let isWithin = await sentinel.isWithinNaturalLightWindow(wakeTime: wake, currentTime: currentWithin)
        XCTAssertTrue(isWithin)
    }

    func testBIO05SaunaColdCyclingLogger() async {
        let logger = SaunaColdCyclingLogger()
        let score = await logger.calculateHSPActivationScore(saunaMinutes: 20, saunaTempC: 85, coldPlungeMinutes: 3)
        XCTAssertEqual(score, 100)
    }

    func testBIO06FastingAutophagyDepthIndex() async {
        let index = FastingAutophagyDepthIndex()
        let score = await index.getCellularRecyclingScore(hoursFasted: 20.0)
        XCTAssertEqual(score, 80)
    }

    func testBIO07ElectrolyteLossCalculator() async {
        let calc = ElectrolyteLossCalculator()
        let targets = await calc.computeReplenishment(activeCalories: 800, ambientTempC: 30.0)
        XCTAssertGreaterThan(targets.sodiumMg, 700)
        XCTAssertGreaterThan(targets.potassiumMg, 200)
    }

    func testBIO08BlueLightShieldScheduler() async {
        let scheduler = BlueLightShieldScheduler()
        let isNight = await scheduler.isNightShieldActive(hourOfDay: 22, minuteOfHour: 0)
        XCTAssertTrue(isNight)
        let isDay = await scheduler.isNightShieldActive(hourOfDay: 14, minuteOfHour: 0)
        XCTAssertFalse(isDay)
    }

    // MARK: - Pillar 5: Wearable Augmentation Tests (WEAR-01 to WEAR-08)

    func testWEAR01SilentHeadGestureTrigger() async {
        let trigger = SilentHeadGestureTrigger()
        let saveAction = await trigger.classifyGesture(pitchOscillations: 2, rollAngleDeg: 5.0)
        XCTAssertEqual(saveAction, .doubleNodSave)
        let discardAction = await trigger.classifyGesture(pitchOscillations: 0, rollAngleDeg: 30.0)
        XCTAssertEqual(discardAction, .headTiltDiscard)
    }

    func testWEAR02AmbientWhisperCoach() async {
        let coach = AmbientWhisperCoach()
        let whisper = await coach.generateWhisper(nextEventInMinutes: 8, currentHRV: 60.0)
        XCTAssertTrue(whisper.contains("Επόμενο ραντεβού σε 8 λεπτά"))
    }

    func testWEAR03SpatialAudioLociMemory() async {
        let loci = SpatialAudioLociMemory()
        let dist = await loci.calculateSpatialDistance(userLat: 37.9838, userLon: 23.7275, lociLat: 37.9839, lociLon: 23.7276)
        XCTAssertGreaterThan(dist, 0.0)
    }

    func testWEAR04WhiteboardOCRSnapper() async {
        let ocr = WhiteboardOCRSnapper()
        let note = await ocr.formatWhiteboardNote(ocrText: "E = mc^2")
        XCTAssertTrue(note.contains("```latex"))
        XCTAssertTrue(note.contains("E = mc^2"))
    }

    func testWEAR05WearableTurnTakingGuard() async {
        let guardEngine = WearableTurnTakingGuard()
        let canRespond = await guardEngine.canAssistantRespond(silenceDurationMs: 650.0)
        XCTAssertTrue(canRespond)
        let mustWait = await guardEngine.canAssistantRespond(silenceDurationMs: 400.0)
        XCTAssertFalse(mustWait)
    }

    func testWEAR06AcousticDecibelSentinel() async {
        let sentinel = AcousticDecibelSentinel()
        let (hazard, _) = await sentinel.evaluateNoiseSafety(currentDb: 88.5)
        XCTAssertTrue(hazard)
        let (safe, _) = await sentinel.evaluateNoiseSafety(currentDb: 55.0)
        XCTAssertFalse(safe)
    }

    func testWEAR07VocalProsodyStressMirror() async {
        let mirror = VocalProsodyStressMirror()
        let (isStressed, cue) = await mirror.analyzeVocalTension(pitchHz: 195.0)
        XCTAssertTrue(isStressed)
        XCTAssertTrue(cue.contains("διαφραγματική ανάσα"))
    }

    func testWEAR08EmergencyPrivacyCloakReportsUnavailable() async {
        let cloak = EmergencyPrivacyCloak()
        let engaged = await cloak.engagePrivacyCloak()
        XCTAssertFalse(engaged, "The privacy cloak is not integrated with vaults or app memory")
        let active = await cloak.isEngaged()
        XCTAssertFalse(active)
    }
}
