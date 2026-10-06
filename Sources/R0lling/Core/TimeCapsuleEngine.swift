import Foundation

/// Μηχανή «Σαν Σήμερα» (Time Capsule) για ανάσυρση αναμνήσεων από προηγούμενες χρονιές ή μήνες
public struct TimeCapsuleEngine: Sendable {
    public init() {}

    public struct CapsuleMemory: Identifiable, Sendable {
        public let id: UUID
        public let entry: JournalEntry
        public let yearsAgo: Int
        public let monthsAgo: Int
        public let displayText: String
    }

    /// Εντοπισμός αναμνήσεων για τη σημερινή ημερομηνία.
    /// Χρησιμοποιεί TZ εγγραφής για day/month/year της μνήμης· TZ προβολής για το «σήμερα».
    public func findTimeCapsuleEntries(
        today: Date,
        allEntries: [JournalEntry],
        displayTimeZone: TimeZone = .current
    ) -> [CapsuleMemory] {
        var displayCalendar = Calendar(identifier: .gregorian)
        displayCalendar.timeZone = displayTimeZone
        let currentDay = displayCalendar.component(.day, from: today)
        let currentMonth = displayCalendar.component(.month, from: today)
        let currentYear = displayCalendar.component(.year, from: today)

        var memories: [CapsuleMemory] = []

        for entry in allEntries {
            var entryCalendar = Calendar(identifier: .gregorian)
            entryCalendar.timeZone = TimeZone(identifier: entry.timeZoneIdentifier) ?? displayTimeZone
            let entryDay = entryCalendar.component(.day, from: entry.timestamp)
            let entryMonth = entryCalendar.component(.month, from: entry.timestamp)
            let entryYear = entryCalendar.component(.year, from: entry.timestamp)

            // Ελέγχουμε αν είναι ακριβώς η ίδια ημέρα και μήνας αλλά προηγούμενο έτος
            if entryDay == currentDay && entryMonth == currentMonth && entryYear < currentYear {
                let yearsDiff = currentYear - entryYear
                let label = "Σαν σήμερα πριν \(yearsDiff) \(yearsDiff == 1 ? "χρόνο" : "χρόνια")"
                memories.append(CapsuleMemory(
                    id: UUID(),
                    entry: entry,
                    yearsAgo: yearsDiff,
                    monthsAgo: yearsDiff * 12,
                    displayText: label
                ))
            }
            // Ή αν είναι ακριβώς η ίδια ημέρα στον προηγούμενο μήνα της ίδιας χρονιάς
            else if entryDay == currentDay && entryYear == currentYear && entryMonth < currentMonth {
                let monthsDiff = currentMonth - entryMonth
                let label = "Σαν σήμερα πριν \(monthsDiff) \(monthsDiff == 1 ? "μήνα" : "μήνες")"
                memories.append(CapsuleMemory(
                    id: UUID(),
                    entry: entry,
                    yearsAgo: 0,
                    monthsAgo: monthsDiff,
                    displayText: label
                ))
            }
        }

        return memories.sorted { $0.entry.timestamp > $1.entry.timestamp }
    }
}
