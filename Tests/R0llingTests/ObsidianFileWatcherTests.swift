import Foundation
import XCTest
@testable import R0lling

final class ObsidianFileWatcherTests: XCTestCase {
    func testReadingMissingVaultDoesNotCreateRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("R0lling-Watcher-Missing-Read-\(UUID().uuidString)", isDirectory: true)
        let vault = root.appendingPathComponent("MissingVault", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertNil(try VaultDirectoryFileAccess.readData(
            rootURL: vault,
            relativePath: "note.md",
            maximumBytes: 1024
        ))
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.path))
    }

    func testListingMissingVaultDoesNotCreateRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("R0lling-Watcher-Missing-List-\(UUID().uuidString)", isDirectory: true)
        let vault = root.appendingPathComponent("MissingVault", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try VaultDirectoryFileAccess.directoryFileNames(
            rootURL: vault,
            relativeDirectory: ""
        ))
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.path))
    }

    func testProductionDirectoryTreePreservesLiteralBackslashesInPOSIXNames() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("R0lling-Watcher-Backslash-\(UUID().uuidString)", isDirectory: true)
        let vault = root.appendingPathComponent("Vault", isDirectory: true)
        let namedDirectory = vault.appendingPathComponent("notes\\2026", isDirectory: true)
        try FileManager.default.createDirectory(at: namedDirectory.appendingPathComponent("nested", isDirectory: true), withIntermediateDirectories: true)
        try Data("literal filename".utf8).write(to: vault.appendingPathComponent("literal\\name.md"))
        defer { try? FileManager.default.removeItem(at: root) }

        let registry = WatcherTestSourceRegistry()
        let watcher = ObsidianFileWatcher(
            startHandler: registry.startHandler,
            directoryTreeProvider: { try VaultDirectoryFileAccess.descendantDirectorySnapshots(rootURL: $0) }
        )
        try watcher.startWatching(directoryURL: vault) { _ in }
        defer { watcher.stopWatching() }

        XCTAssertEqual(registry.activeRelativePaths, Set(["", "notes\\2026", "notes\\2026/nested"]))
    }

    func testStartsWatcherForExistingNestedDirectories() throws {
        let registry = WatcherTestSourceRegistry()
        let tree = WatcherTestDirectoryTree(paths: ["", "notes", "notes/2026"])
        let watcher = ObsidianFileWatcher(
            debounceInterval: 0.06,
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider
        )
        let directory = URL(fileURLWithPath: "/tmp/R0lling-Watcher-Tree", isDirectory: true)
        try watcher.startWatching(directoryURL: directory) { _ in }

        XCTAssertEqual(registry.activeRelativePaths, Set(["", "notes", "notes/2026"]))
        watcher.stopWatching()
        XCTAssertEqual(registry.stopCount, 3)
    }

    func testDescriptorBudgetRejectsOversizedTreeBeforeOpeningSources() {
        let registry = WatcherTestSourceRegistry()
        let tree = WatcherTestDirectoryTree(paths: ["", "one", "two"])
        let watcher = ObsidianFileWatcher(
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider,
            descriptorBudgetProvider: { 2 }
        )

        XCTAssertThrowsError(try watcher.startWatching(
            directoryURL: URL(fileURLWithPath: "/tmp/R0lling-Watcher-Descriptor-Budget", isDirectory: true)
        ) { _ in }) { error in
            XCTAssertTrue(error.localizedDescription.contains("προϋπολογισμός file descriptors"))
        }
        XCTAssertEqual(registry.startCount, 0)
        XCTAssertTrue(registry.activeRelativePaths.isEmpty)
    }

    func testProductionDirectoryTreeSkipsSymlinkedSubtrees() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("R0lling-Watcher-Symlink-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("Vault", isDirectory: true)
        let external = root.appendingPathComponent("External", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("Notes/2026", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: external.appendingPathComponent("OutsideNested", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: directory.appendingPathComponent("ExternalLink", isDirectory: true),
            withDestinationURL: external
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let registry = WatcherTestSourceRegistry()
        let watcher = ObsidianFileWatcher(
            startHandler: registry.startHandler,
            directoryTreeProvider: { try VaultDirectoryFileAccess.descendantDirectorySnapshots(rootURL: $0) }
        )
        try watcher.startWatching(directoryURL: directory) { _ in }

        XCTAssertEqual(registry.activeRelativePaths, Set(["", "Notes", "Notes/2026"]))
        watcher.stopWatching()
    }

    func testDirectorySnapshotsDetectReplacementAtTheSamePath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("R0lling-Watcher-Identity-\(UUID().uuidString)", isDirectory: true)
        let vault = root.appendingPathComponent("Vault", isDirectory: true)
        let notes = vault.appendingPathComponent("Notes", isDirectory: true)
        let moved = vault.appendingPathComponent("MovedNotes", isDirectory: true)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let before = try XCTUnwrap(VaultDirectoryFileAccess.descendantDirectorySnapshots(rootURL: vault)
            .first { $0.relativePath == "Notes" })
        try FileManager.default.moveItem(at: notes, to: moved)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: false)
        let after = try XCTUnwrap(VaultDirectoryFileAccess.descendantDirectorySnapshots(rootURL: vault)
            .first { $0.relativePath == "Notes" })

        XCTAssertNotEqual(before.identity, after.identity)
    }

    func testNestedStartFailureRollsBackAlreadyStartedRootSource() {
        let registry = WatcherTestSourceRegistry(failingRelativePath: "nested")
        let tree = WatcherTestDirectoryTree(paths: ["", "nested"])
        let watcher = ObsidianFileWatcher(
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider
        )

        XCTAssertThrowsError(try watcher.startWatching(
            directoryURL: URL(fileURLWithPath: "/tmp/R0lling-Watcher-Partial-Start", isDirectory: true)
        ) { _ in })
        XCTAssertTrue(registry.activeRelativePaths.isEmpty)
        XCTAssertEqual(registry.stopCount, 1)
    }

    func testUnsafeRelativeDirectoryPathIsRejectedBeforeStartingSources() {
        let registry = WatcherTestSourceRegistry()
        let tree = WatcherTestDirectoryTree(paths: ["", "../outside"])
        let watcher = ObsidianFileWatcher(
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider
        )

        XCTAssertThrowsError(try watcher.startWatching(
            directoryURL: URL(fileURLWithPath: "/tmp/R0lling-Watcher-Unsafe-Tree", isDirectory: true)
        ) { _ in })
        XCTAssertEqual(registry.startCount, 0)
    }

    func testNewNestedDirectoryIsWatchedAfterParentEvent() async throws {
        let registry = WatcherTestSourceRegistry()
        let tree = WatcherTestDirectoryTree(paths: [""])
        let watcher = ObsidianFileWatcher(
            debounceInterval: 0.02,
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider
        )
        let recorder = WatcherTestNotificationRecorder()
        let directory = URL(fileURLWithPath: "/tmp/R0lling-Watcher-New-Tree", isDirectory: true)
        try watcher.startWatching(directoryURL: directory) { recorder.append($0) }

        tree.replace(with: ["", "new-folder", "new-folder/nested"])
        registry.fireEvent(for: "")
        try await pauseForWatcher()

        XCTAssertEqual(registry.activeRelativePaths, Set(["", "new-folder", "new-folder/nested"]))
        XCTAssertEqual(recorder.directories, [directory.standardizedFileURL])

        registry.fireEvent(for: "new-folder/nested")
        try await pauseForWatcher()
        XCTAssertEqual(recorder.directories, [directory.standardizedFileURL, directory.standardizedFileURL])
        watcher.stopWatching()
    }

    func testRemovedNestedDirectoryClosesWatchAndRejectsQueuedStaleEvent() async throws {
        let registry = WatcherTestSourceRegistry()
        let tree = WatcherTestDirectoryTree(paths: ["", "removed"])
        let watcher = ObsidianFileWatcher(
            debounceInterval: 0.02,
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider
        )
        let recorder = WatcherTestNotificationRecorder()
        let directory = URL(fileURLWithPath: "/tmp/R0lling-Watcher-Removed-Tree", isDirectory: true)
        try watcher.startWatching(directoryURL: directory) { recorder.append($0) }

        tree.replace(with: [""])
        registry.fireEvent(for: "")
        try await pauseForWatcher()

        XCTAssertEqual(registry.activeRelativePaths, Set([""]))
        XCTAssertEqual(registry.stopCount, 1)
        registry.fireEvent(for: "removed")
        try await pauseForWatcher()
        XCTAssertEqual(recorder.directories, [directory.standardizedFileURL])
        watcher.stopWatching()
    }

    func testDirectoryReplacementAtSamePathReopensSourceAndRejectsStaleEvent() async throws {
        let registry = WatcherTestSourceRegistry()
        let tree = WatcherTestDirectoryTree(paths: ["", "notes"])
        let watcher = ObsidianFileWatcher(
            debounceInterval: 0.02,
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider
        )
        let recorder = WatcherTestNotificationRecorder()
        let directory = URL(fileURLWithPath: "/tmp/R0lling-Watcher-Replace-Tree", isDirectory: true)
        try watcher.startWatching(directoryURL: directory) { recorder.append($0) }
        let oldNotes = try XCTUnwrap(tree.snapshot(for: "notes"))

        tree.replaceIdentity(for: "notes", with: "replacement-notes")
        let replacementNotes = try XCTUnwrap(tree.snapshot(for: "notes"))
        registry.fireEvent(for: "")
        try await pauseForWatcher()

        XCTAssertEqual(registry.activeIdentities["notes"], replacementNotes.identity)
        XCTAssertEqual(registry.stopCount, 1)
        registry.fireEvent(for: oldNotes)
        try await pauseForWatcher()
        XCTAssertEqual(recorder.directories.count, 1)

        registry.fireEvent(for: replacementNotes)
        try await pauseForWatcher()
        XCTAssertEqual(recorder.directories.count, 2)
        watcher.stopWatching()
    }

    func testRootReplacementAtSamePathReopensSourceAndRejectsStaleEvent() async throws {
        let registry = WatcherTestSourceRegistry()
        let tree = WatcherTestDirectoryTree(paths: ["", "notes"])
        let watcher = ObsidianFileWatcher(
            debounceInterval: 0.02,
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider
        )
        let recorder = WatcherTestNotificationRecorder()
        let directory = URL(fileURLWithPath: "/tmp/R0lling-Watcher-Replace-Root", isDirectory: true)
        try watcher.startWatching(directoryURL: directory) { recorder.append($0) }
        let oldRoot = try XCTUnwrap(tree.snapshot(for: ""))

        tree.replaceIdentity(for: "", with: "replacement-root")
        let replacementRoot = try XCTUnwrap(tree.snapshot(for: ""))
        registry.fireEvent(for: oldRoot)
        try await pauseForWatcher()

        XCTAssertEqual(registry.activeIdentities[""], replacementRoot.identity)
        XCTAssertEqual(registry.stopCount, 1)
        registry.fireEvent(for: oldRoot)
        try await pauseForWatcher()
        XCTAssertEqual(recorder.directories.count, 1)

        registry.fireEvent(for: replacementRoot)
        try await pauseForWatcher()
        XCTAssertEqual(recorder.directories.count, 2)
        watcher.stopWatching()
    }

    func testRepeatedRootEventsAreDebouncedIntoOneNotification() async throws {
        let registry = WatcherTestSourceRegistry()
        let tree = WatcherTestDirectoryTree(paths: [""])
        let watcher = ObsidianFileWatcher(
            debounceInterval: 0.06,
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider
        )
        let recorder = WatcherTestNotificationRecorder()
        let directory = URL(fileURLWithPath: "/tmp/R0lling-Watcher-Debounce", isDirectory: true)
        try watcher.startWatching(directoryURL: directory) { recorder.append($0) }

        registry.fireEvent(at: 0)
        registry.fireEvent(at: 0)
        registry.fireEvent(at: 0)
        try await pauseForWatcher()

        XCTAssertEqual(recorder.directories, [directory.standardizedFileURL])
        watcher.stopWatching()
    }

    func testStopCancelsPendingNotificationAndClosesSource() async throws {
        let registry = WatcherTestSourceRegistry()
        let tree = WatcherTestDirectoryTree(paths: [""])
        let watcher = ObsidianFileWatcher(
            debounceInterval: 0.06,
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider
        )
        let recorder = WatcherTestNotificationRecorder()
        try watcher.startWatching(
            directoryURL: URL(fileURLWithPath: "/tmp/R0lling-Watcher-Stop", isDirectory: true)
        ) { recorder.append($0) }

        registry.fireEvent(at: 0)
        watcher.stopWatching()
        try await pauseForWatcher()

        XCTAssertTrue(recorder.directories.isEmpty)
        XCTAssertEqual(registry.stopCount, 1)
    }

    func testRestartInvalidatesOldSourceAndReportsCurrentDirectory() async throws {
        let registry = WatcherTestSourceRegistry()
        let tree = WatcherTestDirectoryTree(paths: [""])
        let watcher = ObsidianFileWatcher(
            debounceInterval: 0.06,
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider
        )
        let recorder = WatcherTestNotificationRecorder()
        let first = URL(fileURLWithPath: "/tmp/R0lling-Watcher-Old", isDirectory: true)
        let current = URL(fileURLWithPath: "/tmp/R0lling-Watcher-Current", isDirectory: true)
        try watcher.startWatching(directoryURL: first) { recorder.append($0) }
        try watcher.startWatching(directoryURL: current) { recorder.append($0) }

        registry.fireEvent(at: 0)
        registry.fireEvent(at: 1)
        try await pauseForWatcher()

        XCTAssertEqual(recorder.directories, [current.standardizedFileURL])
        XCTAssertEqual(registry.stopCount, 1)
        watcher.stopWatching()
        XCTAssertEqual(registry.stopCount, 2)
    }

    func testPreviousGenerationEventDuringReplacementStartDoesNotCancelCurrentNotification() async throws {
        let startHandler = WatcherTestGenerationRaceHandler()
        let tree = WatcherTestDirectoryTree(paths: [""])
        let watcher = ObsidianFileWatcher(
            debounceInterval: 0.02,
            startHandler: startHandler.startHandler,
            directoryTreeProvider: tree.provider
        )
        let recorder = WatcherTestNotificationRecorder()
        let directory = URL(fileURLWithPath: "/tmp/R0lling-Watcher-Generation-Race", isDirectory: true)

        try watcher.startWatching(directoryURL: directory) { recorder.append($0) }
        try watcher.startWatching(directoryURL: directory) { recorder.append($0) }
        try await pauseForWatcher()

        XCTAssertEqual(recorder.directories, [directory.standardizedFileURL])
        watcher.stopWatching()
    }

    func testFailedStartLeavesWatcherRetryable() async throws {
        let registry = WatcherTestSourceRegistry(failNextStart: true)
        let tree = WatcherTestDirectoryTree(paths: [""])
        let watcher = ObsidianFileWatcher(
            debounceInterval: 0.06,
            startHandler: registry.startHandler,
            directoryTreeProvider: tree.provider
        )
        let recorder = WatcherTestNotificationRecorder()
        let directory = URL(fileURLWithPath: "/tmp/R0lling-Watcher-Retry", isDirectory: true)

        XCTAssertThrowsError(try watcher.startWatching(directoryURL: directory) { recorder.append($0) })
        try watcher.startWatching(directoryURL: directory) { recorder.append($0) }
        registry.fireEvent(at: 0)
        try await pauseForWatcher()

        XCTAssertEqual(recorder.directories, [directory.standardizedFileURL])
        XCTAssertEqual(registry.startCount, 2)
        watcher.stopWatching()
    }

    func testReconciliationFailureStopsWatcherAndReportsError() async throws {
        let registry = WatcherTestSourceRegistry()
        let tree = WatcherTestDirectoryTree(paths: [""])
        let watcher = ObsidianFileWatcher(debounceInterval: 0.02, startHandler: registry.startHandler, directoryTreeProvider: tree.provider)
        let recorder = WatcherTestNotificationRecorder()
        let directory = URL(fileURLWithPath: "/tmp/R0lling-Watcher-Reconcile-Failure", isDirectory: true)
        try watcher.startWatching(
            directoryURL: directory,
            onFileChanged: { recorder.append($0) },
            onError: { recorder.appendError($0) }
        )

        tree.failNextRead()
        registry.fireEvent(for: "")
        try await pauseForWatcher()

        XCTAssertTrue(registry.activeRelativePaths.isEmpty)
        XCTAssertTrue(recorder.directories.isEmpty)
        XCTAssertEqual(recorder.errors.count, 1)
        XCTAssertTrue(recorder.errors[0].contains("reconciliation"))
        watcher.stopWatching()
    }

    private func pauseForWatcher() async throws {
        try await Task.sleep(nanoseconds: 250_000_000)
    }
}

