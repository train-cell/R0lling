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
    private var previousSample: IMUSample?
    private var previousSlope: Double = 0.0
    private var lastTroughTime: Double?
    private var lastNodTime: Double?
    private var lastTriggerTime: Double = -.infinity

    private let minimumNodAmplitude = 0.40
    private let minimumDoubleNodInterval = 0.25
    private let maximumDoubleNodInterval = 1.0
    private let triggerCooldown = 5.0
    public var onDoubleNodDetected: (@Sendable () -> Void)?

    public init() {}

    /// Τροφοδοτεί pitch δείγμα. Μία κάμψη μετρά όταν ολοκληρωθεί τοπικό trough
    /// με επαρκές prominence· συνεχόμενα frames της ίδιας κίνησης δεν μετρούν ως νέα nods.
    public func feedIMUSample(_ sample: IMUSample) {
        guard sample.pitch.isFinite, sample.timestamp.isFinite else { return }
        if let previousSample, sample.timestamp <= previousSample.timestamp {
            return
        }

        recentPitches.append((sample.pitch, sample.timestamp))
        let cutoff = sample.timestamp - 1.5
        recentPitches.removeAll(where: { $0.time < cutoff })

        guard let previousSample else {
            self.previousSample = sample
            return
        }

        let slope = sample.pitch - previousSample.pitch
        defer {
            previousSlope = slope
            self.previousSample = sample
        }

        // A trough is complete when pitch changes from descending to level/rising.
        // Count one event per trough instead of testing the same rolling amplitude
        // on every frame (which continually reset the previous event timestamp).
        guard previousSlope < 0, slope >= 0, recentPitches.count >= 6 else { return }

        let trough = previousSample
        let windowStart = max(
            trough.timestamp - 1.5,
            lastTroughTime ?? recentPitches[0].time
        )
        let precedingPeak = recentPitches
            .lazy
            .filter { $0.time >= windowStart && $0.time <= trough.timestamp }
            .map(\.pitch)
            .max() ?? trough.pitch

        lastTroughTime = trough.timestamp
        guard precedingPeak - trough.pitch > minimumNodAmplitude else { return }

        if let lastNodTime {
            let interval = trough.timestamp - lastNodTime
            if interval >= minimumDoubleNodInterval,
               interval <= maximumDoubleNodInterval,
               trough.timestamp - lastTriggerTime > triggerCooldown {
                lastTriggerTime = trough.timestamp
                onDoubleNodDetected?()
            }
        }
        lastNodTime = trough.timestamp
    }
}
