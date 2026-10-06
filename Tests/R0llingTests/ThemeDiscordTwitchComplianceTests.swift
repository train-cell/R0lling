import XCTest
import SwiftUI
@testable import R0lling

/// Επαλήθευση συμμόρφωσης UI χρωμάτων με την αισθητική Discord × Twitch
/// και ρητή απαγόρευση πορτοκαλί / κόκκινου σε κανονικές καταστάσεις.
final class ThemeDiscordTwitchComplianceTests: XCTestCase {

    func testDiscordTwitchColorHexValues() {
        // Discord Dark Cold Surfaces
        XCTAssertNotNil(R0llingTheme.bgPrimary)
        XCTAssertNotNil(R0llingTheme.bgSurface)
        XCTAssertNotNil(R0llingTheme.bgElevated)
        XCTAssertNotNil(R0llingTheme.borderSubtle)

        // Twitch & Discord Accents
        XCTAssertNotNil(R0llingTheme.accentPurple)
        XCTAssertNotNil(R0llingTheme.accentTwitch)
        XCTAssertNotNil(R0llingTheme.accentLavender)
        XCTAssertNotNil(R0llingTheme.accentCyan)

        // Status
        XCTAssertNotNil(R0llingTheme.statusLive)
        XCTAssertNotNil(R0llingTheme.statusSuccess)
        XCTAssertNotNil(R0llingTheme.statusWarning)
        XCTAssertNotNil(R0llingTheme.statusError)
    }

    func testBackwardCompatibilityAliasesPointToColdPurple() {
        // Όλα τα παλιά aliases (stravaOrange, stravaFlame) πρέπει να έχουν ανακατευθυνθεί
        // αυστηρά σε Twitch Purple (#7742DC) και Lavender (#A78BFA)
        XCTAssertEqual(R0llingTheme.stravaOrange, R0llingTheme.accentPurple)
        XCTAssertEqual(R0llingTheme.stravaFlame, R0llingTheme.accentLavender)
        XCTAssertEqual(R0llingTheme.statusLive, R0llingTheme.accentPurple)
    }

    func testGradientsArePurpleTwitchOriented() {
        XCTAssertNotNil(R0llingTheme.primaryButtonGradient)
        XCTAssertNotNil(R0llingTheme.twitchRingGradient)
        XCTAssertNotNil(R0llingTheme.heroCardGradient)
    }
}
