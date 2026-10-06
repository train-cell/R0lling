import SwiftUI
import Combine

/// Κεντρικός διαχειριστής κατάστασης της εφαρμογής R0lling
@MainActor
public final class AppState: ObservableObject {
    // Services
    public let storage: JSONFileStorageService
    public let mediaStorage: MediaStorageService
    public let bufferService: RollingBufferService
    public let glassesAdapter: MetaGlassesAdapter
    public let speechService: SpeechTranscriptionService
    public let obsidianBridge: ObsidianVaultBridge
    public let agentManager: AgentFolderManager
    public let aiRouter: AIRouter
    public let gameEngine: ObservationGameEngine
    public let backupEngine: BackupRestoreEngine

    // Published State
    @Published public var todayEntries: [JournalEntry] = []
    @Published public var allEntries: [JournalEntry] = []
    @Published public var selectedDate: Date = Date()
    @Published public var glassesState: GlassesConnectionState = .disconnected
    @Published public var bufferDuration: Double = 0.0
    @Published public var isStreaming: Bool = false
    @Published public var isListeningSpeech: Bool = false
    @Published public var toastMessage: String?
    @Published public var chatMessages: [(id: UUID, isUser: Bool, text: String, timestamp: Date)] = []
    @Published public var currentMission: ObservationMission?
    @Published public var gameScore: Int = 0
    @Published public var activeProvider: AIProviderType = .directAPI

    // Super-Feature Engines
    public let acousticTrigger = AcousticTriggerService()
    public let gestureDetector = HeadGestureDetector()
    public let timeCapsuleEngine = TimeCapsuleEngine()
    public let streakManager = ScavengerHuntStreakManager()
    public let podcastGenerator = DailyPodcastGenerator()
    public let highlightMuxer: HighlightReelMuxer
    public let canvasGenerator = ObsidianCanvasGenerator()
    public let emotionAnalyzer = VoiceEmotionAnalyzer()
    public let onDeviceVision = OnDeviceVisionService()
    public let proximityManager = ProximityAlertManager()
    public let entityRecognizer = LocalEntityRecognizer()

    // Next-Gen Batch Engines (Ideas 3, 4, 8, 11, 12, 13, 16)
    public let vectorSearchEngine = MobileCLIPVectorSearchEngine()
    public let turnTakingGuard = TurnTakingGuard()
    public let mirrorStreamServer = RemoteMirrorStreamServer()
    public let knowledgeGraphEngine = AssociativeKnowledgeGraphEngine()
    public let hyperlapseCompressor = HyperlapseTripCompressor()
    public let offlineWhisperService = LocalWhisperOfflineService()
    public let nutritionLogger = MealNutritionVisionLogger()

    @Published public var isMirrorStreaming: Bool = false
    @Published public var activeMirrorClientsCount: Int = 0

    @Published public var timeCapsuleMemories: [TimeCapsuleEngine.CapsuleMemory] = []
    @Published public var scavengerStreak: Int = 0
    @Published public var scavengerBadges: [String] = []

    private var cancellables = Set<AnyCancellable>()
    private var tickerTimer: Timer?

    /// Mic RMS → `AcousticTriggerService.processAudioLevel` (RollingBuffer / speech path).
    private static let SUPER_FEATURE_ACOUSTIC_MIC_FEED_WIRED = false
    /// IMU → `HeadGestureDetector.feedIMUSample` (`MetaGlassesAdapter`).
    private static let SUPER_FEATURE_IMU_FEED_WIRED = false

    public init() {
        let storage = JSONFileStorageService()
        let mediaStorage = MediaStorageService()
        let bufferService = RollingBufferService(mediaStorage: mediaStorage)
        let glasses = MetaGlassesAdapter(bufferService: bufferService)
        let speech = SpeechTranscriptionService()
        let obsidian = ObsidianVaultBridge()
        let agent = AgentFolderManager()
        let ai = AIRouter(settings: AISettings())
        let game = ObservationGameEngine(aiRouter: ai)
        let backup = BackupRestoreEngine(storage: storage, mediaStorage: mediaStorage)

        self.storage = storage
        self.mediaStorage = mediaStorage
        self.bufferService = bufferService
        self.glassesAdapter = glasses
        self.speechService = speech
        self.obsidianBridge = obsidian
        self.agentManager = agent
        self.aiRouter = ai
        self.gameEngine = game
        self.backupEngine = backup
        self.highlightMuxer = HighlightReelMuxer(mediaStorage: mediaStorage)

        setupSpeechCommandHandler()
        setupSuperFeatureHooks()
        startPeriodicStateSync()
    }

