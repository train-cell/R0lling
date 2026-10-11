import XCTest
@testable import R0lling

final class JournalSearchRequestGateTests: XCTestCase {
    func testOnlyNewestSearchRequestCanApplyResults() {
        var gate = JournalSearchRequestGate()
        let slowOlderSearch = gate.beginRequest()
        let fastNewerSearch = gate.beginRequest()

        XCTAssertFalse(gate.canApplyResult(for: slowOlderSearch))
        XCTAssertTrue(gate.canApplyResult(for: fastNewerSearch))

        let nextSearch = gate.beginRequest()
        XCTAssertFalse(gate.canApplyResult(for: fastNewerSearch))
        XCTAssertTrue(gate.canApplyResult(for: nextSearch))
    }
}
