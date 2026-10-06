import Foundation

/// Διαχειριστής σερί ημερών (Streaks & Badges) για το Daily Walking Scavenger Hunt
public final class ScavengerHuntStreakManager: @unchecked Sendable {
    public struct StreakData: Codable, Sendable {
        public var currentStreak: Int
        public var bestStreak: Int
        public var lastCompletedDateKey: String?
        public var unlockedBadges: [String]

        public init(currentStreak: Int = 0, bestStreak: Int = 0, lastCompletedDateKey: String? = nil, unlockedBadges: [String] = []) {
            self.currentStreak = currentStreak
            self.bestStreak = bestStreak
            self.lastCompletedDateKey = lastCompletedDateKey
            self.unlockedBadges = unlockedBadges
        }
    }

    private var streakData: StreakData
    private let userDefaultsKey = "r0lling.scavenger_streak_data"

    public init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(StreakData.self, from: data) {
            self.streakData = decoded
        } else {
            self.streakData = StreakData()
        }
    }

    public var currentStreak: Int {
        return streakData.currentStreak
    }

    public var bestStreak: Int {
        return streakData.bestStreak
    }

    public var badges: [String] {
        return streakData.unlockedBadges
    }

    /// Καταγραφή ολοκλήρωσης σημερινής αποστολής (ημερολογιακά κλειδιά σε ρητό TimeZone).
    public func recordMissionCompleted(date: Date = Date(), timeZone: TimeZone = .current) -> (newStreak: Int, newlyUnlockedBadge: String?) {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: date)

        guard streakData.lastCompletedDateKey != todayKey else {
            return (streakData.currentStreak, nil) // Ήδη ολοκληρώθηκε σήμερα
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        let yesterdayKey = formatter.string(from: yesterday)

        if streakData.lastCompletedDateKey == yesterdayKey {
            streakData.currentStreak += 1
        } else {
            streakData.currentStreak = 1 // Επανεκκίνηση σερί
        }

        if streakData.currentStreak > streakData.bestStreak {
            streakData.bestStreak = streakData.currentStreak
        }
        streakData.lastCompletedDateKey = todayKey

        // Έλεγχος νέων Badges — χωρίς force unwrap (G5-004).
        var newBadge: String?
        if streakData.currentStreak == 3 && !streakData.unlockedBadges.contains("Bronze Explorer (3 Days)") {
            newBadge = "Bronze Explorer (3 Days)"
        } else if streakData.currentStreak == 7 && !streakData.unlockedBadges.contains("Silver Scavenger (7 Days)") {
            newBadge = "Silver Scavenger (7 Days)"
        } else if streakData.currentStreak == 30 && !streakData.unlockedBadges.contains("Gold Master Watcher (30 Days)") {
            newBadge = "Gold Master Watcher (30 Days)"
        }
        if let badge = newBadge {
            streakData.unlockedBadges.append(badge)
        }

        save()
        return (streakData.currentStreak, newBadge)
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(streakData) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
}
