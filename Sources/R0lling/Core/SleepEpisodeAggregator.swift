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
    public let startedAt: Date
    public let endedAt: Date
    public let sourceNames: [String]
}

public enum SleepStageCategory: String, Codable, CaseIterable, Sendable, Equatable {
    case awake
    case rem
    case deep
    case core
    case asleepUnspecified

    public var displayName: String {
        switch self {
        case .awake: "Ξύπνιος/α"
        case .rem: "REM"
        case .deep: "Βαθύς ύπνος"
        case .core: "Ελαφρύς ύπνος"
        case .asleepUnspecified: "Ύπνος χωρίς φάση"
        }
    }

    fileprivate var overlapPriority: Int {
        switch self {
        case .awake: 5
        case .rem, .deep, .core: 4
        case .asleepUnspecified: 1
        }
    }

    fileprivate var countsTowardSleep: Bool {
        self != .awake
    }
}

/// A stage reported by HealthKit, including the original source attribution.
public struct SleepStageSample: Sendable, Equatable {
    public let startDate: Date
    public let endDate: Date
    public let stage: SleepStageCategory
    public let sourceName: String

    public init(startDate: Date, endDate: Date, stage: SleepStageCategory, sourceName: String) {
        self.startDate = startDate
        self.endDate = endDate
        self.stage = stage
        self.sourceName = sourceName
    }
}

public struct SleepTimelineSegment: Codable, Sendable, Equatable, Identifiable {
    public let startDate: Date
    public let endDate: Date
    public let stage: SleepStageCategory
    public let sourceNames: [String]

    public var id: String {
        "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)-\(stage.rawValue)"
    }

    public init(startDate: Date, endDate: Date, stage: SleepStageCategory, sourceNames: [String]) {
        self.startDate = startDate
        self.endDate = endDate
        self.stage = stage
        self.sourceNames = sourceNames
    }

    public var durationSeconds: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

public struct SleepStageDuration: Codable, Sendable, Equatable, Identifiable {
    public let stage: SleepStageCategory
    public let durationSeconds: TimeInterval
    public var id: String { stage.rawValue }

    public init(stage: SleepStageCategory, durationSeconds: TimeInterval) {
        self.stage = stage
        self.durationSeconds = durationSeconds
    }
}

/// Overnight metric shown in the sleep detail. Values use display units after conversion from HealthKit.
public enum SleepVitalMetric: String, Codable, CaseIterable, Hashable, Sendable, Equatable {
    case heartRate
    case heartRateVariability
    case respiratoryRate
    case oxygenSaturation

    public var shortName: String {
        switch self {
        case .heartRate: "HR"
        case .heartRateVariability: "HRV"
        case .respiratoryRate: "RR"
        case .oxygenSaturation: "SpO₂"
        }
    }

    public var displayName: String {
        switch self {
        case .heartRate: "Καρδιακός ρυθμός"
        case .heartRateVariability: "Μεταβλητότητα καρδιακού ρυθμού"
        case .respiratoryRate: "Αναπνευστικός ρυθμός"
        case .oxygenSaturation: "Κορεσμός οξυγόνου"
        }
    }

    public var unitName: String {
        switch self {
        case .heartRate: "bpm"
        case .heartRateVariability: "ms"
        case .respiratoryRate: "αναπνοές/λεπτό"
        case .oxygenSaturation: "%"
        }
    }

    /// Converts a raw HealthKit unit value to the unit presented in the UI.
    public func normalizedValue(fromHealthKitUnit value: Double) -> Double? {
        guard value.isFinite, value > 0 else { return nil }
        let normalized: Double
        switch self {
        case .heartRate, .respiratoryRate:
            normalized = value
        case .heartRateVariability:
            normalized = value * 1_000 // HealthKit seconds → milliseconds
        case .oxygenSaturation:
            normalized = value * 100 // HealthKit fraction → percent
        }
        guard normalized.isFinite, normalized > 0 else { return nil }
        if self == .oxygenSaturation, normalized > 100 { return nil }
        return normalized
    }

    /// Chart lines break across longer gaps instead of implying unmeasured values.
    public var maximumContinuousGap: TimeInterval {
        switch self {
        case .heartRate: 15 * 60
        case .heartRateVariability: 2 * 60 * 60
        case .respiratoryRate: 60 * 60
        case .oxygenSaturation: 30 * 60
        }
    }
}

public struct SleepVitalSample: Codable, Sendable, Equatable, Identifiable {
    public let metric: SleepVitalMetric
    public let measuredAt: Date
    public let value: Double
    public let sourceName: String

