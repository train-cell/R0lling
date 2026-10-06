import Foundation

public enum VoiceCommandType: Sendable, Equatable {
    case clip(seconds: Double)
    case note(text: String)
    case whatAmISeeing
    case unknown(raw: String)
}

/// Αναλυτής φωνητικών εντολών EL/EN με ενεργό dedup τελικών transcripts (R3-006).
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

        // Καταγράφουμε μόνο actionable commands (όχι unknown) για dedup.
        switch command {
        case .unknown:
            break
        default:
            lastHandledTranscript = lower
            lastHandledAt = Date()
        }

        return command
    }

    /// Επαναφορά dedup state (tests / νέα σύνοδος ακρόασης).
    public func resetDedup() {
        lastHandledTranscript = ""
        lastHandledAt = .distantPast
    }

    private func resolveCommand(trimmed: String, lower: String) -> VoiceCommandType {
        let clipKeywords = [
            "clip this", "hey meta, clip this", "hey meta clip this",
            "κράτα κλιπ", "κλιπ", "αποθήκευσε κλιπ", "κρατα κλιπ", "κανε κλιπ", "clip"
        ]
        for keyword in clipKeywords {
            if lower.contains(keyword) {
                if lower.contains("5") || lower.contains("πέντε") {
                    return .clip(seconds: 5.0)
                }
                return .clip(seconds: 10.0)
            }
        }

        let seeingKeywords = [
            "what am i seeing", "what do i see", "what is this",
            "τι βλέπω", "τι βλεπω", "τι είναι αυτό", "τι ειναι αυτο", "περιέγραψε τι βλέπω"
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
