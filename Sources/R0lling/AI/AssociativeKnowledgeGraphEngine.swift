import Foundation

/// Μηχανή Σημασιολογικού Συνειρμικού Γράφου Γνώσης (Associative Knowledge Graph Engine)
/// Εξάγει RDF Σημασιολογικά Τρίπλετα (Subject - Predicate - Object) από καταγραφές και φωνητικές σημειώσεις.
/// Επιτρέπει δημιουργία 3D συνειρμικών χαρτών γνώσης και εξαγωγή σε Mermaid & Graphviz για το Obsidian.
public final class AssociativeKnowledgeGraphEngine: @unchecked Sendable {
    
    public struct RDFTriple: Identifiable, Sendable, Codable, Hashable {
        public let id: UUID
        public let subject: String
        public let predicate: String
        public let object: String
        public let confidence: Float
        public let timestamp: Date
        
        public init(
            id: UUID = UUID(),
            subject: String,
            predicate: String,
            object: String,
            confidence: Float = 0.90,
            timestamp: Date = Date()
        ) {
            self.id = id
            self.subject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            self.predicate = predicate.trimmingCharacters(in: .whitespacesAndNewlines)
            self.object = object.trimmingCharacters(in: .whitespacesAndNewlines)
            self.confidence = confidence
            self.timestamp = timestamp
        }
    }
    
    private let lock = NSLock()
    private var triples: [RDFTriple] = []
    
    public init() {}
    
    /// Προσθήκη ενός τριπλέτου στο γράφο
    public func addTriple(_ triple: RDFTriple) {
        lock.lock()
        defer { lock.unlock() }
        if !triples.contains(where: { $0.subject == triple.subject && $0.predicate == triple.predicate && $0.object == triple.object }) {
            triples.append(triple)
        }
    }
    
    /// Μαζική προσθήκη τριπλέτων
    public func addTriples(_ newTriples: [RDFTriple]) {
        for t in newTriples {
            addTriple(t)
        }
    }
    
    /// Εξαγωγή τριπλέτων από κείμενο με χρήση Pattern Matching & Heuristics
    public func extractTriples(from text: String, date: Date = Date()) -> [RDFTriple] {
        var extracted: [RDFTriple] = []
        let lower = text.lowercased()
        
        // Patterns: "Συνάντηση με X", "Met with X", "Συνάντησα τον X"
        if let range = lower.range(of: "συνάντηση με ") ?? lower.range(of: "συνάντησα τον ") ?? lower.range(of: "met with ") {
            let entity = String(text[range.upperBound...]).components(separatedBy: CharacterSet(charactersIn: " .,;")).first ?? ""
            if !entity.isEmpty {
                extracted.append(RDFTriple(subject: "User", predicate: "metWith", object: entity.capitalized, timestamp: date))
            }
        }
        
        // Patterns: "Στο γραφείο", "Στο σπίτι", "at X", "στο X"
        if let range = lower.range(of: "στο ") ?? lower.range(of: "στην ") ?? lower.range(of: "στη ") ?? lower.range(of: "at ") {
            let place = String(text[range.upperBound...]).components(separatedBy: CharacterSet(charactersIn: " .,;")).first ?? ""
            if !place.isEmpty {
                extracted.append(RDFTriple(subject: "User", predicate: "visitedLocation", object: place.capitalized, timestamp: date))
            }
        }
        
        // Patterns: "Συζητήσαμε για X", "discussed X"
        if let range = lower.range(of: "συζητήσαμε για ") ?? lower.range(of: "μίλησα για ") ?? lower.range(of: "discussed ") {
            let topic = String(text[range.upperBound...]).components(separatedBy: CharacterSet(charactersIn: ".,;")).first ?? ""
            if !topic.isEmpty {
                extracted.append(RDFTriple(subject: "User", predicate: "discussedTopic", object: topic.trimmingCharacters(in: .whitespaces), timestamp: date))
            }
        }
        
        return extracted
    }
    
    /// Εξαγωγή του γράφου σε Obsidian Mermaid format (`graph TD`)
    public func exportMermaidGraph() -> String {
        lock.lock()
        let currentTriples = triples
        lock.unlock()
        
        var output = "```mermaid\ngraph TD\n"
        for t in currentTriples {
            let cleanSub = sanitizeIdentifier(t.subject)
            let cleanObj = sanitizeIdentifier(t.object)
            output += "    \(cleanSub)[\"\(t.subject)\"] -->|\"\(t.predicate)\"| \(cleanObj)[\"\(t.object)\"]\n"
        }
        output += "```\n"
        return output
    }
    
    /// Εξαγωγή του γράφου σε Graphviz DOT format
    public func exportGraphvizDot() -> String {
        lock.lock()
        let currentTriples = triples
        lock.unlock()
        
        var dot = "digraph KnowledgeGraph {\n"
        dot += "    rankdir=LR;\n"
        dot += "    node [shape=box, style=rounded, fontname=\"Helvetica\"];\n"
        for t in currentTriples {
            dot += "    \"\(t.subject)\" -> \"\(t.object)\" [label=\"\(t.predicate)\"];\n"
        }
        dot += "}\n"
        return dot
    }
    
    /// Αναζήτηση όλων των συνδέσεων ενός κόμβου
    public func findConnections(for entity: String) -> [RDFTriple] {
        lock.lock()
        defer { lock.unlock() }
        let target = entity.lowercased()
        return triples.filter { $0.subject.lowercased() == target || $0.object.lowercased() == target }
    }
    
    private func sanitizeIdentifier(_ str: String) -> String {
        return str.replacingOccurrences(of: " ", with: "_")
                  .replacingOccurrences(of: "-", with: "_")
                  .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    
    public var allTriples: [RDFTriple] {
        lock.lock()
        defer { lock.unlock() }
        return triples
    }
}