/// On the replacement start, emits a valid new-generation event followed by an event
/// queued by the previous source before the new source has finished starting.
private final class WatcherTestGenerationRaceHandler: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [@Sendable () -> Void] = []

    var startHandler: ObsidianFileWatcher.StartHandler {
        { [weak self] _, _, onEvent in
            guard let self else { throw NSError(domain: "R0lling.WatcherTests", code: 4) }
            self.lock.lock()
            let previousEvent = self.events.last
            self.events.append(onEvent)
            self.lock.unlock()

            if let previousEvent {
                onEvent()
                previousEvent()
            }
            return {}
        }
    }
}

private final class WatcherTestSourceRegistry: @unchecked Sendable {
    private struct Source {
        let directory: VaultDirectorySnapshot
        let onEvent: @Sendable () -> Void
        var isStopped: Bool
    }

    private let lock = NSLock()
    private var sources: [Source] = []
    private var stops = 0
    private var starts = 0
    private var shouldFailNextStart: Bool
    private var failingRelativePath: String?

    init(failNextStart: Bool = false, failingRelativePath: String? = nil) {
        shouldFailNextStart = failNextStart
        self.failingRelativePath = failingRelativePath
    }

    var startHandler: ObsidianFileWatcher.StartHandler {
        { [weak self] _, directory, onEvent in
            guard let self else {
                throw NSError(domain: "R0lling.WatcherTests", code: 1)
            }
            let sourceID = try self.addSource(directory: directory, onEvent: onEvent)
            return { [weak self] in self?.recordStop(sourceID: sourceID) }
        }
    }

