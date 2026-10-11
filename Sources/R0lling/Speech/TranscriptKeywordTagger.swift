import Foundation

/// Adds explicit text cues to journal entries; it does not infer emotion from voice acoustics.
public struct TranscriptKeywordTagger: Sendable {
    public init() {}

    public enum Cue: String, Sendable {
        case excitement = "κείμενο: ενθουσιασμός"
        case urgency = "κείμενο: επείγον"
        case reflection = "κείμενο: σκέψη"
        case idea = "κείμενο: ιδέα"
    }

    public typealias EmotionTag = Cue

    /// Detects keyword/phrase cues with token boundaries and stable category order.
    public func detectCues(in transcript: String) -> [String] {
        let words = transcript.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)

        var cues: [Cue] = []
        if Self.containsAny(["τέλειο", "τελειο", "φοβερό", "φοβερο", "απίστευτο", "απιστευτο", "ουάου", "ουαου", "πανέμορφο", "πανεμορφο", "τρέλα", "τρελα", "φανταστικό", "φανταστικο", "wow", "amazing"], in: words)
            || transcript.contains("!") {
            cues.append(.excitement)
        }
        if Self.containsAny(["άμεσα", "αμεσα", "γρήγορα", "γρηγορα", "επείγον", "επειγον", "urgent"], in: words)
            || Self.containsPhrase("μην ξεχάσεις", in: words)
            || Self.containsPhrase("μην ξεχασεις", in: words)
            || Self.containsPhrase("πρέπει οπωσδήποτε", in: words)
            || Self.containsPhrase("πρεπει οπωσδηποτε", in: words) {
            cues.append(.urgency)
        }
        if Self.containsAny(["σκέφτομαι", "σκεφτομαι", "ίσως", "ισως", "αναρωτιέμαι", "αναρωτιεμαι", "μήπως", "μηπως"], in: words)
            || transcript.contains("?") {
            cues.append(.reflection)
        }
        if Self.containsAny(["ιδέα", "ιδεα", "σχέδιο", "σχεδιο", "project"], in: words)
            || Self.containsPhrase("σκέφτηκα να", in: words)
            || Self.containsPhrase("σκεφτηκα να", in: words)
            || Self.containsPhrase("τι θα έλεγες", in: words)
            || Self.containsPhrase("τι θα ελεγες", in: words) {
            cues.append(.idea)
        }
        return cues.map(\.rawValue)
    }

    @available(*, deprecated, message: "Use detectCues(in:); this is transcript keyword tagging, not voice-emotion analysis.")
    public func analyzeTranscript(text: String, durationSeconds: Double? = nil) -> [String] {
        detectCues(in: text)
    }

    private static func containsAny(_ phrases: [String], in words: [String]) -> Bool {
        phrases.contains { containsPhrase($0, in: words) }
    }

    private static func containsPhrase(_ phrase: String, in words: [String]) -> Bool {
        let phraseWords = phrase.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard !phraseWords.isEmpty, phraseWords.count <= words.count else { return false }
        for start in 0...(words.count - phraseWords.count) {
            if words[start..<(start + phraseWords.count)].elementsEqual(phraseWords) {
                return true
            }
        }
        return false
    }
}
