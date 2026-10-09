import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private func agentOpen(_ path: UnsafePointer<CChar>, _ flags: Int32) -> Int32 {
#if canImport(Darwin)
    Darwin.open(path, flags)
#elseif canImport(Glibc)
    Glibc.open(path, flags)
#else
    -1
#endif
}

private struct AgentFileIdentity: Equatable {
    let device: UInt64
    let inode: UInt64
    let mode: UInt32

    init(_ metadata: stat) {
        device = UInt64(metadata.st_dev)
        inode = UInt64(metadata.st_ino)
        mode = UInt32(metadata.st_mode)
    }

    var isRegularFile: Bool {
        mode & UInt32(S_IFMT) == UInt32(S_IFREG)
    }

    func identifiesSameObject(as other: AgentFileIdentity) -> Bool {
        device == other.device && inode == other.inode
    }

    var permissions: mode_t {
        mode_t(mode & 0o777)
    }
}

private final class AgentOpenedFile {
    let descriptor: Int32
    let identity: AgentFileIdentity

    init(descriptor: Int32, identity: AgentFileIdentity) {
        self.descriptor = descriptor
        self.identity = identity
    }

    deinit {
        _ = close(descriptor)
    }
}

/// Keeps all managed file operations relative to already-open directory descriptors.
/// O_NOFOLLOW and *at operations prevent a swapped symlink from redirecting writes.
private final class AgentDirectoryHandle {
    fileprivate static let maximumManagedTextBytes = 4 * 1024 * 1024
    private let vaultDescriptor: Int32
    private let agentDescriptor: Int32
    let vaultIdentity: AgentFileIdentity
    private let agentIdentity: AgentFileIdentity

    private init(
        vaultDescriptor: Int32,
        agentDescriptor: Int32,
        vaultIdentity: AgentFileIdentity,
        agentIdentity: AgentFileIdentity
    ) {
        self.vaultDescriptor = vaultDescriptor
        self.agentDescriptor = agentDescriptor
        self.vaultIdentity = vaultIdentity
        self.agentIdentity = agentIdentity
    }

    deinit {
        _ = close(agentDescriptor)
        _ = close(vaultDescriptor)
    }

