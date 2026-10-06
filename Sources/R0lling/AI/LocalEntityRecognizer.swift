import Foundation

/// Τοπικός ανιχνευτής οντοτήτων (πρόσωπα, κατοικίδια, οχήματα) για άμεση σήμανση στα καταγεγραμμένα clips
public struct LocalEntityRecognizer: Sendable {
    public init() {}

    public enum RecognizedEntity: String, CaseIterable, Sendable {
        case person = "πρόσωπο"
        case pet = "κατοικίδιο"
        case car = "αυτοκίνητο"
        case bicycle = "ποδήλατο"
        case coffee = "καφές"
        case nature = "φύση"
    }

    /// Ανάλυση ετικετών και παραμέτρων καρέ για εξαγωγή οντοτήτων
    public func detectEntities(textClues: [String]) -> [String] {
        var foundTags: [String] = []
        let joined = textClues.joined(separator: " ").lowercased()

        if joined.contains("dog") || joined.contains("cat") || joined.contains("σκύλος") || joined.contains("γάτα") {
            foundTags.append("κατοικίδιο")
        }
        if joined.contains("car") || joined.contains("αυτοκίνητο") || joined.contains("όχημα") {
            foundTags.append("αυτοκίνητο")
        }
        if joined.contains("coffee") || joined.contains("καφές") || joined.contains("κούπα") {
            foundTags.append("καφές")
        }
        if joined.contains("park") || joined.contains("δέντρο") || joined.contains("λουλούδι") {
            foundTags.append("φύση")
        }

        return Array(Set(foundTags))
    }
}