    public var id: String {
        "\(metric.rawValue):\(measuredAt.timeIntervalSince1970):\(sourceName):\(value)"
    }

    public init(metric: SleepVitalMetric, measuredAt: Date, value: Double, sourceName: String) {
        self.metric = metric
        self.measuredAt = measuredAt
        self.value = value
        self.sourceName = sourceName
    }
}

/// HealthKit-backed primary sleep episode and its observed stage timeline; contains no score.
public struct SleepReportSnapshot: Codable, Sendable, Equatable {
    public let startedAt: Date
    public let endedAt: Date
    public let asleepSeconds: TimeInterval
    public let timeline: [SleepTimelineSegment]
    public let stageDurations: [SleepStageDuration]
    public let sourceNames: [String]
    private let storedVitalSamples: [SleepVitalSample]?
    private let storedVitalQueryFailures: [SleepVitalMetric]?

    public var vitalSamples: [SleepVitalSample] { storedVitalSamples ?? [] }
    public var vitalQueryFailures: [SleepVitalMetric] { storedVitalQueryFailures ?? [] }

    public var observedSpanSeconds: TimeInterval { endedAt.timeIntervalSince(startedAt) }
    public var hasDetailedStages: Bool {
        stageDurations.contains { [.rem, .deep, .core].contains($0.stage) }
    }

    public init(
        startedAt: Date,
        endedAt: Date,
        asleepSeconds: TimeInterval,
        timeline: [SleepTimelineSegment],
        stageDurations: [SleepStageDuration],
        sourceNames: [String],
        vitalSamples: [SleepVitalSample] = [],
        vitalQueryFailures: [SleepVitalMetric] = []
    ) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.asleepSeconds = asleepSeconds
        self.timeline = timeline
        self.stageDurations = stageDurations
        self.sourceNames = sourceNames
        self.storedVitalSamples = vitalSamples
        self.storedVitalQueryFailures = vitalQueryFailures
    }

    private enum CodingKeys: String, CodingKey {
        case startedAt
        case endedAt
        case asleepSeconds
        case timeline
        case stageDurations
        case sourceNames
        case storedVitalSamples = "vitalSamples"
        case storedVitalQueryFailures = "vitalQueryFailures"
    }
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
            var startedAt: Date
            var endedAt: Date
            var sourceNames: Set<String>

