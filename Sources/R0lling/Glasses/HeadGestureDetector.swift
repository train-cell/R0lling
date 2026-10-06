import Foundation

/// Head double-nod IMU detector — **ready=false** μέχρι IMU feed (`FeatureReadinessRegistry.headGesture`).
public final class HeadGestureDetector: @unchecked Sendable {
    public struct IMUSample: Sendable {
        public let pitch: Double // Κλίση πάνω/κάτω (Nod)
        public let roll: Double  // Κλίση δεξιά/αριστερά
        public let yaw: Double   // Περιστροφή
        public let timestamp: Double

        public init(pitch: Double, roll: Double, yaw: Double, timestamp: Double) {
            self.pitch = pitch
            self.roll = roll
            self.yaw = yaw
            self.timestamp = timestamp
        }
    }

    private var recentPitches: [(pitch: Double, time: Double)] = []
    private var lastNodTime: Double = 0.0
    private var lastTriggerTime: Double = 0.0
    public var onDoubleNodDetected: (@Sendable () -> Void)?

    public init() {}

    /// Τροφοδοσία δείγματος IMU από τα γυαλιά
    public func feedIMUSample(_ sample: IMUSample) {
        recentPitches.append((sample.pitch, sample.timestamp))

        // Διατήρηση μόνο του τελευταίου 1.5 δευτερολέπτου
        let cutoff = sample.timestamp - 1.5
        recentPitches.removeAll(where: { $0.time < cutoff })

        // Έλεγχος ανίχνευσης κατακόρυφης ταλάντωσης (Nod: Pitch μεταβολή > 0.35 rad)
        guard recentPitches.count >= 6 else { return }

        let minPitch = recentPitches.map { $0.pitch }.min() ?? 0.0
        let maxPitch = recentPitches.map { $0.pitch }.max() ?? 0.0
        let amplitude = maxPitch - minPitch

        if amplitude > 0.40 {
            // Εντοπίστηκε έντονη κίνηση νεύματος
            if (sample.timestamp - lastNodTime) > 0.25 && (sample.timestamp - lastNodTime) < 1.0 {
                // Δεύτερο συνεχόμενο νεύμα εντός 1 δευτερολέπτου -> Double Nod!
                if (sample.timestamp - lastTriggerTime) > 5.0 {
                    lastTriggerTime = sample.timestamp
                    onDoubleNodDetected?()
                }
            }
            lastNodTime = sample.timestamp
        }
    }
}
