import Foundation

@main
struct UIStateProbe {
    static func main() {
        let accessBeforeRequest = HealthKitAccessPresentation.resolve(
            hasMeasurements: false,
            didCompleteRequest: false
        )
        precondition(accessBeforeRequest.shouldShowRequestButton)
        precondition(accessBeforeRequest.explanation == nil)

        let accessAfterEmptyRequest = HealthKitAccessPresentation.resolve(
            hasMeasurements: false,
            didCompleteRequest: true
        )
        precondition(!accessAfterEmptyRequest.shouldShowRequestButton)
        precondition(accessAfterEmptyRequest.explanation != nil)
        precondition(accessAfterEmptyRequest.statusText.contains("ΑΝΑΓΝΩΣΙΜΑ"))

        let accessWithMeasurements = HealthKitAccessPresentation.resolve(
            hasMeasurements: true,
            didCompleteRequest: true
        )
        precondition(accessWithMeasurements == .measurementsAvailable)

        precondition(JournalTimeZoneIdentifier.normalized(" Europe/Athens ") == "Europe/Athens")
        precondition(JournalTimeZoneIdentifier.normalized("  ", fallback: TimeZone(secondsFromGMT: 0)!) == "GMT")
        precondition(JournalTimeZoneIdentifier.normalized("Not/A_Real_Zone") == nil)

        let weekdays = FitnessActivityWeekdayLabels.greekMondayFirst
        precondition(weekdays.count == 7)
        precondition(Set(weekdays).count == 7)
        precondition(weekdays == ["Δε", "Τρ", "Τε", "Πε", "Πα", "Σα", "Κυ"])

        var searchGate = JournalSearchRequestGate()
        let olderSearch = searchGate.beginRequest()
        let newerSearch = searchGate.beginRequest()
        precondition(!searchGate.canApplyResult(for: olderSearch))
        precondition(searchGate.canApplyResult(for: newerSearch))

        print("PASS: HealthKit prompt, journal time-zone/search, and Greek weekday UI state")
    }
}
