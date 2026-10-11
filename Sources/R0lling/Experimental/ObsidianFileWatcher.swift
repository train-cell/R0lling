import Foundation
import Dispatch

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Debounced directory-entry change hints for a vault subtree. It never reads or writes vault content.
/// `FeatureReadinessRegistry.fileWatcher.ready` remains false until Apple Files-provider validation.
public final class ObsidianFileWatcher: @unchecked Sendable {
    typealias StartHandler = @Sendable (
        URL,
        VaultDirectorySnapshot,
        @escaping @Sendable () -> Void
    ) throws -> (@Sendable () -> Void)
    typealias DirectoryTreeProvider = @Sendable (URL) throws -> [VaultDirectorySnapshot]
    typealias DescriptorBudgetProvider = @Sendable () -> Int

    private struct ActiveSource {
        let identity: String
        let stop: @Sendable () -> Void
    }

    private let lock = NSLock()
    private let reconciliationLock = NSLock()
    private let reconciliationQueue = DispatchQueue(label: "R0lling.ObsidianFileWatcher.reconcile", qos: .utility)
    private let startHandler: StartHandler
    private let directoryTreeProvider: DirectoryTreeProvider
    private let descriptorBudgetProvider: DescriptorBudgetProvider
    private let debounceInterval: TimeInterval
    private var generation: UInt64 = 0
    private var watchedDirectory: URL?
    private var callback: (@Sendable (URL) -> Void)?
    private var failureCallback: (@Sendable (String) -> Void)?
    private var stopPlatformWatchers: [String: ActiveSource] = [:]
    private var startingPaths: [String: String] = [:]
    private var pendingNotification: DispatchWorkItem?

    public convenience init() {
        self.init(
            debounceInterval: 0.35,
            startHandler: { rootURL, directory, onEvent in
                try Self.startPlatformWatcher(
                    rootURL: rootURL,
                    directory: directory,
                    onEvent: onEvent
                )
            },
            directoryTreeProvider: { rootURL in
                try VaultDirectoryFileAccess.descendantDirectorySnapshots(rootURL: rootURL)
            }
        )
    }

    internal init(
        debounceInterval: TimeInterval = 0.35,
        startHandler: @escaping StartHandler,
        directoryTreeProvider: @escaping DirectoryTreeProvider = { rootURL in
            try VaultDirectoryFileAccess.descendantDirectorySnapshots(rootURL: rootURL)
        },
        descriptorBudgetProvider: DescriptorBudgetProvider? = nil
    ) {
        self.startHandler = startHandler
        self.directoryTreeProvider = directoryTreeProvider
        self.descriptorBudgetProvider = descriptorBudgetProvider ?? { Self.availableWatcherDescriptorBudget() }
        self.debounceInterval = max(0, debounceInterval)
    }

    /// Starts watching the selected root and its existing nested directories.
    /// Newly created nested directories are added after their parent reports an event.
    /// Throws when access, safe tree enumeration, or any initial platform source fails.
    public func startWatching(
        directoryURL: URL,
        onFileChanged: @escaping @Sendable (URL) -> Void,
        onError: @escaping @Sendable (String) -> Void = { _ in }
    ) throws {
        stopWatching()
        let directory = directoryURL.standardizedFileURL

        lock.lock()
        generation &+= 1
        let activeGeneration = generation
        watchedDirectory = directory
        callback = onFileChanged
        failureCallback = onError
        lock.unlock()

        do {
            try reconcileWatchTree(root: directory, generation: activeGeneration)
        } catch {
            rollbackFailedStart(generation: activeGeneration)
            throw error
        }
    }

    public func stopWatching() {
        lock.lock()
        generation &+= 1
        watchedDirectory = nil
        callback = nil
        failureCallback = nil
        pendingNotification?.cancel()
        pendingNotification = nil
        let stops = stopPlatformWatchers.values.map(\.stop)
        stopPlatformWatchers.removeAll()
        startingPaths.removeAll()
        lock.unlock()
        stops.forEach { $0() }
    }

    deinit {
        stopWatching()
    }

    private func scheduleNotification(generation expectedGeneration: UInt64, source: VaultDirectorySnapshot) {
        let work = DispatchWorkItem { [weak self] in
            self?.deliverNotification(generation: expectedGeneration)
        }
        lock.lock()
        guard generation == expectedGeneration,
              watchedDirectory != nil,
              callback != nil,
              (stopPlatformWatchers[source.relativePath]?.identity == source.identity
                || startingPaths[source.relativePath] == source.identity) else {
            lock.unlock()
            return
        }
        pendingNotification?.cancel()
        pendingNotification = work
        lock.unlock()

        DispatchQueue.main.asyncAfter(
            deadline: .now() + debounceInterval,
            execute: work
        )
    }

