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
    private let userDefaults: UserDefaults
    private let userDefaultsKey: String
    private let canPersist: Bool

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "r0lling.scavenger_streak_data"
    ) {
        self.userDefaults = userDefaults
        self.userDefaultsKey = storageKey
        if let data = userDefaults.data(forKey: storageKey) {
            do {
                self.streakData = try JSONDecoder().decode(StreakData.self, from: data)
                self.canPersist = true
            } catch {
                // Keep unreadable persisted bytes intact instead of replacing history with defaults.
                self.streakData = StreakData()
                self.canPersist = false
                print("[ScavengerHunt] Stored streak data could not be decoded: \(error.localizedDescription)")
            }
        } else {
            self.streakData = StreakData()
            self.canPersist = true
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
    /// `didPersist` = false αν υπάρχει corrupt persisted state ή το UserDefaults encode απέτυχε.
    public func recordMissionCompleted(date: Date = Date(), timeZone: TimeZone = .current) -> (newStreak: Int, newlyUnlockedBadge: String?, didPersist: Bool) {
        guard canPersist else {
            return (streakData.currentStreak, nil, false)
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: date)

        guard streakData.lastCompletedDateKey != todayKey else {
            return (streakData.currentStreak, nil, true) // Ήδη ολοκληρώθηκε σήμερα
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

        let didPersist = save()
        return (streakData.currentStreak, newBadge, didPersist)
    }

    @discardableResult
    private func save() -> Bool {
        guard canPersist else { return false }
        do {
            let encoded = try JSONEncoder().encode(streakData)
            userDefaults.set(encoded, forKey: userDefaultsKey)
            return true
        } catch {
            print("[ScavengerHunt] Persist failed: \(error.localizedDescription)")
            return false
        }
    }
}
