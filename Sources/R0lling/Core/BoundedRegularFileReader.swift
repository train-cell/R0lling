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

        let basePath = baseDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
        guard targetPath.hasPrefix(prefix) else {
            throw BoundedRegularFileReaderError.notRegularFile
        }
        let relativePath = String(targetPath.dropFirst(prefix.count))
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw BoundedRegularFileReaderError.notRegularFile
        }

        var directoryFD = open(basePath, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directoryFD >= 0 else {
            throw posixReadError("Αδυναμία ανοίγματος του επιλεγμένου vault.")
        }
        defer { _ = close(directoryFD) }

        for component in components.dropLast() {
            let childFD = component.withCString { name in
                openat(directoryFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
            guard childFD >= 0 else {
                if errno == ELOOP || errno == ENOTDIR {
                    throw BoundedRegularFileReaderError.notRegularFile
                }
                throw posixReadError("Αδυναμία ασφαλούς διέλευσης φακέλου Obsidian.")
            }
            _ = close(directoryFD)
            directoryFD = childFD
        }

        let filename = String(components[components.count - 1])
        let fileFD = filename.withCString { name in
            openat(directoryFD, name, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW)
        }
        guard fileFD >= 0 else {
            if errno == ELOOP { throw BoundedRegularFileReaderError.notRegularFile }
            throw posixReadError("Αδυναμία ανοίγματος managed αρχείου Obsidian.")
        }
        defer { _ = close(fileFD) }
        return try readData(from: fileFD, maximumBytes: maximumBytes)
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
