import Foundation
import AVFAudio

/// Μηχανή παραγωγής ημερήσιου Audio Podcast Digest μέσω TTS
public final class DailyPodcastGenerator: @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    /// Εκφώνηση της ημερήσιας ανασκόπησης στα ακουστικά ή τα ηχεία των γυαλιών
    public func playDailyPodcast(summaryText: String, completion: (@Sendable () -> Void)? = nil) {
        guard !summaryText.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: summaryText)
        utterance.voice = AVSpeechSynthesisVoice(language: "el-GR") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.50 // Φυσικός ρυθμός ομιλίας
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
        completion?()
    }

    public func stopPodcast() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
