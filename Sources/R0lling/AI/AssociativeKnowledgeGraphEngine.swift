import Foundation

/// Local pattern-based helper for extracting a small set of candidate relations from journal text.
/// Its triples are not a general RDF model, and it does not build a 3D graph.
/// It exports the extracted relations as Mermaid or Graphviz text for Obsidian.
public final class AssociativeKnowledgeGraphEngine: @unchecked Sendable {
    
    /// Lightweight subject-predicate-object value used by the local heuristic extractor.
    /// The existing type name does not imply RDF ontology or inference support.
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

    /// Replace the graph with one complete snapshot (for example, the entries
    /// selected for a single export) without retaining triples from earlier runs.
    public func replaceTriples(_ snapshot: [RDFTriple]) {
        lock.lock()
        defer { lock.unlock() }

        var replacement: [RDFTriple] = []
        for triple in snapshot where !replacement.contains(where: {
            $0.subject == triple.subject && $0.predicate == triple.predicate && $0.object == triple.object
        }) {
            replacement.append(triple)
        }
        triples = replacement
    }
    
    /// Εξαγωγή τριπλέτων από κείμενο με χρήση Pattern Matching & Heuristics
    public func extractTriples(from text: String, date: Date = Date()) -> [RDFTriple] {
        var extracted: [RDFTriple] = []
        
        let tokenSeparators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;"))

        // Patterns: "Συνάντηση με X", "Met with X", "Συνάντησα τον X"
        if let range = firstCaseInsensitiveRange(
            in: text,
            matching: ["συνάντηση με ", "συνάντησα τον ", "met with "]
        ) {
            let entity = firstTrimmedCandidate(in: text, after: range, separatedBy: tokenSeparators)
            if !entity.isEmpty {
                extracted.append(RDFTriple(subject: "User", predicate: "metWith", object: entity.capitalized, timestamp: date))
            }
        }
        
        // Patterns: "Στο γραφείο", "Στο σπίτι", "at X", "στο X"
        if let range = firstCaseInsensitiveRange(
            in: text,
            matching: ["στο ", "στην ", "στη ", "at "]
        ) {
            let place = firstTrimmedCandidate(in: text, after: range, separatedBy: tokenSeparators)
            if !place.isEmpty {
                extracted.append(RDFTriple(subject: "User", predicate: "visitedLocation", object: place.capitalized, timestamp: date))
            }
        }
        
        // Patterns: "Συζητήσαμε για X", "discussed X"
        if let range = firstCaseInsensitiveRange(
            in: text,
            matching: ["συζητήσαμε για ", "μίλησα για ", "discussed "]
        ) {
            let topic = firstTrimmedCandidate(
                in: text,
                after: range,
                separatedBy: CharacterSet(charactersIn: ".,;")
            )
            if !topic.isEmpty {
                extracted.append(RDFTriple(subject: "User", predicate: "discussedTopic", object: topic, timestamp: date))
            }
        }
        
        return extracted
    }

    private func firstCaseInsensitiveRange(in text: String, matching patterns: [String]) -> Range<String.Index>? {
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .caseInsensitive) {
                return range
            }
        }
        return nil
    }

    private func firstTrimmedCandidate(
        in text: String,
        after range: Range<String.Index>,
        separatedBy separators: CharacterSet
    ) -> String {
        String(text[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: separators)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    /// Εξαγωγή του γράφου σε Obsidian Mermaid format (`graph TD`)
    public func exportMermaidGraph() -> String {
        lock.lock()
        let currentTriples = triples
        lock.unlock()
        
        var output = "```mermaid\ngraph TD\n"
        var nodeIDs: [String: String] = [:]
        func nodeID(for label: String) -> String {
            if let existingID = nodeIDs[label] { return existingID }
            let newID = "node_\(nodeIDs.count)"
            nodeIDs[label] = newID
            return newID
        }

        for t in currentTriples {
            let subjectID = nodeID(for: t.subject)
            let objectID = nodeID(for: t.object)
            output += "    \(subjectID)[\"\(mermaidLabel(t.subject))\"] -->|\(mermaidLabel(t.predicate))| \(objectID)[\"\(mermaidLabel(t.object))\"]\n"
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
            dot += "    \"\(graphvizString(t.subject))\" -> \"\(graphvizString(t.object))\" [label=\"\(graphvizString(t.predicate))\"];\n"
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
    
    /// Mermaid flowchart labels accept decimal entity codes for reserved syntax.
    /// Encoding punctuation (including `#`) prevents source text from creating
    /// statements or injecting entity references; line breaks become spaces.
    private func mermaidLabel(_ value: String) -> String {
        value.unicodeScalars.map { scalar in
            if CharacterSet.alphanumerics.contains(scalar) { return String(scalar) }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) || CharacterSet.controlCharacters.contains(scalar) {
                return " "
            }
            return "#\(scalar.value);"
        }.joined()
    }

    /// Escape Graphviz quoted strings and neutralize controls so source text stays
    /// inside one DOT statement. Backslashes are doubled to avoid escString codes.
    private func graphvizString(_ value: String) -> String {
        value.unicodeScalars.map { scalar in
            if CharacterSet.whitespacesAndNewlines.contains(scalar) || CharacterSet.controlCharacters.contains(scalar) {
                return " "
            }
            switch scalar.value {
            case 0x5C: return "\\\\"
            case 0x22: return "\\\""
            default: return String(scalar)
            }
        }.joined()
    }
    
    public var allTriples: [RDFTriple] {
        lock.lock()
        defer { lock.unlock() }
        return triples
    }
}
