import Foundation

/// Bounds the two file copies used by Photos import before creating its temporary copy.
enum MediaImportPreflight {
    static func requiredFreeSpace(payloadBytes: Int64, totalCopies: Int64 = 2) -> Int64? {
        guard payloadBytes > 0, totalCopies > 0 else { return nil }
        let copies = payloadBytes.multipliedReportingOverflow(by: totalCopies)
        guard !copies.overflow else { return nil }
        let required = copies.partialValue.addingReportingOverflow(ELAXISTOS_ELEUTHEROS_XOROS_BYTES)
        return required.overflow ? nil : required.partialValue
    }

    /// Rejects special files and insufficient capacity before Photos copies an asset into temp.
    static func validatePhotosStagingSource(at sourceURL: URL, availableBytes: Int64) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let sourceSize = attributes[.size] as? NSNumber,
              sourceSize.int64Value > 0 else {
            throw MediaApothikeusiError.kenoDedomena
        }
        let payloadBytes = sourceSize.int64Value
        guard let required = requiredFreeSpace(payloadBytes: payloadBytes) else {
            throw MediaApothikeusiError.anepikisXoros(diathesima: availableBytes, apaitoumena: Int64.max)
        }
        guard availableBytes >= required else {
            throw MediaApothikeusiError.anepikisXoros(diathesima: availableBytes, apaitoumena: required)
        }
        return payloadBytes
    }
}

