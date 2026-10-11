import Foundation

/// Maps a measured value onto a visual scale only; the interval is not a health reference range.
public enum HealthMetricDisplayScale {
    public static func progress(for value: Double?, within range: ClosedRange<Double>) -> Double? {
        guard let value,
              value.isFinite,
              range.lowerBound.isFinite,
              range.upperBound.isFinite,
              range.upperBound > range.lowerBound else {
            return nil
        }

        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        guard normalized.isFinite else { return nil }
        return min(max(normalized, 0), 1)
    }
}
