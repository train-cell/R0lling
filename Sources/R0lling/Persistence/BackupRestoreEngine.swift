import Foundation

/// Μηχανή δημιουργίας αντιγράφων ασφαλείας (Backup) και ασφαλούς επαναφοράς (Restore).
/// A15 DoD: no-dupe IDs · clean sandbox restore · media + Agent memory · PathAsfaleia.
public actor BackupRestoreEngine: BackupRestoreProtocol {
    private static let maximumManifestBytes = 16 * 1024 * 1024
    private static let maximumEntryCount = 50_000
    private static let maximumAttachmentsPerEntry = 256
    private static let maximumAttachmentCount = 100_000

    private let storage: JournalStorageProtocol
    private let mediaStorage: MediaStorageProtocol
    private let agentManager: AgentFolderManager?
    private let mediaReferenceMutationGate: MediaReferenceMutationGate

    public struct BackupManifest: Codable {
        public let schemaVersion: Int
        public let backupTimestamp: Date
        public let appVersion: String
        public let entriesCount: Int
        public let entries: [JournalEntry]
        public let agentMemory: AgentMemory?

        public init(entries: [JournalEntry], agentMemory: AgentMemory? = nil) {
            self.schemaVersion = 1
            self.backupTimestamp = Date()
            self.appVersion = "1.0.0"
            self.entriesCount = entries.count
            self.entries = entries
            self.agentMemory = agentMemory
        }
    }

    public init(
        storage: JournalStorageProtocol,
        mediaStorage: MediaStorageProtocol,
        agentManager: AgentFolderManager? = nil,
        mediaReferenceMutationGate: MediaReferenceMutationGate = MediaReferenceMutationGate()
    ) {
        self.storage = storage
        self.mediaStorage = mediaStorage
        self.agentManager = agentManager
        self.mediaReferenceMutationGate = mediaReferenceMutationGate
    }

    /// Δημιουργεί bundle με manifest.json + Media/ + προαιρετικό Agent memory.
    public func createBackupBundle() async throws -> URL {
        try await mediaReferenceMutationGate.withExclusiveAccess { [self] in
            try await self.createBackupBundleUnlocked()
        }
    }

    private func createBackupBundleUnlocked() async throws -> URL {
        let entries = try await storage.getAllEntries()
        try Self.validateManifestBounds(entries: entries)
        let agentMemory = try await agentManager?.loadAgentMemory()

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("R0lling_Backup_\(UUID().uuidString).r0backup", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        var completed = false
        defer {
            if !completed { try? FileManager.default.removeItem(at: tempDir) }
        }

        let mediaBundleDir = tempDir.appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaBundleDir, withIntermediateDirectories: true)
        var backupEntries = entries

        for entryIndex in backupEntries.indices {
            for attachmentIndex in backupEntries[entryIndex].attachments.indices {
                let attachment = backupEntries[entryIndex].attachments[attachmentIndex]
                try Self.validateAttachmentPath(attachment)
                // SEC-002: Reject unsafe paths; never return an incomplete successful backup.
                guard let sourceURL = try? mediaStorage.getMediaFileURL(relativePath: attachment.relativePath),
                      let destURL = try? PathAsfaleia.asfalhs_resolved_url(
                        relativePath: attachment.relativePath,
                        baseDirectory: mediaBundleDir
                      ) else {
                    throw NSError(domain: AppErrorTaxonomy.backupDomain, code: 6, userInfo: [
                        NSLocalizedDescriptionKey: "Μη ασφαλές attachment path στο backup."
                    ])
                }
                guard let sourceSize = try Self.regularFileSize(at: sourceURL), sourceSize > 0 else {
                    throw NSError(domain: AppErrorTaxonomy.backupDomain, code: 4, userInfo: [
                        NSLocalizedDescriptionKey: "Το backup απέτυχε: λείπει ή δεν είναι κανονικό αρχείο το συνημμένο \(attachment.relativePath)."
                    ])
                }

                try FileManager.default.createDirectory(
                    at: destURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let bundleTargetExists = FileManager.default.fileExists(atPath: destURL.path)
                if let bundledSize = try Self.regularFileSize(at: destURL) {
                    guard bundledSize == sourceSize,
                          try Self.filesHaveEqualBytes(sourceURL, destURL) else {
                        throw NSError(domain: AppErrorTaxonomy.backupDomain, code: 6, userInfo: [
                            NSLocalizedDescriptionKey: "Σύγκρουση αρχείου μέσα στο backup για το \(attachment.relativePath)."
                        ])
                    }
                } else {
                    guard !bundleTargetExists else {
                        throw NSError(domain: AppErrorTaxonomy.backupDomain, code: 6, userInfo: [
                            NSLocalizedDescriptionKey: "Ο προορισμός media μέσα στο backup δεν είναι κανονικό αρχείο."
                        ])
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: destURL)
                    guard try Self.regularFileSize(at: destURL) == sourceSize,
                          try Self.filesHaveEqualBytes(sourceURL, destURL) else {
                        throw NSError(domain: AppErrorTaxonomy.backupDomain, code: 6, userInfo: [
                            NSLocalizedDescriptionKey: "Το αντίγραφο media στο backup δεν επαληθεύτηκε."
                        ])
                    }
                }
                backupEntries[entryIndex].attachments[attachmentIndex].byteSize = sourceSize
            }
        }

        let manifest = BackupManifest(entries: backupEntries, agentMemory: agentMemory)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        guard manifestData.count <= Self.maximumManifestBytes else {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupInvalidManifest,
                message: "Το backup manifest υπερβαίνει το επιτρεπόμενο όριο των 16 MiB."
            )
        }
        try manifestData.write(to: tempDir.appendingPathComponent("manifest.json"), options: .atomic)

        completed = true
        return tempDir
    }

    /// Επαναφορά σε καθαρό ή υπάρχον sandbox χωρίς διπλότυπα IDs.
    public func restoreFromBackupBundle(bundleURL: URL) async throws -> (restoredEntries: Int, restoredMedia: Int) {
        try await mediaReferenceMutationGate.withExclusiveAccess { [self] in
            try await self.restoreFromBackupBundleUnlocked(bundleURL: bundleURL)
        }
    }

    private func restoreFromBackupBundleUnlocked(bundleURL: URL) async throws -> (restoredEntries: Int, restoredMedia: Int) {
        let manifestURL: URL
        do {
            manifestURL = try PathAsfaleia.asfalhs_resolved_url(
                relativePath: "manifest.json",
                baseDirectory: bundleURL
            )
        } catch {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupMissingManifest,
                message: "Μη έγκυρο backup: Λείπει το αρχείο manifest.json",
                underlying: error
            )
        }
        guard let manifestSize = try? Self.regularFileSize(at: manifestURL) else {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupMissingManifest,
                message: "Μη έγκυρο backup: Λείπει το αρχείο manifest.json"
            )
        }
        guard manifestSize <= Self.maximumManifestBytes else {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupInvalidManifest,
                message: "Το backup manifest είναι μεγαλύτερο από το επιτρεπόμενο όριο των 16 MiB."
            )
        }

        let manifestData: Data
        do {
            manifestData = try Self.readData(at: manifestURL, maximumBytes: Self.maximumManifestBytes)
        } catch {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupInvalidManifest,
                message: "Αδυναμία ανάγνωσης manifest.json",
                underlying: error
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest: BackupManifest
        do {
            manifest = try decoder.decode(BackupManifest.self, from: manifestData)
        } catch {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupInvalidManifest,
                message: "Μη έγκυρο περιεχόμενο manifest.json",
                underlying: error
            )
        }

        guard manifest.schemaVersion == 1,
              manifest.entriesCount == manifest.entries.count,
              Set(manifest.entries.map(\.id)).count == manifest.entries.count else {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupInvalidManifest,
                message: "Μη υποστηριζόμενο schema ή ασυνεπές manifest."
            )
        }
        try Self.validateManifestBounds(entries: manifest.entries)

        if manifest.agentMemory != nil, agentManager == nil {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupAgentRestoreFailed,
                message: "Η επαναφορά διακόπηκε: το backup περιέχει Agent memory αλλά δεν έχει οριστεί προορισμός."
            )
        }

        let existingEntries = try await storage.getAllEntries()
        let existingIDs = Set(existingEntries.map(\.id))
        var entriesToRestore: [JournalEntry] = []
        var stagedMedia: [(relativePath: String, stagedURL: URL, targetURL: URL)] = []
        var mappedMediaPaths: [String: String] = [:]
        var stagedPaths = Set<String>()
        var installedMediaURLs: [URL] = []
        var installedMediaPaths = Set<String>()
        var restoreCommitted = false
        var preserveInstalledMediaOnFailure = false

        defer {
            if !restoreCommitted && !preserveInstalledMediaOnFailure {
                for item in stagedMedia where FileManager.default.fileExists(atPath: item.stagedURL.path) {
                    try? FileManager.default.removeItem(at: item.stagedURL)
                }
                for url in installedMediaURLs {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }

        for entry in manifest.entries {
            // Αποφυγή διπλότυπων IDs — υπάρχον entry μένει άθικτο.
            // Existing entries and their media remain untouched.
            guard !existingIDs.contains(entry.id) else { continue }
            var restoredEntry = entry
            restoredEntry.attachments = []

            // Reject the entire entry on an unsafe attachment path. Importing the
            // journal row without its referenced media would create a partial restore.
            for originalAttachment in entry.attachments {
                var attachment = originalAttachment
                let backupMediaURL: URL
                do {
                    try Self.validateAttachmentPath(attachment)
                    backupMediaURL = try PathAsfaleia.asfalhs_resolved_url(
                        relativePath: "Media/\(attachment.relativePath)",
                        baseDirectory: bundleURL
                    )
                } catch {
                    throw AppErrorTaxonomy.makeError(
                        domain: AppErrorTaxonomy.backupDomain,
                        code: AppErrorTaxonomy.backupPathRejected,
                        message: "Η επαναφορά διακόπηκε: μη ασφαλής διαδρομή συνημμένου.",
                        underlying: error
                    )
                }

                guard let bundledSize = try Self.regularFileSize(at: backupMediaURL),
                      bundledSize > 0,
                      attachment.byteSize == bundledSize else {
                    throw NSError(domain: AppErrorTaxonomy.backupDomain, code: 5, userInfo: [
                        NSLocalizedDescriptionKey: "Η επαναφορά διακόπηκε: λείπει, δεν είναι κανονικό αρχείο ή έχει λάθος μέγεθος το συνημμένο \(attachment.relativePath)."
                    ])
                }

                if let mappedPath = mappedMediaPaths[attachment.relativePath] {
                    attachment.relativePath = mappedPath
                    restoredEntry.attachments.append(attachment)
                    continue
                }

                let requestedTargetURL = try mediaStorage.getMediaFileURL(relativePath: attachment.relativePath)
                var outputRelativePath = attachment.relativePath
                if FileManager.default.fileExists(atPath: requestedTargetURL.path) {
                    if let existingTargetSize = try Self.regularFileSize(at: requestedTargetURL) {
                        if existingTargetSize == bundledSize,
                           try Self.filesHaveEqualBytes(requestedTargetURL, backupMediaURL) {
                            mappedMediaPaths[originalAttachment.relativePath] = outputRelativePath
                            restoredEntry.attachments.append(attachment)
                            continue
                        }
                    }
                    outputRelativePath = try Self.uniqueRelativePath(
                        for: attachment,
                        avoiding: stagedPaths,
                        mediaStorage: mediaStorage
                    )
                }

                let targetMediaURL = try mediaStorage.getMediaFileURL(relativePath: outputRelativePath)
                guard !FileManager.default.fileExists(atPath: targetMediaURL.path) else {
                    throw NSError(domain: AppErrorTaxonomy.backupDomain, code: 7, userInfo: [
                        NSLocalizedDescriptionKey: "Σύγκρουση αρχείου κατά την επαναφορά του \(outputRelativePath). Δοκιμάστε ξανά."
                    ])
                }
                let mediaTypeDirectory = targetMediaURL.deletingLastPathComponent()
                let mediaRootDirectory = mediaTypeDirectory.deletingLastPathComponent()
                try FileManager.default.createDirectory(
                    at: mediaTypeDirectory,
                    withIntermediateDirectories: true
                )
                // Restored media must have the same iOS Data Protection as imported media.
                // Protect the containing hierarchy before writing, then protect the staged
                // file itself before it can be installed as a journal attachment.
                try R0llingFileProtection.apply(to: mediaRootDirectory)
                try R0llingFileProtection.apply(to: mediaTypeDirectory)
                let stagedURL = mediaTypeDirectory
                    .appendingPathComponent(".restore-\(UUID().uuidString)-\(targetMediaURL.lastPathComponent)")
                stagedMedia.append((
                    relativePath: outputRelativePath,
                    stagedURL: stagedURL,
                    targetURL: targetMediaURL
                ))
                try FileManager.default.copyItem(at: backupMediaURL, to: stagedURL)
                try R0llingFileProtection.apply(to: stagedURL)
                guard try Self.regularFileSize(at: stagedURL) == bundledSize,
                      try Self.filesHaveEqualBytes(stagedURL, backupMediaURL) else {
                    throw NSError(domain: AppErrorTaxonomy.backupDomain, code: 5, userInfo: [
                        NSLocalizedDescriptionKey: "Το συνημμένο δεν επαληθεύτηκε κατά την αντιγραφή."
                    ])
                }
                mappedMediaPaths[originalAttachment.relativePath] = outputRelativePath
                stagedPaths.insert(outputRelativePath)
                attachment.relativePath = outputRelativePath
                restoredEntry.attachments.append(attachment)
            }
            entriesToRestore.append(restoredEntry)
        }

        for item in stagedMedia {
            if FileManager.default.fileExists(atPath: item.targetURL.path) {
                throw NSError(domain: AppErrorTaxonomy.backupDomain, code: 7, userInfo: [
                    NSLocalizedDescriptionKey: "Σύγκρουση αρχείου κατά την επαναφορά του \(item.relativePath). Δοκιμάστε ξανά."
                ])
            }
            try FileManager.default.moveItem(at: item.stagedURL, to: item.targetURL)
            installedMediaURLs.append(item.targetURL)
            installedMediaPaths.insert(item.relativePath)
        }

        let insertedIDs = try await storage.insertEntriesIfAbsentAtomically(entriesToRestore)

        if let memory = manifest.agentMemory, let agentManager {
            do {
                try await agentManager.saveAgentMemory(memory)
            } catch {
                var rollbackErrors: [String] = []
                for id in insertedIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
                    do {
                        try await storage.deleteEntry(id: id)
                    } catch {
                        rollbackErrors.append("\(id.uuidString): \(error.localizedDescription)")
                    }
                }

                if !rollbackErrors.isEmpty {
                    // Retain installed media when a journal row could not be removed,
                    // so the surviving row cannot be left pointing at missing bytes.
                    preserveInstalledMediaOnFailure = true
                    throw AppErrorTaxonomy.makeError(
                        domain: AppErrorTaxonomy.backupDomain,
                        code: AppErrorTaxonomy.backupAgentRestoreFailed,
                        message: "Η Agent memory απέτυχε και δεν μπόρεσαν να αναιρεθούν όλες οι εγγραφές. Τα συνημμένα διατηρήθηκαν για τις εγγραφές που μπορεί να παραμένουν.",
                        underlying: NSError(domain: AppErrorTaxonomy.backupDomain, code: 1, userInfo: [
                            NSLocalizedDescriptionKey: rollbackErrors.joined(separator: "\n"),
                            NSUnderlyingErrorKey: error
                        ])
                    )
                }

                throw AppErrorTaxonomy.makeError(
                    domain: AppErrorTaxonomy.backupDomain,
                    code: AppErrorTaxonomy.backupAgentRestoreFailed,
                    message: "Η Agent memory απέτυχε. Οι νέες εγγραφές αναιρέθηκαν.",
                    underlying: error
                )
            }
        }
        restoreCommitted = true

        // A concurrent writer can add an entry after the initial existing-ID snapshot.
        // The atomic journal insert then skips that ID, so remove newly installed media
        // that no committed journal entry references. If the verification read fails,
        // keep the media rather than risk deleting a file that a concurrent entry uses.
        if !installedMediaPaths.isEmpty {
            do {
                let persistedEntries = try await storage.getAllEntries()
                let activeMediaPaths = Set(persistedEntries.flatMap(\.attachments).map(\.relativePath))
                for item in stagedMedia {
                    guard installedMediaPaths.contains(item.relativePath),
                          !activeMediaPaths.contains(item.relativePath) else { continue }
                    try? FileManager.default.removeItem(at: item.targetURL)
                    installedMediaPaths.remove(item.relativePath)
                }
            } catch {
                // Keep media on verification-read failure rather than risk deleting a live attachment.
            }
        }

        let restoredMediaCount = installedMediaPaths.count

        return (insertedIDs.count, restoredMediaCount)
    }

    private static func validateManifestBounds(entries: [JournalEntry]) throws {
        guard entries.count <= maximumEntryCount else {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupInvalidManifest,
                message: "Το backup έχει υπερβολικά πολλές εγγραφές."
            )
        }
        var attachmentCount = 0
        for entry in entries {
            guard entry.attachments.count <= maximumAttachmentsPerEntry,
                  attachmentCount <= maximumAttachmentCount - entry.attachments.count else {
                throw AppErrorTaxonomy.makeError(
                    domain: AppErrorTaxonomy.backupDomain,
                    code: AppErrorTaxonomy.backupInvalidManifest,
                    message: "Το backup έχει υπερβολικά πολλά συνημμένα."
                )
            }
            attachmentCount += entry.attachments.count
            for attachment in entry.attachments {
                try validateAttachmentPath(attachment)
                guard attachment.byteSize >= 0 else {
                    throw AppErrorTaxonomy.makeError(
                        domain: AppErrorTaxonomy.backupDomain,
                        code: AppErrorTaxonomy.backupInvalidManifest,
                        message: "Το backup περιέχει αρνητικό μέγεθος συνημμένου."
                    )
                }
            }
        }
    }

    private static func validateAttachmentPath(_ attachment: MediaAttachment) throws {
        let parts = attachment.relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              parts[0] == Substring(attachment.mediaType.folderName),
              let filename = parts.last,
              !filename.isEmpty,
              filename.utf8.count <= 255,
              filename.first != ".",
              filename.utf8.allSatisfy({
                  ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90)
                      || ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 46 || $0 == 95
              }) else {
            throw AppErrorTaxonomy.makeError(
                domain: AppErrorTaxonomy.backupDomain,
                code: AppErrorTaxonomy.backupPathRejected,
                message: "Το attachment path πρέπει να δείχνει σε ένα αρχείο μέσα στον φάκελο \(attachment.mediaType.folderName)."
            )
        }
    }

    private static func regularFileSize(at url: URL) throws -> Int64? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let fileSize = values.fileSize else { return nil }
        return Int64(fileSize)
    }

    private static func readData(at url: URL, maximumBytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= maximumBytes {
            let remainingIncludingOverflowByte = maximumBytes + 1 - data.count
            let chunkSize = min(64 * 1024, remainingIncludingOverflowByte)
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            guard !chunk.isEmpty else { return data }
            data.append(chunk)
            guard data.count <= maximumBytes else {
                throw AppErrorTaxonomy.makeError(
                    domain: AppErrorTaxonomy.backupDomain,
                    code: AppErrorTaxonomy.backupInvalidManifest,
                    message: "Το backup manifest είναι μεγαλύτερο από το επιτρεπόμενο όριο των 16 MiB."
                )
            }
        }
        return data
    }

    private static func filesHaveEqualBytes(_ lhs: URL, _ rhs: URL) throws -> Bool {
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

    private static func uniqueRelativePath(
        for attachment: MediaAttachment,
        avoiding reservedPaths: Set<String>,
        mediaStorage: MediaStorageProtocol
    ) throws -> String {
        let pathExtension = URL(fileURLWithPath: attachment.relativePath).pathExtension
        while true {
            let filename = pathExtension.isEmpty
                ? UUID().uuidString
                : "\(UUID().uuidString).\(pathExtension)"
            let candidate = "\(attachment.mediaType.folderName)/\(filename)"
            let url = try mediaStorage.getMediaFileURL(relativePath: candidate)
            if !reservedPaths.contains(candidate), !FileManager.default.fileExists(atPath: url.path) {
                return candidate
            }
        }
    }
}
