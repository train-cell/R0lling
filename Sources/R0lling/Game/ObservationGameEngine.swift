import Foundation

/// Πηγή αξιολόγησης — ειλικρίνεια UI (A14): manual ≠ AI.
public enum ObservationEvaluationSource: String, Codable, Sendable, Equatable {
    case aiVision
    case manual
    case unavailable
}

/// Αποτέλεσμα αξιολόγησης αποστολής (fail-closed scoring).
public struct ObservationEvaluationResult: Sendable, Equatable {
    public let success: Bool
    public let feedback: String
    public let source: ObservationEvaluationSource
    public let awardedPoints: Int

    public init(
        success: Bool,
        feedback: String,
        source: ObservationEvaluationSource,
        awardedPoints: Int
    ) {
        self.success = success
        self.feedback = feedback
        self.source = source
        self.awardedPoints = awardedPoints
    }
}

/// Κατάσταση συνόδου παιχνιδιού παρατήρησης.
public enum ObservationGameSessionState: Sendable, Equatable {
    case idle
    case active
    case evaluating
    case completed
    case failed
}

/// Small seam for deterministic game evaluation tests and an honest boundary around vision.
public protocol ObservationVisionEvaluating: Sendable {
    func evaluateObservation(imageData: Data, question: String) async throws -> String
}

extension AIRouter: ObservationVisionEvaluating {
    public func evaluateObservation(imageData: Data, question: String) async throws -> String {
        try await askWhatAmISeeing(imageData: imageData, customQuestion: question)
    }
}

