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

/// Owns command deduplication for one recording session. A final transcript is parsed
/// once and its stop result is retained so final dictation is not lost to dedup.
public final class VoiceCommandUtteranceResolver: @unchecked Sendable {
    public struct StopResolution: Sendable, Equatable {
        public let result: SpeechStopResult
        /// Non-nil only when stopListening itself must dispatch an actionable command.
        public let commandToDispatch: VoiceCommandType?

        public init(result: SpeechStopResult, commandToDispatch: VoiceCommandType?) {
            self.result = result
            self.commandToDispatch = commandToDispatch
        }
    }

    private let lock = NSRecursiveLock()
    private let parser: VoiceCommandParser
    private var finalResult: SpeechStopResult?

    public init(parser: VoiceCommandParser = VoiceCommandParser()) {
        self.parser = parser
    }

    public func beginUtterance() {
        lock.lock()
        defer { lock.unlock() }
        parser.resetDedup()
        finalResult = nil
    }

    /// Parses a final Speech callback. Actionable results are returned for immediate
    /// dispatch; dictation is saved for stopListening and is never sent as a command.
    @discardableResult
    public func processFinalTranscript(_ transcript: String) -> VoiceCommandType? {
        lock.lock()
        defer { lock.unlock() }
        guard finalResult == nil, let command = parser.parse(transcript: transcript) else { return nil }

        switch command {
        case .unknown(let raw):
            finalResult = raw.isEmpty ? .empty : .dictation(raw)
            return nil
        default:
            finalResult = .commandHandled(command)
            return command
        }
    }

    /// Resolves stop without parsing a final callback twice. If Speech never produced a
    /// final event, the latest transcript is parsed once here and commands are dispatched.
    public func stop(transcript: String) -> StopResolution {
        lock.lock()
        defer { lock.unlock() }
        if let finalResult {
            self.finalResult = nil
            return StopResolution(result: finalResult, commandToDispatch: nil)
        }

        guard let command = parser.parse(transcript: transcript) else {
            return StopResolution(result: .empty, commandToDispatch: nil)
        }
        switch command {
        case .unknown(let raw):
            return StopResolution(result: raw.isEmpty ? .empty : .dictation(raw), commandToDispatch: nil)
        default:
            return StopResolution(result: .commandHandled(command), commandToDispatch: command)
        }
    }
}

/// Αναλυτής φωνητικών εντολών EL/EN με ενεργό dedup τελικών transcripts (R3-006 / A04).
public final class VoiceCommandParser: @unchecked Sendable {
    /// Παράθυρο dedup σε δευτερόλεπτα για πανομοιότυπα final transcripts.
    public static let paraThyroDedupDeuterolepta: TimeInterval = 2.0

    private let stateLock = NSLock()
    private var lastHandledTranscript: String = ""
    private var lastHandledAt: Date = .distantPast
    private let dedupWindowSeconds: TimeInterval

    public init(dedupWindowSeconds: TimeInterval = VoiceCommandParser.paraThyroDedupDeuterolepta) {
        self.dedupWindowSeconds = dedupWindowSeconds
    }

    /// Αναλύει transcript. Επιστρέφει `nil` αν είναι κενό ή διπλότυπο μέσα στο dedup window.
    /// Καλείται ΜΟΝΟ σε final utterances (όχι partial) — A04.
    public func parse(transcript: String) -> VoiceCommandType? {
        stateLock.lock()
        defer { stateLock.unlock() }
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
        stateLock.lock()
        defer { stateLock.unlock() }
        lastHandledTranscript = ""
        lastHandledAt = .distantPast
    }

    /// Καθαρισμός σημείωσης EL/EN (contract `scrubGreekAndEnglish`).
    public func scrubGreekAndEnglish(raw: String) -> String {
        scrubNoteText(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func resolveCommand(trimmed: String, lower: String) -> VoiceCommandType {
        // Dictation prefixes take precedence over action words inside the note body.
        // For example, "note this: clip the paragraph" is still a note, not a clip command.
        let notePrefixes = [
            "hey meta, note this:", "hey meta note this:",
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

        let clipCommandPrefixes = [
            "hey meta, clip this", "hey meta clip this", "clip this",
            "κράτα κλιπ", "κρατα κλιπ", "αποθήκευσε κλιπ", "αποθηκευσε κλιπ",
            "κάνε κλιπ", "κανε κλιπ"
        ]
        let normalizedForClip = lower.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        let isClipCommand = normalizedForClip == "clip"
            || normalizedForClip == "κλιπ"
            || clipCommandPrefixes.contains { normalizedForClip == $0 || normalizedForClip.hasPrefix($0 + " ") }
            || normalizedForClip.hasPrefix("clip 5 ")
            || normalizedForClip.hasPrefix("clip 10 ")
        if isClipCommand {
            if lower.contains("5") || lower.contains("πέντε") || lower.contains("πεντε") {
                return .clip(seconds: 5.0)
            }
            return .clip(seconds: 10.0)
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
