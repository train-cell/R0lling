import Foundation
import AVFAudio

/// Υπηρεσία ανίχνευσης ηχητικών εκρήξεων (Acoustic Spikes: γέλια, φωνές, απότομοι ήχοι) για αυτόματο clipping
public final class AcousticTriggerService: @unchecked Sendable {
    public struct Config: Sendable {
        public var thresholdDecibels: Float = -12.0 // dBFS κατώφλι για έντονο ήχο
        public var cooldownSeconds: Double = 15.0  // Αποφυγή πολλαπλών διαδοχικών triggers
        public var isEnabled: Bool = true

        public init(thresholdDecibels: Float = -12.0, cooldownSeconds: Double = 15.0, isEnabled: Bool = true) {
            self.thresholdDecibels = thresholdDecibels
            self.cooldownSeconds = cooldownSeconds
            self.isEnabled = isEnabled
        }
    }

    public var config: Config
    private var lastTriggerTime: Date = Date.distantPast
    public var onSpikeDetected: (@Sendable (Float) -> Void)?

    public init(config: Config = Config()) {
        self.config = config
    }

    /// Επεξεργασία RMS στάθμης ήχου από buffer μικροφώνου
    public func processAudioLevel(decibels: Float) {
        guard config.isEnabled else { return }

        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) > config.cooldownSeconds else { return }

        if decibels >= config.thresholdDecibels {
            lastTriggerTime = now
            onSpikeDetected?(decibels)
        }
    }

    /// Υπολογισμός μέσης στάθμης dB από PCM Float32 buffer
    public func calculateRMSDecibels(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return -100.0 }
        let frameLength = UInt(buffer.frameLength)
        guard frameLength > 0 else { return -100.0 }

        var sum: Float = 0.0
        for i in 0..<Int(frameLength) {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        if rms > 0.0 {
            return 20.0 * log10(rms)
        }
        return -100.0
    }
}
