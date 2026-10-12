import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum BoundedRegularFileReaderError: Error, Equatable {
    case invalidMaximumBytes
    case notRegularFile
    case exceedsMaximumBytes(Int)
    case sizeMismatch(expected: Int64, actual: Int64)
}

/// Reads a regular file with no unbounded allocation and never blocks on a FIFO.
enum BoundedRegularFileReader {
    static func readData(at url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes >= 0, maximumBytes < Int.max else {
            throw BoundedRegularFileReaderError.invalidMaximumBytes
        }

        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW)
        guard descriptor >= 0 else {
            if errno == ELOOP { throw BoundedRegularFileReaderError.notRegularFile }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
                NSLocalizedDescriptionKey: "Αδυναμία ανοίγματος αρχείου για bounded ανάγνωση."
            ])
        }
        defer { _ = close(descriptor) }
        return try readData(from: descriptor, maximumBytes: maximumBytes)
    }

    /// Opens every vault-relative directory with `openat` + `O_NOFOLLOW` so a
    /// parent component cannot be swapped for a symlink after a path check.
    static func readData(at url: URL, relativeTo baseDirectory: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes >= 0, maximumBytes < Int.max else {
            throw BoundedRegularFileReaderError.invalidMaximumBytes
        }
        let relativePath = try relativePath(for: url, relativeTo: baseDirectory)
        let fileFD = try openRegularFileDescriptor(relativePath: relativePath, relativeTo: baseDirectory)
        defer { _ = close(fileFD) }
        return try readData(from: fileFD, maximumBytes: maximumBytes)
    }

    /// Returns the size from the opened file descriptor, never from a path that
    /// could be redirected after metadata inspection.
    static func fileSize(relativePath: String, relativeTo baseDirectory: URL) throws -> Int64? {
        let descriptor: Int32
        do {
            descriptor = try openRegularFileDescriptor(relativePath: relativePath, relativeTo: baseDirectory)
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == ENOENT {
            return nil
        }
        defer { _ = close(descriptor) }
        return try regularFileSize(from: descriptor)
    }

    /// Copies a selected-bundle file through a descriptor rooted at the bundle.
    /// The optional hook is used by tests to swap a parent path after it is opened.
    @discardableResult
    static func copyRegularFile(
        relativePath: String,
        relativeTo baseDirectory: URL,
        to destinationURL: URL,
        expectedSize: Int64,
        beforeLeafOpen: (() -> Void)? = nil
    ) throws -> Int64 {
        guard expectedSize >= 0 else { throw BoundedRegularFileReaderError.sizeMismatch(expected: 0, actual: expectedSize) }
        let sourceFD = try openRegularFileDescriptor(
            relativePath: relativePath,
            relativeTo: baseDirectory,
            beforeLeafOpen: beforeLeafOpen
        )
        defer { _ = close(sourceFD) }
        let sourceSize = try regularFileSize(from: sourceFD)
        guard sourceSize == expectedSize else {
            throw BoundedRegularFileReaderError.sizeMismatch(expected: expectedSize, actual: sourceSize)
        }

        let destinationFD = open(
            destinationURL.path,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard destinationFD >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
                NSLocalizedDescriptionKey: "Αδυναμία δημιουργίας προσωρινού αρχείου επαναφοράς."
            ])
        }
        var removePartial = true
        defer {
            _ = close(destinationFD)
            if removePartial { _ = unlink(destinationURL.path) }
        }

        var totalBytes: Int64 = 0
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let bytesRead = buffer.withUnsafeMutableBufferPointer { bufferPointer -> Int in
                guard let baseAddress = bufferPointer.baseAddress else { return 0 }
                return Int(read(sourceFD, baseAddress, bufferPointer.count))
            }
            if bytesRead == 0 { break }
            if bytesRead < 0 {
                if errno == EINTR { continue }
                throw posixReadError("Αδυναμία ανάγνωσης attachment από το επιλεγμένο backup.")
            }
            let (nextTotal, overflow) = totalBytes.addingReportingOverflow(Int64(bytesRead))
            guard !overflow, nextTotal <= expectedSize else {
                throw BoundedRegularFileReaderError.sizeMismatch(expected: expectedSize, actual: overflow ? Int64.max : nextTotal)
            }
            try writeAll(buffer, count: bytesRead, to: destinationFD)
            totalBytes = nextTotal
        }

        guard totalBytes == expectedSize else {
            throw BoundedRegularFileReaderError.sizeMismatch(expected: expectedSize, actual: totalBytes)
        }
        let finalSourceSize = try regularFileSize(from: sourceFD)
        guard finalSourceSize == expectedSize else {
            throw BoundedRegularFileReaderError.sizeMismatch(expected: expectedSize, actual: finalSourceSize)
        }
        guard fsync(destinationFD) == 0 else {
            throw posixReadError("Αδυναμία επαλήθευσης αντιγράφου attachment.")
        }
        removePartial = false
        return totalBytes
    }

    /// Compares a bundle file against an application-owned target using open descriptors.
    static func filesHaveEqualBytes(
        relativePath: String,
        relativeTo baseDirectory: URL,
        andAt otherURL: URL
    ) throws -> Bool {
        let bundleFD = try openRegularFileDescriptor(relativePath: relativePath, relativeTo: baseDirectory)
        defer { _ = close(bundleFD) }
        let otherFD = open(otherURL.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW)
        guard otherFD >= 0 else {
            if errno == ENOENT { return false }
            if errno == ELOOP { throw BoundedRegularFileReaderError.notRegularFile }
            throw posixReadError("Αδυναμία ασφαλούς ανάγνωσης του υπάρχοντος αρχείου.")
        }
        defer { _ = close(otherFD) }

        let bundleSize = try regularFileSize(from: bundleFD)
        let otherSize = try regularFileSize(from: otherFD)
        guard bundleSize == otherSize else { return false }
        var left = [UInt8](repeating: 0, count: 64 * 1024)
        var right = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let leftCount = try readChunk(from: bundleFD, into: &left)
            let rightCount = try readChunk(from: otherFD, into: &right)
            guard leftCount == rightCount else { return false }
            guard leftCount > 0 else { return true }
            guard left[0..<leftCount].elementsEqual(right[0..<rightCount]) else { return false }
        }
    }

    private static func relativePath(for url: URL, relativeTo baseDirectory: URL) throws -> String {
        let basePath = baseDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
        guard targetPath.hasPrefix(prefix) else { throw BoundedRegularFileReaderError.notRegularFile }
        let relativePath = String(targetPath.dropFirst(prefix.count))
        try validateRelativePath(relativePath)
        return relativePath
    }

    private static func validateRelativePath(_ relativePath: String) throws {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\") }) else {
            throw BoundedRegularFileReaderError.notRegularFile
        }
    }

    private static func openRegularFileDescriptor(
        relativePath: String,
        relativeTo baseDirectory: URL,
        beforeLeafOpen: (() -> Void)? = nil
    ) throws -> Int32 {
        try validateRelativePath(relativePath)
        let basePath = baseDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        var directoryFD = open(basePath, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard directoryFD >= 0 else { throw posixReadError("Αδυναμία ανοίγματος του επιλεγμένου φακέλου.") }
        defer { _ = close(directoryFD) }

        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        for component in components.dropLast() {
            let childFD = component.withCString { name in
                openat(directoryFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
            guard childFD >= 0 else {
                if errno == ELOOP || errno == ENOTDIR { throw BoundedRegularFileReaderError.notRegularFile }
                throw posixReadError("Αδυναμία ασφαλούς διέλευσης φακέλου backup.")
            }
            _ = close(directoryFD)
            directoryFD = childFD
        }

        beforeLeafOpen?()
        let filename = String(components[components.count - 1])
        let descriptor = filename.withCString { name in
            openat(directoryFD, name, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW)
        }
        guard descriptor >= 0 else {
            if errno == ELOOP || errno == ENOTDIR { throw BoundedRegularFileReaderError.notRegularFile }
            throw posixReadError("Αδυναμία ανοίγματος αρχείου από το επιλεγμένο backup.")
        }
        do {
            _ = try regularFileSize(from: descriptor)
        } catch {
            _ = close(descriptor)
            throw error
        }
        return descriptor
    }

    private static func regularFileSize(from descriptor: Int32) throws -> Int64 {
        var attributes = stat()
        guard fstat(descriptor, &attributes) == 0 else {
            throw posixReadError("Αδυναμία επαλήθευσης αρχείου πριν από τη χρήση.")
        }
        guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw BoundedRegularFileReaderError.notRegularFile
        }
        return Int64(attributes.st_size)
    }

    private static func readChunk(from descriptor: Int32, into buffer: inout [UInt8]) throws -> Int {
        while true {
            let count = buffer.withUnsafeMutableBufferPointer { pointer -> Int in
                guard let baseAddress = pointer.baseAddress else { return 0 }
                return Int(read(descriptor, baseAddress, pointer.count))
            }
            if count >= 0 { return count }
            if errno != EINTR { throw posixReadError("Σφάλμα κατά την ανάγνωση αρχείου.") }
        }
    }

    private static func writeAll(_ buffer: [UInt8], count: Int, to descriptor: Int32) throws {
        var offset = 0
        while offset < count {
            let bytesWritten = buffer.withUnsafeBytes { pointer -> Int in
                guard let baseAddress = pointer.baseAddress else { return 0 }
                return Int(write(descriptor, baseAddress.advanced(by: offset), count - offset))
            }
            if bytesWritten < 0 {
                if errno == EINTR { continue }
                throw posixReadError("Αδυναμία εγγραφής αντιγράφου attachment.")
            }
            guard bytesWritten > 0 else { throw posixReadError("Αδυναμία ολοκλήρωσης εγγραφής attachment.") }
            offset += bytesWritten
        }
    }

    private static func readData(from descriptor: Int32, maximumBytes: Int) throws -> Data {

        var attributes = stat()
        guard fstat(descriptor, &attributes) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
                NSLocalizedDescriptionKey: "Αδυναμία επαλήθευσης αρχείου πριν από την ανάγνωση."
            ])
        }
        let entryType = attributes.st_mode & mode_t(S_IFMT)
        guard entryType == mode_t(S_IFREG) else {
            throw BoundedRegularFileReaderError.notRegularFile
        }
        guard attributes.st_size <= off_t(maximumBytes) else {
            throw BoundedRegularFileReaderError.exceedsMaximumBytes(maximumBytes)
        }

        let chunkSize = min(64 * 1024, maximumBytes + 1)
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var data = Data()
        while true {
            let bytesRead = buffer.withUnsafeMutableBufferPointer { bufferPointer -> Int in
                guard let baseAddress = bufferPointer.baseAddress else { return 0 }
                return Int(read(descriptor, baseAddress, bufferPointer.count))
            }
            if bytesRead < 0 {
                if errno == EINTR { continue }
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
                    NSLocalizedDescriptionKey: "Σφάλμα κατά την bounded ανάγνωση αρχείου."
                ])
            }
            guard bytesRead > 0 else { return data }
            guard bytesRead <= maximumBytes - data.count else {
                throw BoundedRegularFileReaderError.exceedsMaximumBytes(maximumBytes)
            }
            data.append(contentsOf: buffer.prefix(bytesRead))
        }
    }

    private static func posixReadError(_ message: String) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
            NSLocalizedDescriptionKey: message
        ])
    }
}
