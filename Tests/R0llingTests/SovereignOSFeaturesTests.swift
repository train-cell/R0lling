import XCTest
@testable import R0lling

final class SovereignOSFeaturesTests: XCTestCase {

    func testChiefOfStaffParsing() async {
        let service = ChiefOfStaffService()
        let stream = """
        Επείγον: Ολοκλήρωση αρχιτεκτονικής L4NE
        - Έλεγχος Bevel concentric rings
        • Συγχρονισμός Obsidian Vault
        Απλή καταγραφή ημέρας
        """

        let tasks = await service.parseTasks(from: stream)
        XCTAssertEqual(tasks.count, 4)
        XCTAssertEqual(tasks[0].priority, .high)
        XCTAssertEqual(tasks[1].priority, .medium)
        XCTAssertEqual(tasks[2].priority, .medium)
        XCTAssertEqual(tasks[3].priority, .low)

        let toggled = await service.toggleTask(id: tasks[0].id)
        XCTAssertTrue(toggled)
    }

    func testZettelkastenLinker() async {
        let linker = ZettelkastenLinkerActor()
        let notes = [
            (title: "Architecture Principles", path: "Notes/Arch.md"),
            (title: "Cooking Recipes", path: "Notes/Cook.md")
        ]

        let connections = await linker.discoverConnections(
            for: "Software architecture and principles of system design",
            knownNotes: notes
        )

        XCTAssertFalse(connections.isEmpty)
        XCTAssertEqual(connections[0].targetNoteTitle, "Architecture Principles")
        XCTAssertGreaterThan(connections[0].similarityScore, 0.4)
    }

    func testDeepWorkSessionManager() async {
        let manager = DeepWorkSessionManager()
        await manager.startSession(goal: "Swift 6 Concurrency Refactoring", durationMinutes: 25)

        let state = await manager.getState()
        if case .active(_, let duration, let goal) = state {
            XCTAssertEqual(duration, 1500)
            XCTAssertEqual(goal, "Swift 6 Concurrency Refactoring")
        } else {
            XCTFail("State should be active")
        }

        let elapsed = await manager.completeSession(debrief: "Όλα τα tests πέρασαν με επιτυχία.")
        XCTAssertGreaterThanOrEqual(elapsed, 0)
    }

