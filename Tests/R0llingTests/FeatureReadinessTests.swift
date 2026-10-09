import XCTest
@testable import R0lling

final class FeatureReadinessTests: XCTestCase {
    func testSimulatedSensorInputsDoNotAdvertiseLiveCapture() {
        XCTAssertFalse(FeatureReadinessRegistry.acoustic.ready)
        XCTAssertFalse(FeatureReadinessRegistry.headGesture.ready)

        let uiReadyIDs = Set(FeatureReadinessRegistry.uiReadyFlags.map(\.id))
        XCTAssertFalse(uiReadyIDs.contains(FeatureReadinessRegistry.acoustic.id))
        XCTAssertFalse(uiReadyIDs.contains(FeatureReadinessRegistry.headGesture.id))
        XCTAssertTrue(FeatureReadinessRegistry.uiReadyFlags.allSatisfy(\.ready))
    }
}
