import Foundation
import AVFAudio
#if canImport(AudioToolbox)
import AudioToolbox
#endif

/// Plays AudioServices system sounds for existing app events. Output routing is OS-controlled; no Meta-glasses route is wired.
public final class EarconFeedbackService: @unchecked Sendable {
    public static let shared = EarconFeedbackService()

    public enum EarconType {
        case clipSaved
        case recordingStarted
        case recordingStopped
        case missionCompleted
        case warningBattery
        case error
    }

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    public init() {}

    public func playEarcon(_ type: EarconType) {
        #if canImport(AudioToolbox)
        switch type {
        case .clipSaved:
            // Ευχάριστος σύντομος τόνος επιβεβαίωσης
            AudioServicesPlaySystemSound(1057) // Tock / Confirmation
        case .recordingStarted:
            AudioServicesPlaySystemSound(1113) // Begin record tone
        case .recordingStopped:
            AudioServicesPlaySystemSound(1114) // End record tone
        case .missionCompleted:
            AudioServicesPlaySystemSound(1025) // Fanfare / Milestone
        case .warningBattery:
            AudioServicesPlaySystemSound(1053) // Low power chime
        case .error:
            AudioServicesPlaySystemSound(1073) // Alert tone
        }
        #endif
    }
}
