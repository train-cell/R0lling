import XCTest
@testable import R0lling
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class BoundedRegularFileReaderTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BoundedFileRead_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testReadsRegularFileAtLimit() throws {
        let url = tempDirectory.appendingPathComponent("small.txt")
        let expected = Data("bounded text".utf8)
        try expected.write(to: url)

        XCTAssertEqual(try BoundedRegularFileReader.readData(at: url, maximumBytes: expected.count), expected)
    }

    func testRejectsOversizedRegularFile() throws {
        let url = tempDirectory.appendingPathComponent("large.txt")
        try Data("12345".utf8).write(to: url)

        XCTAssertThrowsError(try BoundedRegularFileReader.readData(at: url, maximumBytes: 4)) { error in
            XCTAssertEqual(error as? BoundedRegularFileReaderError, .exceedsMaximumBytes(4))
        }
    }

    func testRejectsDirectoryWithoutReadingIt() throws {
        XCTAssertThrowsError(try BoundedRegularFileReader.readData(at: tempDirectory, maximumBytes: 32)) { error in
            XCTAssertEqual(error as? BoundedRegularFileReaderError, .notRegularFile)
        }
    }

    func testRejectsSymlinkedVaultParent() throws {
        let vault = tempDirectory.appendingPathComponent("Vault", isDirectory: true)
        let outside = tempDirectory.appendingPathComponent("Outside", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let sentinel = outside.appendingPathComponent("note.md")
        try Data("outside sentinel".utf8).write(to: sentinel)
        let linkedParent = vault.appendingPathComponent("2026", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: linkedParent, withDestinationURL: outside)

        XCTAssertThrowsError(try BoundedRegularFileReader.readData(
            at: linkedParent.appendingPathComponent("note.md"),
            relativeTo: vault,
            maximumBytes: 64
        )) { error in
            XCTAssertEqual(error as? BoundedRegularFileReaderError, .notRegularFile)
        }
        XCTAssertEqual(try String(contentsOf: sentinel, encoding: .utf8), "outside sentinel")
    }

    func testReadsManagedFileWhenSelectedVaultRootIsASymlink() throws {
        let actualVault = tempDirectory.appendingPathComponent("ActualVault", isDirectory: true)
        let linkedVault = tempDirectory.appendingPathComponent("VaultShortcut", isDirectory: true)
        try FileManager.default.createDirectory(at: actualVault, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linkedVault, withDestinationURL: actualVault)
        let note = actualVault.appendingPathComponent("2026/09/29.md")
        try FileManager.default.createDirectory(at: note.deletingLastPathComponent(), withIntermediateDirectories: true)
        let expected = Data("selected vault note".utf8)
        try expected.write(to: note)

        let resolverStyleURL = linkedVault
            .appendingPathComponent("2026/09/29.md")
            .resolvingSymlinksInPath()
        XCTAssertEqual(
            try BoundedRegularFileReader.readData(at: resolverStyleURL, relativeTo: linkedVault, maximumBytes: 64),
            expected
        )
    }

    func testRejectsFIFOWithoutBlocking() throws {
        let fifo = tempDirectory.appendingPathComponent("waiting.fifo")
        let result = fifo.path.withCString { path in mkfifo(path, mode_t(0o600)) }
        XCTAssertEqual(result, 0)

        XCTAssertThrowsError(try BoundedRegularFileReader.readData(at: fifo, maximumBytes: 64)) { error in
            XCTAssertEqual(error as? BoundedRegularFileReaderError, .notRegularFile)
        }
    }
}
