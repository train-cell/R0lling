import XCTest
@testable import R0lling

final class KeychainSecretStoreTests: XCTestCase {
    func testCheckedDeleteRemovesStoredSecret() throws {
        let key = "r0lling.test.\(UUID().uuidString)"
        defer { try? KeychainSecretStore.deleteChecked(forKey: key) }

        try KeychainSecretStore.store(value: "temporary-secret", forKey: key)
        XCTAssertEqual(KeychainSecretStore.retrieve(forKey: key), "temporary-secret")

        try KeychainSecretStore.deleteChecked(forKey: key)
        XCTAssertNil(KeychainSecretStore.retrieve(forKey: key))
    }
}
