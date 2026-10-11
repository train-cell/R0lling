import Foundation

/// Honest UI state for HealthKit reads, which do not reveal per-type authorization.
enum HealthKitAccessPresentation: Equatable {
    case measurementsAvailable
    case requestAccess
    case noReadableMeasurements

    static func resolve(hasMeasurements: Bool, didCompleteRequest: Bool) -> Self {
        if hasMeasurements { return .measurementsAvailable }
        return didCompleteRequest ? .noReadableMeasurements : .requestAccess
    }

    var statusText: String {
        switch self {
        case .measurementsAvailable: "ΜΕΤΡΗΣΕΙΣ ΔΙΑΘΕΣΙΜΕΣ"
        case .requestAccess: "ΔΕΝ ΕΧΕΙ ΓΙΝΕΙ ΑΙΤΗΜΑ"
        case .noReadableMeasurements: "ΧΩΡΙΣ ΑΝΑΓΝΩΣΙΜΑ ΔΕΔΟΜΕΝΑ"
        }
    }

    var shouldShowRequestButton: Bool {
        self == .requestAccess
    }

    var explanation: String? {
        guard self == .noReadableMeasurements else { return nil }
        return "Το HealthKit δεν αποκαλύπτει αν η πρόσβαση απορρίφθηκε ή αν δεν υπάρχουν πρόσφατες μετρήσεις. Έλεγξε την πρόσβαση στην εφαρμογή Υγεία."
    }
}
