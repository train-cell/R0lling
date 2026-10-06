import Foundation

/// Αναλυτής συναισθηματικού τόνου φωνητικών σημειώσεων
public struct VoiceEmotionAnalyzer: Sendable {
    public init() {}

    public enum EmotionTag: String, Sendable {
        case excitement = "ενθουσιασμός"
        case urgency = "επείγον"
        case reflection = "σκέψη"
        case idea = "ιδέα"
        case neutral = "ουδέτερο"
    }

    /// Ανάλυση κειμένου και ρυθμού ομιλίας για αυτόματη προσθήκη ετικετών
    public func analyzeTranscript(text: String, durationSeconds: Double? = nil) -> [String] {
        let lower = text.lowercased()
        var tags: [String] = []

        // Έλεγχος ενθουσιασμού (θαυμαστικά, λέξεις όπως "ουάου", "φοβερό", "τέλειο", "απίστευτο")
        let excitementWords = ["τέλειο", "φοβερό", "απίστευτο", "ουάου", "πανέμορφο", "τρέλα", "φανταστικό", "wow", "amazing"]
        if excitementWords.contains(where: { lower.contains($0) }) || text.contains("!") {
            tags.append(EmotionTag.excitement.rawValue)
        }

        // Έλεγχος επείγοντος ("άμεσα", "γρήγορα", "επείγον", "μην ξεχάσεις", "τώρα")
        let urgencyWords = ["άμεσα", "γρήγορα", "επείγον", "επειγον", "μην ξεχάσεις", "πρέπει οπωσδήποτε", "urgent"]
        if urgencyWords.contains(where: { lower.contains($0) }) {
            tags.append(EmotionTag.urgency.rawValue)
        }

        // Έλεγχος σκέψης / αναστοχασμού ("σκέφτομαι", "ίσως", "αναρωτιέμαι", "γιατί")
        let reflectionWords = ["σκέφτομαι", "σκεφτομαι", "ίσως", "ισως", "αναρωτιέμαι", "αναρωτιεμαι", "μήπως"]
        if reflectionWords.contains(where: { lower.contains($0) }) || text.contains("?") {
            tags.append(EmotionTag.reflection.rawValue)
        }

        // Έλεγχος ιδέας ("ιδέα", "σκέφτηκα να", "τι θα έλεγες", "project")
        let ideaWords = ["ιδέα", "ιδεα", "σκέφτηκα να", "σκεφτηκα να", "σχέδιο", "project"]
        if ideaWords.contains(where: { lower.contains($0) }) {
            tags.append(EmotionTag.idea.rawValue)
        }

        return tags
    }
}
