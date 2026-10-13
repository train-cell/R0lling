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
        // Short English keywords match whole words (plus a plural "s"): plain substring matching
        // tagged "card" as a car, "location" as a cat, "dogma" as a dog, and "parking" as nature.
        // Greek keywords keep substring matching so inflected forms such as «γάτας» still match.
        let words = Set(joined.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        func mentionsEnglishWord(_ keyword: String) -> Bool {
            words.contains(keyword) || words.contains(keyword + "s")
        }

        if mentionsEnglishWord("dog") || mentionsEnglishWord("cat") || joined.contains("σκύλος") || joined.contains("γάτα") {
            foundTags.append("κατοικίδιο")
        }
        if mentionsEnglishWord("car") || joined.contains("αυτοκίνητο") || joined.contains("όχημα") {
            foundTags.append("αυτοκίνητο")
        }
        if mentionsEnglishWord("coffee") || joined.contains("καφές") || joined.contains("κούπα") {
            foundTags.append("καφές")
        }
        if mentionsEnglishWord("park") || joined.contains("δέντρο") || joined.contains("λουλούδι") {
            foundTags.append("φύση")
        }

        // Each tag is appended at most once, in a stable category order.
        return foundTags
    }
}
