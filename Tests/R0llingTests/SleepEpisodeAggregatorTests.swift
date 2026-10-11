import XCTest
@testable import R0lling

final class SleepEpisodeAggregatorTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testKeepsLongestNightEpisodeSeparateFromMorningNap() throws {
        let result = try XCTUnwrap(SleepEpisodeAggregator.longestEpisode(
            from: [
                SleepInterval(startDate: date(8, 23), endDate: date(9, 2), sourceName: "Watch"),
                SleepInterval(startDate: date(9, 2), endDate: date(9, 5), sourceName: "Watch"),
                SleepInterval(startDate: date(9, 10), endDate: date(9, 11), sourceName: "Phone")
            ],
            windowStart: date(8, 18),
            windowEnd: date(9, 12)
        ))

        XCTAssertEqual(result.asleepSeconds, 6 * 60 * 60, accuracy: 0.001)
        XCTAssertEqual(result.endedAt, date(9, 5))
        XCTAssertEqual(result.sourceNames, ["Watch"])
    }

    func testMergesShortAwakeGapWithoutCountingItAsSleep() throws {
        let result = try XCTUnwrap(SleepEpisodeAggregator.longestEpisode(
            from: [
                SleepInterval(startDate: date(9, 0), endDate: date(9, 2), sourceName: "Watch"),
                SleepInterval(startDate: date(9, 2, 30), endDate: date(9, 4, 30), sourceName: "Watch")
            ],
            windowStart: date(8, 18),
            windowEnd: date(9, 12),
            maximumAwakeGap: 60 * 60
        ))

        XCTAssertEqual(result.asleepSeconds, 4 * 60 * 60, accuracy: 0.001)
        XCTAssertEqual(result.endedAt, date(9, 4, 30))
    }

    func testClipsToWindowAndCountsOverlappingSourcesOnlyOnce() throws {
        let result = try XCTUnwrap(SleepEpisodeAggregator.longestEpisode(
            from: [
                SleepInterval(startDate: date(8, 17), endDate: date(8, 19), sourceName: "Watch"),
                SleepInterval(startDate: date(8, 18, 30), endDate: date(8, 20), sourceName: "Phone"),
                SleepInterval(startDate: date(9, 11), endDate: date(9, 13), sourceName: "Watch")
            ],
            windowStart: date(8, 18),
            windowEnd: date(9, 12)
        ))

        XCTAssertEqual(result.asleepSeconds, 2 * 60 * 60, accuracy: 0.001)
        XCTAssertEqual(result.endedAt, date(8, 20))
        XCTAssertEqual(result.sourceNames, ["Phone", "Watch"])
    }

    func testSleepReportClipsSampleThatStartsBeforeOvernightWindow() throws {
        let report = try XCTUnwrap(SleepEpisodeAggregator.sleepReport(
            from: [SleepStageSample(
                startDate: date(8, 17, 45),
                endDate: date(8, 18, 30),
                stage: .core,
                sourceName: "Watch"
            )],
            windowStart: date(8, 18),
            windowEnd: date(9, 12)
        ))

        XCTAssertEqual(report.startedAt, date(8, 18))
        XCTAssertEqual(report.endedAt, date(8, 18, 30))
        XCTAssertEqual(report.asleepSeconds, 30 * 60, accuracy: 0.001)
    }

    func testReturnsNilWhenThereIsNoValidSleepInsideWindow() {
        XCTAssertNil(SleepEpisodeAggregator.longestEpisode(
            from: [
                SleepInterval(startDate: date(8, 16), endDate: date(8, 17), sourceName: "Watch"),
                SleepInterval(startDate: date(9, 12), endDate: date(9, 13), sourceName: "Watch"),
                SleepInterval(startDate: date(9, 4), endDate: date(9, 4), sourceName: "Watch")
            ],
            windowStart: date(8, 18),
            windowEnd: date(9, 12)
        ))
    }

    func testSleepReportKeepsObservedStagesAwakeGapsAndPrimaryEpisode() throws {
        let report = try XCTUnwrap(SleepEpisodeAggregator.sleepReport(
            from: [
                SleepStageSample(startDate: date(8, 23), endDate: date(9, 1), stage: .core, sourceName: "Watch"),
                SleepStageSample(startDate: date(9, 1), endDate: date(9, 1, 30), stage: .awake, sourceName: "Watch"),
                SleepStageSample(startDate: date(9, 1, 30), endDate: date(9, 2), stage: .rem, sourceName: "Watch"),
                SleepStageSample(startDate: date(9, 8), endDate: date(9, 8, 30), stage: .deep, sourceName: "Phone")
            ],
            windowStart: date(8, 18),
            windowEnd: date(9, 12)
        ))

        XCTAssertEqual(report.startedAt, date(8, 23))
        XCTAssertEqual(report.endedAt, date(9, 2))
        XCTAssertEqual(report.asleepSeconds, 2.5 * 60 * 60, accuracy: 0.001)
        XCTAssertEqual(report.observedSpanSeconds, 3 * 60 * 60, accuracy: 0.001)
        XCTAssertTrue(report.hasDetailedStages)
        XCTAssertEqual(report.stageDurations.first { $0.stage == .core }?.durationSeconds, 2 * 60 * 60)
        XCTAssertEqual(report.stageDurations.first { $0.stage == .awake }?.durationSeconds, 30 * 60)
        XCTAssertEqual(report.stageDurations.first { $0.stage == .rem }?.durationSeconds, 30 * 60)
        XCTAssertFalse(report.sourceNames.contains("Phone"), "A separate nap must not leak into the primary report")
    }

    func testSleepReportCountsOverlappingSourcesOnceAndPrefersDetailedStage() throws {
        let report = try XCTUnwrap(SleepEpisodeAggregator.sleepReport(
            from: [
                SleepStageSample(startDate: date(9, 0), endDate: date(9, 2), stage: .core, sourceName: "Watch"),
                SleepStageSample(startDate: date(9, 0), endDate: date(9, 2), stage: .core, sourceName: "Phone"),
                SleepStageSample(startDate: date(9, 1), endDate: date(9, 1, 30), stage: .asleepUnspecified, sourceName: "Phone")
            ],
            windowStart: date(8, 18),
            windowEnd: date(9, 12)
        ))

        XCTAssertEqual(report.asleepSeconds, 2 * 60 * 60, accuracy: 0.001)
        XCTAssertEqual(report.stageDurations, [SleepStageDuration(stage: .core, durationSeconds: 2 * 60 * 60)])
        XCTAssertEqual(report.sourceNames, ["Phone", "Watch"])
        XCTAssertEqual(report.timeline.count, 1)
    }

    func testAwakeStageFromAnotherSourceWinsAndSummaryMatchesTimeline() throws {
        let report = try XCTUnwrap(SleepEpisodeAggregator.sleepReport(
            from: [
                SleepStageSample(startDate: date(8, 23), endDate: date(9, 7), stage: .core, sourceName: "Watch"),
                SleepStageSample(startDate: date(9, 2), endDate: date(9, 2, 30), stage: .awake, sourceName: "Phone")
            ],
            windowStart: date(8, 18),
            windowEnd: date(9, 12)
        ))

        let timelineSleepSeconds = report.timeline
            .filter { $0.stage != .awake }
            .reduce(0) { $0 + $1.durationSeconds }
        let stageDurationTotal = report.stageDurations.reduce(0) { $0 + $1.durationSeconds }

        XCTAssertEqual(report.asleepSeconds, 7.5 * 60 * 60, accuracy: 0.001)
        XCTAssertEqual(report.asleepSeconds, timelineSleepSeconds, accuracy: 0.001)
        XCTAssertEqual(stageDurationTotal, report.observedSpanSeconds, accuracy: 0.001)
        XCTAssertEqual(report.stageDurations.first { $0.stage == .awake }?.durationSeconds, 30 * 60)
    }

    func testSleepReportRequiresAtLeastOneAsleepSample() {
        XCTAssertNil(SleepEpisodeAggregator.sleepReport(
            from: [SleepStageSample(startDate: date(9, 0), endDate: date(9, 1), stage: .awake, sourceName: "Watch")],
            windowStart: date(8, 18),
            windowEnd: date(9, 12)
        ))
    }

    func testAttachesSortedVitalsOnlyInsideThePrimaryEpisodeAndPreservesGaps() throws {
        let baseReport = try XCTUnwrap(SleepEpisodeAggregator.sleepReport(
            from: [SleepStageSample(startDate: date(9, 0), endDate: date(9, 2), stage: .core, sourceName: "Watch")],
            windowStart: date(8, 18),
            windowEnd: date(9, 12)
        ))
        let attached = SleepEpisodeAggregator.attachingVitalSamples([
            SleepVitalSample(metric: .heartRate, measuredAt: date(9, 1), value: 82, sourceName: "Watch"),
            SleepVitalSample(metric: .heartRate, measuredAt: date(8, 59), value: 76, sourceName: "Watch"),
            SleepVitalSample(metric: .heartRate, measuredAt: date(9, 1, 40), value: 88, sourceName: "Watch"),
            SleepVitalSample(metric: .heartRate, measuredAt: date(9, 3), value: 70, sourceName: "Watch"),
            SleepVitalSample(metric: .oxygenSaturation, measuredAt: date(9, 1, 20), value: 101, sourceName: "Watch"),
            SleepVitalSample(metric: .heartRate, measuredAt: date(9, 1, 30), value: .nan, sourceName: "Watch")
        ], to: baseReport)

        XCTAssertEqual(attached.vitalSamples.map(\.measuredAt), [date(9, 1), date(9, 1, 40)])
        XCTAssertEqual(attached.vitalSamples.map(\.value), [82, 88])
        XCTAssertGreaterThan(
            attached.vitalSamples[1].measuredAt.timeIntervalSince(attached.vitalSamples[0].measuredAt),
            SleepVitalMetric.heartRate.maximumContinuousGap
        )
        XCTAssertEqual(attached.sourceNames, ["Watch"])
    }

    func testNormalizesHealthKitUnitsAndRejectsInvalidValues() {
        XCTAssertEqual(SleepVitalMetric.heartRateVariability.normalizedValue(fromHealthKitUnit: 0.032) ?? -1, 32, accuracy: 0.0001)
        XCTAssertEqual(SleepVitalMetric.oxygenSaturation.normalizedValue(fromHealthKitUnit: 0.97) ?? -1, 97, accuracy: 0.0001)
        XCTAssertEqual(SleepVitalMetric.heartRate.normalizedValue(fromHealthKitUnit: 62) ?? -1, 62, accuracy: 0.0001)
        XCTAssertNil(SleepVitalMetric.oxygenSaturation.normalizedValue(fromHealthKitUnit: 1.04))
        XCTAssertNil(SleepVitalMetric.respiratoryRate.normalizedValue(fromHealthKitUnit: .nan))
    }

    func testEmptyVitalsRemainEmptyAndLegacyReportDecodesWithoutVitals() throws {
        let report = try XCTUnwrap(SleepEpisodeAggregator.sleepReport(
            from: [SleepStageSample(startDate: date(9, 0), endDate: date(9, 2), stage: .core, sourceName: "Watch")],
            windowStart: date(8, 18),
            windowEnd: date(9, 12)
        ))
        XCTAssertTrue(SleepEpisodeAggregator.attachingVitalSamples([], to: report).vitalSamples.isEmpty)

        let encoded = try JSONEncoder().encode(report)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "vitalSamples")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(SleepReportSnapshot.self, from: legacyData)
        XCTAssertTrue(decoded.vitalSamples.isEmpty)
    }

    func testVitalQueryFailuresRemainDistinctFromSuccessfulEmptyQueries() throws {
        let report = try XCTUnwrap(SleepEpisodeAggregator.sleepReport(
            from: [SleepStageSample(startDate: date(9, 0), endDate: date(9, 2), stage: .core, sourceName: "Watch")],
            windowStart: date(8, 18),
            windowEnd: date(9, 12)
        ))

        let successfulEmpty = SleepEpisodeAggregator.attachingVitalSamples([], to: report)
        XCTAssertTrue(successfulEmpty.vitalSamples.isEmpty)
        XCTAssertTrue(successfulEmpty.vitalQueryFailures.isEmpty)

        let failedQuery = SleepEpisodeAggregator.attachingVitalSamples(
            [],
            queryFailures: [.respiratoryRate, .heartRate],
            to: report
        )
        XCTAssertTrue(failedQuery.vitalSamples.isEmpty)
        XCTAssertEqual(failedQuery.vitalQueryFailures, [.heartRate, .respiratoryRate])

        let encoded = try JSONEncoder().encode(failedQuery)
        let decoded = try JSONDecoder().decode(SleepReportSnapshot.self, from: encoded)
        XCTAssertEqual(decoded.vitalQueryFailures, [.heartRate, .respiratoryRate])
    }
}