    private func deliverNotification(generation expectedGeneration: UInt64) {
        lock.lock()
        guard generation == expectedGeneration,
              let root = watchedDirectory,
              let callback,
              let failureCallback else {
            lock.unlock()
            return
        }
        pendingNotification = nil
        lock.unlock()

        reconciliationQueue.async { [weak self] in
            guard let self, self.isWatching(generation: expectedGeneration) else { return }
            do {
                try self.reconcileWatchTree(root: root, generation: expectedGeneration)
            } catch {
                self.failWatching(
                    generation: expectedGeneration,
                    message: error.localizedDescription,
                    onError: failureCallback
                )
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isWatching(generation: expectedGeneration) else { return }
                callback(root)
            }
        }
    }

    private func reconcileWatchTree(root: URL, generation expectedGeneration: UInt64) throws {
        reconciliationLock.lock()
        defer { reconciliationLock.unlock() }

        guard isWatching(generation: expectedGeneration) else { return }
        let desiredDirectories = try normalizedDirectorySnapshots(directoryTreeProvider(root))

        lock.lock()
        guard generation == expectedGeneration, watchedDirectory == root else {
            lock.unlock()
            return
        }
        let currentIdentities = Dictionary(uniqueKeysWithValues: stopPlatformWatchers.map { ($0.key, $0.value.identity) })
        let directoriesToStart = desiredDirectories.filter { currentIdentities[$0.relativePath] != $0.identity }
        let descriptorBudget = max(0, descriptorBudgetProvider())
        guard directoriesToStart.count <= descriptorBudget else {
            lock.unlock()
            throw NSError(
                domain: "R0lling.ObsidianWatcher",
                code: 6204,
                userInfo: [NSLocalizedDescriptionKey: "Το vault απαιτεί \(directoriesToStart.count) νέες παρακολουθήσεις, αλλά ο διαθέσιμος προϋπολογισμός file descriptors επαρκεί μόνο για \(descriptorBudget). Κλείσε άλλες εφαρμογές ή μείωσε τους φακέλους που παρακολουθούνται."]
            )
        }
        for directory in directoriesToStart {
            startingPaths[directory.relativePath] = directory.identity
        }
        lock.unlock()

        var newlyStarted: [String: ActiveSource] = [:]
        do {
            for directory in directoriesToStart {
                let stop = try startHandler(root, directory) { [weak self] in
                    self?.scheduleNotification(generation: expectedGeneration, source: directory)
                }
                newlyStarted[directory.relativePath] = ActiveSource(identity: directory.identity, stop: stop)
            }
        } catch {
            lock.lock()
            for directory in directoriesToStart where startingPaths[directory.relativePath] == directory.identity {
                startingPaths.removeValue(forKey: directory.relativePath)
            }
            lock.unlock()
            newlyStarted.values.forEach { $0.stop() }
            throw error
        }

        lock.lock()
        guard generation == expectedGeneration, watchedDirectory == root else {
            for directory in directoriesToStart where startingPaths[directory.relativePath] == directory.identity {
                startingPaths.removeValue(forKey: directory.relativePath)
            }
            lock.unlock()
            newlyStarted.values.forEach { $0.stop() }
            return
        }
        for directory in directoriesToStart where startingPaths[directory.relativePath] == directory.identity {
            startingPaths.removeValue(forKey: directory.relativePath)
        }
        let desiredIdentities = Dictionary(uniqueKeysWithValues: desiredDirectories.map { ($0.relativePath, $0.identity) })
        let removedPaths = stopPlatformWatchers.compactMap { path, source in
            desiredIdentities[path] == source.identity ? nil : path
        }
        let removedStops = removedPaths.compactMap { stopPlatformWatchers.removeValue(forKey: $0)?.stop }
        newlyStarted.forEach { stopPlatformWatchers[$0.key] = $0.value }
        lock.unlock()

        removedStops.forEach { $0() }
    }

    private func rollbackFailedStart(generation expectedGeneration: UInt64) {
        lock.lock()
        guard generation == expectedGeneration else {
            lock.unlock()
            return
        }
        generation &+= 1
        watchedDirectory = nil
        callback = nil
        failureCallback = nil
        pendingNotification?.cancel()
        pendingNotification = nil
        let stops = stopPlatformWatchers.values.map(\.stop)
        stopPlatformWatchers.removeAll()
        startingPaths.removeAll()
        lock.unlock()
        stops.forEach { $0() }
    }

    private func failWatching(
        generation expectedGeneration: UInt64,
        message: String,
        onError: @escaping @Sendable (String) -> Void
    ) {
        lock.lock()
        guard generation == expectedGeneration, watchedDirectory != nil else {
            lock.unlock()
            return
        }
        generation &+= 1
        watchedDirectory = nil
        callback = nil
        failureCallback = nil
        pendingNotification?.cancel()
        pendingNotification = nil
        let stops = stopPlatformWatchers.values.map(\.stop)
        stopPlatformWatchers.removeAll()
        startingPaths.removeAll()
        lock.unlock()

        stops.forEach { $0() }
        DispatchQueue.main.async { onError(message) }
    }

