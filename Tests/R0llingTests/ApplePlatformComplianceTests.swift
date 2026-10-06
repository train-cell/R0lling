import XCTest
@testable import R0lling

/// Επαλήθευση συμμόρφωσης με τις πολιτικές ασφαλείας και αδειών της Apple (ATS, Permissions, Sandbox Path Security).
final class ApplePlatformComplianceTests: XCTestCase {

    func testAppTransportSecurityLocalNetworkingAllowedOnlyForLAN() throws {
        // Direct cloud APIs επιτρέπονται ΜΟΝΟ μέσω HTTPS
        XCTAssertThrowsError(try HermesEndpointAsfaleia.epikyroseDirectBaseURL("http://api.openai.com/v1"))

        let validDirect = try HermesEndpointAsfaleia.epikyroseDirectBaseURL("https://api.openai.com/v1")
        XCTAssertEqual(validDirect.scheme, "https")

        // Hermes στο Home PC επιτρέπεται σε cleartext HTTP ΜΟΝΟ σε RFC1918 LAN ή localhost
        let validLan = try HermesEndpointAsfaleia.epikyroseHermesBaseURL("http://192.168.1.50:8000")
        XCTAssertEqual(validLan.host, "192.168.1.50")

        let validLocal = try HermesEndpointAsfaleia.epikyroseHermesBaseURL("http://127.0.0.1:8000")
        XCTAssertEqual(validLocal.host, "127.0.0.1")

        // Δημόσιο μη ασφαλές HTTP στον Hermes απορρίπτεται κατηγορηματικά
        XCTAssertThrowsError(try HermesEndpointAsfaleia.epikyroseHermesBaseURL("http://public-server.com/api"))
    }

    func testApplePermissionErrorCodesRegistered() {
        XCTAssertEqual(AppErrorTaxonomy.permissionCameraDenied, 8001)
        XCTAssertEqual(AppErrorTaxonomy.permissionMicrophoneDenied, 8002)
        XCTAssertEqual(AppErrorTaxonomy.permissionSpeechDenied, 8003)
        XCTAssertEqual(AppErrorTaxonomy.permissionPhotosDenied, 8004)
        XCTAssertEqual(AppErrorTaxonomy.permissionBluetoothDenied, 8005)
        XCTAssertEqual(AppErrorTaxonomy.permissionLocalNetworkDenied, 8006)

        let permErr = AppErrorTaxonomy.makeError(
            domain: AppErrorTaxonomy.permissionDomain,
            code: AppErrorTaxonomy.permissionCameraDenied,
            message: "Η πρόσβαση στην κάμερα δεν επετράπη."
        )
        XCTAssertTrue(AppErrorTaxonomy.isTypedAppError(permErr))
    }

    func testSandboxPathTraversalGuard() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        // Path traversal με .. πρέπει να απορρίπτεται
        XCTAssertThrowsError(
            try PathAsfaleia.asfalhs_resolved_url(
                relativePath: "../../../System/Library",
                baseDirectory: tempDir
            )
        )

        // Κανονικό σχετικό μονοπάτι εντός του sandbox είναι έγκυρο
        let validURL = try? PathAsfaleia.asfalhs_resolved_url(
            relativePath: "Clips/clip_123.mp4",
            baseDirectory: tempDir
        )
        XCTAssertNotNil(validURL)
        XCTAssertTrue(validURL?.path.hasPrefix(tempDir.path) ?? false)
    }
}