    static func open(
        vaultURL: URL,
        expectedVaultIdentity: AgentFileIdentity? = nil
    ) throws -> AgentDirectoryHandle {
        let resolvedVault = vaultURL.standardizedFileURL
        let vaultFD = try openDirectoryPath(resolvedVault.path, createMissing: true)

        var vaultMetadata = stat()
        guard fstat(vaultFD, &vaultMetadata) == 0 else {
            let error = posixError("Δεν ήταν δυνατό να ελεγχθεί το Obsidian vault.")
            _ = close(vaultFD)
            throw error
        }
        let vaultIdentity = AgentFileIdentity(vaultMetadata)
        guard vaultIdentity.mode & UInt32(S_IFMT) == UInt32(S_IFDIR),
              expectedVaultIdentity.map({ vaultIdentity.identifiesSameObject(as: $0) }) ?? true else {
            _ = close(vaultFD)
            throw changedVaultIdentityError()
        }

        let agentFD: Int32 = "Agent".withCString { name in
            openat(vaultFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        var openedAgentFD = agentFD
        if openedAgentFD < 0, errno == ENOENT {
            let mkdirResult = "Agent".withCString { name in mkdirat(vaultFD, name, 0o755) }
            if mkdirResult != 0, errno != EEXIST {
                let error = posixError("Δεν ήταν δυνατό να δημιουργηθεί ο φάκελος Agent.")
                _ = close(vaultFD)
                throw error
            }
            openedAgentFD = "Agent".withCString { name in
                openat(vaultFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
        }

        guard openedAgentFD >= 0 else {
            let error = (errno == ELOOP || isAgentSymlink(vaultFD))
                ? unsafeAgentPathError()
                : posixError("Ο φάκελος Agent δεν είναι ασφαλής ή προσβάσιμος.")
            _ = close(vaultFD)
            throw error
        }

        var metadata = stat()
        guard fstat(openedAgentFD, &metadata) == 0 else {
            let error = posixError("Δεν ήταν δυνατό να ελεγχθεί ο φάκελος Agent.")
            _ = close(openedAgentFD)
            _ = close(vaultFD)
            throw error
        }
        let identity = AgentFileIdentity(metadata)
        guard identity.mode & UInt32(S_IFMT) == UInt32(S_IFDIR) else {
            _ = close(openedAgentFD)
            _ = close(vaultFD)
            throw unsafeAgentPathError()
        }

        let handle = AgentDirectoryHandle(
            vaultDescriptor: vaultFD,
            agentDescriptor: openedAgentFD,
            vaultIdentity: vaultIdentity,
            agentIdentity: identity
        )
        try handle.ensureStillAttached()
        return handle
    }

    static func ensureVaultDirectoryExists(at vaultURL: URL) throws {
        let descriptor = try openDirectoryPath(
            vaultURL.standardizedFileURL.path,
            createMissing: true
        )
        _ = close(descriptor)
    }

    func ensureStillAttached() throws {
        var metadata = stat()
        let result = "Agent".withCString { name in
            fstatat(vaultDescriptor, name, &metadata, AT_SYMLINK_NOFOLLOW)
        }
        guard result == 0 else {
            if errno == ELOOP { throw Self.unsafeAgentPathError() }
            throw Self.posixError("Ο φάκελος Agent άλλαξε κατά την πρόσβαση.")
        }
        let current = AgentFileIdentity(metadata)
        guard current.mode & UInt32(S_IFMT) == UInt32(S_IFDIR),
              current.device == agentIdentity.device,
              current.inode == agentIdentity.inode else {
            throw Self.unsafeAgentPathError()
        }
    }

    func readText(named name: String) throws -> String? {
        guard let file = try openExistingFile(named: name) else { return nil }
        let data = try Self.readAll(
            from: file.descriptor,
            maximumBytes: Self.maximumManagedTextBytes
        )
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "R0lling.Agent",
                code: 6106,
                userInfo: [NSLocalizedDescriptionKey: "Το αρχείο Agent memory δεν είναι έγκυρο UTF-8."]
            )
        }
        return text
    }

    func openExistingFile(named name: String) throws -> AgentOpenedFile? {
        var pathMetadata = stat()
        let pathResult = name.withCString { filename in
            fstatat(agentDescriptor, filename, &pathMetadata, AT_SYMLINK_NOFOLLOW)
        }
        if pathResult != 0 {
            if errno == ENOENT { return nil }
            if errno == ELOOP { throw Self.unsafeAgentPathError() }
            throw Self.posixError("Δεν ήταν δυνατό να ελεγχθεί αρχείο Agent memory.")
        }

        let pathIdentity = AgentFileIdentity(pathMetadata)
        if pathIdentity.mode & UInt32(S_IFMT) == UInt32(S_IFLNK) {
            throw Self.unsafeAgentPathError()
        }
        guard pathIdentity.isRegularFile else {
            throw Self.nonRegularAgentFileError()
        }

        let fileFD = name.withCString { filename in
            openat(agentDescriptor, filename, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        }
        guard fileFD >= 0 else {
            if errno == ELOOP { throw Self.unsafeAgentPathError() }
            if errno == ENOENT { return nil }
            throw Self.posixError("Δεν ήταν δυνατό να ανοιχτεί αρχείο Agent memory.")
        }

        var openedMetadata = stat()
        guard fstat(fileFD, &openedMetadata) == 0 else {
            let error = Self.posixError("Δεν ήταν δυνατό να επαληθευτεί αρχείο Agent memory.")
            _ = close(fileFD)
            throw error
        }
        let openedIdentity = AgentFileIdentity(openedMetadata)
        guard openedIdentity.isRegularFile else {
            _ = close(fileFD)
            throw Self.nonRegularAgentFileError()
        }
        guard openedMetadata.st_size <= off_t(Self.maximumManagedTextBytes) else {
            _ = close(fileFD)
            throw Self.oversizedAgentFileError(maximumBytes: Self.maximumManagedTextBytes)
        }
        return AgentOpenedFile(descriptor: fileFD, identity: openedIdentity)
    }

    func createFile(named name: String, data: Data, permissions: mode_t = 0o600) throws -> AgentFileIdentity {
        let fileFD = name.withCString { filename in
            openat(
                agentDescriptor,
                filename,
                O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                permissions
            )
        }
        guard fileFD >= 0 else {
            if errno == ELOOP { throw Self.unsafeAgentPathError() }
            throw Self.posixError("Δεν ήταν δυνατό να δημιουργηθεί προσωρινό αρχείο Agent memory.")
        }

        var shouldRemovePartial = true
        defer {
            _ = close(fileFD)
            if shouldRemovePartial {
                _ = name.withCString { unlinkat(agentDescriptor, $0, 0) }
            }
        }

        try writeAll(data, to: fileFD)
        guard fchmod(fileFD, permissions) == 0 else {
            throw Self.posixError("Δεν ήταν δυνατό να διατηρηθούν τα δικαιώματα του αρχείου Agent memory.")
        }
        guard fsync(fileFD) == 0 else {
            throw Self.posixError("Δεν ήταν δυνατό να συγχρονιστεί το αρχείο Agent memory.")
        }
        var metadata = stat()
        guard fstat(fileFD, &metadata) == 0 else {
            throw Self.posixError("Δεν ήταν δυνατό να επαληθευτεί το προσωρινό αρχείο Agent memory.")
        }
        shouldRemovePartial = false
        return AgentFileIdentity(metadata)
    }

    func copyFile(from sourceFD: Int32, to name: String, permissions: mode_t) throws -> AgentFileIdentity {
        let destinationFD = name.withCString { filename in
            openat(
                agentDescriptor,
                filename,
                O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                permissions
            )
        }
        guard destinationFD >= 0 else {
            if errno == ELOOP { throw Self.unsafeAgentPathError() }
            throw Self.posixError("Δεν ήταν δυνατό να δημιουργηθεί αντίγραφο ασφαλείας Agent memory.")
        }

        var shouldRemovePartial = true
        defer {
            _ = close(destinationFD)
            if shouldRemovePartial {
                _ = name.withCString { unlinkat(agentDescriptor, $0, 0) }
            }
        }

        var bytes = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = bytes.withUnsafeMutableBytes { buffer in
                read(sourceFD, buffer.baseAddress, buffer.count)
            }
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw Self.posixError("Δεν ήταν δυνατό να διαβαστεί το αρχείο Agent memory για αντίγραφο.")
            }
            try writeAll(bytes: bytes, count: Int(count), to: destinationFD)
        }

        guard fchmod(destinationFD, permissions) == 0, fsync(destinationFD) == 0 else {
            throw Self.posixError("Δεν ήταν δυνατό να συγχρονιστεί το αντίγραφο Agent memory.")
        }
        var metadata = stat()
        guard fstat(destinationFD, &metadata) == 0 else {
            throw Self.posixError("Δεν ήταν δυνατό να επαληθευτεί το αντίγραφο Agent memory.")
        }
        shouldRemovePartial = false
        return AgentFileIdentity(metadata)
    }

    func commit(
        stagedName: String,
        targetName: String,
        expectedTarget: AgentFileIdentity?,
        backupName: String?
    ) throws {
        try ensureStillAttached()
        if let expectedTarget {
            guard let current = try openExistingFile(named: targetName), current.identity == expectedTarget else {
                throw Self.concurrentAgentFileChangeError()
            }
            guard let backupName,
                  try filesHaveEqualContents(named: targetName, and: backupName) else {
                throw Self.concurrentAgentFileChangeError()
            }
            let result = stagedName.withCString { staged in
                targetName.withCString { target in renameat(agentDescriptor, staged, agentDescriptor, target) }
            }
            guard result == 0 else {
                throw Self.posixError("Δεν ήταν δυνατό να αντικατασταθεί αρχείο Agent memory.")
            }
        } else {
            let linkResult = stagedName.withCString { staged in
                targetName.withCString { target in linkat(agentDescriptor, staged, agentDescriptor, target, 0) }
            }
            guard linkResult == 0 else {
                if errno == EEXIST { throw Self.concurrentAgentFileChangeError() }
                throw Self.posixError("Δεν ήταν δυνατό να προστεθεί αρχείο Agent memory.")
            }
            _ = stagedName.withCString { unlinkat(agentDescriptor, $0, 0) }
        }
    }

    func rollback(
        targetName: String,
        stagedIdentity: AgentFileIdentity,
        backupName: String?,
        expectedNewContents: Data
    ) throws {
        if let current = try openExistingFile(named: targetName) {
            guard current.identity == stagedIdentity,
                  try file(named: targetName, matches: expectedNewContents) else {
                throw Self.concurrentAgentFileChangeError()
            }
            if let backupName {
                let result = backupName.withCString { backup in
                    targetName.withCString { target in renameat(agentDescriptor, backup, agentDescriptor, target) }
                }
                guard result == 0 else {
                    throw Self.posixError("Δεν ήταν δυνατό να επανέλθει το αρχείο Agent memory.")
                }
            } else {
                let result = targetName.withCString { unlinkat(agentDescriptor, $0, 0) }
                guard result == 0 else {
                    throw Self.posixError("Δεν ήταν δυνατό να αφαιρεθεί το νέο αρχείο Agent memory.")
                }
            }
        } else if let backupName {
            let result = backupName.withCString { backup in
                targetName.withCString { target in renameat(agentDescriptor, backup, agentDescriptor, target) }
            }
            guard result == 0 else {
                throw Self.posixError("Δεν ήταν δυνατό να επανέλθει το αρχείο Agent memory.")
            }
        }
    }

    func removeRecoveryFile(named name: String) {
        _ = name.withCString { unlinkat(agentDescriptor, $0, 0) }
    }

    func isStillAttached() -> Bool {
        (try? ensureStillAttached()) != nil
    }

    private static func readAll(from descriptor: Int32, maximumBytes: Int) throws -> Data {
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0 else {
            throw Self.posixError("Δεν ήταν δυνατό να επαληθευτεί το μέγεθος Agent memory.")
        }
        guard metadata.st_size <= off_t(maximumBytes) else {
            throw Self.oversizedAgentFileError(maximumBytes: maximumBytes)
        }

        var result = Data()
        var bytes = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = bytes.withUnsafeMutableBytes { buffer in
                read(descriptor, buffer.baseAddress, buffer.count)
            }
            if count == 0 { return result }
            if count < 0 {
                if errno == EINTR { continue }
                throw Self.posixError("Δεν ήταν δυνατό να διαβαστεί αρχείο Agent memory.")
            }
            guard Int(count) <= maximumBytes - result.count else {
                throw Self.oversizedAgentFileError(maximumBytes: maximumBytes)
            }
            result.append(contentsOf: bytes.prefix(Int(count)))
        }
    }

