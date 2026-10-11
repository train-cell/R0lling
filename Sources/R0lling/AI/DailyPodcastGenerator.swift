import Foundation
import AVFAudio

/// Μηχανή παραγωγής ημερήσιου Audio Podcast Digest μέσω TTS
public final class DailyPodcastGenerator: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private let completionRegistry = SpeechCompletionRegistry()

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Εκφώνηση της ημερήσιας ανασκόπησης — `completion` καλείται στο τέλος της ομιλίας (CQ-P2-020).
    public func playDailyPodcast(summaryText: String, completion: (@Sendable () -> Void)? = nil) {
        guard !summaryText.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: summaryText)
        utterance.voice = AVSpeechSynthesisVoice(language: "el-GR") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.50 // Φυσικός ρυθμός ομιλίας
        utterance.pitchMultiplier = 1.0

        if let completion {
            completionRegistry.register(completion, for: utterance)
        }
        synthesizer.speak(utterance)
    }

    public func stopPodcast() {
        completionRegistry.discardAll()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completionRegistry.take(for: utterance)?()
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completionRegistry.discard(for: utterance)
    }
}
