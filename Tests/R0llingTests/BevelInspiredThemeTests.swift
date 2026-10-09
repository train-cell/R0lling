import XCTest
import SwiftUI
@testable import R0lling

final class BevelInspiredThemeTests: XCTestCase {
    func testBevelSurfaceAndMetricTokensExist() {
        XCTAssertNotNil(R0llingTheme.bgPrimary)
        XCTAssertNotNil(R0llingTheme.bgSurface)
        XCTAssertNotNil(R0llingTheme.bgElevated)
        XCTAssertNotNil(R0llingTheme.borderSubtle)
        XCTAssertNotNil(R0llingTheme.accentAmber)
        XCTAssertNotNil(R0llingTheme.accentLime)
        XCTAssertNotNil(R0llingTheme.accentCyan)
        XCTAssertNotNil(R0llingTheme.accentPurple)
    }

    func testStatusColorsAndGradientsAreAvailable() {
        XCTAssertNotNil(R0llingTheme.statusLive)
        XCTAssertNotNil(R0llingTheme.statusSuccess)
        XCTAssertNotNil(R0llingTheme.statusWarning)
        XCTAssertNotNil(R0llingTheme.statusError)
        XCTAssertNotNil(R0llingTheme.primaryButtonGradient)
        XCTAssertNotNil(R0llingTheme.bevelRingGradient)
        XCTAssertNotNil(R0llingTheme.heroCardGradient)
    }

    func testRaisedBevelSurfaceModifierIsAvailable() {
        XCTAssertEqual(R0llingBevelSurfaceModifier(cornerRadius: 22).cornerRadius, 22)
    }

    func testRaisedBevelCapsuleModifierIsAvailable() {
        XCTAssertNotNil(R0llingBevelCapsuleModifier())
    }

    func testDarkThemedFormModifierIsAvailable() {
        XCTAssertNotNil(R0llingFormSurfaceModifier())
    }
}
