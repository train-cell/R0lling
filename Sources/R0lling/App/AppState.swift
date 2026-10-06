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
    @Published public var gameSessionState: ObservationGameSessionState = .idle
    @Published public var lastGameEvaluation: ObservationEvaluationResult?
    @Published public var activeProvider: AIProviderType = .directAPI

    // MARK: - READY super-feature engines (FeatureReadinessRegistry.ready == true)

    public let timeCapsuleEngine = TimeCapsuleEngine()
    public let streakManager = ScavengerHuntStreakManager()
    public let podcastGenerator = DailyPodcastGenerator()
    public let highlightMuxer: HighlightReelMuxer
    public let canvasGenerator = ObsidianCanvasGenerator()
    public let emotionAnalyzer = VoiceEmotionAnalyzer()
    public let onDeviceVision = OnDeviceVisionService()
    public let entityRecognizer = LocalEntityRecognizer()
    public let knowledgeGraphEngine = AssociativeKnowledgeGraphEngine()
    public let nutritionLogger = MealNutritionVisionLogger()

    // MARK: - Gated hardware hooks (ready=false · κρατούνται για diagnose + μελλοντικό feed)

    public let acousticTrigger = AcousticTriggerService()
    public let gestureDetector = HeadGestureDetector()

    /// Mirror server αρχείο υπάρχει · product surface OFF μέχρι TLS + broadcastFrame.
    private let mirrorStreamServer = RemoteMirrorStreamServer()

    @Published public var isMirrorStreaming: Bool = false
    @Published public var activeMirrorClientsCount: Int = 0

    @Published public var timeCapsuleMemories: [TimeCapsuleEngine.CapsuleMemory] = []
    @Published public var scavengerStreak: Int = 0
    @Published public var scavengerBadges: [String] = []
    /// Εμφανίσιμο path Obsidian vault (Settings / A08).
    @Published public var obsidianVaultDisplayPath: String = VaultBookmarkStore.display_path_i_default()
    /// Τελευταία conflict sidecars από export (A09 UI).
    @Published public var teleutaiaObsidianConflicts: [String] = []

    private var cancellables = Set<AnyCancellable>()
    private var tickerTimer: Timer?
    /// Ενεργή AI Task για cancelation (chat / vision / recall).
    private var activeAITask: Task<Void, Never>?

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
        let backup = BackupRestoreEngine(
            storage: storage,
            mediaStorage: mediaStorage,
            agentManager: agent
        )

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
        // A14: idle → πρώτη αποστολή για session lifecycle.
        if await gameEngine.getCurrentMission() == nil {
            self.currentMission = await gameEngine.startNewMission()
        } else {
            self.currentMission = await gameEngine.getCurrentMission()
        }
        self.gameScore = await gameEngine.getScore()
        self.gameSessionState = await gameEngine.getSessionState()
        self.lastGameEvaluation = await gameEngine.getLastEvaluation()
        await fortosi_obsidian_vault_apo_bookmark()

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

        let detectedEmotionTags = emotionAnalyzer.analyzeTranscript(text: text)
        let detectedEntityTags = entityRecognizer.detectEntities(textClues: [text])
        let mergedTags = Array(Set(tags + detectedEmotionTags + detectedEntityTags))

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

    // MARK: - Speech (Apple Speech Framework — όχι Meta mic / Hey Meta wake)
    /// A04: μία σημείωση ανά final utterance · `SpeechStopResult` αποφεύγει διπλό addNote.
    public func toggleSpeechDictation() {
        if isListeningSpeech {
            let stopResult = speechService.stopListening()
            isListeningSpeech = false
            switch stopResult {
            case .commandHandled:
                break
            case .dictation(let text):
                Task {
                    await self.addNote(text: text, source: .voice)
                }
            case .empty:
                break
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
                await self.routeVoiceCommand(command)
            }
        }
    }

    /// Κεντρική δρομολόγηση φωνητικών εντολών (parser → AppState).
    public func routeVoiceCommand(_ command: VoiceCommandType) async {
        switch command {
        case .clip(let seconds):
            await triggerClip(seconds: seconds)
        case .note(let text):
            await addNote(text: text, source: .voice)
        case .whatAmISeeing:
            await executeWhatAmISeeing()
        case .startObservationGame:
            await playNextMission()
            showToast("🎯 Παιχνίδι παρατήρησης: νέα αποστολή.")
        case .nextMission:
            await playNextMission()
            showToast("➡️ Επόμενη αποστολή.")
        case .unknown:
            break
        }
    }

    // MARK: - AI Assistant

    /// Ακυρώνει τρέχουσα AI κλήση (chat / vision / recall).
    public func cancelActiveAIRequest() {
        activeAITask?.cancel()
        activeAITask = nil
        showToast("Ακυρώθηκε η κλήση AI.")
    }

    public func sendMessageToAssistant(prompt: String) async {
        chatMessages.append((id: UUID(), isUser: true, text: prompt, timestamp: Date()))

        activeAITask?.cancel()
        let task = Task { @MainActor in
            do {
                try Task.checkCancellation()
                let memory = try? await agentManager.loadAgentMemory()
                let result = try await aiRouter.askAssistant(
                    prompt: prompt,
                    contextEntries: todayEntries,
                    agentMemory: memory
                )
                try Task.checkCancellation()
                chatMessages.append((id: UUID(), isUser: false, text: result.reply, timestamp: Date()))
            } catch is CancellationError {
                chatMessages.append((id: UUID(), isUser: false, text: "⏹ Ακυρώθηκε.", timestamp: Date()))
            } catch {
                chatMessages.append((id: UUID(), isUser: false, text: "Σφάλμα επικοινωνίας με το AI: \(error.localizedDescription)", timestamp: Date()))
            }
        }
        activeAITask = task
        await task.value
    }

    /// A11: vision path — multi-frame από buffer· fallback `capturePhoto` (protocol/sim)· OCR on-device.
    public func executeWhatAmISeeing() async {
        activeAITask?.cancel()
        let task = Task { @MainActor in
            do {
                try Task.checkCancellation()
                let bufferFrames = await bufferService.snapshotVisionKeyframes()
                let photoForOCR: Data
                let reply: String

                if bufferFrames.count >= 2 {
                    photoForOCR = bufferFrames.last!
                    reply = try await aiRouter.askWhatAmISeeingMultiFrames(
                        frames: bufferFrames,
                        customQuestion: nil
                    )
                } else if let single = bufferFrames.first {
                    photoForOCR = single
                    reply = try await aiRouter.askWhatAmISeeing(imageData: single, customQuestion: nil)
                } else {
                    let photoData = try await glassesAdapter.capturePhoto()
                    photoForOCR = photoData
                    reply = try await aiRouter.askWhatAmISeeing(imageData: photoData, customQuestion: nil)
                }

                try Task.checkCancellation()

                // On-device OCR (READY) πριν/μαζί με cloud vision
                let ocrTokens = await onDeviceVision.recognizeTextFromImage(imageData: photoForOCR)

                var visionNote = "👀 Περιγραφή εικόνας: \(reply)"
                if !ocrTokens.isEmpty {
                    visionNote += "\n🔤 OCR: \(ocrTokens.joined(separator: ", "))"
                }

                chatMessages.append((id: UUID(), isUser: false, text: "👀 [What am I seeing]: \(reply)", timestamp: Date()))
                await addNote(text: visionNote, tags: ["vision", "glasses"], source: .ai)

                if FeatureReadinessRegistry.nutritionHeuristic.ready {
                    await logMealFromDetectedTokens(ocrTokens)
                }
            } catch is CancellationError {
                showToast("Vision ακυρώθηκε.")
            } catch {
                showToast("Σφάλμα Vision: \(error.localizedDescription)")
            }
        }
        activeAITask = task
        await task.value
    }

    /// A12: ανάκληση μνήμης από journal + AI.
    public func executeRecall(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showToast("Γράψε τι θέλεις να θυμηθείς.")
            return
        }

        chatMessages.append((id: UUID(), isUser: true, text: "🔎 Ανάκληση: \(trimmed)", timestamp: Date()))

        activeAITask?.cancel()
        let task = Task { @MainActor in
            do {
                try Task.checkCancellation()
                let result = try await aiRouter.recallMemories(query: trimmed, allEntries: allEntries)
                try Task.checkCancellation()
                chatMessages.append((id: UUID(), isUser: false, text: result.reply, timestamp: Date()))
            } catch is CancellationError {
                chatMessages.append((id: UUID(), isUser: false, text: "⏹ Ανάκληση ακυρώθηκε.", timestamp: Date()))
            } catch {
                chatMessages.append((
                    id: UUID(),
                    isUser: false,
                    text: "Σφάλμα ανάκλησης: \(error.localizedDescription)",
                    timestamp: Date()
                ))
            }
        }
        activeAITask = task
        await task.value
    }

    // MARK: - Observation Game (A14)
    public func playNextMission() async {
        self.currentMission = await gameEngine.startNewMission()
        self.gameSessionState = await gameEngine.getSessionState()
        self.lastGameEvaluation = nil
    }

    /// Αξιολογεί capture από γυαλιά. `true` μόνο σε επιτυχή αποστολή (G5-002).
    @discardableResult
    public func evaluateGameCapture() async -> Bool {
        do {
            let photoData = try await glassesAdapter.capturePhoto()
            return await evaluateGameCapture(imageData: photoData)
        } catch {
            showToast("Σφάλμα λήψης: \(error.localizedDescription). Δοκίμασε επιλογή φωτογραφίας.")
            return false
        }
    }

    /// Αξιολογεί επιλεγμένη εικόνα (PhotosPicker fallback — χωρίς γυαλιά).
    @discardableResult
    public func evaluateGameCapture(imageData: Data) async -> Bool {
        let result = await gameEngine.evaluateCapturedPhoto(imageData: imageData)
        await syncGamePublishedState(from: result)

        if result.success {
            R0llingTheme.triggerSuccessHaptic()
            let label = result.source == .aiVision ? "AI" : "χειροκίνητα"
            showToast("🎉 Επιτυχία (\(label))! +\(result.awardedPoints) πόντοι")
            return true
        } else {
            let prefix = result.source == .unavailable ? "AI μη διαθέσιμο" : "Δεν βρέθηκε ακόμη"
            showToast("\(prefix): \(result.feedback)")
            return false
        }
    }

    /// Χειροκίνητη επιβεβαίωση — ρητά όχι AI (A14 honesty).
    @discardableResult
    public func confirmGameManually() async -> Bool {
        let result = await gameEngine.confirmManually()
        await syncGamePublishedState(from: result)
        if result.success {
            showToast("✅ Χειροκίνητη επιβεβαίωση (όχι AI) +\(result.awardedPoints)")
            await playNextMission()
            return true
        }
        showToast(result.feedback)
        return false
    }

    /// Streak μετά επιτυχία μόνο (G5-002 / CQ-P2-024).
    @discardableResult
    public func recordGameStreakAfterSuccess() -> Bool {
        let apotelesma = streakManager.recordMissionCompleted()
        scavengerStreak = streakManager.currentStreak
        scavengerBadges = streakManager.badges
        if !apotelesma.didPersist {
            showToast("Το streak ενημερώθηκε στη μνήμη αλλά απέτυχε η αποθήκευση.")
        }
        return apotelesma.didPersist
    }

    private func syncGamePublishedState(from result: ObservationEvaluationResult) async {
        gameScore = await gameEngine.getScore()
        currentMission = await gameEngine.getCurrentMission()
        gameSessionState = await gameEngine.getSessionState()
        lastGameEvaluation = result
    }

    /// Εξαγωγή Obsidian μετά journal save — fail-closed toast αν vault configured αλλά export αποτύχει (CQ-P1-012).
    /// A09: conflict → toast + δημοσίευση sidecar paths.
    private func exportEntryToObsidianIfConfigured(_ entry: JournalEntry) async {
        guard await obsidianBridge.currentVaultURL != nil else { return }
        do {
            let outcome = try await obsidianBridge.exportEntry(entry, mediaStorage: mediaStorage)
            if outcome.hadConflict {
                let sidecar = outcome.conflictSidecarRelativePath ?? "sidecar"
                teleutaiaObsidianConflicts = [sidecar]
                showToast("⚠️ Obsidian conflict — πρωτότυπο ανέπαφο → \(sidecar)")
            }
        } catch {
            showToast("⚠️ Journal OK· Obsidian: \(error.localizedDescription)")
        }
    }

    /// A08: εφαρμογή vault από iOS Files / document picker (security-scoped bookmark).
    public func efarmogi_epilogis_obsidian_vault(_ url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            try VaultBookmarkStore.apothikeusi_bookmark(apo: url)
            await obsidianBridge.setVaultURL(url, requiresScopedAccess: true)
            await agentManager.setVaultURL(url)
            obsidianVaultDisplayPath = url.path
            showToast("Obsidian vault συνδέθηκε: \(url.lastPathComponent)")
        } catch {
            showToast("Σφάλμα vault bookmark: \(error.localizedDescription)")
        }
    }

    /// A15: δημιουργία πλήρους backup bundle (entries + media + agent memory).
    public func dimiourgia_backup_bundle() async {
        do {
            let backupURL = try await backupEngine.createBackupBundle()
            showToast("Backup έτοιμο: \(backupURL.lastPathComponent)")
        } catch {
            showToast(AppErrorTaxonomy.minimaXristi(gia: error))
        }
    }

    /// A15: επαναφορά από Files-picked backup φάκελο (security-scoped).
    public func epanafora_apo_backup_bundle(_ url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let result = try await backupEngine.restoreFromBackupBundle(bundleURL: url)
            await loadInitialData()
            showToast(
                "Επαναφορά: \(result.restoredEntries) εγγραφές, \(result.restoredMedia) μέσα."
            )
        } catch {
            showToast(AppErrorTaxonomy.minimaXristi(gia: error))
        }
    }

    /// Επαναφορά στο default Documents/R0lling/ObsidianVault.
    public func epanekkinisi_proepilegmenou_obsidian_vault() async {
        VaultBookmarkStore.epanekkinisi_proepilegmenou()
        let defaultURL: URL
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            defaultURL = docs.appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
        } else {
            defaultURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
        }
        await obsidianBridge.setVaultURL(defaultURL, requiresScopedAccess: false)
        await agentManager.setVaultURL(defaultURL)
        obsidianVaultDisplayPath = VaultBookmarkStore.display_path_i_default()
        teleutaiaObsidianConflicts = []
        showToast("Επαναφορά στο τοπικό Obsidian vault.")
    }

    /// Επαναφορά bookmark στο launch (χωρίς toast αν OK).
    public func fortosi_obsidian_vault_apo_bookmark() async {
        do {
            if let resolved = try VaultBookmarkStore.fortosi_vault_url() {
                await obsidianBridge.setVaultURL(resolved.url, requiresScopedAccess: resolved.requiresScopedAccess)
                await agentManager.setVaultURL(resolved.url)
                obsidianVaultDisplayPath = resolved.url.path
            } else {
                obsidianVaultDisplayPath = VaultBookmarkStore.display_path_i_default()
            }
        } catch {
            obsidianVaultDisplayPath = VaultBookmarkStore.display_path_i_default()
            showToast("Obsidian bookmark stale — χρησιμοποίησε ξανά Files picker.")
        }
    }

    /// Batch export από Settings — ενημερώνει conflict list για UI.
    public func exportBatchToObsidian() async -> ObsidianExportResult? {
        do {
            let result = try await obsidianBridge.exportBatch(
                entries: allEntries,
                mediaStorage: mediaStorage
            )
            teleutaiaObsidianConflicts = result.conflictsDetected
            return result
        } catch {
            showToast("Σφάλμα εξαγωγής Obsidian: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Super Feature Hooks (μόνο όταν ready=true ή latent WCSession)
    private func setupSuperFeatureHooks() {
        // Acoustic / IMU triggers: fail-closed μέχρι FeatureReadinessRegistry flip.
        // Feed pipeline είναι πάντα wired (adapter → sink) — flip ready = 100% auto-clip.
        acousticTrigger.config.isEnabled = FeatureReadinessRegistry.acoustic.ready

        if FeatureReadinessRegistry.acoustic.ready {
            acousticTrigger.onSpikeDetected = { [weak self] decibels in
                guard let self = self else { return }
                Task { @MainActor in
                    self.showToast("⚡ Ηχητική έκρηξη (\(Int(decibels)) dB): Αυτόματο Clip!")
                    await self.triggerClip(seconds: 10.0)
                }
            }
        }

        if FeatureReadinessRegistry.headGesture.ready {
            gestureDetector.onDoubleNodDetected = { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    self.showToast("🕶️ Νεύμα κεφαλιού: Αθόρυβο Clip!")
                    await self.triggerClip(seconds: 5.0)
                }
            }
        }

        // Feed API end-to-end: MetaGlassesAdapter → AcousticTrigger / HeadGesture.
        Task {
            await glassesAdapter.setSensorFeedSink(self)
        }

        // Latent WCSession: ενεργό μόνο αν companion στείλει (ready=false · χωρίς Watch UI)
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

    // MARK: - A07 App Lifecycle (background / lock)
    /// Κλήση από `R0llingApp` scenePhase — pause/resume με honest UI labels.
    public func handleScenePhaseChange(_ phase: ScenePhase) async {
        let event: GlassesAppLifecycleEvent
        switch phase {
        case .background:
            event = .willEnterBackground
        case .inactive:
            event = .willResignActiveForLock
        case .active:
            event = .didBecomeActive
        @unknown default:
            return
        }

        let outcome = await glassesAdapter.handleAppLifecycle(event)
        glassesState = await glassesAdapter.connectionState
        isStreaming = glassesState.isLive

        if let msg = outcome.userMessage {
            showToast(msg)
        }
        if outcome.bufferStateLabel == "PAUSED" {
            bufferDuration = await bufferService.availableDuration
        }
    }

    public func createDailyHighlightReel() async {
        guard FeatureReadinessRegistry.highlightReel.ready else {
            showToast("Highlight Reel απενεργοποιημένο.")
            return
        }
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
        guard FeatureReadinessRegistry.canvas.ready else {
            showToast("Canvas απενεργοποιημένο.")
            return
        }
        let canvasJSON = canvasGenerator.generateCanvasJSON(
            entries: todayEntries,
            title: "Σύνοψη \(Date().formattedGreekHeader())"
        )
        guard await obsidianBridge.currentVaultURL != nil else {
            showToast("Σφάλμα Canvas: δεν έχει οριστεί Obsidian vault.")
            return
        }
        do {
            _ = try await obsidianBridge.grapse_arxeio_sto_vault(
                relativePath: "Weekly-Canvas.canvas",
                contents: canvasJSON
            )
            showToast("🎨 Obsidian Canvas εξήχθη επιτυχώς!")
        } catch {
            showToast("Σφάλμα Canvas: \(error.localizedDescription)")
        }
    }

    /// Daily podcast — εμφανίζει σφάλμα αν αποτύχει το summarize (G5-005).
    public func playDailyPodcast() async {
        guard FeatureReadinessRegistry.podcast.ready else {
            showToast("Podcast απενεργοποιημένο.")
            return
        }
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

    // MARK: - Mirror (DISABLED μέχρι TLS — ready=false)
    public func toggleMirrorStreaming() {
        guard FeatureReadinessRegistry.mirror.ready else {
            isMirrorStreaming = false
            activeMirrorClientsCount = 0
            showToast("Mirror απενεργοποιημένο μέχρι TLS + glasses frame pipeline.")
            return
        }
        if isMirrorStreaming {
            mirrorStreamServer.stopServer()
            isMirrorStreaming = false
            activeMirrorClientsCount = 0
            showToast("Η απομακρυσμένη ροή (See-What-I-See) τερματίστηκε.")
        } else {
            do {
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
                // SEC-009: μην εκθέτεις pairing token (ούτε prefix) σε toast/logs.
                showToast("Mirror ακούει (Bonjour+AUTH) — χωρίς frame pipeline από glasses.")
            } catch {
                showToast("Σφάλμα Mirror Server: \(error.localizedDescription)")
            }
        }
    }

    public func exportKnowledgeGraphToObsidian() async {
        guard FeatureReadinessRegistry.knowledgeGraph.ready else {
            showToast("Knowledge Graph απενεργοποιημένο.")
            return
        }
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
        guard await obsidianBridge.currentVaultURL != nil else {
            showToast("Σφάλμα Graph: δεν έχει οριστεί Obsidian vault.")
            return
        }
        let doc = "# 🧠 Associative Knowledge Graph\n\n\(mermaidGraph)"
        do {
            _ = try await obsidianBridge.grapse_arxeio_sto_vault(
                relativePath: "Knowledge-Graph.md",
                contents: doc
            )
            showToast("🧠 Knowledge Graph (\(tripleCount) triples) εξήχθη στο Obsidian.")
        } catch {
            showToast("Σφάλμα εξαγωγής Graph: \(error.localizedDescription)")
        }
    }

    /// Heuristic εκτίμηση από tokens όρασης — όχι μετρημένες θερμίδες / HealthKit.
    public func logMealFromDetectedTokens(_ tokens: [String]) async {
        guard FeatureReadinessRegistry.nutritionHeuristic.ready else { return }
        guard !tokens.isEmpty else { return }
        guard let snapshot = nutritionLogger.analyzeDetectedFoodTokens(tokens: tokens) else { return }

        let md = nutritionLogger.formatObsidianMarkdown(snapshot: snapshot)
        let entry = JournalEntry(content: md, source: .ai, tags: ["meal", "nutrition", "heuristic"])
        do {
            try await storage.saveEntry(entry)
            await refreshEntries()
            await exportEntryToObsidianIfConfigured(entry)
            showToast("🥗 Εκτίμηση γεύματος (~\(Int(snapshot.totalCalories)) kcal, heuristic)")
        } catch {
            showToast("Σφάλμα καταγραφής γεύματος: \(error.localizedDescription)")
        }
    }

    // MARK: - Journal CRUD (A01 / A02)

    /// Διαγραφή καταγραφής + orphan media μόνο αν δεν αναφέρεται αλλού.
    public func deleteEntry(id: UUID) async {
        do {
            guard let entry = await storage.getEntry(id: id) else {
                showToast("Η καταγραφή δεν βρέθηκε.")
                return
            }
            try await storage.deleteEntry(id: id)
            await katharismosOrphanMedia(afairoumena: entry.attachments)
            await refreshEntries()
            showToast("Η καταγραφή διαγράφηκε.")
        } catch {
            showToast("Σφάλμα διαγραφής: \(error.localizedDescription)")
        }
    }

    /// Εναλλαγή αγαπημένου — αποτυχία → toast, όχι silent UI lie.
    public func toggleFavorite(entry: JournalEntry) async {
        var updated = entry
        updated.isFavorite.toggle()
        updated.lastModified = Date()
        do {
            try await storage.saveEntry(updated)
            await refreshEntries()
        } catch {
            showToast("Σφάλμα αγαπημένου: \(error.localizedDescription)")
        }
    }

    /// A02: επεξεργασία με σταθερό ID (overwrite, χωρίς διπλότυπο).
    public func updateEntry(_ entry: JournalEntry) async {
        var updated = entry
        updated.lastModified = Date()
        do {
            try await storage.saveEntry(updated)
            await refreshEntries()
            await exportEntryToObsidianIfConfigured(updated)
            showToast("✅ Η καταγραφή ενημερώθηκε.")
        } catch {
            showToast("Σφάλμα επεξεργασίας: \(error.localizedDescription)")
        }
    }

    /// A02: διόρθωση ημερομηνίας/TZ — ίδιο UUID, νέο `dateKey`.
    public func correctEntryDate(
        id: UUID,
        newTimestamp: Date,
        timeZoneIdentifier: String? = nil
    ) async {
        guard var entry = await storage.getEntry(id: id) else {
            showToast("Η καταγραφή δεν βρέθηκε.")
            return
        }
        entry.timestamp = newTimestamp
        if let timeZoneIdentifier {
            let trimmed = timeZoneIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                entry.timeZoneIdentifier = trimmed
            }
        }
        entry.lastModified = Date()
        do {
            try await storage.saveEntry(entry)
            let sameIdCount = await storage.getAllEntries().filter { $0.id == id }.count
            guard sameIdCount == 1 else {
                showToast("Σφάλμα ακεραιότητας: διπλότυπο ID μετά από διόρθωση ημερομηνίας.")
                return
            }
            await refreshEntries()
            showToast("✅ Ημερομηνία → \(entry.dateKey)")
        } catch {
            showToast("Σφάλμα ημερομηνίας: \(error.localizedDescription)")
        }
    }

    /// A02 search facade — title/content/tags μέσω storage.
    public func searchJournal(
        query: String,
        tag: String? = nil,
        source: EntrySource? = nil
    ) async -> [JournalEntry] {
        await storage.searchEntries(query: query, tag: tag, source: source)
    }

    // MARK: - Media Attach (A03)

    /// Αποθήκευση bytes → `MediaAttachment` → νέα καταγραφή ή επισύναψη σε υπάρχουσα.
    public func attachMediaData(
        data: Data,
        originalFilename: String,
        mediaType: MediaType,
        toEntryId: UUID? = nil,
        noteText: String? = nil
    ) async {
        do {
            let attachment = try await mediaStorage.saveMediaFile(
                data: data,
                originalFilename: originalFilename,
                mediaType: mediaType
            )

            if let toEntryId, var entry = await storage.getEntry(id: toEntryId) {
                entry.attachments.append(attachment)
                entry.lastModified = Date()
                try await storage.saveEntry(entry)
                await refreshEntries()
                await exportEntryToObsidianIfConfigured(entry)
                showToast("✅ Media επισυνάφθηκε στην καταγραφή.")
                return
            }

            let content = (noteText?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
                $0.isEmpty ? nil : $0
            } ?? JournalMediaImporter.proepiloghmenoKeimeno(gia: mediaType)

            let entry = JournalEntry(
                content: content,
                source: .importFile,
                tags: [mediaType.rawValue],
                attachments: [attachment]
            )
            try await storage.saveEntry(entry)
            await refreshEntries()
            await exportEntryToObsidianIfConfigured(entry)
            showToast("✅ \(mediaType.folderName) αποθηκεύτηκε τοπικά.")
        } catch {
            showToast("Σφάλμα media: \(error.localizedDescription)")
        }
    }

    /// Ανάλυση relative path σε sandbox URL (για previews) — `nil` σε fail, χωρίς crash.
    public func resolveMediaURL(relativePath: String) async -> URL? {
        do {
            return try await mediaStorage.getMediaFileURL(relativePath: relativePath)
        } catch {
            return nil
        }
    }

    /// Σβήνει μόνο attachments που δεν αναφέρονται πλέον από καμία καταγραφή.
    private func katharismosOrphanMedia(afairoumena: [MediaAttachment]) async {
        let all = await storage.getAllEntries()
        let activePaths = Set(all.flatMap { $0.attachments.map(\.relativePath) })
        for att in afairoumena where !activePaths.contains(att.relativePath) {
            do {
                try await mediaStorage.deleteMediaFile(relativePath: att.relativePath)
            } catch {
                showToast("Orphan media: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Ticker & Toasts
    private func startPeriodicStateSync() {
        tickerTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.bufferDuration = await self.bufferService.availableDuration
                if FeatureReadinessRegistry.watchCompanion.ready {
                    WatchConnectivityCoordinator.shared.updateWatchBufferState(
                        isStreaming: self.isStreaming,
                        bufferSeconds: self.bufferDuration
                    )
                }
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

// MARK: - GlassesSensorFeedSink (acoustic / IMU feed API end-to-end)
extension AppState: GlassesSensorFeedSink {
    /// Δέχεται dBFS από MetaGlassesAdapter (simulation ή DAT mic).
    /// Auto-clip μόνο όταν `FeatureReadinessRegistry.acoustic.ready == true`.
    public nonisolated func receiveAcousticLevel(decibels: Float) {
        Task { @MainActor in
            self.acousticTrigger.processAudioLevel(decibels: decibels)
        }
    }

    /// Δέχεται IMU από MetaGlassesAdapter (simulation ή DAT).
    /// Auto-clip μόνο όταν `FeatureReadinessRegistry.headGesture.ready == true`.
    public nonisolated func receiveIMUSample(_ sample: HeadGestureDetector.IMUSample) {
        Task { @MainActor in
            self.gestureDetector.feedIMUSample(sample)
        }
    }
}
