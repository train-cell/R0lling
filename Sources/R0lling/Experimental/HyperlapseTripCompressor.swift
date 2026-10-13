import CoreLocation
import Foundation

/// Validation failures for GPS-sampled Hyper-lapse frame selection.
public enum HyperlapseTripCompressorError: LocalizedError, Sendable {
    case invalidMinimumDisplacement
    case invalidTargetFrameRate
    case invalidMaximumFrameCount
    case invalidSample(index: Int)
    case nonIncreasingTimestamp(index: Int)
    case nonIncreasingFrameIndex(index: Int)
    case nonFiniteResult

    public var errorDescription: String? {
        switch self {
        case .invalidMinimumDisplacement:
            "Η ελάχιστη μετατόπιση πρέπει να είναι θετικός, πεπερασμένος αριθμός."
        case .invalidTargetFrameRate:
            "Το frame rate πρέπει να είναι θετικός ακέραιος αριθμός."
        case .invalidMaximumFrameCount:
            "Το όριο καρέ πρέπει να είναι θετικό και τουλάχιστον δύο για διαδρομή με πολλά σημεία."
        case let .invalidSample(index):
            "Το δείγμα διαδρομής \(index) έχει άκυρα καρέ, συντεταγμένες ή heading."
        case let .nonIncreasingTimestamp(index):
            "Το timestamp του δείγματος \(index) δεν αυξάνεται."
        case let .nonIncreasingFrameIndex(index):
            "Το frame index του δείγματος \(index) δεν αυξάνεται."
        case .nonFiniteResult:
            "Οι μετρικές της διαδρομής δεν μπορούν να αναπαρασταθούν ως πεπερασμένοι αριθμοί."
        }
    }
}

/// Επιλέγει καρέ διαδρομής βάσει GPS μετατόπισης και διατηρεί το heading για downstream rendering.
/// Δεν κάνει capture GPS ή export video· αυτά παραμένουν ξεχωριστά, readiness-gated integration work.
public struct HyperlapseTripCompressor: Sendable {
    public struct GeoFrameSample: Sendable {
        public let frameIndex: Int
        public let timestamp: Double
        public let coordinate: CLLocationCoordinate2D
        public let heading: Double
        public let imageRelativePath: String

        public init(
            frameIndex: Int,
            timestamp: Double,
            coordinate: CLLocationCoordinate2D,
            heading: Double = 0.0,
            imageRelativePath: String
        ) {
            self.frameIndex = frameIndex
            self.timestamp = timestamp
            self.coordinate = coordinate
            self.heading = heading
            self.imageRelativePath = imageRelativePath
        }
    }

    public struct HyperlapseResult: Sendable {
        public let selectedFrames: [GeoFrameSample]
        public let totalDistanceMeters: Double
        public let originalDurationSeconds: Double
        public let hyperlapseDurationSeconds: Double
        public let speedupFactor: Double
    }

    public let minDisplacementMeters: Double
    public let targetFps: Int

    public init(minDisplacementMeters: Double = 12.0, targetFps: Int = 30) throws {
        guard minDisplacementMeters.isFinite, minDisplacementMeters > 0 else {
            throw HyperlapseTripCompressorError.invalidMinimumDisplacement
        }
        guard targetFps > 0 else {
            throw HyperlapseTripCompressorError.invalidTargetFrameRate
        }
        self.minDisplacementMeters = minDisplacementMeters
        self.targetFps = targetFps
    }

