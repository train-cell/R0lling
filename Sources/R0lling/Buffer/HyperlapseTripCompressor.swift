import Foundation
import CoreLocation

/// Συμπιεστής διαδρομών Hyper-lapse (Hyper-lapse Trip Compressor)
/// Επιλέγει frames με βάση τη γεωγραφική μετατόπιση GPS (π.χ. ανά 12 μέτρα) και γωνία πορείας.
/// Εξαλείφει στάσεις αναμονής (φανάρια, καφέ) και συνθέτει ένα ομαλό hyper-lapse 15-30s.
public final class HyperlapseTripCompressor: @unchecked Sendable {
    
    public struct GeoFrameSample: Sendable {
        public let frameIndex: Int
        public let timestamp: Double
        public let coordinate: CLLocationCoordinate2D
        public let heading: Double // degrees (0-360)
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
    
    public var minDisplacementMeters: Double = 12.0
    public var targetFps: Int = 30
    
    public init(minDisplacementMeters: Double = 12.0, targetFps: Int = 30) {
        self.minDisplacementMeters = minDisplacementMeters
        self.targetFps = targetFps
    }
    
    /// Υπολογισμός απόστασης Haversine μεταξύ δύο σημείων
    public static func distanceInMeters(from coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let loc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return loc1.distance(from: loc2)
    }
    
    /// Επιλογή των ιδανικών frames για το hyper-lapse
    public func compressRoute(samples: [GeoFrameSample], maxResultFrames: Int = 450) -> HyperlapseResult {
        guard !samples.isEmpty else {
            return HyperlapseResult(selectedFrames: [], totalDistanceMeters: 0, originalDurationSeconds: 0, hyperlapseDurationSeconds: 0, speedupFactor: 1.0)
        }
        
        var selected: [GeoFrameSample] = [samples[0]]
        var lastCoord = samples[0].coordinate
        var totalDist: Double = 0.0
        
        for i in 1..<samples.count {
            let sample = samples[i]
            let dist = Self.distanceInMeters(from: lastCoord, to: sample.coordinate)
            
            // Επιλογή frame μόνο αν υπήρξε πραγματική μετατόπιση (αποφυγή στάσεων)
            if dist >= minDisplacementMeters {
                selected.append(sample)
                totalDist += dist
                lastCoord = sample.coordinate
                
                if selected.count >= maxResultFrames {
                    break
                }
            }
        }
        
        let originalDuration = (samples.last?.timestamp ?? 0) - (samples.first?.timestamp ?? 0)
        let hyperlapseDuration = Double(selected.count) / Double(targetFps)
        let speedup = hyperlapseDuration > 0 ? (originalDuration / hyperlapseDuration) : 1.0
        
        return HyperlapseResult(
            selectedFrames: selected,
            totalDistanceMeters: totalDist,
            originalDurationSeconds: max(0, originalDuration),
            hyperlapseDurationSeconds: hyperlapseDuration,
            speedupFactor: max(1.0, speedup)
        )
    }
}