            mutating func append(_ interval: SleepInterval) {
                let newlyCoveredStart = max(interval.startDate, endedAt)
                asleepSeconds += max(0, interval.endDate.timeIntervalSince(newlyCoveredStart))
                startedAt = min(startedAt, interval.startDate)
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
                var episode = Episode(
                    asleepSeconds: 0,
                    startedAt: interval.startDate,
                    endedAt: interval.startDate,
                    sourceNames: []
                )
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
            startedAt: selected.startedAt,
            endedAt: selected.endedAt,
            sourceNames: selected.sourceNames.sorted()
        )
    }

    /// Reduces stage samples for the longest asleep episode. Overlapping samples are counted
    /// once; detailed stages win over unspecified sleep, and awake samples remain visible.
    public static func sleepReport(
        from samples: [SleepStageSample],
        windowStart: Date,
        windowEnd: Date,
        maximumAwakeGap: TimeInterval = defaultMaximumAwakeGap
    ) -> SleepReportSnapshot? {
        let clipped = samples.compactMap { sample -> SleepStageSample? in
            let start = max(sample.startDate, windowStart)
            let end = min(sample.endDate, windowEnd)
            guard end > start else { return nil }
            return SleepStageSample(
                startDate: start,
                endDate: end,
                stage: sample.stage,
                sourceName: sample.sourceName
            )
        }
        guard windowEnd > windowStart, maximumAwakeGap >= 0 else { return nil }
        let boundaries = Set(clipped.flatMap { [$0.startDate, $0.endDate] }).sorted()
        guard boundaries.count >= 2 else { return nil }

        var resolvedTimeline: [SleepTimelineSegment] = []
        for index in 0..<(boundaries.count - 1) {
            let start = boundaries[index]
            let end = boundaries[index + 1]
            guard end > start else { continue }
            let active = clipped.filter { $0.startDate <= start && $0.endDate >= end }
            guard let selectedStage = active.map(\.stage).max(by: {
                if $0.overlapPriority == $1.overlapPriority {
                    return SleepStageCategory.allCases.firstIndex(of: $0)! > SleepStageCategory.allCases.firstIndex(of: $1)!
                }
                return $0.overlapPriority < $1.overlapPriority
            }) else { continue }
            let sourceNames = Array(Set(active.filter { $0.stage == selectedStage }.map(\.sourceName)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })).sorted()

            if let last = resolvedTimeline.last,
               last.endDate == start,
               last.stage == selectedStage,
               last.sourceNames == sourceNames {
                resolvedTimeline[resolvedTimeline.count - 1] = SleepTimelineSegment(
                    startDate: last.startDate,
                    endDate: end,
                    stage: selectedStage,
                    sourceNames: sourceNames
                )
            } else {
                resolvedTimeline.append(SleepTimelineSegment(
                    startDate: start,
                    endDate: end,
                    stage: selectedStage,
                    sourceNames: sourceNames
                ))
            }
        }

        let resolvedAsleepIntervals = resolvedTimeline
            .filter { $0.stage.countsTowardSleep }
            .map {
                SleepInterval(
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    sourceName: $0.sourceNames.joined(separator: ", ")
                )
            }
        guard let episode = longestEpisode(
            from: resolvedAsleepIntervals,
            windowStart: windowStart,
            windowEnd: windowEnd,
            maximumAwakeGap: maximumAwakeGap
        ) else {
            return nil
        }

        let timeline = resolvedTimeline.compactMap { segment -> SleepTimelineSegment? in
            let start = max(segment.startDate, episode.startedAt)
            let end = min(segment.endDate, episode.endedAt)
            guard end > start else { return nil }
            return SleepTimelineSegment(
                startDate: start,
                endDate: end,
                stage: segment.stage,
                sourceNames: segment.sourceNames
            )
        }
        guard !timeline.isEmpty else { return nil }
        var durations: [SleepStageCategory: TimeInterval] = [:]
        for segment in timeline {
            durations[segment.stage, default: 0] += segment.durationSeconds
        }
        let asleepSeconds = timeline
            .filter { $0.stage.countsTowardSleep }
            .reduce(0) { $0 + $1.durationSeconds }
        guard asleepSeconds > 0 else { return nil }

        let sourceNames = Array(Set(timeline.flatMap(\.sourceNames))).sorted()
        return SleepReportSnapshot(
            startedAt: episode.startedAt,
            endedAt: episode.endedAt,
            asleepSeconds: asleepSeconds,
            timeline: timeline,
            stageDurations: SleepStageCategory.allCases.compactMap { stage in
                guard let duration = durations[stage], duration > 0 else { return nil }
                return SleepStageDuration(stage: stage, durationSeconds: duration)
            },
            sourceNames: sourceNames
        )
    }

    /// Clips and sorts real overnight measurements to the selected sleep episode; gaps remain absent.
    public static func attachingVitalSamples(
        _ samples: [SleepVitalSample],
        queryFailures: [SleepVitalMetric] = [],
        to report: SleepReportSnapshot
    ) -> SleepReportSnapshot {
        let clipped = samples.filter { sample in
            sample.measuredAt >= report.startedAt &&
                sample.measuredAt <= report.endedAt &&
                sample.value.isFinite && sample.value > 0 &&
                (sample.metric != .oxygenSaturation || sample.value <= 100)
        }.sorted {
            if $0.measuredAt == $1.measuredAt {
                if $0.metric == $1.metric { return $0.value < $1.value }
                return SleepVitalMetric.allCases.firstIndex(of: $0.metric)! <
                    SleepVitalMetric.allCases.firstIndex(of: $1.metric)!
            }
            return $0.measuredAt < $1.measuredAt
        }
        let vitalSources = clipped.map(\.sourceName)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let failedMetrics = Set(report.vitalQueryFailures + queryFailures).sorted {
            SleepVitalMetric.allCases.firstIndex(of: $0)! <
                SleepVitalMetric.allCases.firstIndex(of: $1)!
        }
        return SleepReportSnapshot(
            startedAt: report.startedAt,
            endedAt: report.endedAt,
            asleepSeconds: report.asleepSeconds,
            timeline: report.timeline,
            stageDurations: report.stageDurations,
            sourceNames: Array(Set(report.sourceNames + vitalSources)).sorted(),
            vitalSamples: clipped,
            vitalQueryFailures: failedMetrics
        )
    }
}
