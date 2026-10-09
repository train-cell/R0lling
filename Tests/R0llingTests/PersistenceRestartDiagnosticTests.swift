import XCTest
@testable import R0lling

/// Διαγνωστικά Stage 3→4: R3-001 ISO8601 restart.
/// Μετά το Stage 4 fix αναμένεται PASS.
final class PersistenceRestartDiagnosticTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("R0llingRestartDiag_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let dir = tempDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    /// R3-001: save σε instance A → load από instance B στο ίδιο path πρέπει να επιστρέφει την εγγραφή.
    func testJournalSurvivesNewStorageInstance() async throws {
        let fileURL = tempDirectory.appendingPathComponent("journal_v1.json")
        let writer = JSONFileStorageService(storageURL: fileURL)

        let entry = JournalEntry(
            title: "Restart Probe",
            content: "Να πω στη Μαρία για το ταξίδι",
            source: .voice,
            tags: ["ταξίδι"]
        )
        try await writer.saveEntry(entry)

        let reader = JSONFileStorageService(storageURL: fileURL)
        let retrieved = try await reader.getEntry(id: entry.id)

        XCTAssertNotNil(
            retrieved,
            "R3-001: Η εγγραφή πρέπει να επιβιώνει σε νέο JSONFileStorageService instance (decode ISO8601)."
        )
        XCTAssertEqual(retrieved?.content, entry.content)
        XCTAssertEqual(retrieved?.tags, ["ταξίδι"])
    }
}
