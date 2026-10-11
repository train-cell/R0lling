import Foundation

// Standalone host probe uses a deterministic equality digest; production uses CryptoKit SHA-256.
extension Data {
    var sha256Hash: String { map { String(format: "%02x", $0) }.joined() }
}

@main
enum ObsidianVaultNoFollowProbe {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("R0llingVaultNoFollowProbe-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let vault = root.appendingPathComponent("Vault", isDirectory: true)
        let outside = root.appendingPathComponent("Outside", isDirectory: true)
        try fileManager.createDirectory(at: vault, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: outside, withIntermediateDirectories: true)
        let canonicalVault = vault.resolvingSymlinksInPath().standardizedFileURL

        try checkExclusiveWrite(vault: canonicalVault, outside: outside)
        try checkAttachmentCopy(vault: canonicalVault, outside: outside, root: root)
        try checkAtomicReplacement(vault: canonicalVault, outside: outside)
        print("PASS: generated file, attachment copy, and note/hash atomic replacement stayed on opened directory FDs during parent symlink swaps")
    }

    private static func checkExclusiveWrite(vault: URL, outside: URL) throws {
        let parent = vault.appendingPathComponent("Generated", isDirectory: true)
        let moved = vault.appendingPathComponent("GeneratedOriginal", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let sentinel = outside.appendingPathComponent("sentinel.txt")
        try Data("keep".utf8).write(to: sentinel)
        var raceError: Error?

        let didCreate = try VaultDirectoryFileAccess.createExclusive(
            rootURL: vault,
            relativePath: "Generated/weekly.canvas",
            contents: Data("generated".utf8),
            beforeLeafOperation: {
                do { try installSymlink(parent: parent, moved: moved, outside: outside) }
                catch { raceError = error }
            }
        )
        if let raceError { throw raceError }
        precondition(didCreate)
        let sentinelData = try Data(contentsOf: sentinel)
        let generatedData = try Data(contentsOf: moved.appendingPathComponent("weekly.canvas"))
        precondition(sentinelData == Data("keep".utf8))
        precondition(!FileManager.default.fileExists(atPath: outside.appendingPathComponent("weekly.canvas").path))
        precondition(generatedData == Data("generated".utf8))
    }

    private static func checkAttachmentCopy(vault: URL, outside: URL, root: URL) throws {
        let parent = vault.appendingPathComponent("Attachments", isDirectory: true)
        let moved = vault.appendingPathComponent("AttachmentsOriginal", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("clip.mp4")
        let bytes = Data(repeating: 0xA7, count: 128 * 1024)
        try bytes.write(to: source)
        let sentinel = outside.appendingPathComponent("clip.mp4")
        try Data("keep".utf8).write(to: sentinel)
        var raceError: Error?

        let didCopy = try VaultDirectoryFileAccess.copyRegularFile(
            from: source,
            toRootURL: vault,
            relativePath: "Attachments/clip.mp4",
            beforeLeafOperation: {
                do { try installSymlink(parent: parent, moved: moved, outside: outside) }
                catch { raceError = error }
            }
        )
        if let raceError { throw raceError }
        precondition(didCopy)
        let sentinelData = try Data(contentsOf: sentinel)
        let copiedData = try Data(contentsOf: moved.appendingPathComponent("clip.mp4"))
        precondition(sentinelData == Data("keep".utf8))
        precondition(copiedData == bytes)
    }

    private static func checkAtomicReplacement(vault: URL, outside: URL) throws {
        let parent = vault.appendingPathComponent("Notes", isDirectory: true)
        let moved = vault.appendingPathComponent("NotesOriginal", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let original = Data("original note".utf8)
        try original.write(to: parent.appendingPathComponent("daily.md"))
        let sentinel = outside.appendingPathComponent("daily.md")
        try Data("keep".utf8).write(to: sentinel)
        var raceError: Error?

        let didReplace = try VaultDirectoryFileAccess.replaceRegularFileAtomically(
            rootURL: vault,
            relativePath: "Notes/daily.md",
            contents: Data("updated note".utf8),
            expectedExistingHash: original.sha256Hash,
            beforeLeafOperation: {
                do { try installSymlink(parent: parent, moved: moved, outside: outside) }
                catch { raceError = error }
            }
        )
        if let raceError { throw raceError }
        precondition(didReplace)
        let sentinelData = try Data(contentsOf: sentinel)
        let updatedData = try Data(contentsOf: moved.appendingPathComponent("daily.md"))
        precondition(sentinelData == Data("keep".utf8))
        precondition(updatedData == Data("updated note".utf8))
    }

    private static func installSymlink(parent: URL, moved: URL, outside: URL) throws {
        try FileManager.default.moveItem(at: parent, to: moved)
        try FileManager.default.createSymbolicLink(at: parent, withDestinationURL: outside)
    }
}
