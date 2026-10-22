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
    public let originEntryId: UUID?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        originEntryId: UUID? = nil,
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

    public func parseTasks(from stream: String, originId: UUID? = nil) -> [ChiefOfStaffTask] {
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

// MARK: - [13] Cognitive Deep Work Sentinel

public enum DeepWorkSessionTiming {
    public static let defaultDurationMinutes = 25
    public static let defaultDurationSeconds = TimeInterval(defaultDurationMinutes * 60)
}

public actor DeepWorkSessionManager {
    public enum SessionState: Codable, Sendable, Equatable {
        case idle
        case active(startedAt: Date, durationSeconds: TimeInterval, goal: String)
        case paused(elapsedSeconds: TimeInterval, goal: String)
        case completed(durationSeconds: TimeInterval, goal: String, debrief: String?)
    }

    private struct CompletedSession: Codable, Sendable {
        let startedAt: Date
        let completedAt: Date
        let durationSeconds: TimeInterval
    }

    private struct PersistedState: Codable {
        let sessionState: SessionState
        let completedSessions: [CompletedSession]
    }

    private let storageKey: String
    private var state: SessionState
    private var completedSessions: [CompletedSession]
    private var persistenceWritesBlocked: Bool

    public init(storageKey: String = "r0lling.deepWork.session.v1") {
        self.storageKey = storageKey
        if let storedValue = UserDefaults.standard.object(forKey: storageKey) {
            guard let data = storedValue as? Data else {
                self.state = .idle
                self.completedSessions = []
                self.persistenceWritesBlocked = true
                return
            }

            if let persisted = try? JSONDecoder().decode(PersistedState.self, from: data) {
                self.state = persisted.sessionState
                self.completedSessions = persisted.completedSessions
                self.persistenceWritesBlocked = false
            } else if let legacyState = try? JSONDecoder().decode(SessionState.self, from: data) {
                // Migrate the previous single-session payload without treating an undated
                // legacy completion as focus performed today.
                self.state = legacyState
                self.completedSessions = []
                self.persistenceWritesBlocked = false
            } else {
                self.state = .idle
                self.completedSessions = []
                self.persistenceWritesBlocked = true
            }
        } else {
            self.state = .idle
            self.completedSessions = []
            self.persistenceWritesBlocked = false
        }
    }

    /// True when saved state exists but could not be decoded; mutations remain blocked
    /// until the caller explicitly discards the corrupt value through the reset API.
    public var requiresPersistenceRecovery: Bool {
        persistenceWritesBlocked
    }

    /// Explicitly discard unreadable persisted state and resume with an empty session.
    /// Returns false when there is no blocked corrupt value or removal did not take effect.
    @discardableResult
    public func discardCorruptPersistenceAndReset() -> Bool {
        guard persistenceWritesBlocked else { return false }
        UserDefaults.standard.removeObject(forKey: storageKey)
        guard UserDefaults.standard.object(forKey: storageKey) == nil else { return false }

        state = .idle
        completedSessions = []
        persistenceWritesBlocked = false
        return true
    }

    public func startSession(goal: String, durationMinutes: Int = DeepWorkSessionTiming.defaultDurationMinutes) {
        startSession(goal: goal, durationMinutes: durationMinutes, startedAt: Date())
    }

    func startSession(goal: String, durationMinutes: Int, startedAt: Date) {
        guard !persistenceWritesBlocked else { return }
        let cleanGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard durationMinutes > 0, !cleanGoal.isEmpty, startedAt.timeIntervalSince1970.isFinite else { return }
        let duration = TimeInterval(durationMinutes) * 60
        state = .active(startedAt: startedAt, durationSeconds: duration, goal: cleanGoal)
        persistState()
    }

    public func completeSession(debrief: String? = nil) -> TimeInterval {
        guard !persistenceWritesBlocked else { return 0 }
        switch state {
        case .active(let startedAt, let duration, let goal):
            let completedAt = Date()
            let elapsed = min(duration, max(0, completedAt.timeIntervalSince(startedAt)))
            state = .completed(durationSeconds: elapsed, goal: goal, debrief: debrief)
            completedSessions.append(CompletedSession(
                startedAt: startedAt,
                completedAt: completedAt,
                durationSeconds: elapsed
            ))
            persistState()
            return elapsed
        case .paused(let elapsed, let goal):
            let completedAt = Date()
            state = .completed(durationSeconds: elapsed, goal: goal, debrief: debrief)
            completedSessions.append(CompletedSession(
                startedAt: completedAt.addingTimeInterval(-max(0, elapsed)),
                completedAt: completedAt,
                durationSeconds: max(0, elapsed)
            ))
            persistState()
            return elapsed
        default:
            return 0
        }
    }

    public func getState() -> SessionState {
        getState(at: Date())
    }

    func getState(at now: Date) -> SessionState {
        if case .active(let startedAt, let duration, let goal) = state,
           now >= startedAt.addingTimeInterval(max(0, duration)) {
            let completedAt = startedAt.addingTimeInterval(max(0, duration))
            let elapsed = max(0, duration)
            state = .completed(durationSeconds: elapsed, goal: goal, debrief: nil)
            completedSessions.append(CompletedSession(
                startedAt: startedAt,
                completedAt: completedAt,
                durationSeconds: elapsed
            ))
            persistState()
        }
        return state
    }

    /// Returns completed and currently active focus time overlapping the requested local day.
    public func focusSeconds(on date: Date = Date(), includeActiveSession: Bool = true) -> TimeInterval {
        _ = getState(at: date)
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }

        let completedSeconds = completedSessions.reduce(0.0) { total, session in
            let overlapStart = max(session.startedAt, dayStart)
            let overlapEnd = min(session.completedAt, nextDay)
            let overlap = max(0, overlapEnd.timeIntervalSince(overlapStart))
            return total + min(max(0, session.durationSeconds), overlap)
        }

        guard includeActiveSession, case .active(let startedAt, let duration, _) = state else {
            return completedSeconds
        }
        let activeEnd = min(date, startedAt.addingTimeInterval(max(0, duration)))
        let activeStart = max(startedAt, dayStart)
        let activeOverlap = max(0, activeEnd.timeIntervalSince(activeStart))
        return completedSeconds + min(max(0, duration), activeOverlap)
    }

    private func persistState() {
        guard !persistenceWritesBlocked else { return }
        let persisted = PersistedState(sessionState: state, completedSessions: completedSessions)
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
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

// MARK: - [15] Daily Energy & Cognitive Readiness Index

public struct CognitiveTelemetryScore: Codable, Sendable, Equatable {
    public let cognitiveStrain: Double   // 0.0 to 21.0
    public let focusMinutes: Int
    public let readinessPercent: Int?   // nil when there are no journal/focus inputs

    public init(cognitiveStrain: Double, focusMinutes: Int, readinessPercent: Int?) {
        self.cognitiveStrain = cognitiveStrain
        self.focusMinutes = focusMinutes
        self.readinessPercent = readinessPercent
    }

    public func includingActiveFocus(
        deadline: Date?,
        at now: Date,
        completedFocusSeconds: TimeInterval? = nil,
        plannedDurationSeconds: TimeInterval = DeepWorkSessionTiming.defaultDurationSeconds
    ) -> Self {
        guard let deadline, plannedDurationSeconds.isFinite, plannedDurationSeconds > 0 else { return self }
        let sessionStartedAt = deadline.addingTimeInterval(-plannedDurationSeconds)
        let elapsedTodayStart = max(sessionStartedAt, Calendar.current.startOfDay(for: now))
        let elapsedTodayEnd = min(now, deadline)
        let elapsedSeconds = min(
            plannedDurationSeconds,
            max(0, elapsedTodayEnd.timeIntervalSince(elapsedTodayStart))
        )
        let completedSeconds = completedFocusSeconds.flatMap { $0.isFinite ? max(0, $0) : nil } ?? 0
        return Self(
            cognitiveStrain: cognitiveStrain,
            focusMinutes: Int((completedSeconds + elapsedSeconds) / 60),
            readinessPercent: readinessPercent
        )
    }
}

public actor CognitiveReadinessCalculator {
    public init() {}

    public func computeTelemetry(entriesCount: Int, deepWorkSeconds: TimeInterval, vocalStressFactor: Double = 1.0) -> CognitiveTelemetryScore {
        let safeEntriesCount = max(0, entriesCount)
        let maxRepresentableFocusSeconds = Double(Int.max / 2) * 60
        let safeFocusSeconds = deepWorkSeconds.isFinite
            ? min(max(0, deepWorkSeconds), maxRepresentableFocusSeconds)
            : 0
        let safeStressFactor = vocalStressFactor.isFinite ? max(0, vocalStressFactor) : 1
        let hoursOfFocus = safeFocusSeconds / 3600.0
        let rawStrain = (Double(safeEntriesCount) * 1.4) + (hoursOfFocus * 4.2) * safeStressFactor
        let normalizedStrain = min(21.0, max(0.0, rawStrain))
        
        let fatigueReduction = Int(normalizedStrain * 3.8)
        let baseReadiness = 100 - fatigueReduction
        let finalReadiness = safeEntriesCount == 0 && safeFocusSeconds == 0
            ? nil
            : max(15, min(100, baseReadiness))

        return CognitiveTelemetryScore(
            cognitiveStrain: (normalizedStrain * 10).rounded() / 10,
            focusMinutes: Int(safeFocusSeconds / 60),
            readinessPercent: finalReadiness
        )
    }
}

// MARK: - [21] UI-Gated Local Diary

public actor BiometricSecurityManager {
    public init() {}

    public func canAuthenticate() -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        #else
        return false
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
        return false
        #endif
    }
}

// MARK: - [37] Ambient Soundscape & Binaural Focus Synthesizer

public actor BinauralFocusSynthesizer {
    public enum BeatType: String, CaseIterable, Hashable, Sendable {
        case gamma40Hz = "Gamma · 40 Hz"
        case beta20Hz = "Beta · 20 Hz"
        case alpha10Hz = "Alpha · 10 Hz"
        case theta6Hz = "Theta · 6 Hz"

        public var beatFrequencyHz: Double {
            switch self {
            case .gamma40Hz: 40
            case .beta20Hz: 20
            case .alpha10Hz: 10
            case .theta6Hz: 6
            }
        }

        public var leftChannelFrequencyHz: Double { 200 - beatFrequencyHz / 2 }
        public var rightChannelFrequencyHz: Double { 200 + beatFrequencyHz / 2 }
    }

    private var currentBeat: BeatType = .gamma40Hz
    private var isPlaying = false

#if canImport(AVFoundation)
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
#endif

#if os(iOS)
    private struct PreviousAudioSessionConfiguration {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
    }

    private var previousAudioSessionConfiguration: PreviousAudioSessionConfiguration?
#endif

    public init() {}

#if canImport(AVFoundation)
    public enum PlaybackError: Error, LocalizedError, Sendable {
        case audioUnavailable
        case audioFormatUnavailable

        public var errorDescription: String? {
            switch self {
            case .audioUnavailable:
                "Η έξοδος ήχου δεν είναι διαθέσιμη σε αυτή τη συσκευή."
            case .audioFormatUnavailable:
                "Δεν ήταν δυνατή η δημιουργία στερεοφωνικής μορφής ήχου."
            }
        }
    }
#else
    public enum PlaybackError: Error, LocalizedError, Sendable {
        case audioUnavailable
        case audioFormatUnavailable

        public var errorDescription: String? {
            "Η έξοδος ήχου δεν είναι διαθέσιμη σε αυτή τη συσκευή."
        }
    }
#endif

    public func setBeat(_ beat: BeatType) throws {
#if canImport(AVFoundation)
        if isPlaying {
            guard let playerNode else { throw PlaybackError.audioUnavailable }
            let buffer = try Self.makeToneBuffer(for: beat)
            playerNode.stop()
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            playerNode.play()
        }
#endif
        self.currentBeat = beat
    }

    public func startPlayback() throws {
#if canImport(AVFoundation)
        guard !isPlaying else { return }
        try configureAudioSession()
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        do {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2) else {
                throw PlaybackError.audioFormatUnavailable
            }
            let buffer = try Self.makeToneBuffer(for: currentBeat, format: format)
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            engine.prepare()
            try engine.start()
            player.play()
            audioEngine = engine
            playerNode = player
            isPlaying = true
        } catch {
            player.stop()
            engine.stop()
            try? restoreAudioSession()
            throw error
        }
#else
        throw PlaybackError.audioUnavailable
#endif
    }

    public func stopPlayback() throws {
#if canImport(AVFoundation)
        playerNode?.stop()
        audioEngine?.stop()
        playerNode = nil
        audioEngine = nil
#endif
        isPlaying = false
#if os(iOS) && canImport(AVFoundation)
        try restoreAudioSession()
#endif
    }

    public func getStatus() -> (isPlaying: Bool, currentBeat: BeatType) {
        (isPlaying, currentBeat)
    }

#if canImport(AVFoundation)
    private static func makeToneBuffer(
        for beat: BeatType,
        format: AVAudioFormat? = nil
    ) throws -> AVAudioPCMBuffer {
        guard let outputFormat = format ?? AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 48_000),
              let channels = buffer.floatChannelData else {
            throw PlaybackError.audioFormatUnavailable
        }

        buffer.frameLength = 48_000
        let sampleRate = outputFormat.sampleRate
        let sampleCount = Int(buffer.frameLength)
        let amplitude = Float(0.12)
        for index in 0..<sampleCount {
            let time = Double(index) / sampleRate
            channels[0][index] = Float(sin(2 * Double.pi * beat.leftChannelFrequencyHz * time)) * amplitude
            channels[1][index] = Float(sin(2 * Double.pi * beat.rightChannelFrequencyHz * time)) * amplitude
        }
        return buffer
    }

    private func configureAudioSession() throws {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        previousAudioSessionConfiguration = PreviousAudioSessionConfiguration(
            category: session.category,
            mode: session.mode,
            options: session.categoryOptions
        )
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            try? restoreAudioSession()
            throw error
        }