    private func isWatching(generation expectedGeneration: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generation == expectedGeneration && watchedDirectory != nil && callback != nil
    }

    private func normalizedDirectorySnapshots(_ snapshots: [VaultDirectorySnapshot]) throws -> [VaultDirectorySnapshot] {
        var normalized: [String: VaultDirectorySnapshot] = [:]
        for snapshot in snapshots {
            let path = snapshot.relativePath
            guard !snapshot.identity.isEmpty else {
                throw NSError(
                    domain: "R0lling.ObsidianWatcher",
                    code: 6202,
                    userInfo: [NSLocalizedDescriptionKey: "Το Obsidian vault δεν επέστρεψε ταυτότητα φακέλου."]
                )
            }
            if let existing = normalized[path], existing.identity != snapshot.identity {
                throw NSError(
                    domain: "R0lling.ObsidianWatcher",
                    code: 6202,
                    userInfo: [NSLocalizedDescriptionKey: "Το Obsidian vault επέστρεψε αντικρουόμενες ταυτότητες φακέλου."]
                )
            }
            if path.isEmpty {
                normalized[path] = snapshot
                continue
            }
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !path.hasPrefix("/"),
                  !path.contains("\0"),
                  components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
                throw NSError(
                    domain: "R0lling.ObsidianWatcher",
                    code: 6202,
                    userInfo: [NSLocalizedDescriptionKey: "Το Obsidian vault περιέχει μη ασφαλή διαδρομή φακέλου."]
                )
            }
            normalized[path] = snapshot
        }
        guard normalized[""] != nil else {
            throw NSError(
                domain: "R0lling.ObsidianWatcher",
                code: 6202,
                userInfo: [NSLocalizedDescriptionKey: "Το Obsidian vault δεν επέστρεψε τον αρχικό φάκελο."]
            )
        }
        return normalized.values.sorted {
            let left = $0.relativePath
            let right = $1.relativePath
            let leftDepth = left.isEmpty ? 0 : left.split(separator: "/").count
            let rightDepth = right.isEmpty ? 0 : right.split(separator: "/").count
            if leftDepth != rightDepth { return leftDepth < rightDepth }
            return left < right
        }
    }

    /// Keep directory event sources below the process descriptor ceiling. The reserve is
    /// deliberately separate from this watcher's descriptors so unrelated app work keeps room.
    private static func availableWatcherDescriptorBudget() -> Int {
        var limits = rlimit()
#if canImport(Glibc)
        let limitResult = getrlimit(Int32(RLIMIT_NOFILE.rawValue), &limits)
#else
        let limitResult = getrlimit(RLIMIT_NOFILE, &limits)
#endif
        guard limitResult == 0 else { return 16 }
        let softLimit = Int(min(limits.rlim_cur, rlim_t(Int32.max)))
        let descriptorDirectory: String
#if canImport(Darwin)
        descriptorDirectory = "/dev/fd"
#elseif canImport(Glibc)
        descriptorDirectory = "/proc/self/fd"
#else
        descriptorDirectory = "/dev/fd"
#endif
        let reserve = 64
        guard let openDescriptorCount = try? FileManager.default.contentsOfDirectory(atPath: descriptorDirectory).count else {
            return max(0, min(32, softLimit - reserve))
        }
        return max(0, softLimit - openDescriptorCount - reserve)
    }

    private static func startPlatformWatcher(
        rootURL: URL,
        directory: VaultDirectorySnapshot,
        onEvent: @escaping @Sendable () -> Void
    ) throws -> (@Sendable () -> Void) {
#if canImport(Darwin)
        let descriptor = try VaultDirectoryFileAccess.openDirectoryDescriptor(
            rootURL: rootURL,
            relativePath: directory.relativePath
        )
        var metadata = stat()
        let metadataRead = fstat(descriptor, &metadata) == 0
        let actualIdentity = metadataRead ? "\(metadata.st_dev):\(metadata.st_ino)" : ""
        guard metadataRead,
              metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR),
              actualIdentity == directory.identity else {
            let errorCode = metadataRead ? 6203 : Int(errno)
            _ = close(descriptor)
            throw NSError(
                domain: "R0lling.ObsidianWatcher",
                code: Int(errorCode),
                userInfo: [NSLocalizedDescriptionKey: "Ο φάκελος Obsidian άλλαξε κατά την επανεκκίνηση της παρακολούθησης."]
            )
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .link, .rename, .delete, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler(handler: onEvent)
        source.setCancelHandler { _ = close(descriptor) }
        source.resume()
        return { source.cancel() }
#else
        _ = rootURL
        _ = directory
        _ = onEvent
        throw NSError(
            domain: "R0lling.ObsidianWatcher",
            code: 6201,
            userInfo: [NSLocalizedDescriptionKey: "Η παρακολούθηση Obsidian απαιτεί Apple File System events."]
        )
#endif
    }
}