    public func loadInitialData() async {
        await refreshEntries()
        self.currentMission = await gameEngine.getCurrentMission()
        self.gameScore = await gameEngine.getScore()

        // Προσθήκη εισαγωγικού μηνύματος βοηθού
        if chatMessages.isEmpty {
            chatMessages.append((
                id: UUID(),
                isUser: false,
                text: "Γεια σου! Είμαι ο προσωπικός σου βοηθός R0lling. Πώς μπορώ να σε βοηθήσω σήμερα με τις καταγραφές σου;",
                timestamp: Date()
            ))
        }
    }

    public func refreshEntries() async {
        let all = await storage.getAllEntries()
        self.allEntries = all
        self.todayEntries = await storage.getEntriesForDate(selectedDate)
        self.timeCapsuleMemories = timeCapsuleEngine.findTimeCapsuleEntries(today: selectedDate, allEntries: all)
        self.scavengerStreak = streakManager.currentStreak
        self.scavengerBadges = streakManager.badges
    }

    // MARK: - Glasses & Streaming
    public func toggleGlassesConnection() async {
        do {
            if case .disconnected = glassesState {
                try await glassesAdapter.connectDevice()
                glassesState = await glassesAdapter.connectionState
                showToast("Τα Meta Glasses συνδέθηκαν.")
            } else {
                await glassesAdapter.disconnectDevice()
                glassesState = .disconnected
                isStreaming = false
                showToast("Τα Meta Glasses αποσυνδέθηκαν.")
            }
        } catch {
            showToast("Σφάλμα σύνδεσης: \(error.localizedDescription)")
        }
    }

    public func toggleLiveStream() async {
        do {
            if isStreaming {
                await glassesAdapter.stopStreaming()
                isStreaming = false
                glassesState = await glassesAdapter.connectionState
                showToast("Η ροή σταμάτησε.")
            } else {
                try await glassesAdapter.startStreaming()
                isStreaming = true
                glassesState = await glassesAdapter.connectionState
                showToast("Η ροή ξεκίνησε. Buffer ενεργό.")
            }
        } catch {
            showToast("Σφάλμα ροής: \(error.localizedDescription)")
        }
    }

    // MARK: - Clipping Action
    public func triggerClip(seconds: Double = 10.0) async {
        do {
            let result = try await bufferService.triggerClip(requestedSeconds: seconds)

            // R3-008: πραγματικό μέγεθος αρχείου, όχι hardcoded 1MB.
            let byteSize = result.byteSize > 0
                ? result.byteSize
                : ((try? FileManager.default.attributesOfItem(atPath: result.fileURL.path)[.size] as? Int64) ?? 0)

            let attachment = MediaAttachment(
                relativePath: result.relativePath,
                mediaType: .clip,
                byteSize: byteSize,
                durationSeconds: result.duration,
                hasAudio: result.hasAudio
            )

            let simulationSuffix = result.isSimulationPlaceholder
                ? " [simulation placeholder — playable MP4 με moov]"
                : ""
            let entry = JournalEntry(
                content: "Rolling Clip (\(String(format: "%.1f", result.duration))s) από τα Meta Glasses.\(simulationSuffix)",
                source: .glassesClip,
                attachments: [attachment]
            )

            try await storage.saveEntry(entry)
            await refreshEntries()

            await exportEntryToObsidianIfConfigured(entry)

            // Αναπαραγωγή διακριτικού ήχου Earcon στα ηχεία των γυαλιών
            EarconFeedbackService.shared.playEarcon(.clipSaved)

            if result.isPlayable {
                let label = result.isSimulationPlaceholder ? "Simulation Clip" : "Clip"
                showToast("✂️ Το \(label) (\(String(format: "%.1fs", result.duration))) αποθηκεύτηκε (playable).")
            } else {
                showToast("⚠️ Clip αποθηκεύτηκε αλλά ΔΕΝ είναι playable.")
            }
        } catch {
            showToast("Αποτυχία clip: \(error.localizedDescription)")
            EarconFeedbackService.shared.playEarcon(.error)
        }
    }

