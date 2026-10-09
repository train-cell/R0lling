import XCTest
@testable import R0lling

final class FitnessActivityTests: XCTestCase {
    func testSnapshotBucketsCurrentAndPreviousThirtyDayWorkouts() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12)))
        let today = calendar.startOfDay(for: referenceDate)
        let currentStart = try XCTUnwrap(calendar.date(byAdding: .day, value: -29, to: today))
        let previousStart = try XCTUnwrap(calendar.date(byAdding: .day, value: -30, to: currentStart))
        let oldWorkout = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: previousStart))
        let futureWorkout = referenceDate.addingTimeInterval(60)

        let snapshot = FitnessActivitySnapshot(
            samples: [
                FitnessWorkoutSample(startedAt: currentStart.addingTimeInterval(60), durationSeconds: 600),
                FitnessWorkoutSample(startedAt: currentStart.addingTimeInterval(180), durationSeconds: 1_200),
                FitnessWorkoutSample(startedAt: today.addingTimeInterval(60), durationSeconds: 900),
                FitnessWorkoutSample(startedAt: previousStart.addingTimeInterval(60), durationSeconds: 1_800),
                FitnessWorkoutSample(startedAt: oldWorkout, durationSeconds: 3_600),
                FitnessWorkoutSample(startedAt: futureWorkout, durationSeconds: 3_600),
                FitnessWorkoutSample(startedAt: today, durationSeconds: .nan),
                FitnessWorkoutSample(startedAt: today, durationSeconds: -10)
            ],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.currentDays.count, 30)
        XCTAssertEqual(snapshot.previousDays.count, 30)
        XCTAssertEqual(snapshot.totalWorkoutCount, 3)
        XCTAssertEqual(snapshot.totalDurationSeconds, 2_700, accuracy: 0.001)
        XCTAssertEqual(snapshot.previousWorkoutCount, 1)
        XCTAssertEqual(snapshot.previousDurationSeconds, 1_800, accuracy: 0.001)
        XCTAssertEqual(snapshot.currentDays.first?.workoutCount, 2)
        XCTAssertEqual(snapshot.currentDays.last?.workoutCount, 1)
        XCTAssertTrue(snapshot.querySucceeded)
    }

    func testEmptySuccessfulAndUnavailableSnapshotsStayDistinct() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let empty = FitnessActivitySnapshot(samples: [], referenceDate: date)
        let unavailable = FitnessActivitySnapshot.unavailable(at: date)

        XCTAssertTrue(empty.querySucceeded)
        XCTAssertFalse(unavailable.querySucceeded)
        XCTAssertFalse(empty.hasCurrentWorkouts)
        XCTAssertEqual(empty.totalWorkoutCount, 0)
        XCTAssertEqual(empty.totalDurationSeconds, 0)
    }

    func testMonthGridAlignsMondayFirstAndBlanksDatesOutsideThirtyDayWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12)))
        let snapshot = FitnessActivitySnapshot(samples: [], referenceDate: referenceDate, calendar: calendar)
        let grids = FitnessActivityMonthGrid.make(from: snapshot.currentDays, calendar: calendar)

        XCTAssertEqual(grids.count, 2)
        let september = try XCTUnwrap(grids.first { calendar.component(.month, from: $0.monthStart) == 9 })
        let october = try XCTUnwrap(grids.first { calendar.component(.month, from: $0.monthStart) == 10 })
        XCTAssertEqual(september.cells.count, 35)
        XCTAssertEqual(september.cells[0], nil) // September 1, 2026 is Tuesday; Monday starts the row.
        XCTAssertEqual(september.cells[10]?.date, snapshot.rangeStart)
        XCTAssertEqual(october.cells[3]?.date, try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))))
        XCTAssertNil(october.cells[12]) // October 10 lies outside the current 30-day window.
    }

    func testCumulativeDurationSeriesUsesHoursRatherThanWorkoutCount() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12)))
        let today = calendar.startOfDay(for: referenceDate)
        let start = try XCTUnwrap(calendar.date(byAdding: .day, value: -29, to: today))
        let snapshot = FitnessActivitySnapshot(
            samples: [
                FitnessWorkoutSample(startedAt: start, durationSeconds: 3_600),
                FitnessWorkoutSample(startedAt: start.addingTimeInterval(60), durationSeconds: 1_800)
            ],
            referenceDate: referenceDate,
            calendar: calendar
        )
        let series = FitnessActivitySnapshot.cumulativeDurationHours(for: snapshot.currentDays)

        XCTAssertEqual(series.count, 30)
        XCTAssertEqual(series[0], 1.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(series.last), 1.5, accuracy: 0.0001)
    }
}
