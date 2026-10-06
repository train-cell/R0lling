import Foundation

/// Φύλακας σειράς συνομιλίας (Conversational Turn-Taking Guard)
/// Αποτρέπει διακοπές (interruptions) όταν ο χρήστης ή ο συνομιλητής του μιλούν.
/// Επιτρέπει στον Jarvis να αποκρίνεται στα open-ear ηχεία ΜΟΝΟ όταν εντοπιστεί
/// φυσική παύση ομιλίας (σιωπή > 600ms) με ασφαλή ροή.
public final class TurnTakingGuard: @unchecked Sendable {
    
    public enum SpeakerState: Sendable, Equatable {
        case idleSilence
        case userSpeaking
        case interlocutorSpeaking
        case naturalPause(durationMs: Double)
    }
    
    private let lock = NSLock()
    private var currentState: SpeakerState = .idleSilence
    private var lastSpeechTimestamp: Date = Date()
    private var speechActive: Bool = false
    
    /// Ελάχιστη απαιτούμενη παύση σιωπής σε millisecond πριν επιτραπεί η ομιλία του βοηθού
    public var requiredSilenceMs: Double = 600.0
    
    public init(requiredSilenceMs: Double = 600.0) {
        self.requiredSilenceMs = requiredSilenceMs
    }
    
    /// Ενημέρωση ακουστικής δραστηριότητας (Voice Activity Detection - VAD)
    public func reportAudioSample(rmsDbfs: Float, isUserVoice: Bool = true) {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let voiceThreshold: Float = -38.0 // dBFS
        
        if rmsDbfs > voiceThreshold {
            speechActive = true
            lastSpeechTimestamp = now
            currentState = isUserVoice ? .userSpeaking : .interlocutorSpeaking
        } else {
            if speechActive {
                let elapsedMs = now.timeIntervalSince(lastSpeechTimestamp) * 1000.0
                if elapsedMs >= requiredSilenceMs {
                    speechActive = false
                    currentState = .idleSilence
                } else {
                    currentState = .naturalPause(durationMs: elapsedMs)
                }
            } else {
                currentState = .idleSilence
            }
        }
    }
    
    /// Ελέγχει άμεσα εάν είναι ασφαλές να μιλήσει ο βοηθός αυτή τη στιγμή
    public func canAssistantSpeak() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        switch currentState {
        case .idleSilence:
            return true
        case .naturalPause(let durationMs):
            return durationMs >= requiredSilenceMs
        case .userSpeaking, .interlocutorSpeaking:
            return false
        }
    }
    
    /// Αναμονή μέχρι να υπάρξει φυσικό παράθυρο ομιλίας ή timeout
    public func waitForTurnPermission(timeoutSeconds: Double = 5.0) async -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeoutSeconds {
            if canAssistantSpeak() {
                return true
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms polling loop
        }
        return false
    }
    
    /// Επιστρέφει την τρέχουσα κατάσταση ομιλίας
    public func getSpeakerState() -> SpeakerState {
        lock.lock()
        defer { lock.unlock() }
        return currentState
    }
}
