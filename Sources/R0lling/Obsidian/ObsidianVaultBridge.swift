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
    /// Canonical filesystem root captured when a vault URL is selected; never re-resolve it during I/O.
    private var vaultFilesystemRootURL: URL?
    private var vaultRequiresScopedAccess: Bool = false
    private var lastKnownHashes: [String: String] = [:]
    private var hashesFortomenoi: Bool = false
    private var vaultConfigurationVersion: UInt64 = 0
    var attachmentExportBarrierForTesting: (@Sendable () async -> Void)?

    private func activeVaultFilesystemRoot() throws -> URL {
        guard let vaultFilesystemRootURL else {
            throw obsidianError(6001, "Δεν έχει οριστεί filesystem root για το Obsidian vault.")
        }
        return vaultFilesystemRootURL
    }

    private func requireVaultConfigurationVersion(_ expectedVersion: UInt64) throws {
        guard vaultConfigurationVersion == expectedVersion else {
            throw obsidianError(6014, "Το επιλεγμένο Obsidian vault άλλαξε κατά το export· επανάλαβε την εξαγωγή.")
        }
    }

    public init(vaultURL: URL? = nil) {
        if let url = vaultURL {
            self.vaultDirectoryURL = url
            self.vaultFilesystemRootURL = url.resolvingSymlinksInPath().standardizedFileURL
            self.vaultRequiresScopedAccess = false
        } else if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = docs.appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
            self.vaultDirectoryURL = url
            self.vaultFilesystemRootURL = url.resolvingSymlinksInPath().standardizedFileURL
            self.vaultRequiresScopedAccess = false
        } else {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
            self.vaultDirectoryURL = url
            self.vaultFilesystemRootURL = url.resolvingSymlinksInPath().standardizedFileURL
            self.vaultRequiresScopedAccess = false
        }
    }

    /// Ορισμός vault URL (default Documents ή security-scoped από Files picker).
    public func setVaultURL(_ url: URL, requiresScopedAccess: Bool = false) async {
        vaultConfigurationVersion &+= 1
        self.vaultDirectoryURL = url
        self.vaultFilesystemRootURL = url.resolvingSymlinksInPath().standardizedFileURL
        self.vaultRequiresScopedAccess = requiresScopedAccess
        self.hashesFortomenoi = false
        self.lastKnownHashes = [:]
    }

    func setAttachmentExportBarrierForTesting(_ barrier: (@Sendable () async -> Void)?) {
        attachmentExportBarrierForTesting = barrier
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
            guard vaultDirectoryURL != nil else {
                throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
            }
            let vaultRootURL = try activeVaultFilesystemRoot()
            let destURL = try Self.resolvedVaultPathWithoutSymlinks(
                relativePath: relativePath,
                baseDirectory: vaultRootURL
            )
            let data = Data(contents.utf8)
            let parentPath = relativePath.replacingOccurrences(of: "\\", with: "/")
                .split(separator: "/", omittingEmptySubsequences: true).dropLast().joined(separator: "/")
            if !parentPath.isEmpty {
                try VaultDirectoryFileAccess.ensureDirectory(rootURL: vaultRootURL, relativePath: parentPath)
            }
            if let existing = try VaultDirectoryFileAccess.readData(
                rootURL: vaultRootURL,
                relativePath: relativePath,
                maximumBytes: max(Self.maximumDailyNoteBytes, data.count)
            ) {
                if existing == data { return destURL }
                return try createConflictSidecar(for: destURL, data: data)
            }

            if try VaultDirectoryFileAccess.createExclusive(
                rootURL: vaultRootURL,
                relativePath: relativePath,
                contents: data
            ) {
                return destURL
            }

            // The path appeared after the initial existence check. Re-evaluate it without overwriting.
            if try VaultDirectoryFileAccess.fileMatches(
                rootURL: vaultRootURL,
                relativePath: relativePath,
                contents: data
            ) { return destURL }
            return try createConflictSidecar(for: destURL, data: data)
        }
    }

    /// Creates a new regular file atomically, returning false if the path already exists.
    /// O_EXCL prevents a concurrent edit or symlink from being replaced between check and write.
    static func writeFileExclusively(at url: URL, contents data: Data) throws -> Bool {
        let parent = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        return try VaultDirectoryFileAccess.createExclusive(
            rootURL: parent,
            relativePath: url.lastPathComponent,
            contents: data
        )
    }

    private func createConflictSidecar(for destinationURL: URL, data: Data) throws -> URL {
        let baseName = destinationURL.deletingPathExtension().lastPathComponent
        let fileExtension = destinationURL.pathExtension
        let conflictPrefix = "\(baseName).r0lling-conflict-"
        let conflictSuffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
        let vaultRoot = try activeVaultFilesystemRoot()
        let relativeParent = Self.relativePath(from: vaultRoot, to: destinationURL.deletingLastPathComponent())
        if let relativeParent {
            let existingFiles = try VaultDirectoryFileAccess.directoryFileNames(
                rootURL: vaultRoot,
                relativeDirectory: relativeParent
            )
            for conflictName in existingFiles where conflictName.hasPrefix(conflictPrefix)
                && conflictName.hasSuffix(conflictSuffix) {
                let relative = relativeParent.isEmpty ? conflictName : "\(relativeParent)/\(conflictName)"
                if try VaultDirectoryFileAccess.fileMatches(rootURL: vaultRoot, relativePath: relative, contents: data) {
                    return destinationURL.deletingLastPathComponent().appendingPathComponent(conflictName)
                }
            }
        }
        for _ in 0..<3 {
            let conflictName = "\(conflictPrefix)\(UUID().uuidString)\(conflictSuffix)"
            let conflictURL = destinationURL.deletingLastPathComponent().appendingPathComponent(conflictName)
            if let relativePath = Self.relativePath(from: vaultRoot, to: conflictURL),
               try VaultDirectoryFileAccess.createExclusive(
                   rootURL: vaultRoot,
                   relativePath: relativePath,
                   contents: data
               ) { return conflictURL }
        }
        throw obsidianError(6007, "Δεν ήταν δυνατή η δημιουργία ασφαλούς conflict αρχείου για το Obsidian export.")
    }

    /// Ανάγνωση ημερήσιας σημείωσης από vault (import/read path — χωρίς overwrite journal).
    public func diabase_imerisia_simeiosi(dateKey: String) async throws -> String? {
        try await me_prosbasi_vault {
            guard vaultDirectoryURL != nil else {
                throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
            }
            let relative = try relative_note_path(gia: dateKey)
            let vaultRootURL = try activeVaultFilesystemRoot()
            _ = try Self.resolvedVaultPathWithoutSymlinks(
                relativePath: relative,
                baseDirectory: vaultRootURL
            )
            guard let data = try VaultDirectoryFileAccess.readData(
                rootURL: vaultRootURL,
                relativePath: relative,
                maximumBytes: Self.maximumDailyNoteBytes
            ) else { return nil }
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
        let expectedVaultConfigurationVersion = vaultConfigurationVersion
        return try await me_prosbasi_vault {
            try await exportEntryLocked(
                entry,
                mediaStorage: mediaStorage,
                expectedVaultConfigurationVersion: expectedVaultConfigurationVersion
            )
        }
    }

    /// Exports an edited entry and, when its day changes, removes its previous managed block
    /// only if the old daily note still matches the last content written by R0lling.
    public func moveEntry(
        from previousEntry: JournalEntry,
        to updatedEntry: JournalEntry,
        mediaStorage: MediaStorageProtocol
    ) async throws -> ObsidianSingleExportResult {
        let expectedVaultConfigurationVersion = vaultConfigurationVersion
        return try await me_prosbasi_vault {
            try requireVaultConfigurationVersion(expectedVaultConfigurationVersion)
            guard previousEntry.dateKey != updatedEntry.dateKey else {
                return try await exportEntryLocked(
                    updatedEntry,
                    mediaStorage: mediaStorage,
                    expectedVaultConfigurationVersion: expectedVaultConfigurationVersion
                )
            }

            // Write the destination first, so a destination conflict cannot leave the
            // old managed block removed without a replacement.
            let destinationResult = try await exportEntryLocked(
                updatedEntry,
                mediaStorage: mediaStorage,
                expectedVaultConfigurationVersion: expectedVaultConfigurationVersion
            )
            try requireVaultConfigurationVersion(expectedVaultConfigurationVersion)
            guard !destinationResult.hadConflict else { return destinationResult }

            if let conflictPath = try removeMovedEntryFromPreviousNote(
                previousEntry,
                updatedEntry: updatedEntry
            ) {
                return ObsidianSingleExportResult(
                    noteURL: destinationResult.noteURL,
                    hadConflict: true,
                    conflictSidecarRelativePath: conflictPath
                )
            }
            return destinationResult
        }
    }

    /// Εξαγωγή συνόλου εγγραφών (Batch Export — A08).
    public func exportBatch(entries: [JournalEntry], mediaStorage: MediaStorageProtocol) async throws -> ObsidianExportResult {
        let expectedVaultConfigurationVersion = vaultConfigurationVersion
        return try await me_prosbasi_vault {
            try requireVaultConfigurationVersion(expectedVaultConfigurationVersion)
            var exportedPaths = Set<String>()
            var modifiedList: [String] = []
            var conflictsList: [String] = []

            let grouped = Dictionary(grouping: entries, by: { $0.dateKey })

            for (_, dayEntries) in grouped {
                for entry in dayEntries {
                    let outcome = try await exportEntryLocked(
                        entry,
                        mediaStorage: mediaStorage,
                        expectedVaultConfigurationVersion: expectedVaultConfigurationVersion
                    )
                    try requireVaultConfigurationVersion(expectedVaultConfigurationVersion)
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
        mediaStorage: MediaStorageProtocol,
        expectedVaultConfigurationVersion: UInt64
    ) async throws -> ObsidianSingleExportResult {
        try requireVaultConfigurationVersion(expectedVaultConfigurationVersion)
        guard let vaultURL = vaultDirectoryURL else {
            throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
        }
        let vaultRootURL = try activeVaultFilesystemRoot()
        if !hashesFortomenoi {
            try fortosi_hashes_apo_disk_unlocked()
        }

        let relativeNotePath = try relative_note_path(gia: entry.dateKey)
        let noteURL = try Self.resolvedVaultPathWithoutSymlinks(
            relativePath: relativeNotePath,
            baseDirectory: vaultRootURL
        )
        let yearMonthPath = relativeNotePath.split(separator: "/").dropLast().joined(separator: "/")
        try VaultDirectoryFileAccess.ensureDirectory(rootURL: vaultRootURL, relativePath: yearMonthPath)

        let dayString = entry.dateKey

        var existingContent = ""
        var existingContentHash: String?

        // A09: εξωτερική τροποποίηση αν υπάρχει καταγεγραμμένο hash.
        if let existingData = try VaultDirectoryFileAccess.readData(
            rootURL: vaultRootURL,
            relativePath: relativeNotePath,
            maximumBytes: Self.maximumDailyNoteBytes
        ) {
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
                try apothikeusi_hashes_sto_disk(vaultRootURL: vaultRootURL)
            }
            existingContent = decodedContent
        }

        if let barrier = attachmentExportBarrierForTesting {
            await barrier()
        }
        try requireVaultConfigurationVersion(expectedVaultConfigurationVersion)
        try await antigrafi_attachments(
            entry: entry,
            mediaStorage: mediaStorage,
            vaultRootURL: vaultRootURL
        )
        try requireVaultConfigurationVersion(expectedVaultConfigurationVersion)

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
        try apothikeusi_hashes_sto_disk(vaultRootURL: vaultRootURL)
        return ObsidianSingleExportResult(
            noteURL: noteURL,
            hadConflict: false,
            conflictSidecarRelativePath: nil
        )
    }

    /// Returns a conflict sidecar path when the source note is not safe to modify.
    private func removeMovedEntryFromPreviousNote(
        _ previousEntry: JournalEntry,
        updatedEntry: JournalEntry
    ) throws -> String? {
        guard let vaultURL = vaultDirectoryURL else {
            throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
        }
        if !hashesFortomenoi {
            try fortosi_hashes_apo_disk_unlocked()
        }

        let relativeNotePath = try relative_note_path(gia: previousEntry.dateKey)
        let vaultRootURL = try activeVaultFilesystemRoot()
        let noteURL = try Self.resolvedVaultPathWithoutSymlinks(
            relativePath: relativeNotePath,
            baseDirectory: vaultRootURL
        )
        guard let originalData = try VaultDirectoryFileAccess.readData(
            rootURL: vaultRootURL,
            relativePath: relativeNotePath,
            maximumBytes: Self.maximumDailyNoteBytes
        ) else { return nil }
        guard let originalContent = String(data: originalData, encoding: .utf8) else {
            throw obsidianError(6005, "Η παλιά ημερήσια σημείωση δεν είναι έγκυρο UTF-8· το Obsidian move σταμάτησε.")
        }

        let openingMarker = "<!-- r0lling:id:\(previousEntry.id.uuidString) -->"
        // No old managed block means there is nothing to relocate from this note.
        guard originalContent.contains(openingMarker) else { return nil }

        func reportConflict(_ content: String) throws -> String {
            let conflict = try grapse_conflict_sidecar(
                dayString: previousEntry.dateKey,
                relativeNotePath: relativeNotePath,
                noteURL: noteURL,
                existingContent: content,
                entry: previousEntry,
                vaultURL: vaultURL,
                conflictContext: "Η καταγραφή μεταφέρθηκε στο \(updatedEntry.dateKey), αλλά η παλιά σημείωση άλλαξε μετά το export. Το αρχικό αρχείο διατηρήθηκε και η μεταφορά του παλιού block δεν εφαρμόστηκε."
            )
            return conflict.conflictSidecarRelativePath ?? ""
        }

        guard let expectedHash = lastKnownHashes[relativeNotePath],
              originalData.sha256Hash == expectedHash else {
            return try reportConflict(originalContent)
        }

        let closingMarker = "<!-- /r0lling:id:\(previousEntry.id.uuidString) -->"
        guard originalContent.components(separatedBy: openingMarker).count == 2,
              originalContent.components(separatedBy: closingMarker).count == 2,
              let openingRange = originalContent.range(of: openingMarker),
              let closingRange = originalContent.range(of: closingMarker),
              openingRange.lowerBound < closingRange.lowerBound else {
            return try reportConflict(originalContent)
        }

        var removalStart = openingRange.lowerBound
        if removalStart > originalContent.startIndex {
            let previousCharacter = originalContent.index(before: removalStart)
            if originalContent[previousCharacter] == "\n" {
                removalStart = previousCharacter
            }
        }
        var removalEnd = closingRange.upperBound
        if removalEnd < originalContent.endIndex, originalContent[removalEnd] == "\n" {
            removalEnd = originalContent.index(after: removalEnd)
        }
        var updatedContent = originalContent
        updatedContent.removeSubrange(removalStart..<removalEnd)

        if let latestContent = try writeNoteIfUnchanged(
            at: noteURL,
            relativePath: relativeNotePath,
            vaultURL: vaultURL,
            expectedHash: expectedHash,
            originalContent: originalContent,
            updatedContent: updatedContent
        ) {
            return try reportConflict(latestContent)
        }

        lastKnownHashes[relativeNotePath] = updatedContent.sha256Hash
        try apothikeusi_hashes_sto_disk(vaultRootURL: vaultRootURL)
        return nil
    }

    private func grapse_conflict_sidecar(
        dayString: String,
        relativeNotePath: String,
        noteURL: URL,
        existingContent: String,
        entry: JournalEntry,
        vaultURL: URL,
        conflictContext: String? = nil
    ) throws -> ObsidianSingleExportResult {
        let vaultRootURL = try activeVaultFilesystemRoot()
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
        let defaultConflictContext = "Εξωτερική τροποποίηση ανιχνεύθηκε. Το πρωτότυπο `\(dayString).md` **δεν** υπεργράφηκε."
        let sidecarBody = """
        # R0lling Conflict — \(dayString)

        \(conflictContext ?? defaultConflictContext)

        ---
        ## Προτεινόμενη συγχώνευση R0lling (μη εφαρμοσμένη)

        \(attemptedMerge)
        """
        if !sidecarRelative.isEmpty {
            try VaultDirectoryFileAccess.ensureDirectory(rootURL: vaultRootURL, relativePath: sidecarRelative)
        }
        let data = Data(sidecarBody.utf8)
        var finalSidecarRelativePath = sidecarRelativePath
        _ = try Self.resolvedVaultPathWithoutSymlinks(
            relativePath: sidecarRelativePath,
            baseDirectory: vaultRootURL
        )
        if !(try VaultDirectoryFileAccess.createExclusive(
            rootURL: vaultRootURL,
            relativePath: sidecarRelativePath,
            contents: data
        )) {
            if try VaultDirectoryFileAccess.fileMatches(
                rootURL: vaultRootURL,
                relativePath: sidecarRelativePath,
                contents: data
            ) {
                // Reuse identical conflict output; never replace an existing sidecar.
            } else {
                var created = false
                let conflictPrefix = "\(dayString).r0lling-conflict-"
                let existingSidecars = try VaultDirectoryFileAccess.directoryFileNames(
                    rootURL: vaultRootURL,
                    relativeDirectory: sidecarRelative
                )
                for existingName in existingSidecars where existingName.hasPrefix(conflictPrefix)
                    && existingName.hasSuffix(".md") {
                    let existingRelative = sidecarRelative.isEmpty
                        ? existingName
                        : "\(sidecarRelative)/\(existingName)"
                    if try VaultDirectoryFileAccess.fileMatches(
                        rootURL: vaultRootURL,
                        relativePath: existingRelative,
                        contents: data
                    ) {
                        finalSidecarRelativePath = sidecarRelative.isEmpty
                            ? existingName
                            : "\(sidecarRelative)/\(existingName)"
                        _ = try Self.resolvedVaultPathWithoutSymlinks(
                            relativePath: finalSidecarRelativePath,
                            baseDirectory: vaultRootURL
                        )
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
                    _ = try Self.resolvedVaultPathWithoutSymlinks(
                        relativePath: uniqueRelative,
                        baseDirectory: vaultRootURL
                    )
                    if try VaultDirectoryFileAccess.createExclusive(
                        rootURL: vaultRootURL,
                        relativePath: uniqueRelative,
                        contents: data
                    ) {
                        finalSidecarRelativePath = uniqueRelative
                        created = true
                        break
                    }
                    if try VaultDirectoryFileAccess.fileMatches(
                        rootURL: vaultRootURL,
                        relativePath: uniqueRelative,
                        contents: data
                    ) {
                        finalSidecarRelativePath = uniqueRelative
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
                let coordinatedParent = coordinatedURL.deletingLastPathComponent().standardizedFileURL
                let coordinatedLeaf = coordinatedURL.lastPathComponent
                let latestData = try VaultDirectoryFileAccess.readData(
                    rootURL: coordinatedParent,
                    relativePath: coordinatedLeaf,
                    maximumBytes: Self.maximumDailyNoteBytes
                )
                if let latestData {
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

                let wrote = try VaultDirectoryFileAccess.replaceRegularFileAtomically(
                    rootURL: coordinatedParent,
                    relativePath: coordinatedLeaf,
                    contents: Data(updatedContent.utf8),
                    expectedExistingHash: expectedHash
                )
                if !wrote {
                    let latest = try VaultDirectoryFileAccess.readData(
                        rootURL: coordinatedParent,
                        relativePath: coordinatedLeaf,
                        maximumBytes: Self.maximumDailyNoteBytes
                    )
                    conflictDetected = true
                    conflictContent = latest.flatMap { String(data: $0, encoding: .utf8) } ?? originalContent
                }
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
        vaultRootURL: URL
    ) async throws {
        try VaultDirectoryFileAccess.ensureDirectory(rootURL: vaultRootURL, relativePath: Self.attachmentsFolderName)

        for attachment in entry.attachments {
            let sourceURL: URL
            let destRelativePath: String
            do {
                try validateAttachmentStoragePath(attachment)
                sourceURL = try mediaStorage.getMediaFileURL(relativePath: attachment.relativePath)
                destRelativePath = "\(Self.attachmentsFolderName)/\(attachment.relativePath)"
                let destParent = destRelativePath.split(separator: "/").dropLast().joined(separator: "/")
                try VaultDirectoryFileAccess.ensureDirectory(rootURL: vaultRootURL, relativePath: destParent)
            } catch {
                throw obsidianError(6011, "Μη ασφαλές attachment path στο Obsidian export: \(attachment.relativePath)")
            }
            let sourceSize: Int
            do {
                sourceSize = try VaultDirectoryFileAccess.regularFileSize(at: sourceURL)
            } catch {
                throw obsidianError(6010, "Δεν ήταν δυνατή η επιβεβαίωση του μεγέθους του συνημμένου: \(attachment.relativePath)")
            }

            let destinationSize: Int?
            do {
                destinationSize = try VaultDirectoryFileAccess.regularFileSize(
                    rootURL: vaultRootURL,
                    relativePath: destRelativePath
                )
            } catch {
                throw obsidianError(6012, "Ο προορισμός attachment δεν είναι ασφαλές κανονικό αρχείο: \(attachment.relativePath)")
            }
            if let destinationSize {
                guard destinationSize == sourceSize,
                      try VaultDirectoryFileAccess.filesHaveEqualBytes(
                          sourceURL: sourceURL,
                          rootURL: vaultRootURL,
                          relativePath: destRelativePath
                      ) else {
                    throw obsidianError(6012, "Υπάρχει διαφορετικό αρχείο στο Obsidian attachment path: \(attachment.relativePath)")
                }
            } else {
                let copied = try VaultDirectoryFileAccess.copyRegularFile(
                    from: sourceURL,
                    toRootURL: vaultRootURL,
                    relativePath: destRelativePath
                )
                guard copied,
                      try VaultDirectoryFileAccess.regularFileSize(
                          rootURL: vaultRootURL,
                          relativePath: destRelativePath
                      ) == sourceSize,
                      try VaultDirectoryFileAccess.filesHaveEqualBytes(
                          sourceURL: sourceURL,
                          rootURL: vaultRootURL,
                          relativePath: destRelativePath
                      ) else {
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

    // MARK: - Hash persistence (A09 across restarts)

    /// Φόρτωση hashes — καλείται μόνο μέσα σε `me_prosbasi_vault` ή default vault.
    private func fortosi_hashes_apo_disk_unlocked() throws {
        guard vaultDirectoryURL != nil else {
            throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
        }

        let vaultRootURL = try activeVaultFilesystemRoot()
        try VaultDirectoryFileAccess.ensureDirectory(rootURL: vaultRootURL, relativePath: "R0llingMeta")
        let data: Data
        do {
            guard let storedData = try VaultDirectoryFileAccess.readData(
                rootURL: vaultRootURL,
                relativePath: Self.hashStoreRelativePath,
                maximumBytes: Self.maximumHashMetadataBytes
            ) else {
                lastKnownHashes = [:]
                hashesFortomenoi = true
                return
            }
            data = storedData
        } catch let error as NSError where error.domain == "R0lling.Obsidian" && error.code == 6012 {
            // Keep path-safety failures visible instead of disguising a symlink or
            // non-regular metadata file as corrupt JSON.
            throw error
        } catch {
            throw obsidianError(6004, "Αδυναμία ασφαλούς ανάγνωσης Obsidian export metadata· το export σταμάτησε.")
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

    private func apothikeusi_hashes_sto_disk(vaultRootURL: URL) throws {
        try VaultDirectoryFileAccess.ensureDirectory(rootURL: vaultRootURL, relativePath: "R0llingMeta")
        let data = try JSONEncoder().encode(lastKnownHashes)
        let oldData = try VaultDirectoryFileAccess.readData(
            rootURL: vaultRootURL,
            relativePath: Self.hashStoreRelativePath,
            maximumBytes: Self.maximumHashMetadataBytes
        )
        let wrote = try VaultDirectoryFileAccess.replaceRegularFileAtomically(
            rootURL: vaultRootURL,
            relativePath: Self.hashStoreRelativePath,
            contents: data,
            expectedExistingHash: oldData?.sha256Hash
        )
        guard wrote else {
            throw obsidianError(6004, "Το Obsidian export metadata άλλαξε κατά την εγγραφή· το export σταμάτησε.")
        }
    }

    /// Resolves a vault-relative path while refusing a symlink in any existing path component.
    /// The regular containment check still rejects traversal and paths outside the selected vault.
    private static func resolvedVaultPathWithoutSymlinks(
        relativePath: String,
        baseDirectory: URL
    ) throws -> URL {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        // Preserve PathAsfaleia's public traversal error for lexically invalid paths.
        if normalized.isEmpty || normalized.hasPrefix("/") || normalized.hasPrefix("\\")
            || normalized.contains("\0") || components.contains("..") || components.contains(".") {
            return try PathAsfaleia.asfalhs_resolved_url(relativePath: relativePath, baseDirectory: baseDirectory)
        }
        do {
            // This validates containment. Descriptor-relative I/O below is the authority
            // for symlink safety; this path result is never used for filesystem writes.
            _ = try PathAsfaleia.asfalhs_resolved_url(relativePath: relativePath, baseDirectory: baseDirectory)
        } catch {
            throw NSError(domain: "R0lling.Obsidian", code: 6012, userInfo: [
                NSLocalizedDescriptionKey: "Το Obsidian path περιέχει symbolic link ή βγαίνει εκτός vault."
            ])
        }
        let candidate = baseDirectory.standardizedFileURL
            .appendingPathComponent(normalized)
            .standardizedFileURL
        let basePath = baseDirectory.standardizedFileURL.path
        let candidatePath = candidate.path
        let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
        guard candidatePath.hasPrefix(prefix) else {
            throw NSError(domain: "R0lling.Obsidian", code: 6012, userInfo: [
                NSLocalizedDescriptionKey: "Το Obsidian path βγαίνει εκτός vault."
            ])
        }
        return candidate
    }

    private static func relativePath(from rootURL: URL, to targetURL: URL) -> String? {
        let rootPath = rootURL.standardizedFileURL.path
        let targetPath = targetURL.standardizedFileURL.path
        if targetPath == rootPath { return "" }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard targetPath.hasPrefix(prefix) else { return nil }
        return String(targetPath.dropFirst(prefix.count))
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
