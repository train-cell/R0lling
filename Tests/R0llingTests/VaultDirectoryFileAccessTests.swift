import Foundation
import XCTest
@testable import R0lling

final class VaultDirectoryFileAccessTests: XCTestCase {
    private var root: URL!
    private var vault: URL!
    private var movedDirectory: URL!
    private var outside: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("R0llingVaultFD-\(UUID().uuidString)", isDirectory: true)
        let requestedVault = root.appendingPathComponent("Vault", isDirectory: true)
        outside = root.appendingPathComponent("Outside", isDirectory: true)
        try FileManager.default.createDirectory(at: requestedVault.appendingPathComponent("Exports", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        vault = requestedVault.resolvingSymlinksInPath().standardizedFileURL
        movedDirectory = vault.appendingPathComponent("ExportsOriginal", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    func testExclusiveGeneratedWriteCannotFollowSwappedParentSymlink() throws {
        let outsideSentinel = outside.appendingPathComponent("keep.txt")
        try Data("external sentinel".utf8).write(to: outsideSentinel)

        let wrote = try VaultDirectoryFileAccess.createExclusive(
            rootURL: vault,
            relativePath: "Exports/generated.canvas",
            contents: Data("generated".utf8),
            beforeLeafOperation: swapExportsDirectoryForSymlink
        )

        XCTAssertTrue(wrote)
        XCTAssertEqual(try Data(contentsOf: outsideSentinel), Data("external sentinel".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("generated.canvas").path))
        XCTAssertEqual(
            try Data(contentsOf: movedDirectory.appendingPathComponent("generated.canvas")),
            Data("generated".utf8)
        )
    }

    func testAttachmentCopyCannotFollowSwappedParentSymlink() throws {
        let source = root.appendingPathComponent("source.mp4")
        let bytes = Data(repeating: 0xA7, count: 128 * 1024)
        try bytes.write(to: source)
        let outsideSentinel = outside.appendingPathComponent("clip.mp4")
        try Data("preserve".utf8).write(to: outsideSentinel)

        let copied = try VaultDirectoryFileAccess.copyRegularFile(
            from: source,
            toRootURL: vault,
            relativePath: "Exports/clip.mp4",
            beforeLeafOperation: swapExportsDirectoryForSymlink
        )

        XCTAssertTrue(copied)
        XCTAssertEqual(try Data(contentsOf: outsideSentinel), Data("preserve".utf8))
        XCTAssertEqual(try Data(contentsOf: movedDirectory.appendingPathComponent("clip.mp4")), bytes)
    }

    func testCoordinatedNoteAndHashReplacementCannotFollowSwappedParentSymlink() throws {
        let original = Data("original daily note".utf8)
        let target = vault.appendingPathComponent("Exports/note.md")
        try original.write(to: target)
        let outsideSentinel = outside.appendingPathComponent("note.md")
        try Data("outside note".utf8).write(to: outsideSentinel)

        let replaced = try VaultDirectoryFileAccess.replaceRegularFileAtomically(
            rootURL: vault,
            relativePath: "Exports/note.md",
            contents: Data("updated daily note".utf8),
            expectedExistingHash: original.sha256Hash,
            beforeLeafOperation: swapExportsDirectoryForSymlink
        )

        XCTAssertTrue(replaced)
        XCTAssertEqual(try Data(contentsOf: outsideSentinel), Data("outside note".utf8))
        XCTAssertEqual(
            try Data(contentsOf: movedDirectory.appendingPathComponent("note.md")),
            Data("updated daily note".utf8)
        )
    }

    private func swapExportsDirectoryForSymlink() {
        let checkedDirectory = vault.appendingPathComponent("Exports", isDirectory: true)
        do {
            try FileManager.default.moveItem(at: checkedDirectory, to: movedDirectory)
            try FileManager.default.createSymbolicLink(at: checkedDirectory, withDestinationURL: outside)
        } catch {
            XCTFail("Unable to install deterministic parent-symlink race: \(error)")
        }
    }
}
