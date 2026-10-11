import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// File operations rooted at an already-open vault directory. Parent components are
/// traversed with `openat` and `O_NOFOLLOW`, so replacing a checked directory with a
/// symlink cannot redirect a later read or write outside the opened directory.
struct VaultDirectorySnapshot: Equatable, Sendable {
    let relativePath: String
    let identity: String
}

enum VaultDirectoryFileAccess {
    private enum PathReadError: Error {
        case missingParent
    }

    static func ensureDirectory(rootURL: URL, relativePath: String) throws {
        try withRootDirectory(rootURL: rootURL, createMissingRoot: true) { rootFD in
            var currentFD = rootFD
            var ownsCurrentFD = false
            defer { if ownsCurrentFD { _ = close(currentFD) } }

            for component in try components(of: relativePath) {
                let nextFD = component.withCString { name in
                    openat(currentFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
                }
                var openedFD = nextFD
                if openedFD < 0, errno == ENOENT {
                    let made = component.withCString { name in mkdirat(currentFD, name, 0o755) }
                    if made != 0, errno != EEXIST { throw posixError("Αδυναμία δημιουργίας φακέλου Obsidian.") }
                    openedFD = component.withCString { name in
                        openat(currentFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
                    }
                }
                guard openedFD >= 0 else { throw unsafePathError() }
                if ownsCurrentFD { _ = close(currentFD) }
                currentFD = openedFD
                ownsCurrentFD = true
            }
        }
    }

    static func readData(rootURL: URL, relativePath: String, maximumBytes: Int) throws -> Data? {
        guard maximumBytes >= 0, maximumBytes < Int.max else { throw posixError("Μη έγκυρο όριο ανάγνωσης Obsidian.") }
        do {
            return try withParentDirectory(rootURL: rootURL, relativePath: relativePath, createMissing: false) { parentFD, leaf in
            let descriptor = leaf.withCString { name in
                openat(parentFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
            }
            guard descriptor >= 0 else {
                if errno == ENOENT { return nil }
                if errno == ELOOP { throw unsafePathError() }
                throw posixError("Αδυναμία ασφαλούς ανάγνωσης αρχείου Obsidian.")
            }
            defer { _ = close(descriptor) }
            var metadata = stat()
            guard fstat(descriptor, &metadata) == 0 else { throw posixError("Αδυναμία επαλήθευσης αρχείου Obsidian.") }
            guard metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw unsafePathError() }
            guard metadata.st_size <= off_t(maximumBytes) else { throw oversizedFileError(maximumBytes) }
            return try readAll(from: descriptor, maximumBytes: maximumBytes)
            }
        } catch PathReadError.missingParent {
            return nil
        }
    }

    /// Creates a file only when its leaf path is absent. Returns false when occupied.
    static func createExclusive(
        rootURL: URL,
        relativePath: String,
        contents: Data,
        beforeLeafOperation: (() -> Void)? = nil
    ) throws -> Bool {
        try withParentDirectory(rootURL: rootURL, relativePath: relativePath, createMissing: true) { parentFD, leaf in
            beforeLeafOperation?()
            let descriptor = leaf.withCString { name in
                openat(parentFD, name, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
            }
            guard descriptor >= 0 else {
                if errno == EEXIST { return false }
                if errno == ELOOP { throw unsafePathError() }
                throw posixError("Αδυναμία αποκλειστικής δημιουργίας αρχείου Obsidian.")
            }
            var removePartial = true
            defer {
                _ = close(descriptor)
                if removePartial { _ = leaf.withCString { unlinkat(parentFD, $0, 0) } }
            }
            try writeAll(contents, to: descriptor)
            guard fsync(descriptor) == 0 else { throw posixError("Αδυναμία συγχρονισμού αρχείου Obsidian.") }
            removePartial = false
            return true
        }
    }

    /// Copies a regular source file into an absent vault-relative destination.
    /// The source and destination are both opened without following their final component.
    static func copyRegularFile(
        from sourceURL: URL,
        toRootURL rootURL: URL,
        relativePath: String,
        beforeLeafOperation: (() -> Void)? = nil
    ) throws -> Bool {
        let sourceFD = try openRegularFileURL(sourceURL)
        defer { _ = close(sourceFD) }
        var sourceMetadata = stat()
        guard fstat(sourceFD, &sourceMetadata) == 0,
              sourceMetadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw unsafePathError()
        }

        return try withParentDirectory(rootURL: rootURL, relativePath: relativePath, createMissing: true) { parentFD, leaf in
            beforeLeafOperation?()
            let destinationFD = leaf.withCString { name in
                openat(parentFD, name, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
            }
            guard destinationFD >= 0 else {
                if errno == EEXIST { return false }
                if errno == ELOOP { throw unsafePathError() }
                throw posixError("Αδυναμία δημιουργίας attachment στο Obsidian vault.")
            }
            var removePartial = true
            defer {
                _ = close(destinationFD)
                if removePartial { _ = leaf.withCString { unlinkat(parentFD, $0, 0) } }
            }

            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            while true {
                let count = buffer.withUnsafeMutableBytes { bytes in
                    read(sourceFD, bytes.baseAddress, bytes.count)
                }
                if count == 0 { break }
                if count < 0 {
                    if errno == EINTR { continue }
                    throw posixError("Αδυναμία ανάγνωσης attachment για Obsidian export.")
                }
                try writeAll(buffer, count: Int(count), to: destinationFD)
            }
            guard fsync(destinationFD) == 0 else { throw posixError("Αδυναμία συγχρονισμού attachment Obsidian.") }
            removePartial = false
            return true
        }
    }

    /// Atomically installs new bytes. A missing target is created without replacement;
    /// an existing target is replaced only if it is a regular file with the expected hash.
    static func replaceRegularFileAtomically(
        rootURL: URL,
        relativePath: String,
        contents: Data,
        expectedExistingHash: String?,
        beforeLeafOperation: (() -> Void)? = nil
    ) throws -> Bool {
        try withParentDirectory(rootURL: rootURL, relativePath: relativePath, createMissing: true) { parentFD, leaf in
            let stagedName = ".r0lling-write-\(UUID().uuidString).tmp"
            let stagedFD = stagedName.withCString { name in
                openat(parentFD, name, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
            }
            guard stagedFD >= 0 else { throw posixError("Αδυναμία δημιουργίας προσωρινού αρχείου Obsidian.") }
            var removeStaged = true
            defer {
                _ = close(stagedFD)
                if removeStaged { _ = stagedName.withCString { unlinkat(parentFD, $0, 0) } }
            }
            try writeAll(contents, to: stagedFD)
            guard fsync(stagedFD) == 0 else { throw posixError("Αδυναμία συγχρονισμού προσωρινού αρχείου Obsidian.") }

            beforeLeafOperation?()
            let current = try readData(at: parentFD, leaf: leaf, maximumBytes: max(16 * 1024 * 1024, contents.count))
            if let expectedExistingHash {
                guard let current, current.sha256Hash == expectedExistingHash else { return false }
                let result = stagedName.withCString { staged in
                    leaf.withCString { target in renameat(parentFD, staged, parentFD, target) }
                }
                guard result == 0 else { throw posixError("Αδυναμία ασφαλούς ενημέρωσης ημερήσιας σημείωσης Obsidian.") }
            } else {
                guard current == nil else { return false }
                let result = stagedName.withCString { staged in
                    leaf.withCString { target in linkat(parentFD, staged, parentFD, target, 0) }
                }
                guard result == 0 else {
                    if errno == EEXIST { return false }
                    throw posixError("Αδυναμία ασφαλούς δημιουργίας ημερήσιας σημείωσης Obsidian.")
                }
                _ = stagedName.withCString { unlinkat(parentFD, $0, 0) }
            }
            removeStaged = false
            return true
        }
    }

    static func fileMatches(rootURL: URL, relativePath: String, contents: Data) throws -> Bool {
        guard let size = try regularFileSize(rootURL: rootURL, relativePath: relativePath), size == contents.count,
              let data = try readData(rootURL: rootURL, relativePath: relativePath, maximumBytes: contents.count) else { return false }
        return data == contents
    }

    static func regularFileSize(rootURL: URL, relativePath: String) throws -> Int? {
        do {
            return try withParentDirectory(rootURL: rootURL, relativePath: relativePath, createMissing: false) { parentFD, leaf in
            let descriptor = leaf.withCString { name in
                openat(parentFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
            }
            guard descriptor >= 0 else {
                if errno == ENOENT { return nil }
                if errno == ELOOP { throw unsafePathError() }
                throw posixError("Αδυναμία ελέγχου μεγέθους αρχείου Obsidian.")
            }
            defer { _ = close(descriptor) }
            var metadata = stat()
            guard fstat(descriptor, &metadata) == 0,
                  metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
                  metadata.st_size <= off_t(Int.max) else { throw unsafePathError() }
            return Int(metadata.st_size)
            }
        } catch PathReadError.missingParent {
            return nil
        }
    }

    static func regularFileSize(at url: URL) throws -> Int {
        let descriptor = try openRegularFileURL(url)
        defer { _ = close(descriptor) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
              metadata.st_size >= 0,
              metadata.st_size <= off_t(Int.max) else { throw unsafePathError() }
        return Int(metadata.st_size)
    }

    static func filesHaveEqualBytes(sourceURL: URL, rootURL: URL, relativePath: String) throws -> Bool {
        let sourceFD = try openRegularFileURL(sourceURL)
        defer { _ = close(sourceFD) }
        return try withParentDirectory(rootURL: rootURL, relativePath: relativePath, createMissing: false) { parentFD, leaf in
            let destinationFD = leaf.withCString { name in
                openat(parentFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
            }
            guard destinationFD >= 0 else {
                if errno == ENOENT { return false }
                if errno == ELOOP { throw unsafePathError() }
                throw posixError("Αδυναμία ασφαλούς ανοίγματος attachment Obsidian.")
            }
            defer { _ = close(destinationFD) }
            var sourceMetadata = stat()
            var destinationMetadata = stat()
            guard fstat(sourceFD, &sourceMetadata) == 0,
                  fstat(destinationFD, &destinationMetadata) == 0,
                  sourceMetadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
                  destinationMetadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw unsafePathError() }
            guard sourceMetadata.st_size == destinationMetadata.st_size else { return false }
            while true {
                let sourceChunk = try readChunk(from: sourceFD)
                let destinationChunk = try readChunk(from: destinationFD)
                guard sourceChunk == destinationChunk else { return false }
                if sourceChunk.isEmpty { return true }
            }
        }
    }

    static func directoryFileNames(rootURL: URL, relativeDirectory: String) throws -> [String] {
        let markerPath = relativeDirectory.isEmpty ? ".r0lling-list-marker" : "\(relativeDirectory)/.r0lling-list-marker"
        return try withParentDirectory(rootURL: rootURL, relativePath: markerPath, createMissing: false) { directoryFD, _ in
            let streamFD = dup(directoryFD)
            guard streamFD >= 0, let stream = fdopendir(streamFD) else {
                if streamFD >= 0 { _ = close(streamFD) }
                throw posixError("Αδυναμία ασφαλούς απαρίθμησης Obsidian directory.")
            }
            defer { _ = closedir(stream) }
            var names: [String] = []
            while let entry = readdir(stream) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                    pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: entry.pointee.d_name)) {
                        String(cString: $0)
                    }
                }
                if name != ".", name != ".." { names.append(name) }
            }
            return names
        }
    }

    /// Returns every directory below the selected root, including the root as an empty path.
    /// Each path component is reopened relative to the root with `O_NOFOLLOW` before it is
    /// traversed, so symlinks and swapped parents are never followed into an external tree.
    static func descendantDirectoryPaths(rootURL: URL) throws -> [String] {
        try descendantDirectorySnapshots(rootURL: rootURL).map(\.relativePath)
    }

    /// Returns each directory path with the identity of the descriptor opened for it.
    /// Watchers use this to replace event sources when a directory is recreated at the same path.
    static func descendantDirectorySnapshots(rootURL: URL) throws -> [VaultDirectorySnapshot] {
        var snapshots = [try directorySnapshot(rootURL: rootURL, relativePath: "")]
        var index = 0
        while index < snapshots.count {
            let parentPath = snapshots[index].relativePath
            index += 1

            for name in try directoryFileNames(rootURL: rootURL, relativeDirectory: parentPath).sorted() {
                let childPath = parentPath.isEmpty ? name : "\(parentPath)/\(name)"
                do {
                    snapshots.append(try directorySnapshot(rootURL: rootURL, relativePath: childPath))
                } catch let error as NSError {
                    let pathChangedDuringEnumeration = error.domain == NSPOSIXErrorDomain
                        && [Int(ENOENT), Int(ENOTDIR), Int(ELOOP)].contains(error.code)
                    if !pathChangedDuringEnumeration { throw error }
                }
            }
        }
        return snapshots
    }

    private static func directorySnapshot(rootURL: URL, relativePath: String) throws -> VaultDirectorySnapshot {
        let descriptor = try openDirectoryDescriptor(rootURL: rootURL, relativePath: relativePath)
        defer { _ = close(descriptor) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
              metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else {
            throw posixError("Αδυναμία επαλήθευσης ταυτότητας φακέλου Obsidian.")
        }
        return VaultDirectorySnapshot(
            relativePath: relativePath,
            identity: "\(metadata.st_dev):\(metadata.st_ino)"
        )
    }

    /// Opens a vault-relative directory without following any root or child symlink.
    /// The caller owns and must close the returned descriptor.
    static func openDirectoryDescriptor(rootURL: URL, relativePath: String) throws -> Int32 {
        let rootPath = rootURL.standardizedFileURL.path
        var currentDescriptor = try openDirectoryPath(rootPath, createMissing: false)
        let pathComponents = relativePath.isEmpty ? [] : try components(of: relativePath)
        for component in pathComponents {
            let nextDescriptor = component.withCString { name in
                openat(currentDescriptor, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
            guard nextDescriptor >= 0 else {
                let errorCode = errno
                _ = close(currentDescriptor)
                throw posixError("Αδυναμία ασφαλούς ανοίγματος υποφακέλου Obsidian.", code: Int(errorCode))
            }
            _ = close(currentDescriptor)
            currentDescriptor = nextDescriptor
        }
        return currentDescriptor
    }

    private static func readChunk(from descriptor: Int32) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        let count = buffer.withUnsafeMutableBytes { bytes in read(descriptor, bytes.baseAddress, bytes.count) }
        if count < 0 {
            if errno == EINTR { return try readChunk(from: descriptor) }
            throw posixError("Αδυναμία ανάγνωσης attachment Obsidian.")
        }
        return Data(buffer.prefix(count))
    }

    private static func readData(at parentFD: Int32, leaf: String, maximumBytes: Int) throws -> Data? {
        let descriptor = leaf.withCString { name in
            openat(parentFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        }
        guard descriptor >= 0 else {
            if errno == ENOENT { return nil }
            if errno == ELOOP { throw unsafePathError() }
            throw posixError("Αδυναμία ασφαλούς ανάγνωσης αρχείου Obsidian.")
        }
        defer { _ = close(descriptor) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
              metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw unsafePathError() }
        guard metadata.st_size <= off_t(maximumBytes) else { throw oversizedFileError(maximumBytes) }
        return try readAll(from: descriptor, maximumBytes: maximumBytes)
    }

    private static func readAll(from descriptor: Int32, maximumBytes: Int) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: min(64 * 1024, maximumBytes + 1))
        while true {
            let count = buffer.withUnsafeMutableBytes { bytes in read(descriptor, bytes.baseAddress, bytes.count) }
            if count == 0 { return data }
            if count < 0 {
                if errno == EINTR { continue }
                throw posixError("Σφάλμα bounded ανάγνωσης αρχείου Obsidian.")
            }
            guard count <= maximumBytes - data.count else { throw oversizedFileError(maximumBytes) }
            data.append(contentsOf: buffer.prefix(count))
        }
    }

    private static func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            try writeAll(base: base, count: bytes.count, to: descriptor)
        }
    }

    private static func writeAll(_ bytes: [UInt8], count: Int, to descriptor: Int32) throws {
        try bytes.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            try writeAll(base: base, count: count, to: descriptor)
        }
    }

