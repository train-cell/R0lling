import Foundation

/// Γεννήτρια οπτικών αρχείων Obsidian Canvas (.canvas) για εβδομαδιαία και μηνιαία ανασκόπηση
public struct ObsidianCanvasGenerator: Sendable {
    public init() {}

    public struct CanvasNode: Codable, Sendable {
        public let id: String
        public let type: String // "text" or "file"
        public let text: String?
        public let file: String?
        public let x: Int
        public let y: Int
        public let width: Int
        public let height: Int
        public let color: String?
    }

    public struct CanvasEdge: Codable, Sendable {
        public let id: String
        public let fromNode: String
        public let toNode: String
        public let label: String?
    }

    public struct CanvasDocument: Codable, Sendable {
        public let nodes: [CanvasNode]
        public let edges: [CanvasEdge]
    }

    /// Δημιουργία περιεχομένου JSON για Obsidian .canvas
    public func generateCanvasJSON(entries: [JournalEntry], title: String) -> String {
        var nodes: [CanvasNode] = []
        var edges: [CanvasEdge] = []

        // Κεντρικός κόμβος τίτλου
        let centerID = "center-node"
        nodes.append(CanvasNode(
            id: centerID,
            type: "text",
            text: "# \(title)\n\nΣύνολο καταγραφών: \(entries.count)",
            file: nil,
            x: 0,
            y: 0,
            width: 300,
            height: 140,
            color: "4" // Purple
        ))

        // Τοποθέτηση των entries γύρω από το κέντρο σε κυκλική διάταξη
        let radius = 450
        for (index, entry) in entries.prefix(12).enumerated() {
            let angle = (Double(index) / Double(min(entries.count, 12))) * (2.0 * Double.pi)
            let x = Int(Double(radius) * cos(angle))
            let y = Int(Double(radius) * sin(angle))
            let nodeID = "node-\(entry.id.uuidString.prefix(8))"

            let summaryText = "### [\(entry.formattedTime)] \(entry.source.displayName)\n\n\(entry.content.prefix(120))..."

            nodes.append(CanvasNode(
                id: nodeID,
                type: "text",
                text: summaryText,
                file: nil,
                x: x,
                y: y,
                width: 260,
                height: 160,
                color: entry.attachments.isEmpty ? "1" : "5" // Gray or Cyan
            ))

            edges.append(CanvasEdge(
                id: "edge-\(index)",
                fromNode: centerID,
                toNode: nodeID,
                label: entry.formattedTime
            ))
        }

        let doc = CanvasDocument(nodes: nodes, edges: edges)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(doc), let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }

        return "{\"nodes\":[],\"edges\":[]}"
    }
}
