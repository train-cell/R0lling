import XCTest
@testable import R0lling

final class AssociativeKnowledgeGraphEngineTests: XCTestCase {
    func testExtractionKeepsOriginalIndicesAfterUnicodeCaseExpansion() throws {
        let engine = AssociativeKnowledgeGraphEngine()

        let meeting = try XCTUnwrap(
            engine.extractTriples(from: "İ met with Alice")
                .first(where: { $0.predicate == "metWith" })
        )
        XCTAssertEqual(meeting.object, "Alice")

        let location = try XCTUnwrap(
            engine.extractTriples(from: "İ at Paris")
                .first(where: { $0.predicate == "visitedLocation" })
        )
        XCTAssertEqual(location.object, "Paris")

        let topic = try XCTUnwrap(
            engine.extractTriples(from: "İ discussed Swift")
                .first(where: { $0.predicate == "discussedTopic" })
        )
        XCTAssertEqual(topic.object, "Swift")
    }

    func testGraphExportsEscapeUntrustedLabelsAndKeepOneStatementPerTriple() {
        let engine = AssociativeKnowledgeGraphEngine()
        engine.addTriple(.init(
            subject: "Alice\"]\n    hacked --> injected",
            predicate: "knows|classDef evil;",
            object: "Bob\\N\""
        ))

        let mermaid = engine.exportMermaidGraph()
        XCTAssertEqual(mermaid.components(separatedBy: .newlines).count, 5)
        XCTAssertTrue(mermaid.contains("node_0[\"Alice#34;#93;"))
        XCTAssertTrue(mermaid.contains("knows#124;classDef evil#59;"))
        XCTAssertTrue(mermaid.contains("node_1[") && mermaid.contains("Bob#92;N#34;"))
        XCTAssertFalse(mermaid.contains("hacked --> injected"))

        let dot = engine.exportGraphvizDot()
        XCTAssertEqual(dot.components(separatedBy: .newlines).count, 6)
        XCTAssertTrue(dot.contains("Alice\\\"]     hacked --> injected"))
        XCTAssertTrue(dot.contains("label=\"knows|classDef evil;\""))
        XCTAssertTrue(dot.contains("Bob\\\\N\\\""))
    }
}
