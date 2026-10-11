import XCTest
@testable import R0lling

final class ScavengerHuntStreakManagerTests: XCTestCase {
    private func isolatedManager() throws -> (ScavengerHuntStreakManager, UserDefaults, String) {
        let suiteName = "r0lling.tests.streak.manager.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        return (ScavengerHuntStreakManager(userDefaults: defaults, storageKey: "streak"), defaults, suiteName)
    }

    private func localDate(_ day: Int, hour: Int = 12, timeZone: TimeZone) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = day
        components.hour = hour
        return try XCTUnwrap(calendar.date(from: components))
    }

    func testCurrentStreakRemainsValidOnCompletionDayAndFollowingLocalDay() throws {
        let (manager, defaults, suiteName) = try isolatedManager()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Athens"))
        let completed = try localDate(10, timeZone: timeZone)
        _ = manager.recordMissionCompleted(date: completed, timeZone: timeZone)
        let followingDay = try localDate(11, timeZone: timeZone)

        XCTAssertEqual(manager.currentStreak(asOf: completed, timeZone: timeZone), 1)
        XCTAssertEqual(manager.currentStreak(asOf: followingDay, timeZone: timeZone), 1)
        XCTAssertEqual(manager.bestStreak, 1)
    }

    func testCurrentStreakExpiresAfterMissedLocalDay() throws {
        let (manager, defaults, suiteName) = try isolatedManager()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Athens"))
        let completed = try localDate(10, timeZone: timeZone)
        _ = manager.recordMissionCompleted(date: completed, timeZone: timeZone)

        XCTAssertEqual(manager.currentStreak(asOf: try localDate(12, timeZone: timeZone), timeZone: timeZone), 0)
        XCTAssertEqual(manager.bestStreak, 1)
    }

    func testCompletionAfterGapRestartsAtOneAndPreservesBestStreak() throws {
        let (manager, defaults, suiteName) = try isolatedManager()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Athens"))
        for day in 10...12 {
            _ = manager.recordMissionCompleted(date: try localDate(day, timeZone: timeZone), timeZone: timeZone)
        }

        let restarted = manager.recordMissionCompleted(date: try localDate(14, timeZone: timeZone), timeZone: timeZone)
        XCTAssertEqual(restarted.newStreak, 1)
        XCTAssertEqual(manager.currentStreak(asOf: try localDate(14, timeZone: timeZone), timeZone: timeZone), 1)
        XCTAssertEqual(manager.bestStreak, 3)
    }

    func testStreakUsesExplicitTimezoneAcrossUTCDayBoundary() throws {
        let (manager, defaults, suiteName) = try isolatedManager()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Athens"))
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let firstCompletion = try XCTUnwrap(utcCalendar.date(from: DateComponents(
            year: 2026, month: 1, day: 2, hour: 21, minute: 30
        )))
        let secondCompletion = firstCompletion.addingTimeInterval(60 * 60)
        _ = manager.recordMissionCompleted(date: firstCompletion, timeZone: timeZone)

        let nextLocalDay = manager.recordMissionCompleted(date: secondCompletion, timeZone: timeZone)
        XCTAssertEqual(nextLocalDay.newStreak, 2)
        XCTAssertEqual(manager.currentStreak(asOf: secondCompletion, timeZone: timeZone), 2)
    }

    func testDefaultGetterExpiresStoredStreakAfterTwoDays() throws {
        let (manager, defaults, suiteName) = try isolatedManager()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date()
        let oldCompletion = now.addingTimeInterval(-3 * 24 * 60 * 60)
        _ = manager.recordMissionCompleted(date: oldCompletion, timeZone: .current)

        XCTAssertEqual(manager.currentStreak, 0)
    }
}