/// Μηχανή παιχνιδιού παρατήρησης («Βρες κάτι κόκκινο») — session + fail-closed score + persistence.
public actor ObservationGameEngine {
    public static let pontosAIEpityxias: Int = 10
    public static let pontosXeirokinitis: Int = 5
    public static let scoreDefaultsKey = "r0lling.observation_game_score"

    private var currentMission: ObservationMission?
    private var score: Int = 0
    private var sessionState: ObservationGameSessionState = .idle
    private var lastEvaluation: ObservationEvaluationResult?
    private let visionEvaluator: any ObservationVisionEvaluating
    private let scoreDefaults: UserDefaults
    private let scoreStorageKey: String

    private let presetMissions = [
        ("Βρες κάτι κόκκινο γύρω σου", "κόκκινο αντικείμενο"),
        ("Βρες ένα φλιτζάνι καφέ ή κούπα", "κούπα ή φλιτζάνι"),
        ("Βρες ένα βιβλίο ή σημειωματάριο", "βιβλίο"),
        ("Βρες ένα φυτό ή λουλούδι", "φυτό"),
        ("Βρες ένα ζευγάρι παπούτσια", "παπούτσια"),
        ("Βρες ένα πληκτρολόγιο ή ποντίκι", "πληκτρολόγιο"),
        ("Βρες ένα κλειδί ή μπρελόκ", "κλειδί")
    ]

    public init(aiRouter: AIRouter) {
        self.visionEvaluator = aiRouter
        self.scoreDefaults = .standard
        self.scoreStorageKey = Self.scoreDefaultsKey
        if let saved = UserDefaults.standard.object(forKey: Self.scoreDefaultsKey) as? Int, saved >= 0 {
            self.score = saved
        }
        self.currentMission = nil
        self.sessionState = .idle
    }

    public init(
        visionEvaluator: any ObservationVisionEvaluating,
        userDefaults: UserDefaults = .standard,
        scoreStorageKey: String = "r0lling.observation_game_score"
    ) {
        self.visionEvaluator = visionEvaluator
        self.scoreDefaults = userDefaults
        self.scoreStorageKey = scoreStorageKey
        if let saved = userDefaults.object(forKey: scoreStorageKey) as? Int, saved >= 0 {
            self.score = saved
        }
        self.currentMission = nil
        self.sessionState = .idle
    }

    public func getCurrentMission() -> ObservationMission? {
        currentMission
    }

    public func getScore() -> Int {
        score
    }

    public func getSessionState() -> ObservationGameSessionState {
        sessionState
    }

    public func getLastEvaluation() -> ObservationEvaluationResult? {
        lastEvaluation
    }

    /// Ξεκινά νέα σύνοδο με τυχαία αποστολή.
    @discardableResult
    public func startNewMission() -> ObservationMission {
        let randomIndex = Int.random(in: 0..<presetMissions.count)
        let (prompt, target) = presetMissions[randomIndex]
        let mission = ObservationMission(prompt: prompt, targetDescription: target)
        self.currentMission = mission
        self.sessionState = .active
        self.lastEvaluation = nil
        return mission
    }

    /// Αξιολόγηση φωτογραφίας (γυαλιά ή Photos picker). Fail-closed: ασαφές/σφάλμα AI → 0 πόντοι.
    public func evaluateCapturedPhoto(imageData: Data) async -> ObservationEvaluationResult {
        guard sessionState != .evaluating else {
            return ObservationEvaluationResult(
                success: false,
                feedback: "Η αξιολόγηση αυτής της αποστολής βρίσκεται ήδη σε εξέλιξη.",
                source: .unavailable,
                awardedPoints: 0
            )
        }
        guard var mission = currentMission, !mission.isCompleted else {
            let result = ObservationEvaluationResult(
                success: false,
                feedback: "Δεν υπάρχει ενεργή αποστολή. Πάτησε «Επόμενη Αποστολή».",
                source: .unavailable,
                awardedPoints: 0
            )
            lastEvaluation = result
            sessionState = .failed
            return result
        }

        guard !imageData.isEmpty else {
            let result = ObservationEvaluationResult(
                success: false,
                feedback: "Κενή εικόνα — δεν απονεμήθηκαν πόντοι.",
                source: .unavailable,
                awardedPoints: 0
            )
            lastEvaluation = result
            sessionState = .failed
            return result
        }

        sessionState = .evaluating
        let evaluationMissionID = mission.id

        let evaluationQuestion = """
        Εξέτασε την εικόνα. Περιέχει \(mission.targetDescription);
        Απάντησε αυστηρά με τη λέξη ΝΑΙ ή ΟΧΙ στην πρώτη γραμμή, και στη δεύτερη εξήγησε με μία σύντομη φιλική πρόταση τι βλέπεις.
        """

        do {
            let reply = try await visionEvaluator.evaluateObservation(
                imageData: imageData,
                question: evaluationQuestion
            )
            guard currentMission?.id == evaluationMissionID,
                  sessionState == .evaluating,
                  currentMission?.isCompleted == false else {
                return staleEvaluationResult()
            }
            let verdict = Self.parseFailClosedVerdict(reply)

            switch verdict {
            case .yes:
                score += Self.pontosAIEpityxias
                persistScore()
                mission.isCompleted = true
                mission.completedTimestamp = Date()
                mission.evaluationFeedback = reply
                currentMission = mission
                let result = ObservationEvaluationResult(
                    success: true,
                    feedback: reply,
                    source: .aiVision,
                    awardedPoints: Self.pontosAIEpityxias
                )
                lastEvaluation = result
                sessionState = .completed
                return result

            case .no:
                mission.evaluationFeedback = reply
                currentMission = mission
                let result = ObservationEvaluationResult(
                    success: false,
                    feedback: reply,
                    source: .aiVision,
                    awardedPoints: 0
                )
                lastEvaluation = result
                sessionState = .failed
                return result

            case .ambiguous:
                // Fail-closed: χωρίς σαφές ΝΑΙ/ΟΧΙ → κανένας πόντος.
                let msg = "Ασαφής απάντηση AI — δεν απονεμήθηκαν πόντοι. Απάντηση: \(reply)"
                mission.evaluationFeedback = msg
                currentMission = mission
                let result = ObservationEvaluationResult(
                    success: false,
                    feedback: msg,
                    source: .aiVision,
                    awardedPoints: 0
                )
                lastEvaluation = result
                sessionState = .failed
                return result
            }
        } catch {
            guard currentMission?.id == evaluationMissionID,
                  sessionState == .evaluating,
                  currentMission?.isCompleted == false else {
                return staleEvaluationResult()
            }
            let fallbackFeedback = """
            Το Vision AI δεν ήταν διαθέσιμο (\(error.localizedDescription)). \
            Χρησιμοποίησε χειροκίνητη επιβεβαίωση — δεν είναι αξιολόγηση AI. Δεν απονεμήθηκαν πόντοι από AI.
            """
            let result = ObservationEvaluationResult(
                success: false,
                feedback: fallbackFeedback,
                source: .unavailable,
                awardedPoints: 0
            )
            lastEvaluation = result
            sessionState = .failed
            return result
        }
    }

    /// Χειροκίνητη επιβεβαίωση χρήστη — ρητά ΟΧΙ AI αξιολόγηση (A14 honesty).
    @discardableResult
    public func confirmManually() -> ObservationEvaluationResult {
        guard sessionState != .evaluating else {
            return ObservationEvaluationResult(
                success: false,
                feedback: "Η αξιολόγηση AI βρίσκεται ήδη σε εξέλιξη. Περίμενε να ολοκληρωθεί πριν επιβεβαιώσεις χειροκίνητα.",
                source: .manual,
                awardedPoints: 0
            )
        }
        guard var mission = currentMission, !mission.isCompleted else {
            let result = ObservationEvaluationResult(
                success: false,
                feedback: "Δεν υπάρχει ενεργή αποστολή για χειροκίνητη επιβεβαίωση.",
                source: .manual,
                awardedPoints: 0
            )
            lastEvaluation = result
            return result
        }

        score += Self.pontosXeirokinitis
        persistScore()
        mission.isCompleted = true
        mission.completedTimestamp = Date()
        mission.evaluationFeedback = "Χειροκίνητη επιβεβαίωση χρήστη (όχι AI)."
        currentMission = mission

        let result = ObservationEvaluationResult(
            success: true,
            feedback: mission.evaluationFeedback ?? "",
            source: .manual,
            awardedPoints: Self.pontosXeirokinitis
        )
        lastEvaluation = result
        sessionState = .completed
        return result
    }

    /// Fail-closed parser: μόνο ρητό ΝΑΙ/YES ή ΟΧΙ/NO στην πρώτη γραμμή.
    public static func parseFailClosedVerdict(_ reply: String) -> ObservationVerdict {
        let firstLine = reply
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        let normalized = firstLine
            .uppercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ";", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let yesTokens: Set<String> = ["ΝΑΙ", "NAI", "YES", "ΝΑΙ,", "YES,"]
        let noTokens: Set<String> = ["ΟΧΙ", "OXI", "NO", "ΟΧΙ,", "NO,"]

        if yesTokens.contains(normalized) { return .yes }
        if noTokens.contains(normalized) { return .no }

        // Επιτρέπουμε "ΝΑΙ — ..." / "YES - ..." μόνο αν ξεκινά με token + διαχωριστικό.
        let yesPrefixes = ["ΝΑΙ ", "ΝΑΙ-", "ΝΑΙ—", "ΝΑΙ:", "YES ", "YES-", "YES:", "NAI "]
        let noPrefixes = ["ΟΧΙ ", "ΟΧΙ-", "ΟΧΙ—", "ΟΧΙ:", "NO ", "NO-", "NO:", "OXI "]
        for p in yesPrefixes where normalized.hasPrefix(p) || firstLine.uppercased().hasPrefix(p) {
            return .yes
        }
        for p in noPrefixes where normalized.hasPrefix(p) || firstLine.uppercased().hasPrefix(p) {
            return .no
        }
        return .ambiguous
    }

    private func persistScore() {
        scoreDefaults.set(score, forKey: scoreStorageKey)
    }

    private func staleEvaluationResult() -> ObservationEvaluationResult {
        ObservationEvaluationResult(
            success: false,
            feedback: "Η αποστολή άλλαξε όσο περίμενε η αξιολόγηση. Δεν απονεμήθηκαν πόντοι.",
            source: .unavailable,
            awardedPoints: 0
        )
    }
}

/// Ρητό verdict για fail-closed scoring.
public enum ObservationVerdict: Sendable, Equatable {
    case yes
    case no
    case ambiguous
}