/// Διαχείριση αποθήκευσης αρχείων πολυμέσων (Photos, Videos, Clips, Audio)
public actor MediaStorageService: MediaStorageProtocol {
    private let baseMediaDirectory: URL
    /// Αν `true`, αγνοεί τον έλεγχο δίσκου (μόνο unit tests).
    private let paradekampseElegxoXorou: Bool
    private let availableFreeDiskSpaceProvider: @Sendable () -> Int64

    public init(
        baseDirectory: URL? = nil,
        paradekampseElegxoXorou: Bool = false,
        availableFreeDiskSpaceProvider: (@Sendable () -> Int64)? = nil
    ) {
        self.paradekampseElegxoXorou = paradekampseElegxoXorou
        let resolvedBaseDirectory: URL
        if let dir = baseDirectory {
            resolvedBaseDirectory = dir
        } else if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            resolvedBaseDirectory = docs.appendingPathComponent("R0lling/Media", isDirectory: true)
        } else {
            // Fail-soft: χωρίς Documents (σπάνιο) → temp, όχι force-unwrap crash.
            resolvedBaseDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("R0lling/Media", isDirectory: true)
        }
        self.baseMediaDirectory = resolvedBaseDirectory
        self.availableFreeDiskSpaceProvider = availableFreeDiskSpaceProvider ?? {
            do {
                let values = try resolvedBaseDirectory.resourceValues(
                    forKeys: [.volumeAvailableCapacityForImportantUsageKey]
                )
                return values.volumeAvailableCapacityForImportantUsage ?? 0
            } catch {
                return 0
            }
        }
    }

    public func saveMediaFile(data: Data, originalFilename: String, mediaType: MediaType) throws -> MediaAttachment {
        guard !data.isEmpty else {
            throw MediaApothikeusiError.kenoDedomena
        }

        let mediaDirectory = try ensureMediaDirectory(for: mediaType)

        if !paradekampseElegxoXorou {
            let diathesima = availableFreeDiskSpace()
            let requiredSpace = requiredFreeSpace(forPayloadBytes: Int64(data.count))
            guard let requiredSpace, diathesima >= requiredSpace else {
                throw MediaApothikeusiError.anepikisXoros(
                    diathesima: diathesima,
                    apaitoumena: requiredSpace ?? Int64.max
                )
            }
        }

        let id = UUID()
        let safeExtension = safeFileExtension(for: originalFilename, mediaType: mediaType)
        let filename = "\(id.uuidString).\(safeExtension)"
        let relativePath = "\(mediaType.folderName)/\(filename)"
        let destinationURL = mediaDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: destinationURL, options: R0llingFileProtection.atomicWriteOptions)
        } catch {
            throw MediaApothikeusiError.egrafiApetixe(minima: error.localizedDescription)
        }

        // Verify file exists — no pretend success.
        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw MediaApothikeusiError.egrafiApetixe(minima: "Το αρχείο δεν εμφανίστηκε μετά την εγγραφή.")
        }

        let attachment = MediaAttachment(
            id: id,
            relativePath: relativePath,
            originalFilename: displayFilename(for: originalFilename, fallback: filename),
            mediaType: mediaType,
            byteSize: Int64(data.count),
            durationSeconds: nil,
            captureTimestamp: Date(),
            width: nil,
            height: nil,
            hasAudio: mediaType == .audio
        )

        return attachment
    }

    /// File-backed import for Photos/Files assets, including large videos.
    public func saveMediaFile(from sourceURL: URL, originalFilename: String, mediaType: MediaType) throws -> MediaAttachment {
        let sourceValues = try sourceURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard sourceValues.isRegularFile == true,
              let sourceSize = sourceValues.fileSize,
              sourceSize > 0 else {
            throw MediaApothikeusiError.kenoDedomena
        }

        let mediaDirectory = try ensureMediaDirectory(for: mediaType)
        if !paradekampseElegxoXorou {
            let requiredSpace = requiredFreeSpace(forPayloadBytes: Int64(sourceSize))
            let available = availableFreeDiskSpace()
            guard let requiredSpace, available >= requiredSpace else {
                throw MediaApothikeusiError.anepikisXoros(
                    diathesima: available,
                    apaitoumena: requiredSpace ?? Int64.max
                )
            }
        }

        let id = UUID()
        let safeExtension = safeFileExtension(for: originalFilename, mediaType: mediaType)
        let relativePath = "\(mediaType.folderName)/\(id.uuidString).\(safeExtension)"
        let destinationURL = mediaDirectory.appendingPathComponent("\(id.uuidString).\(safeExtension)")
        let stagedURL = destinationURL.deletingLastPathComponent()
            .appendingPathComponent(".import-\(UUID().uuidString).\(safeExtension)")

        do {
            try FileManager.default.copyItem(at: sourceURL, to: stagedURL)
            let copiedValues = try stagedURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard copiedValues.isRegularFile == true, copiedValues.fileSize == sourceSize else {
                throw MediaApothikeusiError.egrafiApetixe(minima: "Το αντιγραμμένο αρχείο δεν ταιριάζει με την πηγή.")
            }
            try R0llingFileProtection.apply(to: stagedURL)
            try FileManager.default.moveItem(at: stagedURL, to: destinationURL)
        } catch {
            try? FileManager.default.removeItem(at: stagedURL)
            if let mediaError = error as? MediaApothikeusiError { throw mediaError }
            throw MediaApothikeusiError.egrafiApetixe(minima: error.localizedDescription)
        }

        return MediaAttachment(
            id: id,
            relativePath: relativePath,
            originalFilename: displayFilename(for: originalFilename, fallback: "\(id.uuidString).\(safeExtension)"),
            mediaType: mediaType,
            byteSize: Int64(sourceSize),
            durationSeconds: nil,
            captureTimestamp: Date(),
            width: nil,
            height: nil,
            hasAudio: mediaType == .audio
        )
    }

    private func safeFileExtension(for originalFilename: String, mediaType: MediaType) -> String {
        let fileExtension = (originalFilename as NSString).pathExtension.lowercased()
        // The caller controls only a short alphanumeric suffix, never any path component.
        let isSafeExtension = !fileExtension.isEmpty
            && fileExtension.utf8.count <= 12
            && fileExtension.utf8.allSatisfy { byte in
                (byte >= 48 && byte <= 57) || (byte >= 97 && byte <= 122)
            }
        return isSafeExtension ? fileExtension : defaultExtension(for: mediaType)
    }

    /// Keeps the user-facing source name without storing a caller-supplied path in the journal.
    private func displayFilename(for originalFilename: String, fallback: String) -> String {
        let normalized = originalFilename.replacingOccurrences(of: "\\", with: "/")
        let basename = normalized.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        let cleanBasename = String(basename.trimmingCharacters(in: .whitespacesAndNewlines).prefix(255))
        guard !cleanBasename.isEmpty, cleanBasename != ".", cleanBasename != ".." else {
            return fallback
        }
        return cleanBasename
    }

    private nonisolated func validatedMediaDirectory(for mediaType: MediaType) throws -> URL {
        let directory = baseMediaDirectory.appendingPathComponent(mediaType.folderName, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw MediaApothikeusiError.unsafeRelativePath(relativePath: mediaType.folderName)
        }
        let resolvedBase = baseMediaDirectory.resolvingSymlinksInPath().standardizedFileURL
        let resolvedDirectory = directory.resolvingSymlinksInPath().standardizedFileURL
        let expectedDirectory = resolvedBase
            .appendingPathComponent(mediaType.folderName, isDirectory: true)
            .standardizedFileURL
        guard resolvedDirectory == expectedDirectory else {
            throw MediaApothikeusiError.unsafeRelativePath(relativePath: mediaType.folderName)
        }
        return resolvedDirectory
    }

    /// Creates only the requested media folder after checking that it is not redirected by a symlink.
    /// Resolving the configured base first allows an explicitly configured base symlink while keeping
    /// each Photos/Videos/Clips/Audio folder inside that resolved base.
    private nonisolated func ensureMediaDirectory(for mediaType: MediaType) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: baseMediaDirectory, withIntermediateDirectories: true)

        let resolvedBase = baseMediaDirectory.resolvingSymlinksInPath().standardizedFileURL
        let expectedDirectory = resolvedBase
            .appendingPathComponent(mediaType.folderName, isDirectory: true)
            .standardizedFileURL
        let unresolvedDirectory = baseMediaDirectory.appendingPathComponent(mediaType.folderName, isDirectory: true)

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: unresolvedDirectory.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue,
                  unresolvedDirectory.resolvingSymlinksInPath().standardizedFileURL == expectedDirectory else {
                throw MediaApothikeusiError.unsafeRelativePath(relativePath: mediaType.folderName)
            }
        } else {
            try fileManager.createDirectory(at: expectedDirectory, withIntermediateDirectories: false)
        }

        try R0llingFileProtection.apply(to: resolvedBase)
        try R0llingFileProtection.apply(to: expectedDirectory)

        // Recheck after creation and use the resolved location for all I/O.
        guard fileManager.fileExists(atPath: unresolvedDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              unresolvedDirectory.resolvingSymlinksInPath().standardizedFileURL == expectedDirectory else {
            throw MediaApothikeusiError.unsafeRelativePath(relativePath: mediaType.folderName)
        }
        return expectedDirectory
    }

    public nonisolated func getMediaFileURL(relativePath: String) throws -> URL {
        let components = relativePath.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
        let normalizedRelativePath = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard components.count == 2,
              let mediaType = MediaType.allCases.first(where: { $0.folderName == String(components[0]) }),
              !components[1].isEmpty,
              normalizedRelativePath == "\(components[0])/\(components[1])",
              components[1] != ".",
              components[1] != ".." else {
            throw MediaApothikeusiError.unsafeRelativePath(relativePath: relativePath)
        }

        let url = try PathAsfaleia.asfalhs_resolved_url(
            relativePath: relativePath,
            baseDirectory: baseMediaDirectory
        )
        // Compare canonical paths: a type folder that does not exist yet resolves without its
        // trailing slash, so `URL ==` rejected every first restore target or missing clip.
        let expectedDirectory = baseMediaDirectory.appendingPathComponent(mediaType.folderName, isDirectory: true)
        guard PathAsfaleia.canonicalPath(of: url.deletingLastPathComponent())
                == PathAsfaleia.canonicalPath(of: expectedDirectory),
              url.lastPathComponent == String(components[1]) else {
            throw MediaApothikeusiError.unsafeRelativePath(relativePath: relativePath)
        }

        // Existing symlinks, directories, and special files must never be consumed as media.
        var isDirectory: ObjCBool = false
        let unresolvedURL = baseMediaDirectory
            .appendingPathComponent(normalizedRelativePath)
        if FileManager.default.fileExists(atPath: unresolvedURL.path, isDirectory: &isDirectory) {
            let attributes = try FileManager.default.attributesOfItem(atPath: unresolvedURL.path)
            guard !isDirectory.boolValue,
                  attributes[.type] as? FileAttributeType == .typeRegular else {
                throw MediaApothikeusiError.unsafeRelativePath(relativePath: relativePath)
            }
            try R0llingFileProtection.apply(to: unresolvedURL)
        }
        return url
    }

    public func deleteMediaFile(relativePath: String) throws {
        let fileURL = try getMediaFileURL(relativePath: relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw MediaApothikeusiError.unsafeRelativePath(relativePath: relativePath)
            }
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    public nonisolated func availableFreeDiskSpace() -> Int64 {
        availableFreeDiskSpaceProvider()
    }

    private nonisolated func requiredFreeSpace(forPayloadBytes payloadBytes: Int64) -> Int64? {
        guard payloadBytes >= 0 else { return nil }
        let result = payloadBytes.addingReportingOverflow(ELAXISTOS_ELEUTHEROS_XOROS_BYTES)
        return result.overflow ? nil : result.partialValue
    }

    public func cleanupOrphanedFiles(activeRelativePaths: Set<String>) throws -> Int {
        var removedCount = 0
        let fileManager = FileManager.default

        for type in MediaType.allCases {
            let subDir = baseMediaDirectory.appendingPathComponent(type.folderName, isDirectory: true)
            guard fileManager.fileExists(atPath: subDir.path) else { continue }
            let safeSubDirectory = try validatedMediaDirectory(for: type)
            let fileURLs = try fileManager.contentsOfDirectory(at: safeSubDirectory, includingPropertiesForKeys: nil)

            for fileURL in fileURLs {
                let relPath = "\(type.folderName)/\(fileURL.lastPathComponent)"
                if !activeRelativePaths.contains(relPath) {
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    guard attributes[.type] as? FileAttributeType == .typeRegular else { continue }
                    try fileManager.removeItem(at: fileURL)
                    removedCount += 1
                }
            }
        }
        return removedCount
    }

    private func defaultExtension(for mediaType: MediaType) -> String {
        switch mediaType {
        case .photo: return "jpg"
        case .video, .clip: return "mp4"
        case .audio: return "m4a"
        }
    }
}