    private static func writeAll(base: UnsafeRawPointer, count: Int, to descriptor: Int32) throws {
        var offset = 0
        while offset < count {
            let written = write(descriptor, base.advanced(by: offset), count - offset)
            if written < 0 {
                if errno == EINTR { continue }
                throw posixError("Αδυναμία εγγραφής αρχείου Obsidian.")
            }
            guard written > 0 else { throw posixError("Μηδενική εγγραφή αρχείου Obsidian.") }
            offset += written
        }
    }

    private static func openRegularFileURL(_ url: URL) throws -> Int32 {
        let standardized = url.standardizedFileURL
        let leaf = standardized.lastPathComponent
        let parentURL = standardized.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let parentFD = try openDirectoryPath(parentURL.path, createMissing: false)
        defer { _ = close(parentFD) }
        let descriptor = leaf.withCString { name in
            openat(parentFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        }
        guard descriptor >= 0 else { throw posixError("Αδυναμία ασφαλούς ανοίγματος πηγαίου attachment.") }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
              metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            _ = close(descriptor)
            throw unsafePathError()
        }
        return descriptor
    }

    private static func withParentDirectory<T>(
        rootURL: URL,
        relativePath: String,
        createMissing: Bool,
        _ body: (Int32, String) throws -> T
    ) throws -> T {
        let pathComponents = try components(of: relativePath)
        guard let leaf = pathComponents.last else { throw unsafePathError() }
        return try withRootDirectory(rootURL: rootURL, createMissingRoot: createMissing) { rootFD in
            var currentFD = rootFD
            var ownsCurrentFD = false
            defer { if ownsCurrentFD { _ = close(currentFD) } }
            for component in pathComponents.dropLast() {
                var nextFD = component.withCString { name in
                    openat(currentFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
                }
                if nextFD < 0, errno == ENOENT {
                    if createMissing {
                        let made = component.withCString { name in mkdirat(currentFD, name, 0o755) }
                        if made != 0, errno != EEXIST { throw posixError("Αδυναμία δημιουργίας φακέλου Obsidian.") }
                        nextFD = component.withCString { name in
                            openat(currentFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
                        }
                    } else {
                        throw PathReadError.missingParent
                    }
                }
                guard nextFD >= 0 else { throw unsafePathError() }
                if ownsCurrentFD { _ = close(currentFD) }
                currentFD = nextFD
                ownsCurrentFD = true
            }
            return try body(currentFD, leaf)
        }
    }

    private static func withRootDirectory<T>(
        rootURL: URL,
        createMissingRoot: Bool,
        _ body: (Int32) throws -> T
    ) throws -> T {
        // Callers pass a canonical root captured when the vault was selected. Resolving
        // symlinks here would reintroduce a check/use race at the root itself.
        let path = rootURL.standardizedFileURL.path
        let rootFD = try openDirectoryPath(path, createMissing: createMissingRoot)
        defer { _ = close(rootFD) }
        return try body(rootFD)
    }

    private static func openDirectoryPath(_ path: String, createMissing: Bool) throws -> Int32 {
        guard path.hasPrefix("/") else { throw unsafePathError() }
        let rootFD = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard rootFD >= 0 else { throw posixError("Αδυναμία ανοίγματος filesystem root.") }
        var currentFD = rootFD
        for component in path.split(separator: "/").map(String.init) {
            var nextFD = component.withCString { name in
                openat(currentFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
            if nextFD < 0, errno == ENOENT, createMissing {
                let made = component.withCString { name in mkdirat(currentFD, name, 0o755) }
                if made != 0, errno != EEXIST {
                    let error = posixError("Αδυναμία δημιουργίας Obsidian vault directory.")
                    _ = close(currentFD)
                    throw error
                }
                nextFD = component.withCString { name in
                    openat(currentFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
                }
            }
            guard nextFD >= 0 else {
                let openError = errno
                _ = close(currentFD)
                if openError == ENOENT, !createMissing {
                    throw PathReadError.missingParent
                }
                throw unsafePathError()
            }
            _ = close(currentFD)
            currentFD = nextFD
        }
        return currentFD
    }

    private static func components(of relativePath: String) throws -> [String] {
        // POSIX treats backslash as an ordinary filename character. Only slash separates
        // components; preserving backslashes also keeps names returned by readdir lossless.
        let parts = relativePath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !parts.isEmpty,
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\0") }) else {
            throw unsafePathError()
        }
        return parts
    }

    private static func unsafePathError() -> NSError {
        NSError(domain: "R0lling.Obsidian", code: 6012, userInfo: [
            NSLocalizedDescriptionKey: "Το Obsidian path περιέχει symbolic link ή μη κανονικό αρχείο."
        ])
    }

    private static func oversizedFileError(_ maximumBytes: Int) -> NSError {
        NSError(domain: "R0lling.Obsidian", code: 6013, userInfo: [
            NSLocalizedDescriptionKey: "Το αρχείο Obsidian υπερβαίνει το όριο ανάγνωσης των \(maximumBytes) bytes."
        ])
    }

    private static func posixError(_ message: String, code: Int? = nil) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: code ?? Int(errno), userInfo: [
            NSLocalizedDescriptionKey: message
        ])
    }
}
