import Foundation

/// Μηχανή παιχνιδιού παρατήρησης («Βρες κάτι κόκκινο»)
public actor ObservationGameEngine {
    private var currentMission: ObservationMission?
    private var score: Int = 0
    private let aiRouter: AIRouter

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
        self.aiRouter = aiRouter
        self.currentMission = startNewMission()
    }

    public func getCurrentMission() -> ObservationMission? {
        return currentMission
    }

    public func getScore() -> Int {
        return score
    }

    public func startNewMission() -> ObservationMission {
        let randomIndex = Int.random(in: 0..<presetMissions.count)
        let (prompt, target) = presetMissions[randomIndex]
        let mission = ObservationMission(prompt: prompt, targetDescription: target)
        self.currentMission = mission
        return mission
    }

    /// Αξιολόγηση ληφθείσας φωτογραφίας από τα γυαλιά ή την κάμερα
    public func evaluateCapturedPhoto(imageData: Data) async throws -> (success: Bool, feedback: String) {
        guard var mission = currentMission else {
            throw NSError(domain: "R0lling.Game", code: 8001, userInfo: [NSLocalizedDescriptionKey: "Δεν υπάρχει ενεργή αποστολή."])
        }

        let evaluationQuestion = """
        Εξέτασε την εικόνα. Περιέχει \(mission.targetDescription);
        Απάντησε αυστηρά με τη λέξη ΝΑΙ ή ΟΧΙ στην πρώτη γραμμή, και στη δεύτερη εξήγησε με μία σύντομη φιλική πρόταση τι βλέπεις.
        """

        do {
            let reply = try await aiRouter.askWhatAmISeeing(imageData: imageData, customQuestion: evaluationQuestion)
            let isFound = reply.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().hasPrefix("ΝΑΙ") ||
                          reply.uppercased().contains("YES")

            if isFound {
                score += 10
                mission.isCompleted = true
                mission.completedTimestamp = Date()
                mission.evaluationFeedback = reply
                self.currentMission = mission
                return (success: true, feedback: reply)
            } else {
                mission.evaluationFeedback = reply
                self.currentMission = mission
                return (success: false, feedback: reply)
            }
        } catch {
            // Manual fallback αν το AI δεν είναι διαθέσιμο
            let fallbackFeedback = "Το AI δεν ήταν προσβάσιμο. Μπορείτε να επιβεβαιώσετε χειροκίνητα αν βρήκατε: \(mission.targetDescription)."
            return (success: false, feedback: fallbackFeedback)
        }
    }

    public func confirmManually() {
        guard var mission = currentMission else { return }
        score += 5
        mission.isCompleted = true
        mission.completedTimestamp = Date()
        mission.evaluationFeedback = "Χειροκίνητη επιβεβαίωση από τον χρήστη."
        self.currentMission = mission
    }
}