    /// Υπολογίζει γεωδαιτική απόσταση μεταξύ δύο σημείων.
    public static func distanceInMeters(
        from coordinate: CLLocationCoordinate2D,
        to otherCoordinate: CLLocationCoordinate2D
    ) -> Double {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: otherCoordinate.latitude, longitude: otherCoordinate.longitude))
    }

    /// Επιλέγει καρέ σε όλη τη διαδρομή και περιορίζει το αποτέλεσμα διατηρώντας αρχή και τέλος.
    public func compressRoute(
        samples: [GeoFrameSample],
        maxResultFrames: Int = 450
    ) throws -> HyperlapseResult {
        guard maxResultFrames > 0 else {
            throw HyperlapseTripCompressorError.invalidMaximumFrameCount
        }
        try validate(samples: samples)
        guard samples.count <= 1 || maxResultFrames >= 2 else {
            throw HyperlapseTripCompressorError.invalidMaximumFrameCount
        }

        guard let first = samples.first else {
            return HyperlapseResult(
                selectedFrames: [],
                totalDistanceMeters: 0,
                originalDurationSeconds: 0,
                hyperlapseDurationSeconds: 0,
                speedupFactor: 1
            )
        }

        var candidates = [first]
        var lastSelectedCoordinate = first.coordinate
        var totalDistanceMeters = 0.0

        for index in samples.indices.dropFirst() {
            let sample = samples[index]
            let previousSample = samples[index - 1]
            let routeSegmentDistance = Self.distanceInMeters(
                from: previousSample.coordinate,
                to: sample.coordinate
            )
            let selectedFrameDisplacement = Self.distanceInMeters(
                from: lastSelectedCoordinate,
                to: sample.coordinate
            )
            guard routeSegmentDistance.isFinite, selectedFrameDisplacement.isFinite else {
                throw HyperlapseTripCompressorError.nonFiniteResult
            }

            totalDistanceMeters += routeSegmentDistance
            if selectedFrameDisplacement >= minDisplacementMeters {
                candidates.append(sample)
                lastSelectedCoordinate = sample.coordinate
            }
        }

        if let finalSample = samples.last, finalSample.frameIndex != candidates.last?.frameIndex {
            candidates.append(finalSample)
        }

        let selectedFrames = Self.downsample(candidates, limit: maxResultFrames)
        let originalDuration = samples.count > 1 ? samples[samples.count - 1].timestamp - first.timestamp : 0
        let hyperlapseDuration = Double(selectedFrames.count) / Double(targetFps)
        let rawSpeedup = hyperlapseDuration > 0 ? originalDuration / hyperlapseDuration : 1
        guard totalDistanceMeters.isFinite,
              originalDuration.isFinite,
              hyperlapseDuration.isFinite,
              rawSpeedup.isFinite else {
            throw HyperlapseTripCompressorError.nonFiniteResult
        }

        return HyperlapseResult(
            selectedFrames: selectedFrames,
            totalDistanceMeters: totalDistanceMeters,
            originalDurationSeconds: originalDuration,
            hyperlapseDurationSeconds: hyperlapseDuration,
            speedupFactor: max(1, rawSpeedup)
        )
    }

    private func validate(samples: [GeoFrameSample]) throws {
        var previousTimestamp: Double?
        var previousFrameIndex: Int?

        for (index, sample) in samples.enumerated() {
            guard sample.frameIndex >= 0,
                  sample.timestamp.isFinite,
                  CLLocationCoordinate2DIsValid(sample.coordinate),
                  sample.heading.isFinite,
                  (0...360).contains(sample.heading),
                  !sample.imageRelativePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw HyperlapseTripCompressorError.invalidSample(index: index)
            }

            if let previousTimestamp, sample.timestamp <= previousTimestamp {
                throw HyperlapseTripCompressorError.nonIncreasingTimestamp(index: index)
            }
            if let previousFrameIndex, sample.frameIndex <= previousFrameIndex {
                throw HyperlapseTripCompressorError.nonIncreasingFrameIndex(index: index)
            }
            previousTimestamp = sample.timestamp
            previousFrameIndex = sample.frameIndex
        }
    }

    private static func downsample(_ frames: [GeoFrameSample], limit: Int) -> [GeoFrameSample] {
        guard frames.count > limit else { return frames }
        guard limit > 1 else { return [frames[0]] }

        let lastSourceIndex = frames.count - 1
        return (0..<limit).map { outputIndex in
            let progress = Double(outputIndex) / Double(limit - 1)
            let sourceIndex = Int((progress * Double(lastSourceIndex)).rounded())
            return frames[sourceIndex]
        }
    }
}
