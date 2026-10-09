import Foundation

/// One source-backed asleep interval from HealthKit.
public struct SleepInterval: Sendable, Equatable {
    public let startDate: Date
    public let endDate: Date
    public let sourceName: String

    public init(startDate: Date, endDate: Date, sourceName: String) {
        self.startDate = startDate
        self.endDate = endDate
        self.sourceName = sourceName
    }
}

/// A merged sleep episode. Overlapping sources/stages count once; short awake gaps are excluded from asleep time.
public struct SleepEpisodeSummary: Sendable, Equatable {
    public let asleepSeconds: TimeInterval
    public let endedAt: Date
    public let sourceNames: [String]
}

/// Reduces HealthKit sleep-stage intervals to a single episode within a caller-defined overnight window.
public enum SleepEpisodeAggregator {
    public static let defaultMaximumAwakeGap: TimeInterval = 2 * 60 * 60

    /// Selects the longest merged episode in the bounded window, so separate naps are not added to overnight sleep.
    public static func longestEpisode(
        from intervals: [SleepInterval],
        windowStart: Date,
        windowEnd: Date,
        maximumAwakeGap: TimeInterval = defaultMaximumAwakeGap
    ) -> SleepEpisodeSummary? {
        guard windowEnd > windowStart, maximumAwakeGap >= 0 else { return nil }

        let clipped = intervals.compactMap { interval -> SleepInterval? in
            let start = max(interval.startDate, windowStart)
            let end = min(interval.endDate, windowEnd)
            guard end > start else { return nil }
            return SleepInterval(startDate: start, endDate: end, sourceName: interval.sourceName)
        }.sorted {
            if $0.startDate == $1.startDate { return $0.endDate < $1.endDate }
            return $0.startDate < $1.startDate
        }

        struct Episode {
            var asleepSeconds: TimeInterval
            var endedAt: Date
            var sourceNames: Set<String>

            mutating func append(_ interval: SleepInterval) {
                let newlyCoveredStart = max(interval.startDate, endedAt)
                asleepSeconds += max(0, interval.endDate.timeIntervalSince(newlyCoveredStart))
                endedAt = max(endedAt, interval.endDate)
                if !interval.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sourceNames.insert(interval.sourceName)
                }
            }
        }

        var episodes: [Episode] = []
        for interval in clipped {
            if let lastIndex = episodes.indices.last,
               interval.startDate.timeIntervalSince(episodes[lastIndex].endedAt) <= maximumAwakeGap {
                episodes[lastIndex].append(interval)
            } else {
                var episode = Episode(asleepSeconds: 0, endedAt: interval.startDate, sourceNames: [])
                episode.append(interval)
                episodes.append(episode)
            }
        }

        guard let selected = episodes.max(by: { $0.asleepSeconds < $1.asleepSeconds }),
              selected.asleepSeconds > 0 else {
            return nil
        }
        return SleepEpisodeSummary(
            asleepSeconds: selected.asleepSeconds,
            endedAt: selected.endedAt,
            sourceNames: selected.sourceNames.sorted()
        )
    }
}
