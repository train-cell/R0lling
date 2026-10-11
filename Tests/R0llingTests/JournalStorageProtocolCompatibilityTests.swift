import XCTest
@testable import R0lling

final class JournalStorageProtocolCompatibilityTests: XCTestCase {
    func testLegacyConformerUsesSafeDefaultsForNewAtomicOperations() async {
        let storage: any JournalStorageProtocol = LegacyJournalStorageStub()
        let entry = JournalEntry(content: "Compatibility probe")
        let attachment = MediaAttachment(
            relativePath: "Photos/probe.jpg",
            mediaType: .photo,
            byteSize: 1
        )

        do {
            _ = try await storage.updateEntryIfPresent(entry)
            XCTFail("A legacy conformer must not claim an atomic update it cannot provide")
        } catch let error as JournalStorageOperationError {
            guard case .atomicUpdateUnsupported = error else {
                return XCTFail("Unexpected storage error: \(error)")
            }
        } catch {
            XCTFail("Unexpected storage error: \(error)")
        }

        do {
            _ = try await storage.appendAttachmentIfPresent(attachment, toEntryID: entry.id)
            XCTFail("A legacy conformer must not claim an atomic append it cannot provide")
        } catch let error as JournalStorageOperationError {
            guard case .atomicAttachmentAppendUnsupported = error else {
                return XCTFail("Unexpected storage error: \(error)")
            }
        } catch {
            XCTFail("Unexpected storage error: \(error)")
        }
    }
}

/// Implements the protocol as it existed before the atomic mutation methods were added.
private actor LegacyJournalStorageStub: JournalStorageProtocol {
    func saveEntry(_ entry: JournalEntry) async throws {}

    func insertEntriesIfAbsentAtomically(_ entries: [JournalEntry]) async throws -> Set<UUID> { [] }

    func deleteEntry(id: UUID) async throws {}

    func getEntry(id: UUID) async throws -> JournalEntry? { nil }

    func getEntriesForDate(_ date: Date) async throws -> [JournalEntry] { [] }

    func getAllEntries() async throws -> [JournalEntry] { [] }

    func searchEntries(query: String, tag: String?, source: EntrySource?) async throws -> [JournalEntry] { [] }

    func getDatesWithEntries() async throws -> Set<String> { [] }
}