    // MARK: - Notes & Composer
    public func addNote(text: String, tags: [String] = [], source: EntrySource = .manual) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Αυτόματη ανάλυση τόνου και συναισθήματος
        let detectedEmotionTags = emotionAnalyzer.analyzeTranscript(text: text)
        let mergedTags = Array(Set(tags + detectedEmotionTags))

        let entry = JournalEntry(
            content: text,
            source: source,
            tags: mergedTags
        )

        do {
            try await storage.saveEntry(entry)
            await refreshEntries()
            await exportEntryToObsidianIfConfigured(entry)
            showToast("✅ Η σημείωση αποθηκεύτηκε.")
        } catch {
            showToast("Σφάλμα αποθήκευσης: \(error.localizedDescription)")
        }
    }

    // MARK: - Speech
    public func toggleSpeechDictation() {
        if isListeningSpeech {
            let transcript = speechService.stopListening()
            isListeningSpeech = false
            if let text = transcript, !text.isEmpty {
                Task {
                    await self.addNote(text: text, source: .voice)
                }
            }
        } else {
            do {
                try speechService.startListening()
                isListeningSpeech = true
            } catch {
                showToast("Σφάλμα μικροφώνου: \(error.localizedDescription)")
            }
        }
    }

    private func setupSpeechCommandHandler() {
        speechService.setCommandHandler { [weak self] command in
            guard let self = self else { return }
            Task { @MainActor in
                switch command {
                case .clip(let seconds):
                    await self.triggerClip(seconds: seconds)
                case .note(let text):
                    await self.addNote(text: text, source: .voice)
                case .whatAmISeeing:
                    await self.executeWhatAmISeeing()
                case .unknown:
                    break
                }
            }
        }
    }

    // MARK: - AI Assistant
    public func sendMessageToAssistant(prompt: String) async {
        chatMessages.append((id: UUID(), isUser: true, text: prompt, timestamp: Date()))

        do {
            let memory = try? await agentManager.loadAgentMemory()
            let result = try await aiRouter.askAssistant(
                prompt: prompt,
                contextEntries: todayEntries,
                agentMemory: memory
            )

            chatMessages.append((id: UUID(), isUser: false, text: result.reply, timestamp: Date()))
        } catch {
            chatMessages.append((id: UUID(), isUser: false, text: "Σφάλμα επικοινωνίας με το AI: \(error.localizedDescription)", timestamp: Date()))
        }
    }

    public func executeWhatAmISeeing() async {
        do {
            let photoData = try await glassesAdapter.capturePhoto()
            let reply = try await aiRouter.askWhatAmISeeing(imageData: photoData, customQuestion: nil)

            // Προσθήκη της περιγραφής στο chat και ως σημείωση
            chatMessages.append((id: UUID(), isUser: false, text: "👀 [What am I seeing]: \(reply)", timestamp: Date()))
            await addNote(text: "👀 Περιγραφή εικόνας: \(reply)", tags: ["vision", "glasses"], source: .ai)
        } catch {
            showToast("Σφάλμα Vision: \(error.localizedDescription)")
        }
    }

    // MARK: - Observation Game
    public func playNextMission() async {
        self.currentMission = await gameEngine.startNewMission()
    }

    /// Αξιολογεί capture παιχνιδιού. Επιστρέφει `true` μόνο σε επιτυχή αποστολή (G5-002).
    @discardableResult
    public func evaluateGameCapture() async -> Bool {
        do {
            let photoData = try await glassesAdapter.capturePhoto()
            let result = try await gameEngine.evaluateCapturedPhoto(imageData: photoData)
            self.gameScore = await gameEngine.getScore()
            self.currentMission = await gameEngine.getCurrentMission()

            if result.success {
                R0llingTheme.triggerSuccessHaptic()
                showToast("🎉 Συγχαρητήρια! +10 πόντοι")
                return true
            } else {
                showToast("Δεν βρέθηκε ακόμη: \(result.feedback)")
                return false
            }
        } catch {
            showToast("Σφάλμα αξιολόγησης: \(error.localizedDescription)")
            return false
        }
    }

    /// Εξαγωγή Obsidian μετά journal save — fail-closed toast αν vault configured αλλά export αποτύχει (CQ-P1-012).
    private func exportEntryToObsidianIfConfigured(_ entry: JournalEntry) async {
        guard await obsidianBridge.currentVaultURL != nil else { return }
        do {
            _ = try await obsidianBridge.exportEntry(entry, mediaStorage: mediaStorage)
        } catch {
            showToast("⚠️ Journal OK· Obsidian: \(error.localizedDescription)")
        }
    }

    // MARK: - Super Feature Hooks & Integrations
    private func setupSuperFeatureHooks() {
        // CQ-P0-007: fail-closed — μην εμφανίζεις hardware toasts χωρίς πραγματικό feed.
        acousticTrigger.config.isEnabled = Self.SUPER_FEATURE_ACOUSTIC_MIC_FEED_WIRED

        if Self.SUPER_FEATURE_ACOUSTIC_MIC_FEED_WIRED {
            acousticTrigger.onSpikeDetected = { [weak self] decibels in
                guard let self = self else { return }
                Task { @MainActor in
                    self.showToast("⚡ Ηχητική έκρηξη (\(Int(decibels)) dB): Αυτόματο Clip!")
                    await self.triggerClip(seconds: 10.0)
                }
            }
        }

        if Self.SUPER_FEATURE_IMU_FEED_WIRED {
            gestureDetector.onDoubleNodDetected = { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    self.showToast("🕶️ Νεύμα κεφαλιού: Αθόρυβο Clip!")
                    await self.triggerClip(seconds: 5.0)
                }
            }
        }

        // Apple Watch Remote Triggers (ενεργά μόνο αν στείλει companion — δεν υπάρχει watch target ακόμα)
        WatchConnectivityCoordinator.shared.onRemoteClipTriggerRequested = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.triggerClip(seconds: 10.0)
            }
        }

        WatchConnectivityCoordinator.shared.onRemoteNoteReceived = { [weak self] noteText in
            guard let self = self else { return }
            Task { @MainActor in
                await self.addNote(text: noteText, source: .voice)
            }
        }
    }

    public func createDailyHighlightReel() async {
        do {
            let reel = try await highlightMuxer.createDailyHighlightReel(for: todayEntries)
            showToast("🎬 Highlight Reel (\(reel.totalClipsIncluded) clips, \(Int(reel.totalDurationSeconds))s) έτοιμο!")
            await refreshEntries()
        } catch {
            showToast("Σφάλμα Reel: \(error.localizedDescription)")
        }
    }

    /// Εξαγωγή Obsidian canvas — fail-closed toast (G5-003), χωρίς ψευδή επιτυχία.
    public func exportObsidianCanvas() async {
        let canvasJSON = canvasGenerator.generateCanvasJSON(
            entries: todayEntries,
            title: "Σύνοψη \(Date().formattedGreekHeader())"
        )
        guard let vaultURL = await obsidianBridge.currentVaultURL else {
            showToast("Σφάλμα Canvas: δεν έχει οριστεί Obsidian vault.")
            return
        }
        let canvasURL = vaultURL.appendingPathComponent("Weekly-Canvas.canvas")
        do {
            try canvasJSON.write(to: canvasURL, atomically: true, encoding: .utf8)
            showToast("🎨 Obsidian Canvas εξήχθη επιτυχώς!")
        } catch {
            showToast("Σφάλμα Canvas: \(error.localizedDescription)")
        }
    }

    /// Daily podcast — εμφανίζει σφάλμα αν αποτύχει το summarize (G5-005).
    public func playDailyPodcast() async {
        do {
            let summary = try await aiRouter.summarizeDay(entries: todayEntries)
            podcastGenerator.playDailyPodcast(summaryText: summary)
            showToast("🎙️ Αναπαραγωγή Daily Podcast...")
        } catch {
            showToast("Σφάλμα Podcast: \(error.localizedDescription)")
        }
    }

    public func stopDailyPodcast() {
        podcastGenerator.stopPodcast()
    }

    // MARK: - Next-Gen Feature Helpers (Batch 7)
    public func toggleMirrorStreaming() {
        if isMirrorStreaming {
            mirrorStreamServer.stopServer()
            isMirrorStreaming = false
            activeMirrorClientsCount = 0
            showToast("Η απομακρυσμένη ροή (See-What-I-See) τερματίστηκε.")
        } else {
            do {
                // SEC-001: ephemeral pairing token πριν listener — AUTH υποχρεωτικό πριν frames.
                if mirrorStreamServer.pairingToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    mirrorStreamServer.pairingToken = UUID().uuidString
                }
                try mirrorStreamServer.startServer()
                isMirrorStreaming = true
                mirrorStreamServer.onClientConnected = { [weak self] count in
                    Task { @MainActor in
                        self?.activeMirrorClientsCount = count
                    }
                }
                let pinHint = String(mirrorStreamServer.pairingToken.prefix(8))
                showToast("Mirror ακούει (Bonjour+AUTH \(pinHint)…) — χωρίς frame pipeline από glasses.")
            } catch {
                showToast("Σφάλμα Mirror Server: \(error.localizedDescription)")
            }
        }
    }

    public func exportKnowledgeGraphToObsidian() async {
        // CQ-P0-004: γέμισε τον γράφο από σημερινές entries πριν το export (αλλιώς άδειο Mermaid + fake success).
        for entry in todayEntries {
            let extracted = knowledgeGraphEngine.extractTriples(from: entry.content, date: entry.timestamp)
            knowledgeGraphEngine.addTriples(extracted)
        }
        let tripleCount = knowledgeGraphEngine.allTriples.count
        guard tripleCount > 0 else {
            showToast("Knowledge Graph: καμία σχέση από τις σημερινές καταγραφές.")
            return
        }
        let mermaidGraph = knowledgeGraphEngine.exportMermaidGraph()
        guard let vaultURL = await obsidianBridge.currentVaultURL else {
            showToast("Σφάλμα Graph: δεν έχει οριστεί Obsidian vault.")
            return
        }
        let graphURL = vaultURL.appendingPathComponent("Knowledge-Graph.md")
        let doc = "# 🧠 Associative Knowledge Graph\n\n\(mermaidGraph)"
        do {
            try doc.write(to: graphURL, atomically: true, encoding: .utf8)
            showToast("🧠 Knowledge Graph (\(tripleCount) triples) εξήχθη στο Obsidian.")
        } catch {
            showToast("Σφάλμα εξαγωγής Graph: \(error.localizedDescription)")
        }
    }

    /// Heuristic εκτίμηση από tokens όρασης — όχι μετρημένες θερμίδες / HealthKit proof.
    public func logMealFromDetectedTokens(_ tokens: [String]) async {
        if let snapshot = nutritionLogger.analyzeDetectedFoodTokens(tokens: tokens) {
            let md = nutritionLogger.formatObsidianMarkdown(snapshot: snapshot)
            await addNote(text: md, source: .camera)
            showToast("🥗 Εκτίμηση γεύματος (~\(Int(snapshot.totalCalories)) kcal, heuristic)")
        } else {
            showToast("Δεν αναγνωρίστηκαν γνωστά τρόφιμα στα tokens.")
        }
    }

    // MARK: - Ticker & Toasts
    private func startPeriodicStateSync() {
        tickerTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.bufferDuration = await self.bufferService.availableDuration
                WatchConnectivityCoordinator.shared.updateWatchBufferState(
                    isStreaming: self.isStreaming,
                    bufferSeconds: self.bufferDuration
                )
            }
        }
    }

    public func showToast(_ message: String) {
        self.toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }
}
