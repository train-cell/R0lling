import Foundation
import XCTest
import Security
@testable import R0lling

final class EncryptedDiaryStoreTests: XCTestCase {
    private var testDirectory: URL!
    private var storageURL: URL!
    private var keyTag: String!
    private var store: EncryptedDiaryStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("R0llingEncryptedStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        storageURL = testDirectory.appendingPathComponent("private.bin")
        keyTag = "test-\(UUID().uuidString)"
        store = EncryptedDiaryStore(storageURL: storageURL, keyTag: keyTag)
    }

    override func tearDownWithError() throws {
        if let keyTag {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.r0lling.vault.aes",
                kSecAttrAccount as String: keyTag
            ]
            SecItemDelete(query as CFDictionary)
        }
        if let testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
        try super.tearDownWithError()
    }

    func testDiaryCRUDPersistsEncryptedContentAcrossStoreInstances() async throws {
        store = EncryptedDiaryStore(
            testingStorageURL: storageURL,
            keyTag: keyTag,
            restoreParentBackupExclusion: true
        )
        let authorization = await store.testingAuthorization()
        let secret = "ιδιωτική φράση \(UUID().uuidString)"
        let siblingJournalURL = testDirectory.appendingPathComponent("journal.json")
        try Data("journal data".utf8).write(to: siblingJournalURL)
        var priorDirectoryValues = URLResourceValues()
        priorDirectoryValues.isExcludedFromBackup = true
        var testDirectoryURL = testDirectory!
        try testDirectoryURL.setResourceValues(priorDirectoryValues)
        let created = try await store.save(content: secret, using: authorization)
        let fileBackupFlag = try storageURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        let directoryBackupFlag = try testDirectoryURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        let siblingBackupFlag = try siblingJournalURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        XCTAssertEqual(fileBackupFlag, true)
        XCTAssertEqual(directoryBackupFlag, false, "The vault must clear a legacy exclusion on the shared journal directory.")
        XCTAssertNotEqual(siblingBackupFlag, true, "Excluding the vault must not exclude the containing journal directory.")
        let encryptedBytes = try Data(contentsOf: storageURL)
        XCTAssertNil(encryptedBytes.range(of: Data(secret.utf8)))

        let updated = try await store.save(content: "ενημερωμένη ιδιωτική φράση", editing: created.id, using: authorization)
        XCTAssertEqual(updated.id, created.id)
        XCTAssertEqual(
            try storageURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup,
            true,
            "Atomic replacement must preserve the vault backup exclusion."
        )

        let reopenedStore = EncryptedDiaryStore(storageURL: storageURL, keyTag: keyTag)
        let reopenedAuthorization = await reopenedStore.testingAuthorization()
        let restoredEntries = try await reopenedStore.entries(using: reopenedAuthorization)
        XCTAssertEqual(restoredEntries.count, 1)
        XCTAssertEqual(restoredEntries.first?.id, created.id)
        XCTAssertEqual(restoredEntries.first?.content, "ενημερωμένη ιδιωτική φράση")

        try await reopenedStore.delete(id: created.id, using: reopenedAuthorization)
        let remainingEntries = try await reopenedStore.entries(using: reopenedAuthorization)
        XCTAssertTrue(remainingEntries.isEmpty)
    }

    func testCorruptCiphertextFailsClosedAndIsNotOverwritten() async throws {
        let authorization = await store.testingAuthorization()
        _ = try await store.save(content: "original private note", using: authorization)
        let corruptBytes = Data("not a valid AES-GCM sealed box".utf8)
        try corruptBytes.write(to: storageURL, options: .atomic)

        do {
            _ = try await store.entries(using: authorization)
            XCTFail("Expected corrupt ciphertext to be rejected")
        } catch {
            XCTAssertEqual((try Data(contentsOf: storageURL)), corruptBytes)
        }

        do {
            _ = try await store.save(content: "replacement", using: authorization)
            XCTFail("A write must not replace unreadable ciphertext")
        } catch {
            XCTAssertEqual((try Data(contentsOf: storageURL)), corruptBytes)
        }
    }

    func testFutureLettersPersistAndRejectPastUnlockDate() async throws {
        let authorization = await store.testingAuthorization()
        let now = Date()
        do {
            _ = try await store.sealFutureLetter(
                titleHint: "Past",
                unlockDate: now.addingTimeInterval(-1),
                payloadText: "must reject",
                using: authorization
            )
            XCTFail("Past unlock dates must be rejected")
        } catch {
            let remainingLetters = try await store.futureLetters(using: authorization)
            XCTAssertTrue(remainingLetters.isEmpty)
        }

        let unlockDate = now.addingTimeInterval(3_600)
        let letter = try await store.sealFutureLetter(
            titleHint: "Μελλοντικό γράμμα",
            unlockDate: unlockDate,
            payloadText: "Κράτησε τις αξίες σου.",
            using: authorization
        )
        let reopenedStore = EncryptedDiaryStore(storageURL: storageURL, keyTag: keyTag)
        let reopenedAuthorization = await reopenedStore.testingAuthorization()
        let restoredLetters = try await reopenedStore.futureLetters(using: reopenedAuthorization)
        XCTAssertEqual(restoredLetters.count, 1)
        XCTAssertEqual(restoredLetters[0].id, letter.id)
        XCTAssertGreaterThan(restoredLetters[0].unlockDate, now)
        XCTAssertNil(restoredLetters[0].payloadText, "The store API must redact plaintext until the local unlock date.")
    }

    func testDecisionReviewIsDueDatedAndPersistsOutcome() async throws {
        let authorization = await store.testingAuthorization()
        let createdAt = Date()
        let reviewDate = createdAt.addingTimeInterval(86_400)
        let decision = DecisionRecord(
            decisionText: "Δοκιμαστική απόφαση",
            coreAssumptions: ["Η παραδοχή θα ελεγχθεί"],
            confidencePercent: 70,
            createdAt: createdAt,
            reviewDate: reviewDate
        )
        _ = try await store.saveDecision(decision, using: authorization)

        do {
            _ = try await store.reviewDecision(id: decision.id, outcome: "Πρόωρη", using: authorization)
            XCTFail("A decision cannot be reviewed before its due date")
        } catch {
            let earlyReviewRecords = try await store.decisionRecords(using: authorization)
            XCTAssertFalse(earlyReviewRecords[0].isReviewed)
        }

        _ = try await store.reviewDecision(
            id: decision.id,
            outcome: "Η παραδοχή επιβεβαιώθηκε",
            at: reviewDate,
            using: authorization
        )
        let reopenedStore = EncryptedDiaryStore(storageURL: storageURL, keyTag: keyTag)
        let reopenedAuthorization = await reopenedStore.testingAuthorization()
        let records = try await reopenedStore.decisionRecords(using: reopenedAuthorization)
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(records[0].isReviewed)
        XCTAssertEqual(records[0].outcomeReview, "Η παραδοχή επιβεβαιώθηκε")
    }

    func testLockedStoreRejectsReadsAndRevokedCapabilityCannotBeReused() async throws {
        let authorization = await store.testingAuthorization()
        _ = try await store.save(content: "κλειδωμένη σημείωση", using: authorization)

        await store.lock(authorization)

        do {
            _ = try await store.entries(using: authorization)
            XCTFail("A revoked vault capability must not read private data")
        } catch {
            XCTAssertEqual((error as NSError).code, 18)
        }

        do {
            _ = try await store.save(content: "μεταγενέστερη εγγραφή", using: authorization)
            XCTFail("A revoked vault capability must not mutate private data")
        } catch {
            XCTAssertEqual((error as NSError).code, 18)
        }
    }

    func testAuthorizationCannotBeReusedWithAnotherStoreInstance() async throws {
        let authorization = await store.testingAuthorization()
        let anotherStore = EncryptedDiaryStore(
            storageURL: testDirectory.appendingPathComponent("other-private.bin"),
            keyTag: "other-\(UUID().uuidString)"
        )

        do {
            _ = try await anotherStore.entries(using: authorization)
            XCTFail("A store capability must not authorize a different store instance")
        } catch {
            XCTAssertEqual((error as NSError).code, 18)
        }
    }

    func testLegacyEncryptionHelperCannotUseTheDiaryKeychainItem() async throws {
        let authorization = await store.testingAuthorization()
        _ = try await store.save(content: "private diary payload", using: authorization)
        let encryptedDocument = try Data(contentsOf: storageURL)
        let helper = ZeroKnowledgeSecureEnclaveVault()

        let bypassedPlaintext = await helper.decryptData(encryptedDocument, keyTag: keyTag)

        XCTAssertNil(bypassedPlaintext, "The generic AES helper must use a separate Keychain service from the diary.")
    }

    func testCustomStorageURLPreservesCallerDirectoryBackupPolicy() async throws {
        var priorDirectoryValues = URLResourceValues()
        priorDirectoryValues.isExcludedFromBackup = true
        var testDirectoryURL = testDirectory!
        try testDirectoryURL.setResourceValues(priorDirectoryValues)
        let authorization = await store.testingAuthorization()

        _ = try await store.save(content: "custom storage note", using: authorization)

        XCTAssertEqual(
            try testDirectoryURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup,
            true,
            "A caller-provided directory keeps its existing backup policy."
        )
        XCTAssertEqual(
            try storageURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup,
            true
        )
    }
}
