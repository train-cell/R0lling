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
}
