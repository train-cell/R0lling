import Foundation

/// A HealthKit workout reduced to the values used by the activity view.
public struct FitnessWorkoutSample: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let startedAt: Date
    public let durationSeconds: TimeInterval
    public let activityName: String

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        durationSeconds: TimeInterval,
        activityName: String = "Προπόνηση"
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.activityName = activityName
    }
}

public struct FitnessActivityDay: Identifiable, Sendable, Equatable {
    public let date: Date
    public let workouts: [FitnessWorkoutSample]

    public var workoutCount: Int { workouts.count }
    public var durationSeconds: TimeInterval { workouts.reduce(0) { $0 + $1.durationSeconds } }

    public var id: Date { date }
}

public enum FitnessActivityCalendar {
    public static let athensTimeZoneIdentifier = "Europe/Athens"

    public static var athensCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "el_GR")
        calendar.timeZone = TimeZone(identifier: athensTimeZoneIdentifier) ?? .current
        return calendar
    }

    public static func formatted(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.calendar = athensCalendar
        formatter.timeZone = athensCalendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}

public enum FitnessActivityWeekdayLabels {
    /// Distinct short Greek labels, Monday first to match the month-grid cell order.
    public static let greekMondayFirst = ["Δε", "Τρ", "Τε", "Πε", "Πα", "Σα", "Κυ"]
}

/// Month layout for the rolling workout window. `nil` cells are dates outside that window.
public struct FitnessActivityMonthGrid: Identifiable, Sendable, Equatable {
    public let monthStart: Date
    public let cells: [FitnessActivityDay?]

    public var id: Date { monthStart }

    public static func make(
        from days: [FitnessActivityDay],
        calendar: Calendar = FitnessActivityCalendar.athensCalendar
    ) -> [Self] {
        let dayByDate = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
        let monthStarts = Set(days.compactMap {
            calendar.dateInterval(of: .month, for: $0.date)?.start
        }).sorted()

        return monthStarts.map { monthStart in
            var cells = [FitnessActivityDay?](
                repeating: nil,
                count: (calendar.component(.weekday, from: monthStart) + 5) % 7
            )
            let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? (1..<1)
            for dayNumber in dayRange {
                guard let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart) else {
                    cells.append(nil)
                    continue
                }
                cells.append(dayByDate[calendar.startOfDay(for: date)])
            }
            while cells.count % 7 != 0 { cells.append(nil) }
            return Self(monthStart: monthStart, cells: cells)
        }
    }
}

/// Source-backed workout totals for a rolling 30-day window and its prior comparison window.
public struct FitnessActivitySnapshot: Sendable, Equatable {
    public let rangeStart: Date
    public let referenceDate: Date
    public let currentDays: [FitnessActivityDay]
    public let previousDays: [FitnessActivityDay]
    /// False means HealthKit was unavailable or the query failed. An empty successful query
    /// can still mean no workouts or an ungranted HealthKit read permission.
    public let querySucceeded: Bool

    public var totalWorkoutCount: Int { currentDays.reduce(0) { $0 + $1.workoutCount } }
    public var totalDurationSeconds: TimeInterval { currentDays.reduce(0) { $0 + $1.durationSeconds } }
    public var previousWorkoutCount: Int { previousDays.reduce(0) { $0 + $1.workoutCount } }
    public var previousDurationSeconds: TimeInterval { previousDays.reduce(0) { $0 + $1.durationSeconds } }
    public var hasCurrentWorkouts: Bool { totalWorkoutCount > 0 }

    public static func cumulativeDurationHours(for days: [FitnessActivityDay]) -> [Double] {
        var total: TimeInterval = 0
        return days.map { day in
            total += day.durationSeconds
            return total / 3_600
        }
    }

    public init(
        samples: [FitnessWorkoutSample],
        referenceDate: Date = Date(),
        calendar: Calendar = FitnessActivityCalendar.athensCalendar,
        querySucceeded: Bool = true
    ) {
        let currentDay = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .day, value: -29, to: currentDay) ?? currentDay
        let previousStart = calendar.date(byAdding: .day, value: -30, to: start) ?? start
        self.rangeStart = start
        self.referenceDate = referenceDate
        self.querySucceeded = querySucceeded

        var currentBuckets: [Date: [FitnessWorkoutSample]] = [:]
        var previousBuckets: [Date: [FitnessWorkoutSample]] = [:]

        for sample in samples {
            guard sample.startedAt <= referenceDate,
                  sample.durationSeconds.isFinite,
                  sample.durationSeconds > 0 else { continue }
            let day = calendar.startOfDay(for: sample.startedAt)
            if day >= start && day <= currentDay {
                currentBuckets[day, default: []].append(sample)
            } else if day >= previousStart && day < start {
                previousBuckets[day, default: []].append(sample)
            }
        }

        self.currentDays = Self.makeDays(
            beginningAt: start,
            calendar: calendar,
            buckets: currentBuckets
        )
        self.previousDays = Self.makeDays(
            beginningAt: previousStart,
            calendar: calendar,
            buckets: previousBuckets
        )
    }

    public static func unavailable(
        at date: Date = Date(),
        calendar: Calendar = FitnessActivityCalendar.athensCalendar
    ) -> Self {
        Self(samples: [], referenceDate: date, calendar: calendar, querySucceeded: false)
    }

    private static func makeDays(
        beginningAt start: Date,
        calendar: Calendar,
        buckets: [Date: [FitnessWorkoutSample]]
    ) -> [FitnessActivityDay] {
        (0..<30).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let workouts = (buckets[date] ?? []).sorted { $0.startedAt < $1.startedAt }
            return FitnessActivityDay(date: date, workouts: workouts)
        }
    }
}
