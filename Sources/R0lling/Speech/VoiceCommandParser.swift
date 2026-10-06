import Foundation

/// Αναγνωρισμένες φωνητικές εντολές EL/EN (χωρίς Meta wake — iOS Speech μόνο).
public enum VoiceCommandType: Sendable, Equatable {
    case clip(seconds: Double)
    case note(text: String)
    case whatAmISeeing
    case startObservationGame
    case nextMission
    case unknown(raw: String)
}

/// Αποτέλεσμα stopListening — αποφυγή διπλής καταχώρισης σημείωσης (A04).
public enum SpeechStopResult: Sendable, Equatable {
    case commandHandled(VoiceCommandType)
    case dictation(String)
    case empty
}

/// Αναλυτής φωνητικών εντολών EL/EN με ενεργό dedup τελικών transcripts (R3-006 / A04).
public final class VoiceCommandParser: @unchecked Sendable {
    /// Παράθυρο dedup σε δευτερόλεπτα για πανομοιότυπα final transcripts.
    public static let paraThyroDedupDeuterolepta: TimeInterval = 2.0

    private var lastHandledTranscript: String = ""
    private var lastHandledAt: Date = .distantPast
    private let dedupWindowSeconds: TimeInterval

    public init(dedupWindowSeconds: TimeInterval = VoiceCommandParser.paraThyroDedupDeuterolepta) {
        self.dedupWindowSeconds = dedupWindowSeconds
    }

    /// Αναλύει transcript. Επιστρέφει `nil` αν είναι κενό ή διπλότυπο μέσα στο dedup window.
    /// Καλείται ΜΟΝΟ σε final utterances (όχι partial) — A04.
    public func parse(transcript: String) -> VoiceCommandType? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()

        // R3-006: Αποφυγή διπλών final events για το ίδιο utterance.
        if lower == lastHandledTranscript,
           Date().timeIntervalSince(lastHandledAt) < dedupWindowSeconds {
            return nil
        }

        let command = resolveCommand(trimmed: trimmed, lower: lower)

        // Καταγράφουμε actionable + unknown για dedup (unknown δεν πρέπει να spam-άρει handler).
        lastHandledTranscript = lower
        lastHandledAt = Date()

        return command
    }

    /// Επαναφορά dedup state (νέα σύνοδος ακρόασης / tests).
    public func resetDedup() {
        lastHandledTranscript = ""
        lastHandledAt = .distantPast
    }

    /// Καθαρισμός σημείωσης EL/EN (contract `scrubGreekAndEnglish`).
    public func scrubGreekAndEnglish(raw: String) -> String {
        scrubNoteText(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func resolveCommand(trimmed: String, lower: String) -> VoiceCommandType {
        let gameStartKeywords = [
            "start observation game", "start the game", "observation game",
            "ξεκίνα το παιχνίδι", "ξεκινα το παιχνιδι", "παιχνίδι παρατήρησης", "παιχνιδι παρατηρησης"
        ]
        for keyword in gameStartKeywords {
            if lower.contains(keyword) {
                return .startObservationGame
            }
        }

        let nextMissionKeywords = [
            "next mission", "next challenge",
            "επόμενη αποστολή", "επομενη αποστολη", "επόμενο mission", "επομενο mission"
        ]
        for keyword in nextMissionKeywords {
            if lower.contains(keyword) {
                return .nextMission
            }
        }

        let clipKeywords = [
            "clip this", "hey meta, clip this", "hey meta clip this",
            "κράτα κλιπ", "κλιπ", "αποθήκευσε κλιπ", "κρατα κλιπ", "κανε κλιπ", "clip"
        ]
        for keyword in clipKeywords {
            if lower.contains(keyword) {
                if lower.contains("5") || lower.contains("πέντε") || lower.contains("πεντε") {
                    return .clip(seconds: 5.0)
                }
                return .clip(seconds: 10.0)
            }
        }

        let seeingKeywords = [
            "what am i seeing", "what do i see", "what is this",
            "τι βλέπω", "τι βλεπω", "τι είναι αυτό", "τι ειναι αυτο", "περιέγραψε τι βλέπω", "περιεγραψε τι βλεπω"
        ]
        for keyword in seeingKeywords {
            if lower.contains(keyword) {
                return .whatAmISeeing
            }
        }

        let notePrefixes = [
            "note this:", "note this", "hey meta, note this", "hey meta note this",
            "σημείωσε:", "σημείωσε", "σημειωσε", "γράψε:", "γράψε", "γραψε"
        ]
        for prefix in notePrefixes {
            if lower.hasPrefix(prefix) {
                let noteContent = trimmed.dropFirst(prefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: ":- ")))
                if !noteContent.isEmpty {
                    return .note(text: scrubNoteText(noteContent))
                }
            }
        }

        return .unknown(raw: trimmed)
    }

    private func scrubNoteText(_ text: String) -> String {
        var cleaned = text
        if let first = cleaned.first {
            cleaned = first.uppercased() + cleaned.dropFirst()
        }
        return cleaned
    }
}
