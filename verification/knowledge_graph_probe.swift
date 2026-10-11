import Foundation

@main
enum KnowledgeGraphProbe {
    static func main() {
        let engine = AssociativeKnowledgeGraphEngine()

        let unicodePatterns: [(String, String)] = [
            ("İ met with Alice", "Alice"),
            ("İ at Paris", "Paris"),
            ("İ discussed Swift", "Swift")
        ]
        for (text, expectedObject) in unicodePatterns {
            let matches = engine.extractTriples(from: text)
            precondition(matches.first?.object == expectedObject, "Unexpected extraction for: \(text)")
        }

        engine.replaceTriples(engine.extractTriples(from: "Met with Alice"))
        precondition(engine.allTriples.map(\.object) == ["Alice"])

        engine.replaceTriples(engine.extractTriples(from: "Met with Bob"))
        precondition(engine.allTriples.map(\.object) == ["Bob"])
        precondition(!engine.exportMermaidGraph().contains("Alice"))

        engine.replaceTriples([.init(
            subject: "A\"]\n    hacked --> injected",
            predicate: "knows|classDef evil;",
            object: "B\\N\""
        )])
        let mermaid = engine.exportMermaidGraph()
        precondition(mermaid.components(separatedBy: .newlines).count == 5)
        precondition(mermaid.contains("node_0[\"A#34;#93;"))
        precondition(mermaid.contains("knows#124;classDef evil#59;"))
        precondition(!mermaid.contains("hacked --> injected"))

        let dot = engine.exportGraphvizDot()
        precondition(dot.components(separatedBy: .newlines).count == 6)
        precondition(dot.contains("A\\\"]     hacked --> injected"))
        precondition(dot.contains("B\\\\N\\\""))

        print("PASS: Unicode extraction, snapshot replacement, and safe graph exports")
    }
}