    private func filesHaveEqualContents(named firstName: String, and secondName: String) throws -> Bool {
        guard let first = try openExistingFile(named: firstName),
              let second = try openExistingFile(named: secondName) else {
            return false
        }

        while true {
            let firstChunk = try readChunk(from: first.descriptor, maximumCount: 64 * 1024)
            let secondChunk = try readChunk(from: second.descriptor, maximumCount: 64 * 1024)
            guard firstChunk.count == secondChunk.count, firstChunk.elementsEqual(secondChunk) else {
                return false
            }
            if firstChunk.isEmpty { return true }
        }
    }

    private func file(named name: String, matches expected: Data) throws -> Bool {
        guard let source = try openExistingFile(named: name) else { return false }
        var offset = 0
        while offset < expected.count {
            let expectedCount = min(64 * 1024, expected.count - offset)
            let actual = try readChunk(from: source.descriptor, maximumCount: expectedCount)
            guard actual.count == expectedCount,
                  actual.elementsEqual(expected[offset..<(offset + expectedCount)]) else {
                return false
            }
            offset += expectedCount
        }
        return try readChunk(from: source.descriptor, maximumCount: 1).isEmpty
    }

    private func readChunk(from descriptor: Int32, maximumCount: Int) throws -> [UInt8] {
        guard maximumCount > 0 else { return [] }
        var bytes = [UInt8](repeating: 0, count: maximumCount)
        var offset = 0
        while offset < maximumCount {
            let count = bytes.withUnsafeMutableBytes { buffer in
                read(descriptor, buffer.baseAddress!.advanced(by: offset), maximumCount - offset)
            }
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw Self.posixError("Δεν ήταν δυνατό να συγκριθούν τα περιεχόμενα Agent memory.")
            }
            offset += count
        }
        return Array(bytes.prefix(offset))
    }

    private func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let count = write(descriptor, baseAddress.advanced(by: offset), buffer.count - offset)
                if count < 0 {
                    if errno == EINTR { continue }
                    throw Self.posixError("Δεν ήταν δυνατό να γραφτεί αρχείο Agent memory.")
                }
                guard count > 0 else {
                    throw Self.posixError("Η εγγραφή Agent memory δεν προχώρησε.")
                }
                offset += count
            }
        }
    }

    private func writeAll(bytes: [UInt8], count: Int, to descriptor: Int32) throws {
        try bytes.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            var offset = 0
            while offset < count {
                let written = write(descriptor, baseAddress.advanced(by: offset), count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw Self.posixError("Δεν ήταν δυνατό να γραφτεί αντίγραφο Agent memory.")
                }
                guard written > 0 else {
                    throw Self.posixError("Η εγγραφή αντιγράφου Agent memory δεν προχώρησε.")
                }
                offset += written
            }
        }
    }

    /// Walk every absolute-path component from `/` with O_NOFOLLOW instead of
    /// opening one resolved string whose intermediate components could be swapped.
    private static func openDirectoryPath(_ path: String, createMissing: Bool) throws -> Int32 {
        guard path.hasPrefix("/") else {
            throw Self.unsafeAgentPathError()
        }
        var currentFD = agentOpen("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard currentFD >= 0 else {
            throw Self.posixError("Δεν ήταν δυνατό να ανοιχτεί η ρίζα του συστήματος αρχείων.")
        }

        for component in path.split(separator: "/").map(String.init) {
            var nextFD = component.withCString { name in
                openat(currentFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
            if nextFD < 0, errno == ENOENT, createMissing {
                let mkdirResult = component.withCString { name in mkdirat(currentFD, name, 0o755) }
                if mkdirResult != 0, errno != EEXIST {
                    let error = Self.posixError("Δεν ήταν δυνατό να δημιουργηθεί φάκελος του Obsidian vault.")
                    _ = close(currentFD)
                    throw error
                }
                nextFD = component.withCString { name in
                    openat(currentFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
                }
            }
            guard nextFD >= 0 else {
                let error = (errno == ELOOP || Self.isSymbolicLink(component, in: currentFD))
                    ? Self.unsafeAgentPathError()
                    : Self.posixError("Το Obsidian vault περιέχει μη ασφαλή ή μη προσβάσιμο φάκελο.")
                _ = close(currentFD)
                throw error
            }
            _ = close(currentFD)
            currentFD = nextFD
        }
        return currentFD
    }

    private static func isSymbolicLink(_ component: String, in parentFD: Int32) -> Bool {
        var metadata = stat()
        let result = component.withCString { name in
            fstatat(parentFD, name, &metadata, AT_SYMLINK_NOFOLLOW)
        }
        return result == 0 && AgentFileIdentity(metadata).mode & UInt32(S_IFMT) == UInt32(S_IFLNK)
    }

    private static func isAgentSymlink(_ vaultFD: Int32) -> Bool {
        var metadata = stat()
        let result = "Agent".withCString { name in
            fstatat(vaultFD, name, &metadata, AT_SYMLINK_NOFOLLOW)
        }
        return result == 0 && AgentFileIdentity(metadata).mode & UInt32(S_IFMT) == UInt32(S_IFLNK)
    }

    private static func unsafeAgentPathError() -> NSError {
        NSError(
            domain: "R0lling.Agent",
            code: 6104,
            userInfo: [NSLocalizedDescriptionKey: "Η διαδρομή Agent περιέχει συμβολικό σύνδεσμο ή μη ασφαλές στοιχείο."]
        )
    }

    private static func nonRegularAgentFileError() -> NSError {
        NSError(
            domain: "R0lling.Agent",
            code: 6102,
            userInfo: [NSLocalizedDescriptionKey: "Το αρχείο Agent memory δεν είναι κανονικό αρχείο."]
        )
    }

    private static func oversizedAgentFileError(maximumBytes: Int) -> NSError {
        NSError(
            domain: "R0lling.Agent",
            code: 6110,
            userInfo: [NSLocalizedDescriptionKey: "Το αρχείο Agent memory υπερβαίνει το όριο ανάγνωσης των \(maximumBytes / (1024 * 1024)) MiB."]
        )
    }

    private static func concurrentAgentFileChangeError() -> NSError {
        NSError(
            domain: "R0lling.Agent",
            code: 6105,
            userInfo: [NSLocalizedDescriptionKey: "Αρχείο Agent memory άλλαξε από άλλη διεργασία κατά την αποθήκευση."]
        )
    }

    private static func changedVaultIdentityError() -> NSError {
        NSError(
            domain: "R0lling.Agent",
            code: 6108,
            userInfo: [NSLocalizedDescriptionKey: "Ο φάκελος του Obsidian vault αντικαταστάθηκε από τότε που συνδέθηκε."]
        )
    }

    private static func posixError(_ message: String) -> NSError {
        NSError(
            domain: "R0lling.Agent",
            code: Int(errno),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

/// Διαχείριση των αρχείων μνήμης του προσωπικού AI Agent (`Agent/` υποφάκελος)
public actor AgentFolderManager {
    private static let memoryFileName = "Memory.md"
    private static let preferencesFileName = "Preferences.md"
    private static let openLoopsFileName = "Open-loops.md"

    private var baseVaultURL: URL?
    private var safeVaultPathURL: URL?
    private var pinnedVaultIdentity: AgentFileIdentity?

    private struct StagedMemoryFile {
        let targetName: String
        let stagedName: String
        let stagedIdentity: AgentFileIdentity
        let expectedTargetIdentity: AgentFileIdentity?
        let newContents: Data
        var backupName: String?
    }

    public init(vaultURL: URL? = nil) {
        if let url = vaultURL {
            self.baseVaultURL = url
            self.safeVaultPathURL = url.resolvingSymlinksInPath().standardizedFileURL
        } else if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = docs.appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
            self.baseVaultURL = url
            self.safeVaultPathURL = url.resolvingSymlinksInPath().standardizedFileURL
        } else {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
            self.baseVaultURL = url
            self.safeVaultPathURL = url.resolvingSymlinksInPath().standardizedFileURL
        }
    }

    public func setVaultURL(_ url: URL) {
        self.baseVaultURL = url
        self.safeVaultPathURL = url.resolvingSymlinksInPath().standardizedFileURL
        self.pinnedVaultIdentity = nil
    }

    public var currentVaultURL: URL? {
        baseVaultURL
    }

    /// Φόρτωση των Agent Markdown αρχείων με no-follow, descriptor-relative access.
    public func loadAgentMemory() throws -> AgentMemory {
        let scope = baseVaultURL?.startAccessingSecurityScopedResource() ?? false
        defer { if scope { baseVaultURL?.stopAccessingSecurityScopedResource() } }
        guard baseVaultURL != nil, let safeVaultPathURL else { return AgentMemory() }

        return try Self.withVaultCoordination(at: safeVaultPathURL) { coordinatedVaultURL in
            let directory = try AgentDirectoryHandle.open(
                vaultURL: coordinatedVaultURL,
                expectedVaultIdentity: pinnedVaultIdentity
            )
            pinnedVaultIdentity = directory.vaultIdentity
            let memoryText = try directory.readText(named: Self.memoryFileName) ?? "# Σημειώσεις Μνήμης Βοηθού\n\n"
            let preferencesText = try directory.readText(named: Self.preferencesFileName) ?? "# Προτιμήσεις Χρήστη\n\n"
            let openLoopsText = try directory.readText(named: Self.openLoopsFileName) ?? "# Εκκρεμότητες & Ανοιχτά Θέματα\n\n"
            try directory.ensureStillAttached()

            return AgentMemory(
                memoryNotes: memoryText,
                userPreferences: preferencesText,
                openLoops: openLoopsText,
                lastUpdated: Date()
            )
        }
    }

    /// Αποθηκεύει τα Agent Markdown αρχεία και επαναφέρει τα προηγούμενα σε σφάλματα I/O που πιάνονται.
    public func saveAgentMemory(_ memory: AgentMemory) throws {
        let scope = baseVaultURL?.startAccessingSecurityScopedResource() ?? false
        defer { if scope { baseVaultURL?.stopAccessingSecurityScopedResource() } }
        guard baseVaultURL != nil, let safeVaultPathURL else {
            throw NSError(
                domain: "R0lling.Agent",
                code: 6101,
                userInfo: [NSLocalizedDescriptionKey: "Δεν έχει οριστεί Obsidian vault για Agent."]
            )
        }

        try Self.withVaultCoordination(at: safeVaultPathURL) { coordinatedVaultURL in
            try saveAgentMemory(
                memory,
                in: coordinatedVaultURL,
                expectedVaultIdentity: pinnedVaultIdentity
            )
        }
    }

    private func saveAgentMemory(
        _ memory: AgentMemory,
        in vaultURL: URL,
        expectedVaultIdentity: AgentFileIdentity?
    ) throws {
        let directory = try AgentDirectoryHandle.open(
            vaultURL: vaultURL,
            expectedVaultIdentity: expectedVaultIdentity
        )
        pinnedVaultIdentity = directory.vaultIdentity
        let contents: [(String, String)] = [
            (Self.memoryFileName, memory.memoryNotes),
            (Self.preferencesFileName, memory.userPreferences),
            (Self.openLoopsFileName, memory.openLoops)
        ]
        guard contents.allSatisfy({ $0.1.utf8.count <= AgentDirectoryHandle.maximumManagedTextBytes }) else {
            throw NSError(
                domain: "R0lling.Agent",
                code: 6110,
                userInfo: [NSLocalizedDescriptionKey: "Κάθε αρχείο Agent memory πρέπει να είναι έως 4 MiB."]
            )
        }
        var stagedFiles: [StagedMemoryFile] = []
        var committedIndices: [Int] = []
        var preserveBackupNames = Set<String>()
        defer {
            for item in stagedFiles {
                directory.removeRecoveryFile(named: item.stagedName)
                if let backupName = item.backupName, !preserveBackupNames.contains(backupName) {
                    directory.removeRecoveryFile(named: backupName)
                }
            }
        }

        do {
            // Stage every file and backup before committing any target.
            for (targetName, text) in contents {
                try directory.ensureStillAttached()
                let existingFile = try directory.openExistingFile(named: targetName)
                let token = UUID().uuidString
                let stagedName = ".\(targetName).\(token).staged"
                let permissions = existingFile?.identity.permissions ?? 0o600
                let newContents = Data(text.utf8)
                let stagedIdentity = try directory.createFile(
                    named: stagedName,
                    data: newContents,
                    permissions: permissions
                )
                stagedFiles.append(StagedMemoryFile(
                    targetName: targetName,
                    stagedName: stagedName,
                    stagedIdentity: stagedIdentity,
                    expectedTargetIdentity: existingFile?.identity,
                    newContents: newContents,
                    backupName: nil
                ))

                if let existingFile {
                    let backupName = ".\(targetName).\(token).backup"
                    _ = try directory.copyFile(
                        from: existingFile.descriptor,
                        to: backupName,
                        permissions: existingFile.identity.permissions
                    )
                    stagedFiles[stagedFiles.count - 1].backupName = backupName
                }
                try directory.ensureStillAttached()
            }

            for index in stagedFiles.indices {
                let item = stagedFiles[index]
                try directory.commit(
                    stagedName: item.stagedName,
                    targetName: item.targetName,
                    expectedTarget: item.expectedTargetIdentity,
                    backupName: item.backupName
                )
                committedIndices.append(index)
                try directory.ensureStillAttached()
            }
        } catch {
            let originalError = error
            var rollbackErrors: [String] = []
            for index in committedIndices.reversed() {
                let item = stagedFiles[index]
                do {
                    try directory.rollback(
                        targetName: item.targetName,
                        stagedIdentity: item.stagedIdentity,
                        backupName: item.backupName,
                        expectedNewContents: item.newContents
                    )
                } catch {
                    if let backupName = item.backupName {
                        preserveBackupNames.insert(backupName)
                    }
                    rollbackErrors.append(error.localizedDescription)
                }
            }

            if !rollbackErrors.isEmpty {
                throw NSError(
                    domain: "R0lling.Agent",
                    code: 6103,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Η αποθήκευση Agent memory απέτυχε και δεν ολοκληρώθηκε πλήρως η επαναφορά των προηγούμενων αρχείων. Τα αντίγραφα ασφαλείας διατηρήθηκαν.",
                        NSUnderlyingErrorKey: originalError,
                        "R0lling.Agent.RollbackErrors": rollbackErrors
                    ]
                )
            }
            throw originalError
        }
    }

    private static func withVaultCoordination<T>(
        at vaultURL: URL,
        operation: (URL) throws -> T
    ) throws -> T {
        let resolvedVaultURL = vaultURL.standardizedFileURL
        try AgentDirectoryHandle.ensureVaultDirectoryExists(at: resolvedVaultURL)

#if canImport(Darwin)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationResult: Result<T, Error>?
        coordinator.coordinate(
            writingItemAt: resolvedVaultURL,
            options: .forMerging,
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result { try operation(coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let operationResult else {
            throw NSError(
                domain: "R0lling.Agent",
                code: 6107,
                userInfo: [NSLocalizedDescriptionKey: "Ο συντονισμός πρόσβασης στο Obsidian vault δεν εκτελέστηκε."]
            )
        }
        return try operationResult.get()
#else
        return try operation(resolvedVaultURL)
#endif
    }

    /// Προσθήκη σημείωσης μετά από ανάγνωση και επαληθευμένη επανεγγραφή.
    public func appendNoteToMemory(note: String) throws {
        var current = try loadAgentMemory()
        current.memoryNotes += "\n- [\(Date().iso8601String)] \(note)\n"
        current.lastUpdated = Date()
        try saveAgentMemory(current)
    }
}
