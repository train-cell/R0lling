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
    private let backupEngine: BackupRestoreEngine

    // Published State
    @Published public var todayEntries: [JournalEntry] = []
    @Published public var allEntries: [JournalEntry] = []
    @Published public var selectedDate: Date = Date()
    @Published public var glassesState: GlassesConnectionState = .disconnected
    @Published public var bufferDuration: Double = 0.0
    @Published public var isStreaming: Bool = false
    @Published public var isSimulationMode: Bool = true
    @Published public var deepWorkEndsAt: Date?
    @Published public private(set) var deepWorkSessionRestored = false
    @Published public private(set) var deepWorkPersistenceNeedsRecovery = false
    @Published public var isDeepWorkRecoveryConfirmationPresented = false
    @Published public private(set) var completedFocusSecondsToday: TimeInterval = 0
    @Published public var isListeningSpeech: Bool = false
    @Published public var toastMessage: String?
    @Published public private(set) var pendingBackupExportURL: URL?
    @Published public var chatMessages: [(id: UUID, isUser: Bool, text: String, timestamp: Date)] = []
    @Published public private(set) var pendingVisionNote: String?
    @Published public private(set) var pendingVisionNoteIsSaved = false
    @Published public private(set) var isSavingVisionNote = false
    @Published public private(set) var pendingNutritionEstimate: MealNutritionVisionLogger.NutritionSnapshot?
    @Published public private(set) var pendingNutritionEstimateIsSaved = false
    @Published public private(set) var isSavingNutritionEstimate = false
    @Published public var currentMission: ObservationMission?
    @Published public var gameScore: Int = 0
    @Published public var gameSessionState: ObservationGameSessionState = .idle
    @Published public var lastGameEvaluation: ObservationEvaluationResult?
    @Published public var activeProvider: AIProviderType = .directAPI

    // MARK: - READY super-feature engines (FeatureReadinessRegistry.ready == true)

    public let timeCapsuleEngine = TimeCapsuleEngine()
    public let streakManager = ScavengerHuntStreakManager()
    public let podcastGenerator = DailyPodcastGenerator()
    @Published public private(set) var isDailyPodcastActive = false
    private var dailyPodcastGeneration: UInt64 = 0
    private var pendingVisionTags: [String] = []
    private var pendingVisionNoteID: UUID?
    public let highlightMuxer: HighlightReelMuxer
    public let canvasGenerator = ObsidianCanvasGenerator()
    public let transcriptKeywordTagger = TranscriptKeywordTagger()
    @available(*, deprecated, renamed: "transcriptKeywordTagger")
    public var emotionAnalyzer: VoiceEmotionAnalyzer { transcriptKeywordTagger }
    public let onDeviceVision = OnDeviceVisionService()
    public let entityRecognizer = LocalEntityRecognizer()
    public let knowledgeGraphEngine = AssociativeKnowledgeGraphEngine()
    public let nutritionLogger = MealNutritionVisionLogger()

    // MARK: - Sovereign OS & Apple HealthKit Live Telemetry
    public let healthKitService = HealthKitService.shared
    public let chiefOfStaff = ChiefOfStaffService()
    public let deepWorkManager = DeepWorkSessionManager()
    public let cognitiveCalculator = CognitiveReadinessCalculator()

    @Published public var liveHealthSnapshot: HealthKitTelemetrySnapshot = HealthKitTelemetrySnapshot()
    @Published public var fitnessActivitySnapshot: FitnessActivitySnapshot = .unavailable()
    /// HealthKit does not disclose per-type read permission; this only tracks callback completion.
    @Published public var didCompleteHealthKitAccessRequest: Bool = false
    @Published public var cognitiveTelemetry: CognitiveTelemetryScore = CognitiveTelemetryScore(cognitiveStrain: 0, focusMinutes: 0, readinessPercent: nil)

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
    /// Root-folder activity hint only; it never imports or synchronizes vault changes.
    @Published public private(set) var obsidianVaultChangeDetected = false
    @Published public private(set) var isObsidianVaultWatcherActive = false
    @Published public private(set) var obsidianVaultWatcherError: String?

    private var cancellables = Set<AnyCancellable>()
    private let obsidianFileWatcher = ObsidianFileWatcher()
    /// Keeps the selected document-provider grant alive for the open directory descriptor.
    private var obsidianWatcherScopedURL: URL?
    /// Prevents restore and orphan cleanup from racing while media paths are referenced by the journal.
    private let mediaReferenceMutationGate: MediaReferenceMutationGate
    private var tickerTimer: Timer?
    /// Ενεργή AI Task για cancelation (chat / vision / recall).
    private var activeAITask: Task<Void, Never>?
    private var toastDismissalTask: Task<Void, Never>?

    public init() {
        let storage = JSONFileStorageService()
        let mediaStorage = MediaStorageService()
        let bufferService = RollingBufferService(mediaStorage: mediaStorage)
        let storedBufferTarget = UserDefaults.standard.object(forKey: "r0lling.buffer.targetSeconds") as? Double ?? 10.0
        let glasses = MetaGlassesAdapter(
            bufferService: bufferService,
            initialBufferTargetSeconds: storedBufferTarget
        )
        let speech = SpeechTranscriptionService()
        let obsidian = ObsidianVaultBridge()
        let agent = AgentFolderManager()
        let aiSettings = AIRouter.loadSettings()
        let ai = AIRouter(settings: aiSettings)
        let game = ObservationGameEngine(aiRouter: ai)
        let mutationGate = MediaReferenceMutationGate()
        let backup = BackupRestoreEngine(
            storage: storage,
            mediaStorage: mediaStorage,
            agentManager: agent,
            mediaReferenceMutationGate: mutationGate
        )

        self.storage = storage
        self.mediaStorage = mediaStorage
        self.bufferService = bufferService
        self.glassesAdapter = glasses
        self.speechService = speech
        self.obsidianBridge = obsidian
        self.agentManager = agent
        self.aiRouter = ai
        self.activeProvider = aiSettings.activeProvider
        self.gameEngine = game
        self.backupEngine = backup
        self.mediaReferenceMutationGate = mutationGate
        self.highlightMuxer = HighlightReelMuxer(mediaStorage: mediaStorage)

        setupSpeechCommandHandler()
        setupSuperFeatureHooks()
        startPeriodicStateSync()
        Task { [weak self] in
            await self?.restoreDeepWorkSession()
        }
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
        do {
            let requestedDate = selectedDate
            let all = try await storage.getAllEntries()
            self.allEntries = all
            let selectedEntries = try await storage.getEntriesForDate(requestedDate)
            guard Calendar.current.isDate(selectedDate, inSameDayAs: requestedDate) else { return }
            self.todayEntries = selectedEntries
            self.timeCapsuleMemories = timeCapsuleEngine.findTimeCapsuleEntries(today: requestedDate, allEntries: all)
            self.scavengerStreak = streakManager.currentStreak
            self.scavengerBadges = streakManager.badges
            await refreshLiveHealthTelemetry()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: - Sovereign OS & HealthKit Methods
    private func restoreDeepWorkSession() async {
        defer { deepWorkSessionRestored = true }
        deepWorkPersistenceNeedsRecovery = await deepWorkManager.requiresPersistenceRecovery
        guard !deepWorkPersistenceNeedsRecovery else {
            deepWorkEndsAt = nil
            return
        }
        guard case .active(let startedAt, let duration, _) = await deepWorkManager.getState() else {
            deepWorkEndsAt = nil
            return
        }
        let deadline = startedAt.addingTimeInterval(duration)
        if deadline > Date() {
            deepWorkEndsAt = deadline
        } else {
            deepWorkEndsAt = nil
            await refreshLiveHealthTelemetry()
        }
    }

    public func requestHealthKitAccess() async {
        do {
            let requestCompleted = try await healthKitService.requestAuthorization()
            self.didCompleteHealthKitAccessRequest = requestCompleted
            if requestCompleted {
                await refreshLiveHealthTelemetry()
                await refreshFitnessActivity()
                showToast("Το αίτημα Apple Health ολοκληρώθηκε. Το HealthKit δεν αποκαλύπτει αν εγκρίθηκε η ανάγνωση· η κάρτα δείχνει μόνο τις μετρήσεις που επέστρεψαν.")
            } else {
                showToast("Το HealthKit δεν είναι διαθέσιμο σε αυτή τη συσκευή.")
            }
        } catch {
            showToast("Σφάλμα πρόσβασης HealthKit: \(error.localizedDescription)")
        }
    }

    public func refreshLiveHealthTelemetry() async {
        let telemetryDate = selectedDate
        let entryCount = todayEntries.count
        let snap = await healthKitService.fetchLiveTelemetrySnapshot()
        self.liveHealthSnapshot = snap
        deepWorkPersistenceNeedsRecovery = await deepWorkManager.requiresPersistenceRecovery
        let selectedDateIsToday = Calendar.current.isDateInToday(telemetryDate)
        let completedFocusSeconds = await deepWorkManager.focusSeconds(
            on: telemetryDate,
            includeActiveSession: false
        )
        let focusSeconds = await deepWorkManager.focusSeconds(
            on: telemetryDate,
            includeActiveSession: selectedDateIsToday
        )
        let sessionState = await deepWorkManager.getState()
        if case .active(let startedAt, let duration, _) = sessionState {
            let deadline = startedAt.addingTimeInterval(duration)
            deepWorkEndsAt = deadline > Date() ? deadline : nil
        } else {
            deepWorkEndsAt = nil
        }
        guard Calendar.current.isDate(selectedDate, inSameDayAs: telemetryDate) else { return }
        self.completedFocusSecondsToday = completedFocusSeconds
        let strainAndReady = await cognitiveCalculator.computeTelemetry(
            entriesCount: entryCount,
            deepWorkSeconds: focusSeconds
        )
        self.cognitiveTelemetry = strainAndReady
    }

    public func refreshFitnessActivity() async {
        fitnessActivitySnapshot = await healthKitService.fetchFitnessActivitySnapshot()
    }

    /// Starts or completes a real elapsed-time focus session.
    public func toggleDeepWork() async {
        guard deepWorkSessionRestored else { return }
        guard !deepWorkPersistenceNeedsRecovery else {
            showToast("Το ιστορικό εστίασης δεν διαβάζεται. Ανάκτησέ το πριν ξεκινήσεις νέα συνεδρία.")
            return
        }
        if deepWorkEndsAt != nil {
            await completeDeepWork()
        } else {
            await deepWorkManager.startSession(
                goal: "Εστίαση",
                durationMinutes: DeepWorkSessionTiming.defaultDurationMinutes
            )
            deepWorkEndsAt = Date().addingTimeInterval(DeepWorkSessionTiming.defaultDurationSeconds)
        }
        await refreshLiveHealthTelemetry()
    }

    /// Called only after the user confirms discarding unreadable focus data.
    public func discardCorruptDeepWorkPersistence() async {
        guard deepWorkSessionRestored, deepWorkPersistenceNeedsRecovery else { return }
        let didReset = await deepWorkManager.discardCorruptPersistenceAndReset()
        deepWorkPersistenceNeedsRecovery = await deepWorkManager.requiresPersistenceRecovery
        guard didReset, !deepWorkPersistenceNeedsRecovery else {
            showToast("Δεν ήταν δυνατή η επαναφορά του ιστορικού εστίασης.")
            return
        }
        deepWorkEndsAt = nil
        await refreshLiveHealthTelemetry()
        showToast("Το ιστορικό εστίασης επαναφέρθηκε.")
    }

    /// Finishes the current session and refreshes its measured focus duration.
    public func completeDeepWork() async {
        guard deepWorkSessionRestored, deepWorkEndsAt != nil else { return }
        _ = await deepWorkManager.completeSession()
        deepWorkEndsAt = nil
        await refreshLiveHealthTelemetry()
    }

    // MARK: - Glasses & Streaming
    public func setGlassesSimulationMode(enabled: Bool) async {
        await glassesAdapter.toggleSimulationMode(enabled: enabled)
        isSimulationMode = await glassesAdapter.isSimulationMode
        if isSimulationMode != enabled {
            showToast("Το live Meta DAT bridge δεν είναι διαθέσιμο· παραμένει ενεργό το Simulation.")
        }
    }

    public func toggleGlassesConnection() async {
        isSimulationMode = await glassesAdapter.isSimulationMode
        switch glassesState {
        case .searching, .connecting:
            return
        case .connected, .streaming, .paused:
            await glassesAdapter.disconnectDevice()
            glassesState = .disconnected
            isStreaming = false
            showToast("Τα Meta Glasses αποσυνδέθηκαν.")
        case .disconnected, .error:
            do {
                try await glassesAdapter.connectDevice()
                glassesState = await glassesAdapter.connectionState
                showToast(isSimulationMode ? "Simulation γυαλιών ενεργή." : "Τα Meta Glasses συνδέθηκαν.")
            } catch {
                glassesState = await glassesAdapter.connectionState
                showToast("Σφάλμα σύνδεσης: \(error.localizedDescription)")
            }
        }
    }

    public func toggleGlassesPrimaryAction(cameraPermissionConfirmed: Bool = false) async {
        isSimulationMode = await glassesAdapter.isSimulationMode
        let action = GlassesPrimaryAction.resolve(isStreaming: isStreaming, state: glassesState)

        if cameraPermissionConfirmed,
           !isSimulationMode,
           action != .stopStreaming,
           action != .waitForConnection {
            if action == .connectThenStartStreaming {
                await toggleGlassesConnection()
                guard glassesState.isConnected else { return }
            }

            do {
                try await glassesAdapter.requestCameraPermissionAfterUserConfirmation()
            } catch {
                glassesState = await glassesAdapter.connectionState
                showToast("Camera permission: \(error.localizedDescription)")
                return
            }

            // Meta AI may background this app during its permission handoff. A07
            // closes the old DAT session there, so reconnect before starting capture.
            glassesState = await glassesAdapter.connectionState
            if !glassesState.isConnected {
                await toggleGlassesConnection()
                guard glassesState.isConnected else { return }
            }

            await toggleLiveStream()
            return
        }

        switch action {
        case .waitForConnection:
            return
        case .stopStreaming, .startStreaming:
            await toggleLiveStream()
        case .connectThenStartStreaming:
            await toggleGlassesConnection()
            guard glassesState.isConnected else { return }
            await toggleLiveStream()
        }
    }

    public func toggleLiveStream() async {
        do {
            if isStreaming || glassesState.isLive {
                await glassesAdapter.stopStreaming()
                isStreaming = false
                glassesState = await glassesAdapter.connectionState
                showToast("Η ροή σταμάτησε.")
            } else {
                try await glassesAdapter.startStreaming()
                isStreaming = true
                glassesState = await glassesAdapter.connectionState
                showToast(isSimulationMode ? "Simulation ροή ενεργή. Συνθετικός buffer." : "Η ροή ξεκίνησε. Buffer ενεργό.")
            }
        } catch {
            showToast("Σφάλμα ροής: \(error.localizedDescription)")
        }
    }

    // MARK: - Clipping Action
    public func triggerClip(seconds: Double = 10.0) async {
        var attachmentForRollback: MediaAttachment?
        var journalCommitted = false
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
            attachmentForRollback = attachment

            let simulationSuffix = result.isSimulationPlaceholder
                ? " [δοκιμαστικό placeholder — επιβεβαιωμένη αναπαραγωγή MP4]"
                : ""
            let entry = JournalEntry(
                content: "Rolling Clip (\(String(format: "%.1f", result.duration))s) από τα Meta Glasses.\(simulationSuffix)",
                source: .glassesClip,
                attachments: [attachment]
            )

            try await mediaReferenceMutationGate.withExclusiveAccess { [self] in
                try await storage.saveEntry(entry)
            }
            journalCommitted = true
            await refreshEntries()

            let obsidianWarning = await exportEntryToObsidianIfConfigured(entry)

            EarconFeedbackService.shared.playEarcon(.clipSaved)

            if result.isPlayable {
                let label = result.isSimulationPlaceholder ? "Simulation Clip" : "Clip"
                showToast(
                    "✂️ Το \(label) (\(String(format: "%.1fs", result.duration))) αποθηκεύτηκε (playable).",
                    obsidianWarning: obsidianWarning
                )
            } else {
                showToast("⚠️ Clip αποθηκεύτηκε αλλά ΔΕΝ είναι playable.", obsidianWarning: obsidianWarning)
            }
        } catch {
            if !journalCommitted, let attachmentForRollback {
                await removeUnreferencedMediaAfterFailedJournalCommit(attachmentForRollback)
            }
            showToast("Αποτυχία clip: \(error.localizedDescription)")
            EarconFeedbackService.shared.playEarcon(.error)
        }
    }

    /// Roll back a clip file if its journal commit failed, even when the caller was canceled
    /// while queued on the mutation gate. The independent task rechecks active references under
    /// the same gate before deleting the file.
    private func removeUnreferencedMediaAfterFailedJournalCommit(_ attachment: MediaAttachment) async {
        let cleanupTask = Task { @MainActor [self] in
            try await mediaReferenceMutationGate.withExclusiveAccess { [self] in
                await katharismosOrphanMedia(afairoumena: [attachment])
            }
        }
        do {
            try await cleanupTask.value
        } catch {
            showToast("Αποτυχία καθαρισμού clip: \(error.localizedDescription)")
        }
    }

    // MARK: - Notes & Composer
    @discardableResult
    public func addNote(text: String, tags: [String] = [], source: EntrySource = .manual) async -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        let detectedTextCues = transcriptKeywordTagger.detectCues(in: text)
        let detectedEntityTags = entityRecognizer.detectEntities(textClues: [text])
        // Order-preserving dedup: caller tags first, then transcript cues, then entity tags.
        var seenTags = Set<String>()
        let mergedTags = (tags + detectedTextCues + detectedEntityTags).filter { seenTags.insert($0).inserted }

        let entry = JournalEntry(
            content: text,
            source: source,
            tags: mergedTags
        )

        do {
            try await storage.saveEntry(entry)
            await refreshEntries()
            let obsidianWarning = await exportEntryToObsidianIfConfigured(entry)
            showToast("✅ Η σημείωση αποθηκεύτηκε.", obsidianWarning: obsidianWarning)
            return true
        } catch {
            showToast("Σφάλμα αποθήκευσης: \(error.localizedDescription)")
            return false
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

    /// Save the latest on-demand vision result only after the user asks.
    public func savePendingVisionNote() async {
        guard !isSavingVisionNote,
              !pendingVisionNoteIsSaved,
              let note = pendingVisionNote,
              let noteID = pendingVisionNoteID else { return }
        isSavingVisionNote = true
        defer { isSavingVisionNote = false }
        let tags = pendingVisionTags
        guard await addNote(text: note, tags: tags, source: .ai) else { return }
        if pendingVisionNoteID == noteID {
            pendingVisionNoteIsSaved = true
        }
    }

    /// Speak the latest on-demand vision result using the existing Greek TTS service.
    public func speakPendingVisionNote() {
        guard let note = pendingVisionNote else { return }
        podcastGenerator.playDailyPodcast(summaryText: note)
        showToast("Η εκφώνηση ξεκίνησε.")
    }

    public func discardPendingVisionNote() {
        pendingVisionNote = nil
        pendingVisionNoteIsSaved = false
        pendingVisionTags = []
        pendingVisionNoteID = nil
    }

    public func sendMessageToAssistant(prompt: String) async {
        chatMessages.append((id: UUID(), isUser: true, text: prompt, timestamp: Date()))

        activeAITask?.cancel()
        let task = Task { @MainActor in
            do {
                try Task.checkCancellation()
                let settings = await aiRouter.currentSettings()
                let memory: AgentMemory?
                if settings.includeAgentMemoryInChat { memory = try await agentManager.loadAgentMemory() }
                else { memory = nil }
                let result = try await aiRouter.askAssistant(
                    prompt: prompt,
                    // Chat context follows the configured newest-journal-entry limit,
                    // independent of the date currently selected in the calendar.
                    contextEntries: allEntries,
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

    /// A11: local-first on-device OCR; cloud vision is an optional description layer.
    public func executeWhatAmISeeing() async {
        guard !(await glassesAdapter.isSimulationMode) else {
            showToast("Η simulation δεν καταγράφει πραγματικές εικόνες για AI ανάλυση.")
            return
        }
        await executeWhatAmISeeing(selectedImage: nil)
    }

    /// A11 fallback: analyze a user-selected Photos image without requiring glasses.
    public func executeWhatAmISeeing(imageData: Data) async {
        guard !imageData.isEmpty else {
            showToast("Η επιλεγμένη φωτογραφία είναι κενή.")
            return
        }
        guard imageData.count <= ImageMetadataSanitizer.maximumVisionInputBytes else {
            showToast("Η εικόνα υπερβαίνει το όριο των 40 MB.")
            return
        }
        await executeWhatAmISeeing(selectedImage: imageData)
    }

    private func executeWhatAmISeeing(selectedImage: Data?) async {
        activeAITask?.cancel()
        pendingNutritionEstimate = nil
        pendingNutritionEstimateIsSaved = false
        let task = Task { @MainActor in
            do {
                try Task.checkCancellation()
                let bufferFrames: [Data]
                if selectedImage == nil {
                    bufferFrames = await bufferService.snapshotVisionKeyframes()
                } else {
                    bufferFrames = []
                }
                let photoForOCR: Data
                let describeWithCloud: @Sendable (Data) async throws -> String
                let router = aiRouter

                if let selectedImage {
                    photoForOCR = selectedImage
                    describeWithCloud = { image in
                        try await router.askWhatAmISeeing(imageData: image, customQuestion: nil)
                    }
                } else if bufferFrames.count >= 2, let lastFrame = bufferFrames.last {
                    photoForOCR = lastFrame
                    let frames = bufferFrames
                    describeWithCloud = { _ in
                        try await router.askWhatAmISeeingMultiFrames(frames: frames, customQuestion: nil)
                    }
                } else if let single = bufferFrames.first {
                    photoForOCR = single
                    describeWithCloud = { image in
                        try await router.askWhatAmISeeing(imageData: image, customQuestion: nil)
                    }
                } else {
                    photoForOCR = try await glassesAdapter.capturePhoto()
                    describeWithCloud = { image in
                        try await router.askWhatAmISeeing(imageData: image, customQuestion: nil)
                    }
                }
                guard !photoForOCR.isEmpty,
                      photoForOCR.count <= ImageMetadataSanitizer.maximumVisionInputBytes else {
                    showToast("Η εικόνα είναι κενή ή υπερβαίνει το όριο των 40 MB.")
                    return
                }

                // Local OCR runs first, so it remains usable if sanitization, credentials,
                // network access, or the vision provider fails.
                let visionService = onDeviceVision
                let outcome = try await OnDeviceVisionAnalysisPipeline.analyze(
                    imageData: photoForOCR,
                    recognizeText: { image in
                        await visionService.recognizeTextFromImage(imageData: image)
                    },
                    prepareForCloud: { image in
                        try Task.checkCancellation()
                        let prepared = try await Task.detached(priority: .userInitiated) {
                            try ImageMetadataSanitizer.encodeForVision(image)
                        }.value
                        try Task.checkCancellation()
                        return prepared
                    },
                    describeWithCloud: describeWithCloud
                )
                try Task.checkCancellation()

                let ocrTokens = outcome.recognizedText
                guard outcome.hasUsableResult else {
                    showToast("Δεν προέκυψε αποτέλεσμα. Η τοπική αναγνώριση δεν βρήκε κείμενο και η περιγραφή AI δεν ήταν διαθέσιμη.")
                    return
                }

                var noteParts: [String] = []
                if let description = outcome.cloudDescription {
                    noteParts.append("👀 Περιγραφή εικόνας: \(description)")
                }
                if !ocrTokens.isEmpty {
                    noteParts.append("🔤 OCR στη συσκευή: \(ocrTokens.joined(separator: ", "))")
                }
                let visionNote = noteParts.joined(separator: "\n")

                let chatText = outcome.cloudDescription.map { "👀 [What am I seeing]: \($0)" }
                    ?? "🔤 [Τοπική αναγνώριση OCR]: \(ocrTokens.joined(separator: ", "))"
                chatMessages.append((id: UUID(), isUser: false, text: chatText, timestamp: Date()))
                pendingVisionNote = visionNote
                pendingVisionNoteIsSaved = false
                pendingVisionTags = ["vision", selectedImage == nil ? "glasses" : "photos"]
                pendingVisionNoteID = UUID()
                prepareMealEstimateForReview(ocrTokens)
                if pendingNutritionEstimate != nil {
                    if outcome.cloudDescription == nil {
                        showToast("Η τοπική OCR ολοκληρώθηκε. Έλεγξε την ενδεικτική εκτίμηση και επιβεβαίωσέ την πριν αποθηκευτεί.")
                    } else {
                        showToast("Η ανάλυση ολοκληρώθηκε. Η ενδεικτική εκτίμηση γεύματος χρειάζεται έλεγχο και επιβεβαίωση πριν αποθηκευτεί.")
                    }
                } else if outcome.cloudDescription == nil {
                    showToast("Η τοπική αναγνώριση ολοκληρώθηκε. Η περιγραφή AI δεν ήταν διαθέσιμη.")
                } else {
                    showToast("Η ανάλυση ολοκληρώθηκε. Το αποτέλεσμα δεν αποθηκεύτηκε ακόμη.")
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
        guard !(await glassesAdapter.isSimulationMode) else {
            showToast("Χρειάζεται πραγματική εικόνα ή εισαγωγή φωτογραφίας για αξιολόγηση.")
            return false
        }
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
            showToast("Το streak δεν αποθηκεύτηκε.")
        }
        return apotelesma.didPersist
    }

    private func syncGamePublishedState(from result: ObservationEvaluationResult) async {
        gameScore = await gameEngine.getScore()
        currentMission = await gameEngine.getCurrentMission()
        gameSessionState = await gameEngine.getSessionState()
        lastGameEvaluation = result
    }

    /// Εξαγωγή Obsidian μετά journal save — fail-closed μήνυμα αν vault configured αλλά export αποτύχει (CQ-P1-012).
    /// A09: conflict → δημοσίευση sidecar paths. Returns the warning so the caller can show it together with
    /// its own success message; a separate toast would be replaced immediately by that success toast.
    @discardableResult
    private func exportEntryToObsidianIfConfigured(
        _ entry: JournalEntry,
        previousEntry: JournalEntry? = nil
    ) async -> String? {
        guard await obsidianBridge.currentVaultURL != nil else { return nil }
        do {
            let outcome: ObsidianSingleExportResult
            if let previousEntry, previousEntry.dateKey != entry.dateKey {
                outcome = try await obsidianBridge.moveEntry(
                    from: previousEntry,
                    to: entry,
                    mediaStorage: mediaStorage
                )
            } else {
                outcome = try await obsidianBridge.exportEntry(entry, mediaStorage: mediaStorage)
            }
            if outcome.hadConflict {
                let sidecar = outcome.conflictSidecarRelativePath ?? "sidecar"
                teleutaiaObsidianConflicts = [sidecar]
                return "⚠️ Obsidian conflict — πρωτότυπο ανέπαφο → \(sidecar)"
            }
            return nil
        } catch {
            return "⚠️ Journal OK· Obsidian: \(error.localizedDescription)"
        }
    }

    /// Shows a success message together with any Obsidian export warning in one toast.
    private func showToast(_ message: String, obsidianWarning: String?) {
        guard let obsidianWarning else {
            showToast(message)
            return
        }
        showToast("\(message)\n\(obsidianWarning)")
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
            configureObsidianVaultWatcher(url: url, requiresScopedAccess: true)
            showToast("Obsidian vault συνδέθηκε: \(url.lastPathComponent)")
        } catch {
            showToast("Σφάλμα vault bookmark: \(error.localizedDescription)")
        }
    }

    /// A15: δημιουργία πλήρους backup bundle (entries + media + agent memory).
    public func dimiourgia_backup_bundle() async {
        do {
            let backupURL = try await backupEngine.createBackupBundle()
            pendingBackupExportURL = backupURL
        } catch {
            showToast(AppErrorTaxonomy.minimaXristi(gia: error))
        }
    }

    public func finishBackupExport(didExport: Bool) {
        guard let backupURL = pendingBackupExportURL else { return }
        if didExport {
            showToast("Το backup αντιγράφηκε στον επιλεγμένο προορισμό.")
        } else {
            showToast("Η εξαγωγή backup ακυρώθηκε.")
        }
        try? FileManager.default.removeItem(at: backupURL)
        pendingBackupExportURL = nil
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
        } catch is CancellationError {
            showToast("Η επαναφορά ακυρώθηκε πριν ξεκινήσει.")
        } catch {
            showToast(AppErrorTaxonomy.minimaXristi(gia: error))
        }
    }

    /// Επαναφορά στο default Documents/R0lling/ObsidianVault.
    public func epanekkinisi_proepilegmenou_obsidian_vault() async {
        VaultBookmarkStore.epanekkinisi_proepilegmenou()
        let defaultURL = defaultObsidianVaultURL()
        await obsidianBridge.setVaultURL(defaultURL, requiresScopedAccess: false)
        await agentManager.setVaultURL(defaultURL)
        obsidianVaultDisplayPath = VaultBookmarkStore.display_path_i_default()
        configureObsidianVaultWatcher(url: defaultURL, requiresScopedAccess: false)
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
                configureObsidianVaultWatcher(
                    url: resolved.url,
                    requiresScopedAccess: resolved.requiresScopedAccess
                )
            } else {
                let defaultURL = defaultObsidianVaultURL()
                await obsidianBridge.setVaultURL(defaultURL, requiresScopedAccess: false)
                await agentManager.setVaultURL(defaultURL)
                obsidianVaultDisplayPath = VaultBookmarkStore.display_path_i_default()
                configureObsidianVaultWatcher(url: defaultURL, requiresScopedAccess: false)
            }
        } catch {
            let defaultURL = defaultObsidianVaultURL()
            await obsidianBridge.setVaultURL(defaultURL, requiresScopedAccess: false)
            await agentManager.setVaultURL(defaultURL)
            obsidianVaultDisplayPath = VaultBookmarkStore.display_path_i_default()
            configureObsidianVaultWatcher(url: defaultURL, requiresScopedAccess: false)
            showToast("Obsidian bookmark stale — χρησιμοποίησε ξανά Files picker.")
        }
    }

    private func defaultObsidianVaultURL() -> URL {
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return docs.appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
    }

    /// Watches only root-folder activity and reports a status hint; vault import/export stays explicit.
    private func configureObsidianVaultWatcher(url: URL, requiresScopedAccess: Bool) {
        stopObsidianVaultWatcher()
        obsidianVaultChangeDetected = false
        obsidianVaultWatcherError = nil

        if !requiresScopedAccess {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                obsidianVaultWatcherError = error.localizedDescription
                return
            }
        } else {
            guard url.startAccessingSecurityScopedResource() else {
                obsidianVaultWatcherError = "Δεν ήταν δυνατή η διατήρηση της πρόσβασης Files στο επιλεγμένο vault."
                return
            }
            obsidianWatcherScopedURL = url
        }

        do {
            try obsidianFileWatcher.startWatching(
                directoryURL: url,
                onFileChanged: { [weak self] changedDirectory in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        guard FileManager.default.fileExists(atPath: changedDirectory.path) else {
                            self.stopObsidianVaultWatcher()
                            self.obsidianVaultWatcherError = "Ο φάκελος vault μετακινήθηκε ή αφαιρέθηκε. Επίλεξέ τον ξανά από τα Files."
                            return
                        }
                        self.obsidianVaultChangeDetected = true
                    }
                },
                onError: { [weak self] message in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.stopObsidianVaultWatcher()
                        self.obsidianVaultWatcherError = "Η παρακολούθηση σταμάτησε μετά από σφάλμα: \(message)"
                    }
                }
            )
            isObsidianVaultWatcherActive = true
        } catch {
            if let scopedURL = obsidianWatcherScopedURL {
                scopedURL.stopAccessingSecurityScopedResource()
                obsidianWatcherScopedURL = nil
            }
            obsidianVaultWatcherError = error.localizedDescription
        }
    }

    private func stopObsidianVaultWatcher() {
        obsidianFileWatcher.stopWatching()
        if let scopedURL = obsidianWatcherScopedURL {
            scopedURL.stopAccessingSecurityScopedResource()
            obsidianWatcherScopedURL = nil
        }
        isObsidianVaultWatcherActive = false
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
        // Acoustic / IMU triggers stay fail-closed: the sink is wired, but the current
        // adapter only simulates sensor values and has no live DAT microphone/IMU source.
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

        guard FeatureReadinessRegistry.watchCompanion.ready else { return }
        // Companion callbacks are disabled until a watchOS target is integrated.
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
        var attachmentForRollback: MediaAttachment?
        var journalCommitted = false
        do {
            let reel = try await highlightMuxer.createDailyHighlightReel(for: todayEntries)
            attachmentForRollback = reel.attachment
            guard reel.isPlayable else {
                throw NSError(domain: "R0lling.HighlightReel", code: 3114, userInfo: [
                    NSLocalizedDescriptionKey: "Το Highlight Reel δεν επιβεβαιώθηκε ως playable."
                ])
            }
            let entry = try await HighlightReelJournalCommitter.commit(
                attachment: reel.attachment,
                clipCount: reel.totalClipsIncluded,
                durationSeconds: reel.totalDurationSeconds,
                storage: storage,
                mutationGate: mediaReferenceMutationGate
            )
            journalCommitted = true
            await refreshEntries()
            let obsidianWarning = await exportEntryToObsidianIfConfigured(entry)
            showToast(
                "🎬 Highlight Reel (\(reel.totalClipsIncluded) clips, \(Int(reel.totalDurationSeconds))s) αποθηκεύτηκε στο journal και είναι playable.",
                obsidianWarning: obsidianWarning
            )
        } catch {
            if !journalCommitted, let attachmentForRollback {
                await removeUnreferencedMediaAfterFailedJournalCommit(attachmentForRollback)
            }
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
            title: "Σύνοψη \(selectedDate.formattedGreekHeader())"
        )
        guard await obsidianBridge.currentVaultURL != nil else {
            showToast("Σφάλμα Canvas: δεν έχει οριστεί Obsidian vault.")
            return
        }
        do {
            let writtenURL = try await obsidianBridge.grapse_arxeio_sto_vault(
                relativePath: "Weekly-Canvas.canvas",
                contents: canvasJSON
            )
            if writtenURL.lastPathComponent == "Weekly-Canvas.canvas" {
                showToast("🎨 Obsidian Canvas εξήχθη επιτυχώς!")
            } else {
                // The bridge never overwrites an existing different file; report the sidecar honestly.
                teleutaiaObsidianConflicts = [writtenURL.lastPathComponent]
                showToast("⚠️ Το Weekly-Canvas.canvas υπήρχε με άλλο περιεχόμενο· το νέο Canvas γράφτηκε στο \(writtenURL.lastPathComponent) χωρίς αντικατάσταση.")
            }
        } catch {
            showToast("Σφάλμα Canvas: \(error.localizedDescription)")
        }
    }

    /// Daily podcast — εμφανίζει σφάλμα αν αποτύχει το summarize (G5-005).
    /// `isDailyPodcastActive` covers both preparing the summary and speaking it, so the UI can offer stop.
    public func playDailyPodcast() async {
        guard FeatureReadinessRegistry.podcast.ready else {
            showToast("Podcast απενεργοποιημένο.")
            return
        }
        guard !isDailyPodcastActive else { return }
        isDailyPodcastActive = true
        dailyPodcastGeneration &+= 1
        let generation = dailyPodcastGeneration
        let entries = todayEntries
        do {
            let summary = try await aiRouter.summarizeDay(entries: entries)
            // Stopped while the summary was being prepared: do not start speaking afterwards.
            guard generation == dailyPodcastGeneration else { return }
            guard !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                isDailyPodcastActive = false
                showToast("Σφάλμα Podcast: η σύνοψη επέστρεψε κενή.")
                return
            }
            podcastGenerator.playDailyPodcast(summaryText: summary) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.dailyPodcastGeneration == generation else { return }
                    self.isDailyPodcastActive = false
                }
            }
            showToast("🎙️ Αναπαραγωγή Daily Podcast..." + daySummaryCoverageNote(entryCount: entries.count))
        } catch {
            guard generation == dailyPodcastGeneration else { return }
            isDailyPodcastActive = false
            showToast("Σφάλμα Podcast: \(error.localizedDescription)")
        }
    }

    public func stopDailyPodcast() {
        dailyPodcastGeneration &+= 1
        isDailyPodcastActive = false
        podcastGenerator.stopPodcast()
    }

    /// Day summaries send only the newest `OpenAIChatRequestBuilder.maxContextEntries` entries to the
    /// AI provider; disclose that when the selected day has more, instead of implying full coverage.
    func daySummaryCoverageNote(entryCount: Int) -> String {
        let limit = OpenAIChatRequestBuilder.maxContextEntries
        guard entryCount > limit else { return "" }
        return "\nΗ σύνοψη βασίζεται στις \(limit) πιο πρόσφατες από τις \(entryCount) καταγραφές της ημέρας."
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
        let currentTriples = todayEntries.flatMap { entry in
            knowledgeGraphEngine.extractTriples(from: entry.content, date: entry.timestamp)
        }
        knowledgeGraphEngine.replaceTriples(currentTriples)
        let tripleCount = knowledgeGraphEngine.allTriples.count
        guard tripleCount > 0 else {
            showToast("Knowledge Graph: καμία σχέση από τις καταγραφές της ημέρας.")
            return
        }
        let mermaidGraph = knowledgeGraphEngine.exportMermaidGraph()
        guard await obsidianBridge.currentVaultURL != nil else {
            showToast("Σφάλμα Graph: δεν έχει οριστεί Obsidian vault.")
            return
        }
        let doc = "# 🧠 Associative Knowledge Graph\n\n\(mermaidGraph)"
        do {
            let writtenURL = try await obsidianBridge.grapse_arxeio_sto_vault(
                relativePath: "Knowledge-Graph.md",
                contents: doc
            )
            if writtenURL.lastPathComponent == "Knowledge-Graph.md" {
                showToast("🧠 Knowledge Graph (\(tripleCount) triples) εξήχθη στο Obsidian.")
            } else {
                // The bridge never overwrites an existing different file; report the sidecar honestly.
                teleutaiaObsidianConflicts = [writtenURL.lastPathComponent]
                showToast("⚠️ Το Knowledge-Graph.md υπήρχε με άλλο περιεχόμενο· το νέο Graph γράφτηκε στο \(writtenURL.lastPathComponent) χωρίς αντικατάσταση.")
            }
        } catch {
            showToast("Σφάλμα εξαγωγής Graph: \(error.localizedDescription)")
        }
    }

    /// Prepare a review-only estimate from actual OCR text; analysis never writes to the journal.
    private func prepareMealEstimateForReview(_ tokens: [String]) {
        guard FeatureReadinessRegistry.nutritionHeuristic.ready else {
            pendingNutritionEstimate = nil
            pendingNutritionEstimateIsSaved = false
            return
        }
        pendingNutritionEstimate = nutritionLogger.analyzeDetectedFoodTokens(tokens: tokens)
        pendingNutritionEstimateIsSaved = false
    }

    /// Persist an OCR-based estimate only after the user presses the explicit save action.
    public func savePendingNutritionEstimate() async {
        guard !isSavingNutritionEstimate,
              !pendingNutritionEstimateIsSaved,
              let snapshot = pendingNutritionEstimate else { return }

        isSavingNutritionEstimate = true
        defer { isSavingNutritionEstimate = false }

        let estimateID = snapshot.id
        let entry = JournalEntry(
            timestamp: snapshot.timestamp,
            content: nutritionLogger.formatObsidianMarkdown(snapshot: snapshot),
            source: .ai,
            tags: ["meal", "nutrition", "heuristic", "ocr"]
        )
        do {
            try await storage.saveEntry(entry)
            if pendingNutritionEstimate?.id == estimateID {
                pendingNutritionEstimateIsSaved = true
            }
            await refreshEntries()
            let obsidianWarning = await exportEntryToObsidianIfConfigured(entry)
            showToast(
                "Η ενδεικτική εκτίμηση γεύματος αποθηκεύτηκε (~\(Int(snapshot.totalCalories)) kcal).",
                obsidianWarning: obsidianWarning
            )
        } catch {
            showToast("Σφάλμα καταγραφής γεύματος: \(error.localizedDescription)")
        }
    }

    public func discardPendingNutritionEstimate() {
        guard !isSavingNutritionEstimate else { return }
        pendingNutritionEstimate = nil
        pendingNutritionEstimateIsSaved = false
    }

    // MARK: - Journal CRUD (A01 / A02)

    /// Διαγραφή καταγραφής + orphan media μόνο αν δεν αναφέρεται αλλού.
    public func deleteEntry(id: UUID) async {
        do {
            try await mediaReferenceMutationGate.withExclusiveAccess { [self] in
                do {
                    guard let entry = try await storage.getEntry(id: id) else {
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
        } catch is CancellationError {
            return
        } catch {
            showToast("Σφάλμα διαγραφής: \(error.localizedDescription)")
        }
    }

    /// Εναλλαγή αγαπημένου — αποτυχία → toast, όχι silent UI lie.
    public func toggleFavorite(entry: JournalEntry) async {
        do {
            try await mediaReferenceMutationGate.withExclusiveAccess { [self] in
                guard var current = try await storage.getEntry(id: entry.id) else {
                    showToast("Η καταγραφή δεν βρέθηκε.")
                    return
                }
                current.isFavorite.toggle()
                current.lastModified = Date()
                guard try await storage.updateEntryIfPresent(current) else {
                    showToast("Η καταγραφή δεν βρέθηκε.")
                    return
                }
            }
            await refreshEntries()
        } catch {
            showToast("Σφάλμα αγαπημένου: \(error.localizedDescription)")
        }
    }

    /// A02: επεξεργασία με σταθερό ID (overwrite, χωρίς διπλότυπο).
    public func updateEntry(_ entry: JournalEntry) async {
        do {
            let (previous, updated): (JournalEntry, JournalEntry) = try await mediaReferenceMutationGate.withExclusiveAccess { [self] in
                guard var current = try await storage.getEntry(id: entry.id) else {
                    throw NSError(domain: "R0lling.Journal", code: 404, userInfo: [
                        NSLocalizedDescriptionKey: "Η καταγραφή δεν βρέθηκε και δεν ενημερώθηκε."
                    ])
                }
                let previous = current
                // Merge editable fields into the current row so a stale sheet cannot
                // overwrite a newer favorite, source, or attachment list.
                current.timestamp = entry.timestamp
                current.timeZoneIdentifier = entry.timeZoneIdentifier
                current.title = entry.title
                current.content = entry.content
                current.tags = entry.tags
                current.locationName = entry.locationName
                current.lastModified = Date()
                guard try await storage.updateEntryIfPresent(current) else {
                    throw NSError(domain: "R0lling.Journal", code: 404, userInfo: [
                        NSLocalizedDescriptionKey: "Η καταγραφή διαγράφηκε πριν ολοκληρωθεί η ενημέρωση."
                    ])
                }
                return (previous, current)
            }
            await refreshEntries()
            let obsidianWarning = await exportEntryToObsidianIfConfigured(updated, previousEntry: previous)
            showToast("✅ Η καταγραφή ενημερώθηκε.", obsidianWarning: obsidianWarning)
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
        do {
            let change: (previous: JournalEntry, updated: JournalEntry)? = try await mediaReferenceMutationGate.withExclusiveAccess { [self] in
                guard var current = try await storage.getEntry(id: id) else { return nil }
                let previous = current
                current.timestamp = newTimestamp
                if let timeZoneIdentifier {
                    let trimmed = timeZoneIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        current.timeZoneIdentifier = trimmed
                    }
                }
                current.lastModified = Date()
                guard try await storage.updateEntryIfPresent(current) else { return nil }
                return (previous, current)
            }
            guard let change else {
                showToast("Η καταγραφή δεν βρέθηκε.")
                return
            }
            let sameIdCount = try await storage.getAllEntries().filter { $0.id == id }.count
            guard sameIdCount == 1 else {
                showToast("Σφάλμα ακεραιότητας: διπλότυπο ID μετά από διόρθωση ημερομηνίας.")
                return
            }
            await refreshEntries()
            let obsidianWarning = await exportEntryToObsidianIfConfigured(change.updated, previousEntry: change.previous)
            let entry = change.updated
            showToast("✅ Ημερομηνία → \(entry.dateKey)", obsidianWarning: obsidianWarning)
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
        do {
            return try await storage.searchEntries(query: query, tag: tag, source: source)
        } catch {
            showToast(error.localizedDescription)
            return []
        }
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
            try await persistMediaAttachment(attachment, toEntryId: toEntryId, noteText: noteText)
        } catch {
            showToast("Σφάλμα media: \(error.localizedDescription)")
        }
    }

    /// File-backed path for Photos/Files imports; avoids loading large assets into Data.
    public func attachMediaFile(
        from sourceURL: URL,
        originalFilename: String,
        mediaType: MediaType,
        toEntryId: UUID? = nil,
        noteText: String? = nil
    ) async {
        do {
            let attachment = try await mediaStorage.saveMediaFile(
                from: sourceURL,
                originalFilename: originalFilename,
                mediaType: mediaType
            )
            try await persistMediaAttachment(attachment, toEntryId: toEntryId, noteText: noteText)
        } catch {
            showToast("Σφάλμα media: \(error.localizedDescription)")
        }
    }

    private func persistMediaAttachment(
        _ attachment: MediaAttachment,
        toEntryId: UUID?,
        noteText: String?
    ) async throws {
        var journalCommitted = false
        do {
            if let toEntryId {
                let entry: JournalEntry? = try await mediaReferenceMutationGate.withExclusiveAccess { [self] in
                    try await storage.appendAttachmentIfPresent(attachment, toEntryID: toEntryId)
                }
                if let entry {
                    journalCommitted = true
                    await refreshEntries()
                    let obsidianWarning = await exportEntryToObsidianIfConfigured(entry)
                    showToast("✅ Media επισυνάφθηκε στην καταγραφή.", obsidianWarning: obsidianWarning)
                    return
                }
                throw NSError(domain: "R0lling.Journal", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Η καταγραφή δεν βρέθηκε· το media δεν επισυνάφθηκε."
                ])
            }

            let content = (noteText?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
                $0.isEmpty ? nil : $0
            } ?? JournalMediaImporter.proepiloghmenoKeimeno(gia: attachment.mediaType)

            let entry = JournalEntry(
                content: content,
                source: .importFile,
                tags: [attachment.mediaType.rawValue],
                attachments: [attachment]
            )
            try await mediaReferenceMutationGate.withExclusiveAccess {
                try await storage.saveEntry(entry)
            }
            journalCommitted = true
            await refreshEntries()
            let obsidianWarning = await exportEntryToObsidianIfConfigured(entry)
            showToast("✅ \(attachment.mediaType.folderName) αποθηκεύτηκε τοπικά.", obsidianWarning: obsidianWarning)
        } catch {
            if !journalCommitted {
                try? await mediaStorage.deleteMediaFile(relativePath: attachment.relativePath)
            }
            throw error
        }
    }

    /// Ανάλυση relative path σε sandbox URL (για previews) — `nil` σε fail, χωρίς crash.
    public func resolveMediaURL(relativePath: String) async -> URL? {
        do {
            return try mediaStorage.getMediaFileURL(relativePath: relativePath)
        } catch {
            return nil
        }
    }

    /// Σβήνει μόνο attachments που δεν αναφέρονται πλέον από καμία καταγραφή.
    private func katharismosOrphanMedia(afairoumena: [MediaAttachment]) async {
        do {
            let all = try await storage.getAllEntries()
            let activePaths = Set(all.flatMap { $0.attachments.map(\.relativePath) })
            for att in afairoumena where !activePaths.contains(att.relativePath) {
                do {
                    try await mediaStorage.deleteMediaFile(relativePath: att.relativePath)
                } catch {
                    showToast("Orphan media: \(error.localizedDescription)")
                }
            }
        } catch {
            showToast(error.localizedDescription)
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
        toastDismissalTask?.cancel()
        self.toastMessage = message
        toastDismissalTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 2_500_000_000)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            self.toastMessage = nil
            self.toastDismissalTask = nil
        }
    }
}

// MARK: - GlassesSensorFeedSink (simulation sink; no live DAT sensor source is available)
extension AppState: GlassesSensorFeedSink {
    /// Receives dBFS values from the adapter; current app builds only provide simulation values.
    /// Auto-clip μόνο όταν `FeatureReadinessRegistry.acoustic.ready == true`.
    public nonisolated func receiveAcousticLevel(decibels: Float) {
        Task { @MainActor in
            self.acousticTrigger.processAudioLevel(decibels: decibels)
        }
    }

    /// Receives IMU values from the adapter; current app builds only provide simulation values.
    /// Auto-clip μόνο όταν `FeatureReadinessRegistry.headGesture.ready == true`.
    public nonisolated func receiveIMUSample(_ sample: HeadGestureDetector.IMUSample) {
        Task { @MainActor in
            self.gestureDetector.feedIMUSample(sample)
        }
    }
}