#endif
    }

    private func restoreAudioSession() throws {
#if os(iOS)
        guard let previousAudioSessionConfiguration else { return }
        try AVAudioSession.sharedInstance().setCategory(
            previousAudioSessionConfiguration.category,
            mode: previousAudioSessionConfiguration.mode,
            options: previousAudioSessionConfiguration.options
        )
        self.previousAudioSessionConfiguration = nil
#endif
    }
#endif
}

// MARK: - [41] Biometric HealthKit Telemetry Correlation

/// Provenance for a returned sample; it records sample time and HealthKit source.
public struct HealthKitReadingMetadata: Codable, Sendable, Equatable {
    public let measuredAt: Date
    public let sourceName: String

    public init(measuredAt: Date, sourceName: String) {
        self.measuredAt = measuredAt
        self.sourceName = sourceName
    }
}

/// Optional readings: nil means unavailable, denied, or a query failure.
public struct HealthKitTelemetrySnapshot: Codable, Sendable, Equatable {
    public let hrvMs: Double?
    public let hrvMetadata: HealthKitReadingMetadata?
    public let restingHRBpm: Int?
    public let restingHRMetadata: HealthKitReadingMetadata?
    public let respiratoryRate: Double?
    public let respiratoryRateMetadata: HealthKitReadingMetadata?
    public let bloodOxygenPercent: Double?
    public let bloodOxygenMetadata: HealthKitReadingMetadata?
    public let bodyTemperatureCelsius: Double?
    public let bodyTemperatureMetadata: HealthKitReadingMetadata?
    public let recoveryScore: Int?
    public let sleepHours: Double?
    public let sleepReport: SleepReportSnapshot?
    /// `true` only when the latest sleep-stage HealthKit query failed; `false` means it succeeded.
    public let sleepQueryFailed: Bool?
    public let sleepMetadata: HealthKitReadingMetadata?
    public let queriedAt: Date

