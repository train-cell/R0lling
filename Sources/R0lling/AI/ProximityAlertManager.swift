import Foundation

/// Διαχειριστής προληπτικών ειδοποιήσεων Jarvis βάσει τοποθεσίας (Proximity Alerts)
public final class ProximityAlertManager: @unchecked Sendable {
    public struct ProximityAlert: Identifiable, Sendable {
        public let id: UUID
        public let matchingLocation: String
        public let relevantOpenLoop: String
        public let alertMessage: String

        public init(id: UUID = UUID(), matchingLocation: String, relevantOpenLoop: String, alertMessage: String) {
            self.id = id
            self.matchingLocation = matchingLocation
            self.relevantOpenLoop = relevantOpenLoop
            self.alertMessage = alertMessage
        }
    }

    public init() {}

    /// Έλεγχος αν η τρέχουσα τοποθεσία σχετίζεται με εκκρεμότητες στο Open-loops.md
    public func checkProximityTriggers(currentLocationName: String, openLoopsText: String) -> [ProximityAlert] {
        let cleanLocation = currentLocationName.lowercased()
        guard !cleanLocation.isEmpty else { return [] }

        var alerts: [ProximityAlert] = []
        let lines = openLoopsText.components(separatedBy: .newlines)

        for line in lines where line.contains("- [") || line.contains("- ") {
            let lowerLine = line.lowercased()
            // Αν η γραμμή περιέχει το όνομα της τοποθεσίας ή σχετικές λέξεις
            if lowerLine.contains(cleanLocation) {
                let alert = ProximityAlert(
                    matchingLocation: currentLocationName,
                    relevantOpenLoop: line,
                    alertMessage: "📍 Jarvis: Βρίσκεσαι κοντά στο «\(currentLocationName)». Εκκρεμότητα: \(line.replacingOccurrences(of: "- ", with: ""))"
                )
                alerts.append(alert)
            }
        }

        return alerts
    }
}
