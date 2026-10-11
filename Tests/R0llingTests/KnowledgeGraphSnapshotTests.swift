import XCTest
@testable import R0lling

final class KnowledgeGraphSnapshotTests: XCTestCase {
    func testReplacingSnapshotDropsTriplesFromEarlierExport() {
        let engine = AssociativeKnowledgeGraphEngine()

        engine.replaceTriples(engine.extractTriples(from: "Met with Alice"))
        XCTAssertEqual(engine.allTriples.map(\.object), ["Alice"])

        engine.replaceTriples(engine.extractTriples(from: "Met with Bob"))

        XCTAssertEqual(engine.allTriples.map(\.object), ["Bob"])
        XCTAssertFalse(engine.exportMermaidGraph().contains("Alice"))
        XCTAssertTrue(engine.exportMermaidGraph().contains("Bob"))
    }

    func testReplacingSnapshotDeduplicatesTriples() {
        let engine = AssociativeKnowledgeGraphEngine()
        let triple = AssociativeKnowledgeGraphEngine.RDFTriple(
            subject: "User",
            predicate: "metWith",
            object: "Alice"
        )

        engine.replaceTriples([triple, triple])

        XCTAssertEqual(engine.allTriples.count, 1)
    }
}