    public init(hrvMs: Double? = nil, restingHRBpm: Int? = nil,
                respiratoryRate: Double? = nil, bloodOxygenPercent: Double? = nil,
                recoveryScore: Int? = nil, sleepHours: Double? = nil,
                sleepReport: SleepReportSnapshot? = nil,
                sleepQueryFailed: Bool? = nil,
                bodyTemperatureCelsius: Double? = nil,
                hrvMetadata: HealthKitReadingMetadata? = nil,
                restingHRMetadata: HealthKitReadingMetadata? = nil,
                respiratoryRateMetadata: HealthKitReadingMetadata? = nil,
                bloodOxygenMetadata: HealthKitReadingMetadata? = nil,
                bodyTemperatureMetadata: HealthKitReadingMetadata? = nil,
                sleepMetadata: HealthKitReadingMetadata? = nil,
                queriedAt: Date = Date()) {
        self.hrvMs = hrvMs
        self.hrvMetadata = hrvMetadata
        self.restingHRBpm = restingHRBpm
        self.restingHRMetadata = restingHRMetadata
        self.respiratoryRate = respiratoryRate
        self.respiratoryRateMetadata = respiratoryRateMetadata
        self.bloodOxygenPercent = bloodOxygenPercent
        self.bloodOxygenMetadata = bloodOxygenMetadata
        self.bodyTemperatureCelsius = bodyTemperatureCelsius
        self.bodyTemperatureMetadata = bodyTemperatureMetadata
        self.recoveryScore = recoveryScore
        self.sleepHours = sleepHours
        self.sleepReport = sleepReport
        self.sleepQueryFailed = sleepQueryFailed
        self.sleepMetadata = sleepMetadata
        self.queriedAt = queriedAt
    }

    public var hasReadings: Bool {
        hrvMs != nil || restingHRBpm != nil || respiratoryRate != nil
            || bloodOxygenPercent != nil || bodyTemperatureCelsius != nil || sleepHours != nil
            || sleepReport != nil
    }
}
