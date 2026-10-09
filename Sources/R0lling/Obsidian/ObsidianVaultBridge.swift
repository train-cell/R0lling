import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct ObsidianExportResult: Sendable, Equatable {
    public let exportedFilesCount: Int
    public let modifiedFiles: [String]
    public let conflictsDetected: [String]

    public init(exportedFilesCount: Int, modifiedFiles: [String], conflictsDetected: [String]) {
        self.exportedFilesCount = exportedFilesCount
        self.modifiedFiles = modifiedFiles
        self.conflictsDetected = conflictsDetected
    }
}

/// Αποτέλεσμα εξαγωγής μίας εγγραφής (R3-005: ρητή δήλωση conflict).
public struct ObsidianSingleExportResult: Sendable, Equatable {
    public let noteURL: URL
    public let hadConflict: Bool
    public let conflictSidecarRelativePath: String?

    public init(noteURL: URL, hadConflict: Bool, conflictSidecarRelativePath: String? = nil) {
        self.noteURL = noteURL
        self.hadConflict = hadConflict
        self.conflictSidecarRelativePath = conflictSidecarRelativePath
    }
}

/// Γέφυρα συγχρονισμού και εξαγωγής Markdown με το Obsidian Vault (A08/A09).
public actor ObsidianVaultBridge {
    private static let hashStoreRelativePath = "R0llingMeta/export-hashes.json"
    private static let attachmentsFolderName = "Attachments"
    private static let maximumDailyNoteBytes = 16 * 1024 * 1024
    private static let maximumHashMetadataBytes = 16 * 1024 * 1024

    private var vaultDirectoryURL: URL?
    private var vaultRequiresScopedAccess: Bool = false
    private var lastKnownHashes: [String: String] = [:]
    private var hashesFortomenoi: Bool = false

    public init(vaultURL: URL? = nil) {
        if let url = vaultURL {
            self.vaultDirectoryURL = url
            self.vaultRequiresScopedAccess = false
        } else if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.vaultDirectoryURL = docs.appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
            self.vaultRequiresScopedAccess = false
        } else {
            self.vaultDirectoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
            self.vaultRequiresScopedAccess = false
        }
    }

    /// Ορισμός vault URL (default Documents ή security-scoped από Files picker).
    public func setVaultURL(_ url: URL, requiresScopedAccess: Bool = false) async {
        self.vaultDirectoryURL = url
        self.vaultRequiresScopedAccess = requiresScopedAccess
        self.hashesFortomenoi = false
        self.lastKnownHashes = [:]
    }

    public var currentVaultURL: URL? {
        vaultDirectoryURL
    }

    public var requiresScopedAccess: Bool {
        vaultRequiresScopedAccess
    }

    /// Εμφανίσιμο path για UI.
    public var displayPath: String {
        vaultDirectoryURL?.path ?? "—"
    }

    /// Writes generated vault content without replacing a pre-existing user file.
    /// Identical generated content is idempotent; differing content is written to a conflict sidecar.
    public func grapse_arxeio_sto_vault(relativePath: String, contents: String) async throws -> URL {
        try await me_prosbasi_vault {
            guard let vaultURL = vaultDirectoryURL else {
                throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
            }
            let destURL = try Self.resolvedVaultPathWithoutSymlinks(
                relativePath: relativePath,
                baseDirectory: vaultURL
            )
            try FileManager.default.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = Data(contents.utf8)
            if FileManager.default.fileExists(atPath: destURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: destURL.path)
                guard attributes[.type] as? FileAttributeType == .typeRegular else {
                    throw obsidianError(6006, "Το αρχείο προορισμού δεν είναι κανονικό αρχείο· το export δεν το αντικατέστησε.")
                }
                if try file(destURL, matches: data) {
                    return destURL
                }

                return try createConflictSidecar(for: destURL, data: data)
            }

            if try Self.writeFileExclusively(at: destURL, contents: data) {
                return destURL
            }

            // The path appeared after the initial existence check. Re-evaluate it without overwriting.
            let attributes = try FileManager.default.attributesOfItem(atPath: destURL.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw obsidianError(6006, "Το αρχείο προορισμού δεν είναι κανονικό αρχείο· το export δεν το αντικατέστησε.")
            }
            if try file(destURL, matches: data) { return destURL }
            return try createConflictSidecar(for: destURL, data: data)
        }
    }

    /// Creates a new regular file atomically, returning false if the path already exists.
    /// O_EXCL prevents a concurrent edit or symlink from being replaced between check and write.
    static func writeFileExclusively(at url: URL, contents data: Data) throws -> Bool {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(S_IRUSR | S_IWUSR))
        guard descriptor >= 0 else {
            if errno == EEXIST { return false }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
                NSLocalizedDescriptionKey: "Δεν ήταν δυνατή η αποκλειστική δημιουργία αρχείου στο Obsidian Vault."
            ])
        }

        var removePartialFile = true
        defer {
            _ = close(descriptor)
            if removePartialFile { _ = unlink(url.path) }
        }

        var writeError: Int32 = 0
        let wroteAllBytes = data.withUnsafeBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return data.isEmpty }
            var offset = 0
            while offset < rawBuffer.count {
                let written = write(descriptor, baseAddress.advanced(by: offset), rawBuffer.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    writeError = errno
                    return false
                }
                guard written > 0 else {
                    writeError = EIO
                    return false
                }
                offset += written
            }
            return true
        }
        guard wroteAllBytes else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(writeError), userInfo: [
                NSLocalizedDescriptionKey: "Δεν ήταν δυνατή η εγγραφή του Obsidian Vault αρχείου."
            ])
        }
        removePartialFile = false
        return true
    }

    private func createConflictSidecar(for destinationURL: URL, data: Data) throws -> URL {
        let baseName = destinationURL.deletingPathExtension().lastPathComponent
        let fileExtension = destinationURL.pathExtension
        let conflictPrefix = "\(baseName).r0lling-conflict-"
        let conflictSuffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
        let existingFiles = try FileManager.default.contentsOfDirectory(
            at: destinationURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )
        for conflictURL in existingFiles where conflictURL.lastPathComponent.hasPrefix(conflictPrefix)
            && conflictURL.lastPathComponent.hasSuffix(conflictSuffix) {
            let attributes = try FileManager.default.attributesOfItem(atPath: conflictURL.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else { continue }
            if try file(conflictURL, matches: data) { return conflictURL }
        }
        for _ in 0..<3 {
            let conflictName = "\(conflictPrefix)\(UUID().uuidString)\(conflictSuffix)"
            let conflictURL = destinationURL.deletingLastPathComponent().appendingPathComponent(conflictName)
            if try Self.writeFileExclusively(at: conflictURL, contents: data) { return conflictURL }
        }
        throw obsidianError(6007, "Δεν ήταν δυνατή η δημιουργία ασφαλούς conflict αρχείου για το Obsidian export.")
    }

    /// Ανάγνωση ημερήσιας σημείωσης από vault (import/read path — χωρίς overwrite journal).
    public func diabase_imerisia_simeiosi(dateKey: String) async throws -> String? {
        try await me_prosbasi_vault {
            guard let vaultURL = vaultDirectoryURL else {
                throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
            }
            let relative = try relative_note_path(gia: dateKey)
            let noteURL = try Self.resolvedVaultPathWithoutSymlinks(
                relativePath: relative,
                baseDirectory: vaultURL
            )
            guard FileManager.default.fileExists(atPath: noteURL.path) else { return nil }
            let data = try readManagedFile(
                at: noteURL,
                relativeTo: vaultURL,
                maximumBytes: Self.maximumDailyNoteBytes
            )
            guard let text = String(data: data, encoding: .utf8) else {
                throw obsidianError(6005, "Η ημερήσια σημείωση δεν είναι έγκυρο UTF-8.")
            }
            return text
        }
    }

    /// Εξαγωγή μίας καταχώρισης στο ημερήσιο Markdown (YYYY/MM/YYYY-MM-DD.md).
    /// R3-005 / A09: hash mismatch → sidecar `.r0lling-conflict.md`, χωρίς overwrite.
    @discardableResult
    public func exportEntry(_ entry: JournalEntry, mediaStorage: MediaStorageProtocol) async throws -> ObsidianSingleExportResult {
        try await me_prosbasi_vault {
            try await exportEntryLocked(entry, mediaStorage: mediaStorage)
        }
    }

    /// Εξαγωγή συνόλου εγγραφών (Batch Export — A08).
    public func exportBatch(entries: [JournalEntry], mediaStorage: MediaStorageProtocol) async throws -> ObsidianExportResult {
        try await me_prosbasi_vault {
            var exportedPaths = Set<String>()
            var modifiedList: [String] = []
            var conflictsList: [String] = []

            let grouped = Dictionary(grouping: entries, by: { $0.dateKey })

            for (_, dayEntries) in grouped {
                for entry in dayEntries {
                    let outcome = try await exportEntryLocked(entry, mediaStorage: mediaStorage)
                    if outcome.hadConflict {
                        if let sidecar = outcome.conflictSidecarRelativePath, !conflictsList.contains(sidecar) {
                            conflictsList.append(sidecar)
                        }
                    } else {
                        let path = outcome.noteURL.standardizedFileURL.path
                        if exportedPaths.insert(path).inserted {
                            modifiedList.append(outcome.noteURL.lastPathComponent)
                        }
                    }
                }
            }

            return ObsidianExportResult(
                exportedFilesCount: exportedPaths.count,
                modifiedFiles: modifiedList,
                conflictsDetected: conflictsList
            )
        }
    }

    // MARK: - Locked export (caller already holds scoped access)

    private func exportEntryLocked(
        _ entry: JournalEntry,
        mediaStorage: MediaStorageProtocol
    ) async throws -> ObsidianSingleExportResult {
        guard let vaultURL = vaultDirectoryURL else {
            throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
        }
        if !hashesFortomenoi {
            try fortosi_hashes_apo_disk_unlocked()
        }

        let relativeNotePath = try relative_note_path(gia: entry.dateKey)
        let noteURL = try Self.resolvedVaultPathWithoutSymlinks(
            relativePath: relativeNotePath,
            baseDirectory: vaultURL
        )
        let yearMonthDir = noteURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: yearMonthDir, withIntermediateDirectories: true)

        let dayString = entry.dateKey

        var existingContent = ""
        var existingContentHash: String?

        // A09: εξωτερική τροποποίηση αν υπάρχει καταγεγραμμένο hash.
        if FileManager.default.fileExists(atPath: noteURL.path) {
            guard try isRegularFile(noteURL) else {
                throw obsidianError(6005, "Η ημερήσια σημείωση δεν είναι κανονικό αρχείο· το export σταμάτησε για να μην αντιγράψει ή αντικαταστήσει φάκελο.")
            }
            let existingData = try readManagedFile(
                at: noteURL,
                relativeTo: vaultURL,
                maximumBytes: Self.maximumDailyNoteBytes
            )
            let existingHash = existingData.sha256Hash
            existingContentHash = existingHash
            guard let decodedContent = String(data: existingData, encoding: .utf8) else {
                throw obsidianError(6005, "Η ημερήσια σημείωση δεν είναι έγκυρο UTF-8· το export σταμάτησε για να μην αντικαταστήσει το αρχείο.")
            }
            if let recordedHash = lastKnownHashes[relativeNotePath] {
                if recordedHash != existingHash {
                    return try grapse_conflict_sidecar(
                        dayString: dayString,
                        relativeNotePath: relativeNotePath,
                        noteURL: noteURL,
                        existingContent: decodedContent,
                        entry: entry,
                        vaultURL: vaultURL
                    )
                }
            } else {
                let entryTagMarker = "<!-- r0lling:id:\(entry.id.uuidString) -->"
                if decodedContent.contains(entryTagMarker) {
                    return try grapse_conflict_sidecar(
                        dayString: dayString,
                        relativeNotePath: relativeNotePath,
                        noteURL: noteURL,
                        existingContent: decodedContent,
                        entry: entry,
                        vaultURL: vaultURL
                    )
                }
                // Πρώτη επαφή μετά restart χωρίς hash: seed baseline (χωρίς conflict ψευδώς).
                lastKnownHashes[relativeNotePath] = existingHash
                try apothikeusi_hashes_sto_disk(vaultURL: vaultURL)
            }
            existingContent = decodedContent
        }

        try await antigrafi_attachments(entry: entry, mediaStorage: mediaStorage, vaultURL: vaultURL)

        let updatedContent = mergeEntryIntoMarkdown(
            existingContent: existingContent,
            entry: entry,
            dayTitle: dayString
        )
        if let conflictContent = try writeNoteIfUnchanged(
            at: noteURL,
            relativePath: relativeNotePath,
            vaultURL: vaultURL,
            expectedHash: existingContentHash,
            originalContent: existingContent,
            updatedContent: updatedContent
        ) {
            return try grapse_conflict_sidecar(
                dayString: dayString,
                relativeNotePath: relativeNotePath,
                noteURL: noteURL,
                existingContent: conflictContent,
                entry: entry,
                vaultURL: vaultURL
            )
        }

        lastKnownHashes[relativeNotePath] = updatedContent.sha256Hash
        try apothikeusi_hashes_sto_disk(vaultURL: vaultURL)
        return ObsidianSingleExportResult(
            noteURL: noteURL,
            hadConflict: false,
            conflictSidecarRelativePath: nil
        )
    }

    private func grapse_conflict_sidecar(
        dayString: String,
        relativeNotePath: String,
        noteURL: URL,
        existingContent: String,
        entry: JournalEntry,
        vaultURL: URL
    ) throws -> ObsidianSingleExportResult {
        let attemptedMerge = mergeEntryIntoMarkdown(
            existingContent: existingContent,
            entry: entry,
            dayTitle: dayString
        )
        let sidecarName = "\(dayString).r0lling-conflict.md"
        let sidecarRelative = relativeNotePath
            .split(separator: "/")
            .dropLast()
            .map(String.init)
            .joined(separator: "/")
        let sidecarRelativePath = sidecarRelative.isEmpty
            ? sidecarName
            : "\(sidecarRelative)/\(sidecarName)"
        let sidecarBody = """
        # R0lling Conflict — \(dayString)

        Εξωτερική τροποποίηση ανιχνεύθηκε. Το πρωτότυπο `\(dayString).md` **δεν** υπεργράφηκε.

        ---
        ## Προτεινόμενη συγχώνευση R0lling (μη εφαρμοσμένη)

        \(attemptedMerge)
        """
        let sidecarDirectory: URL
        if sidecarRelative.isEmpty {
            sidecarDirectory = vaultURL
        } else {
            sidecarDirectory = try Self.resolvedVaultPathWithoutSymlinks(
                relativePath: sidecarRelative,
                baseDirectory: vaultURL
            )
        }
        try FileManager.default.createDirectory(
            at: sidecarDirectory,
            withIntermediateDirectories: true
        )
        let data = Data(sidecarBody.utf8)
        var finalSidecarRelativePath = sidecarRelativePath
        var sidecarURL = try Self.resolvedVaultPathWithoutSymlinks(
            relativePath: sidecarRelativePath,
            baseDirectory: vaultURL
        )
        if !(try Self.writeFileExclusively(at: sidecarURL, contents: data)) {
            if try isRegularFile(sidecarURL), try file(sidecarURL, matches: data) {
                // Reuse identical conflict output; never replace an existing sidecar.
            } else {
                var created = false
                let conflictPrefix = "\(dayString).r0lling-conflict-"
                let existingSidecars = try FileManager.default.contentsOfDirectory(
                    at: sidecarDirectory,
                    includingPropertiesForKeys: nil
                )
                for existingURL in existingSidecars where existingURL.lastPathComponent.hasPrefix(conflictPrefix)
                    && existingURL.lastPathComponent.hasSuffix(".md") {
                    guard try isRegularFile(existingURL) else { continue }
                    if try file(existingURL, matches: data) {
                        let reusedName = existingURL.lastPathComponent
                        finalSidecarRelativePath = sidecarRelative.isEmpty
                            ? reusedName
                            : "\(sidecarRelative)/\(reusedName)"
                        sidecarURL = existingURL
                        created = true
                        break
                    }
                }
                for _ in 0..<3 {
                    guard !created else { break }
                    let uniqueName = "\(dayString).r0lling-conflict-\(UUID().uuidString).md"
                    let uniqueRelative = sidecarRelative.isEmpty
                        ? uniqueName
                        : "\(sidecarRelative)/\(uniqueName)"
                    let uniqueURL = try Self.resolvedVaultPathWithoutSymlinks(
                        relativePath: uniqueRelative,
                        baseDirectory: vaultURL
                    )
                    if try Self.writeFileExclusively(at: uniqueURL, contents: data) {
                        finalSidecarRelativePath = uniqueRelative
                        sidecarURL = uniqueURL
                        created = true
                        break
                    }
                    if try isRegularFile(uniqueURL), try file(uniqueURL, matches: data) {
                        finalSidecarRelativePath = uniqueRelative
                        sidecarURL = uniqueURL
                        created = true
                        break
                    }
                }
                guard created else {
                    throw obsidianError(6007, "Δεν ήταν δυνατή η δημιουργία ασφαλούς conflict αρχείου για το Obsidian export.")
                }
            }
        }
        print("[ObsidianVaultBridge] Conflict στο \(relativeNotePath) → sidecar \(finalSidecarRelativePath)")
        return ObsidianSingleExportResult(
            noteURL: noteURL,
            hadConflict: true,
            conflictSidecarRelativePath: finalSidecarRelativePath
        )
    }

    /// Revalidates the note after attachment I/O and coordinates its replacement.
    /// Returns the latest external content when a conflict was detected.
    private func writeNoteIfUnchanged(
        at noteURL: URL,
        relativePath: String,
        vaultURL: URL,
        expectedHash: String?,
        originalContent: String,
        updatedContent: String
    ) throws -> String? {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var writeError: Error?
        var conflictDetected = false
        var conflictContent: String?

        coordinator.coordinate(writingItemAt: noteURL, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                _ = try Self.resolvedVaultPathWithoutSymlinks(
                    relativePath: relativePath,
                    baseDirectory: vaultURL
                )
                if FileManager.default.fileExists(atPath: coordinatedURL.path) {
                    let attributes = try FileManager.default.attributesOfItem(atPath: coordinatedURL.path)
                    guard attributes[.type] as? FileAttributeType == .typeRegular else {
                        throw NSError(domain: "R0lling.Obsidian", code: 6005, userInfo: [
                            NSLocalizedDescriptionKey: "Η ημερήσια σημείωση δεν είναι κανονικό αρχείο· το export σταμάτησε."
                        ])
                    }
                    let latestData = try Data(contentsOf: coordinatedURL)
                    guard let latestContent = String(data: latestData, encoding: .utf8) else {
                        throw NSError(domain: "R0lling.Obsidian", code: 6005, userInfo: [
                            NSLocalizedDescriptionKey: "Η ημερήσια σημείωση δεν είναι έγκυρο UTF-8· το export σταμάτησε."
                        ])
                    }
                    if latestContent == updatedContent { return }
                    guard let expectedHash, latestData.sha256Hash == expectedHash else {
                        conflictDetected = true
                        conflictContent = latestContent
                        return
                    }
                } else if let expectedHash {
                    // The original note disappeared while attachments were being copied.
                    _ = expectedHash // Keep the branch explicit: a missing known note is a conflict.
                    conflictDetected = true
                    conflictContent = originalContent
                    return
                }

                try updatedContent.write(to: coordinatedURL, atomically: true, encoding: .utf8)
            } catch {
                writeError = error
            }
        }

        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
        return conflictDetected ? (conflictContent ?? originalContent) : nil
    }

    private func antigrafi_attachments(
        entry: JournalEntry,
        mediaStorage: MediaStorageProtocol,
        vaultURL: URL
    ) async throws {
        let attachmentsDir = try Self.resolvedVaultPathWithoutSymlinks(
            relativePath: Self.attachmentsFolderName,
            baseDirectory: vaultURL
        )
        try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

        for attachment in entry.attachments {
            let sourceURL: URL
            let destURL: URL
            do {
                try validateAttachmentStoragePath(attachment)
                sourceURL = try mediaStorage.getMediaFileURL(relativePath: attachment.relativePath)
                destURL = try Self.resolvedVaultPathWithoutSymlinks(
                    relativePath: "\(Self.attachmentsFolderName)/\(attachment.relativePath)",
                    baseDirectory: vaultURL
                )
            } catch {
                throw obsidianError(6011, "Μη ασφαλές attachment path στο Obsidian export: \(attachment.relativePath)")
            }
            guard try isRegularFile(sourceURL) else {
                throw obsidianError(6010, "Λείπει συνημμένο από το Obsidian export: \(attachment.relativePath)")
            }
            let sourceValues = try sourceURL.resourceValues(forKeys: [.fileSizeKey])
            guard let sourceSize = sourceValues.fileSize else {
                throw obsidianError(6010, "Δεν ήταν δυνατή η επιβεβαίωση του μεγέθους του συνημμένου: \(attachment.relativePath)")
            }

            try FileManager.default.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destURL.path) {
                guard try isRegularFile(destURL) else {
                    throw obsidianError(6012, "Ο προορισμός συνημμένου δεν είναι κανονικό αρχείο: \(attachment.relativePath)")
                }
                let destValues = try destURL.resourceValues(forKeys: [.fileSizeKey])
                guard destValues.fileSize == sourceSize,
                      try filesHaveEqualBytes(sourceURL, destURL) else {
                    throw obsidianError(6012, "Υπάρχει διαφορετικό αρχείο στο Obsidian attachment path: \(attachment.relativePath)")
                }
            } else {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                guard try isRegularFile(destURL),
                      try destURL.resourceValues(forKeys: [.fileSizeKey]).fileSize == sourceSize,
                      try filesHaveEqualBytes(sourceURL, destURL) else {
                    throw obsidianError(6012, "Το αντίγραφο συνημμένου στο Obsidian δεν επαληθεύτηκε: \(attachment.relativePath)")
                }
            }
        }
    }

    private func validateAttachmentStoragePath(_ attachment: MediaAttachment) throws {
        let parts = attachment.relativePath.split(separator: "/", omittingEmptySubsequences: false)
        let filename = parts.last ?? ""
        let hasSafeFilenameBytes = filename.utf8.allSatisfy { byte in
            switch byte {
            case 48...57, 65...90, 97...122, 45, 46, 95: return true
            default: return false
            }
        }
        guard parts.count == 2,
              parts[0] == Substring(attachment.mediaType.folderName),
              !filename.isEmpty,
              filename.utf8.count <= 255,
              filename.first != ".",
              hasSafeFilenameBytes else {
            throw obsidianError(6011, "Μη ασφαλές attachment path στο Obsidian export: \(attachment.relativePath)")
        }
    }

    private func isRegularFile(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        return values.isRegularFile == true
    }

    private func readManagedFile(at url: URL, relativeTo vaultURL: URL, maximumBytes: Int) throws -> Data {
        do {
            return try BoundedRegularFileReader.readData(
                at: url,
                relativeTo: vaultURL,
                maximumBytes: maximumBytes
            )
        } catch BoundedRegularFileReaderError.notRegularFile {
            throw obsidianError(6005, "Το managed αρχείο Obsidian δεν είναι κανονικό αρχείο.")
        } catch BoundedRegularFileReaderError.exceedsMaximumBytes {
            throw obsidianError(6013, "Το αρχείο Obsidian ξεπερνά το όριο ανάγνωσης των 16 MiB.")
        } catch {
            throw error
        }
    }

    private func filesHaveEqualBytes(_ lhs: URL, _ rhs: URL) throws -> Bool {
        let left = try FileHandle(forReadingFrom: lhs)
        let right = try FileHandle(forReadingFrom: rhs)
        defer {
            try? left.close()
            try? right.close()
        }
        while true {
            let leftChunk = try left.read(upToCount: 64 * 1024) ?? Data()
            let rightChunk = try right.read(upToCount: 64 * 1024) ?? Data()
            guard leftChunk == rightChunk else { return false }
            if leftChunk.isEmpty { return true }
        }
    }

    private func file(_ url: URL, matches data: Data) throws -> Bool {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? NSNumber,
              fileSize.int64Value == Int64(data.count) else { return false }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var offset = 0
        while offset < data.count {
            let upperBound = min(data.count, offset + 64 * 1024)
            let actual = try handle.read(upToCount: upperBound - offset) ?? Data()
            guard actual == data.subdata(in: offset..<upperBound) else { return false }
            offset = upperBound
        }
        return (try handle.read(upToCount: 1) ?? Data()).isEmpty
    }

    // MARK: - Hash persistence (A09 across restarts)

    /// Φόρτωση hashes — καλείται μόνο μέσα σε `me_prosbasi_vault` ή default vault.
    private func fortosi_hashes_apo_disk_unlocked() throws {
        guard let vaultURL = vaultDirectoryURL else {
            throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
        }

        let storeURL = try Self.resolvedVaultPathWithoutSymlinks(
            relativePath: Self.hashStoreRelativePath,
            baseDirectory: vaultURL
        )
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            lastKnownHashes = [:]
            hashesFortomenoi = true
            return
        }
        guard try isRegularFile(storeURL) else {
            throw obsidianError(6004, "Το Obsidian export metadata δεν είναι κανονικό αρχείο· το export σταμάτησε.")
        }

        let data: Data
        do {
            data = try readManagedFile(
                at: storeURL,
                relativeTo: vaultURL,
                maximumBytes: Self.maximumHashMetadataBytes
            )
        } catch {
            throw obsidianError(6004, "Αδυναμία ανάγνωσης Obsidian export metadata· το export σταμάτησε για να προστατεύσει εξωτερικές αλλαγές.")
        }

        let decoded: [String: String]
        do {
            decoded = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            throw obsidianError(6004, "Μη έγκυρα Obsidian export metadata· το export σταμάτησε για να προστατεύσει εξωτερικές αλλαγές.")
        }

        guard decoded.values.allSatisfy({ value in
            value.utf8.count == 64 && value.utf8.allSatisfy { byte in
                (byte >= 48 && byte <= 57) || (byte >= 97 && byte <= 102)
            }
        }) else {
            throw obsidianError(6004, "Μη έγκυρα SHA-256 hashes στο Obsidian metadata· το export σταμάτησε.")
        }

        lastKnownHashes = decoded
        hashesFortomenoi = true
    }

    private func apothikeusi_hashes_sto_disk(vaultURL: URL) throws {
        let storeURL = try Self.resolvedVaultPathWithoutSymlinks(
            relativePath: Self.hashStoreRelativePath,
            baseDirectory: vaultURL
        )
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        _ = try Self.resolvedVaultPathWithoutSymlinks(
            relativePath: Self.hashStoreRelativePath,
            baseDirectory: vaultURL
        )
        let data = try JSONEncoder().encode(lastKnownHashes)
        try data.write(to: storeURL, options: .atomic)
    }

    /// Resolves a vault-relative path while refusing a symlink in any existing path component.
    /// The regular containment check still rejects traversal and paths outside the selected vault.
    private static func resolvedVaultPathWithoutSymlinks(
        relativePath: String,
        baseDirectory: URL
    ) throws -> URL {
        let resolvedURL = try PathAsfaleia.asfalhs_resolved_url(
            relativePath: relativePath,
            baseDirectory: baseDirectory
        )
        let components = relativePath
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
        var componentURL = baseDirectory.resolvingSymlinksInPath().standardizedFileURL

        for component in components {
            componentURL.appendPathComponent(String(component))
            var attributes = stat()
            if lstat(componentURL.path, &attributes) == 0 {
                let entryType = attributes.st_mode & mode_t(S_IFMT)
                guard entryType != mode_t(S_IFLNK) else {
                    throw NSError(domain: "R0lling.Obsidian", code: 6012, userInfo: [
                        NSLocalizedDescriptionKey: "Το Obsidian export δεν επιτρέπει symbolic links σε managed paths του vault."
                    ])
                }
            } else if errno == ENOENT {
                // Once a component is absent, no descendant can exist to inspect.
                break
            } else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
                    NSLocalizedDescriptionKey: "Αδυναμία επαλήθευσης vault path χωρίς symbolic links."
                ])
            }
        }
        return resolvedURL
    }

    // MARK: - Scoped access

    private func me_prosbasi_vault<T: Sendable>(
        _ body: () async throws -> T
    ) async throws -> T {
        guard let vaultURL = vaultDirectoryURL else {
            throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
        }
        var didStart = false
        if vaultRequiresScopedAccess {
            didStart = vaultURL.startAccessingSecurityScopedResource()
            if !didStart {
                throw obsidianError(6002, "Αποτυχία security-scoped πρόσβασης στο Obsidian vault.")
            }
        }
        defer {
            if didStart {
                vaultURL.stopAccessingSecurityScopedResource()
            }
        }
        return try await body()
    }

    // MARK: - Markdown merge

    private func relative_note_path(gia dateKey: String) throws -> String {
        let parts = dateKey.split(separator: "-")
        guard parts.count == 3,
              let year = parts.first,
              let month = parts.dropFirst().first else {
            throw obsidianError(6003, "Μη έγκυρο dateKey: \(dateKey)")
        }
        return "\(year)/\(month)/\(dateKey).md"
    }

    private func mergeEntryIntoMarkdown(existingContent: String, entry: JournalEntry, dayTitle: String) -> String {
        let entryTagMarker = "<!-- r0lling:id:\(entry.id.uuidString) -->"

        var markdown = existingContent
        if markdown.isEmpty {
            markdown = """
            ---
            date: \(dayTitle)
            type: daily-journal
            app: R0lling
            tags: [journal, rolling]
            ---

            # \(dayTitle)

            """
        }

        let entryBlock = formatSingleEntryMarkdown(entry)

        if markdown.contains(entryTagMarker) {
            if let startRange = markdown.range(of: entryTagMarker) {
                let endMarker = "<!-- /r0lling:id:\(entry.id.uuidString) -->"
                if let endRange = markdown.range(of: endMarker) {
                    let fullRange = startRange.lowerBound..<endRange.upperBound
                    markdown.replaceSubrange(fullRange, with: "\(entryTagMarker)\n\(entryBlock)\n\(endMarker)")
                    return markdown
                }
            }
        }

        markdown += "\n\(entryTagMarker)\n\(entryBlock)\n<!-- /r0lling:id:\(entry.id.uuidString) -->\n"
        return markdown
    }

    private func formatSingleEntryMarkdown(_ entry: JournalEntry) -> String {
        var text = "### [\(entry.formattedTime)] "
        if let title = entry.title, !title.isEmpty {
            text += "\(title)\n\n"
        } else {
            text += "\(entry.source.displayName)\n\n"
        }

        text += "\(entry.content)\n"

        if !entry.tags.isEmpty {
            text += "\n" + entry.tags.map { "#\($0)" }.joined(separator: " ") + "\n"
        }

        for att in entry.attachments {
            let relativeVaultPath = "../../Attachments/\(att.relativePath)"
            switch att.mediaType {
            case .photo:
                text += "\n![Φωτογραφία](\(relativeVaultPath))\n"
            case .video, .clip:
                text += "\n![Κλιπ / Βίντεο](\(relativeVaultPath))\n"
            case .audio:
                text += "\n[Ηχητικό Σημείωμα](\(relativeVaultPath))\n"
            }
        }

        return text
    }

    private func obsidianError(_ code: Int, _ message: String) -> NSError {
        NSError(
            domain: "R0lling.Obsidian",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