    var activeRelativePaths: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(sources.filter { !$0.isStopped }.map { $0.directory.relativePath })
    }

    var activeIdentities: [String: String] {
        lock.lock()
        defer { lock.unlock() }
        return Dictionary(uniqueKeysWithValues: sources.filter { !$0.isStopped }.map {
            ($0.directory.relativePath, $0.directory.identity)
        })
    }

    var startCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return starts
    }

    var stopCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return stops
    }

    func fireEvent(at index: Int) {
        lock.lock()
        let source = sources.indices.contains(index) ? sources[index] : nil
        lock.unlock()
        source?.onEvent()
    }

    func fireEvent(for relativePath: String) {
        lock.lock()
        let source = sources.last { $0.directory.relativePath == relativePath }
        lock.unlock()
        source?.onEvent()
    }

    func fireEvent(for directory: VaultDirectorySnapshot) {
        lock.lock()
        let source = sources.last { $0.directory == directory }
        lock.unlock()
        source?.onEvent()
    }

    private func addSource(directory: VaultDirectorySnapshot, onEvent: @escaping @Sendable () -> Void) throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        starts += 1
        if shouldFailNextStart || failingRelativePath == directory.relativePath {
            shouldFailNextStart = false
            failingRelativePath = nil
            throw NSError(domain: "R0lling.WatcherTests", code: 2)
        }
        sources.append(Source(directory: directory, onEvent: onEvent, isStopped: false))
        return sources.count - 1
    }

    private func recordStop(sourceID: Int) {
        lock.lock()
        stops += 1
        if sources.indices.contains(sourceID) {
            sources[sourceID].isStopped = true
        }
        lock.unlock()
    }
}