    func testDecisionJournalEngine() async {
        let engine = DecisionJournalEngine()
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let record = DecisionRecord(
            decisionText: "Μετάβαση σε 100% On-Device Sovereign OS",
            coreAssumptions: ["Υψηλότερη ιδιωτικότητα", "Μηδενικό cloud API κόστος"],
            confidencePercent: 95,
            reviewDate: pastDate
        )

        await engine.recordDecision(record)
        let pending = await engine.getPendingReviews()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].confidencePercent, 95)
    }

    func testCognitiveReadinessCalculator() async {
        let calc = CognitiveReadinessCalculator()
        let score = await calc.computeTelemetry(entriesCount: 5, deepWorkSeconds: 3600, vocalStressFactor: 1.0)

        XCTAssertGreaterThanOrEqual(score.cognitiveStrain, 0.0)
        XCTAssertLessThanOrEqual(score.cognitiveStrain, 21.0)
        XCTAssertEqual(score.focusMinutes, 60)
        XCTAssertGreaterThanOrEqual(score.readinessPercent, 15)
        XCTAssertLessThanOrEqual(score.readinessPercent, 100)
    }

    func testFutureLetterboxEngine() async {
        let engine = FutureLetterboxEngine()
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let letter = SealedLetter(titleHint: "Γράμμα στα 30 μου", unlockDate: futureDate, payloadText: "Μείνε πιστός στις αξίες σου.")

        await engine.sealLetter(letter)
        let available = await engine.getAvailableLetters()
        let pending = await engine.getPendingCount()

        XCTAssertEqual(available.count, 0)
        XCTAssertEqual(pending, 1)
    }

    func testCreatorAssetEngine() async {
        let engine = CreatorAssetEngine()
        let asset = CreatorAsset(projectTag: "YouTube", title: "Intro hook", transcriptSnippet: "Καλωσήρθατε στο κανάλι")

        await engine.addAsset(asset)
        let ytAssets = await engine.getAssets(for: "YouTube")
        let tags = await engine.getAllProjectTags()

        XCTAssertEqual(ytAssets.count, 1)
        XCTAssertTrue(tags.contains("YouTube"))
    }

    func testStoicPrinciplesEngine() async {
        let engine = StoicPrinciplesEngine()
        let daily = await engine.getDailyPrinciple()
        XCTAssertFalse(daily.title.isEmpty)
        XCTAssertFalse(daily.quote.isEmpty)
    }

    func testBinauralSynthesizer() async {
        let synth = BinauralFocusSynthesizer()
        await synth.setBeat(.gamma40Hz)
        let isPlaying = await synth.togglePlayback()
        XCTAssertTrue(isPlaying)

        let status = await synth.getStatus()
        XCTAssertEqual(status.currentBeat, .gamma40Hz)
    }

    func testCircadianRhythmCoach() async {
        let coach = CircadianRhythmCoach()
        let wake = Date()
        let sched = await coach.calculateSchedule(wakeTime: wake)

        XCTAssertEqual(sched.caffeineCutoffTime.timeIntervalSince(wake), 9 * 3600, accuracy: 1.0)
        XCTAssertEqual(sched.melatoninWindowStart.timeIntervalSince(wake), 14 * 3600, accuracy: 1.0)
    }

    func testGymVoiceLoggerService() async {
        let service = GymVoiceLoggerService()
        let setLog = await service.parseGymUtterance("Squats 120 κιλά 6 reps rpe 8")

        XCTAssertNotNil(setLog)
        XCTAssertEqual(setLog?.exercise, "Squat")
        XCTAssertEqual(setLog?.weightKg, 120)
        XCTAssertEqual(setLog?.reps, 6)

        let volume = await service.getTotalVolumeKg()
        XCTAssertEqual(volume, 720.0)
    }

    func testBoxBreathingGuide() async {
        let guide = BoxBreathingGuide()
        let p1 = await guide.nextPhase()
        XCTAssertEqual(p1, .holdIn)
        let p2 = await guide.nextPhase()
        XCTAssertEqual(p2, .exhale)
        let p3 = await guide.nextPhase()
        XCTAssertEqual(p3, .holdOut)
        let p4 = await guide.nextPhase()
        XCTAssertEqual(p4, .inhale)
    }

    func testHealthKitTelemetryCoordinator() async {
        let coord = HealthKitTelemetryCoordinator()
        let snap = await coord.getLatestSnapshot()

        XCTAssertGreaterThan(snap.hrvMs, 0)
        XCTAssertGreaterThan(snap.restingHRBpm, 0)
        XCTAssertGreaterThan(snap.recoveryScore, 0)
    }

    func testHealthKitService() async {
        let service = HealthKitService.shared
        let _ = await service.isAvailable()
        let snap = await service.fetchLiveTelemetrySnapshot()
        XCTAssertGreaterThan(snap.hrvMs, 0)
        XCTAssertGreaterThan(snap.restingHRBpm, 0)
        XCTAssertGreaterThan(snap.recoveryScore, 0)
    }

    func testChronoPaletteEngine() async {
        let engine = ChronoPaletteEngine()
        let hex = await engine.getDynamicHex()
        XCTAssertTrue(["00E5FF", "A78BFA", "7742DC"].contains(hex))
    }

    func testContentFormatTransformer() async {
        let transformer = ContentFormatTransformer()
        let bundle = await transformer.transform(rawIdea: "Η συνέπεια ξεπερνά την ένταση μακροπρόθεσμα.")

        XCTAssertEqual(bundle.twitterThread.count, 3)
        XCTAssertTrue(bundle.linkedInPost.contains("💡 Στρατηγική Σκέψη"))
        XCTAssertTrue(bundle.newsletterDraft.contains("## Εβδομαδιαίο Insight"))
    }

    func testGeoAudioMemoryCoordinator() async {
        let coord = GeoAudioMemoryCoordinator()
        let memory = GeoAudioMemory(title: "Σκέψη στο Σύνταγμα", latitude: 37.9753, longitude: 23.7361, audioRelativePath: "Audio/syntagma.m4a")

        await coord.addMemory(memory)
        let nearby = await coord.getNearbyMemories(lat: 37.9753, lon: 23.7361, radiusMeters: 20.0)
        XCTAssertEqual(nearby.count, 1)
    }

    func testDreamPatternMatcher() async {
        let matcher = DreamPatternMatcher()
        let counts = await matcher.extractSymbols(from: "Ονειρεύτηκα ότι πετούσα πάνω από τη θάλασσα και έγραφα κώδικα")

        XCTAssertEqual(counts["θάλασσα"], 1)
        XCTAssertEqual(counts["κώδικας"], 1)
    }

    func testLogicFallacyChecker() async {
        let checker = LogicFallacyChecker()
        let results = await checker.auditArgument("Όλοι οι άνθρωποι κάνουν πάντα το ίδιο λάθος αφού έχω ήδη ξοδέψει τόσα χρήματα.")

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].fallacyType, "Black-or-White / False Dilemma")
        XCTAssertEqual(results[1].fallacyType, "Sunk Cost Fallacy")
    }

    // MARK: - Category 1-5 Extended Engines Tests

    func testCategory1NeuroCognitiveEngines() async {
        let dopamine = DopaminePacerEngine()
        var state = await dopamine.registerAppSwitch()
        XCTAssertEqual(state, .regulated)
        for _ in 0..<16 { _ = await dopamine.registerAppSwitch() }
        state = await dopamine.registerAppSwitch()
        XCTAssertEqual(state, .resetRequired)

        let ocular = OcularFatigueTracker()
        let fatigue = await ocular.evaluateBlinkRate(blinks: 25, durationSeconds: 60.0)
        XCTAssertEqual(fatigue.blinksPerMinute, 25)
        XCTAssertEqual(fatigue.classification, "High Fatigue")

        let memory = WorkingMemoryBenchmarker()
        let memScore = await memory.scoreDualTask(forwardSequenceLength: 7, reversedCorrect: true, logicAnswerTimeSec: 2.5)
        XCTAssertEqual(memScore, 100)

        let entropy = VerbalEntropyRadarEngine()
        let entropyMetrics = await entropy.analyzeSpeechEntropy(wordCount: 150, uniqueWords: 105, durationSeconds: 60.0)
        XCTAssertEqual(entropyMetrics.cognitiveState, "Flow State")
    }

    func testCategory2BiomechanicalEngines() async {
        let velocity = BarbellVelocityEngine()
        let repVel = await velocity.calculateVelocity(displacementMeters: 0.85, timeSeconds: 1.0, firstRepVelocity: 0.85)
        XCTAssertEqual(repVel.meanVelocityMps, 0.85)
        XCTAssertEqual(repVel.powerLossPercent, 0.0)

        let hrr = HeartRateRecoveryPacer()
        let (drop, rating) = await hrr.evaluateHRR(peakHR: 175, postOneMinHR: 135)
        XCTAssertEqual(drop, 40)
        XCTAssertEqual(rating, "Elite (Fast Clearance)")

        let fasting = FastingAutophagyEngine()
        let stage = await fasting.getFastingStage(hoursFasted: 18.5)
        XCTAssertEqual(stage, .autophagyActive)
    }

    func testCategory3CryptoAndDefensiveEngines() async {
        let shamir = ShamirKeyShardEngine()
        let shards = await shamir.splitSecretIntoQuorum(secret: "SovereignMasterKey")
        let isQuorum = await shamir.verifyQuorum(shards: [shards.shardA, shards.shardB])
        XCTAssertTrue(isQuorum)

        let leak = AcousticLeakDetector()
        let hasLeak = await leak.scanHighFrequencies(maxDetectedFrequencyHz: 19500.0)
        XCTAssertTrue(hasLeak)

        let canary = NetworkExfiltrationCanary()
        let isLan = await canary.isAddressPrivateLAN(ip: "192.168.1.100")
        XCTAssertTrue(isLan)
        let isPublic = await canary.isAddressPrivateLAN(ip: "8.8.8.8")
        XCTAssertFalse(isPublic)
    }

    func testCategory4ExecutiveOperationsEngines() async {
        let rehearsal = NegotiationRehearsalEngine()
        let (score, _) = await rehearsal.evaluateCounterResponse(latencySeconds: 1.2, pitchStabilityScore: 0.95)
        XCTAssertGreaterThanOrEqual(score, 80)

        let alloc = EnergyRoiTaskAllocator()
        let valid = await alloc.validateDailyCapacity(highEnergyTasksCount: 3)
        XCTAssertTrue(valid)
        let invalid = await alloc.validateDailyCapacity(highEnergyTasksCount: 5)
        XCTAssertFalse(invalid)

        let council = AdvisoryBoardSimulator()
        let advice = await council.queryAdvisors(problem: "Αρχιτεκτονική κλιμάκωση")
        XCTAssertEqual(advice.count, 3)
    }

    func testCategory5SensoryAndCreativeEngines() async {
        let soundscape = AcousticSoundscapeSynthesizer()
        let freqHigh = await soundscape.getAdaptiveFrequency(ambientNoiseDb: 68.0)
        XCTAssertEqual(freqHigh, 528.0)
        let freqLow = await soundscape.getAdaptiveFrequency(ambientNoiseDb: 45.0)
        XCTAssertEqual(freqLow, 432.0)

        let pitch = VoicePitchBiofeedbackEngine()
        let status = await pitch.evaluateTension(pitchHz: 195.0)
        XCTAssertTrue(status.contains("High Vocal Tension"))

        let legacy = GenerationalLegacyVault()
        let seal = await legacy.createArchiveSeal(recordTitle: "MasterBlueprint")
        XCTAssertTrue(seal.contains("MASTERBLUEPRINT"))
    }
}