private final class WatcherTestDirectoryTree: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshots: [VaultDirectorySnapshot]
    private var failOnNextRead = false

    init(paths: [String]) {
        snapshots = paths.map { VaultDirectorySnapshot(relativePath: $0, identity: "identity:\($0)") }
    }

    var provider: ObsidianFileWatcher.DirectoryTreeProvider {
        { [weak self] _ in
            guard let self else {
                return [VaultDirectorySnapshot(relativePath: "", identity: "detached")]
            }
            self.lock.lock()
            defer { self.lock.unlock() }
            if self.failOnNextRead {
                self.failOnNextRead = false
                throw NSError(domain: "R0lling.WatcherTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Watcher reconciliation failed"])
            }
            return self.snapshots
        }
    }

    func replace(with paths: [String]) {
        lock.lock()
        snapshots = paths.map { VaultDirectorySnapshot(relativePath: $0, identity: "identity:\($0)") }
        lock.unlock()
    }

    func replaceIdentity(for path: String, with identity: String) {
        lock.lock()
        if let index = snapshots.firstIndex(where: { $0.relativePath == path }) {
            snapshots[index] = VaultDirectorySnapshot(relativePath: path, identity: identity)
        }
        lock.unlock()
    }

    func snapshot(for path: String) -> VaultDirectorySnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return snapshots.first { $0.relativePath == path }
    }

    func failNextRead() {
        lock.lock()
        failOnNextRead = true
        lock.unlock()
    }
}

private final class WatcherTestNotificationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [URL] = []
    private var errorValues: [String] = []

    var directories: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    var errors: [String] {
        lock.lock()
        defer { lock.unlock() }
        return errorValues
    }

    func append(_ directory: URL) {
        lock.lock()
        values.append(directory)
        lock.unlock()
    }

    func appendError(_ error: String) {
        lock.lock()
        errorValues.append(error)
        lock.unlock()
    }
}
