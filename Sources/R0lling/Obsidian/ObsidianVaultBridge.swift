import Foundation

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
        do {
            try await me_prosbasi_vault {
                self.fortosi_hashes_apo_disk_unlocked()
            }
        } catch {
            lastKnownHashes = [:]
            hashesFortomenoi = true
        }
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

    /// Ασφαλής εγγραφή αρχείου στο vault μέσω PathAsfaleia (canvas / KG / meta).
    public func grapse_arxeio_sto_vault(relativePath: String, contents: String) async throws -> URL {
        try await me_prosbasi_vault {
            guard let vaultURL = vaultDirectoryURL else {
                throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
            }
            let destURL = try PathAsfaleia.asfalhs_resolved_url(
                relativePath: relativePath,
                baseDirectory: vaultURL
            )
            try FileManager.default.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try contents.write(to: destURL, atomically: true, encoding: .utf8)
            return destURL
        }
    }

    /// Ανάγνωση ημερήσιας σημείωσης από vault (import/read path — χωρίς overwrite journal).
    public func diabase_imerisia_simeiosi(dateKey: String) async throws -> String? {
        try await me_prosbasi_vault {
            guard let vaultURL = vaultDirectoryURL else {
                throw obsidianError(6001, "Δεν έχει οριστεί φάκελος Obsidian Vault.")
            }
            let relative = try relative_note_path(gia: dateKey)
            let noteURL = try PathAsfaleia.asfalhs_resolved_url(
                relativePath: relative,
                baseDirectory: vaultURL
            )
            guard FileManager.default.fileExists(atPath: noteURL.path) else { return nil }
            return try String(contentsOf: noteURL, encoding: .utf8)
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
            var exportedCount = 0
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
                        exportedCount += 1
                        if !modifiedList.contains(outcome.noteURL.lastPathComponent) {
                            modifiedList.append(outcome.noteURL.lastPathComponent)
                        }
                    }
                }
            }

            return ObsidianExportResult(
                exportedFilesCount: exportedCount,
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
            fortosi_hashes_apo_disk_unlocked()
        }

        let relativeNotePath = try relative_note_path(gia: entry.dateKey)
        let noteURL = try PathAsfaleia.asfalhs_resolved_url(
            relativePath: relativeNotePath,
            baseDirectory: vaultURL
        )
        let yearMonthDir = noteURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: yearMonthDir, withIntermediateDirectories: true)

        let dayString = entry.dateKey

        // A09: εξωτερική τροποποίηση αν υπάρχει καταγεγραμμένο hash.
        if FileManager.default.fileExists(atPath: noteURL.path) {
            let existingData = try Data(contentsOf: noteURL)
            let existingHash = existingData.sha256Hash
            if let recordedHash = lastKnownHashes[relativeNotePath] {
                if recordedHash != existingHash {
                    return try grapse_conflict_sidecar(
                        dayString: dayString,
                        relativeNotePath: relativeNotePath,
                        noteURL: noteURL,
                        existingContent: String(data: existingData, encoding: .utf8) ?? "",
                        entry: entry,
                        vaultURL: vaultURL
                    )
                }
            } else {
                // Πρώτη επαφή μετά restart χωρίς hash: seed baseline (χωρίς conflict ψευδώς).
                lastKnownHashes[relativeNotePath] = existingHash
                try apothikeusi_hashes_sto_disk(vaultURL: vaultURL)
            }
        }

        try await antigrafi_attachments(entry: entry, mediaStorage: mediaStorage, vaultURL: vaultURL)

        var existingContent = ""
        if FileManager.default.fileExists(atPath: noteURL.path) {
            existingContent = (try? String(contentsOf: noteURL, encoding: .utf8)) ?? ""
        }

        let updatedContent = mergeEntryIntoMarkdown(
            existingContent: existingContent,
            entry: entry,
            dayTitle: dayString
        )
        try updatedContent.write(to: noteURL, atomically: true, encoding: .utf8)

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
        let sidecarURL = try PathAsfaleia.asfalhs_resolved_url(
            relativePath: sidecarRelativePath,
            baseDirectory: vaultURL
        )
        let sidecarBody = """
        # R0lling Conflict — \(dayString)

        Εξωτερική τροποποίηση ανιχνεύθηκε. Το πρωτότυπο `\(dayString).md` **δεν** υπεργράφηκε.

        ---
        ## Προτεινόμενη συγχώνευση R0lling (μη εφαρμοσμένη)

        \(attemptedMerge)
        """
        try FileManager.default.createDirectory(
            at: sidecarURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try sidecarBody.write(to: sidecarURL, atomically: true, encoding: .utf8)
        print("[ObsidianVaultBridge] Conflict στο \(relativeNotePath) → sidecar \(sidecarRelativePath)")
        return ObsidianSingleExportResult(
            noteURL: noteURL,
            hadConflict: true,
            conflictSidecarRelativePath: sidecarRelativePath
        )
    }

    private func antigrafi_attachments(
        entry: JournalEntry,
        mediaStorage: MediaStorageProtocol,
        vaultURL: URL
    ) async throws {
        let attachmentsDir = try PathAsfaleia.asfalhs_resolved_url(
            relativePath: Self.attachmentsFolderName,
            baseDirectory: vaultURL
        )
        try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

        for attachment in entry.attachments {
            // SEC-002: reject `..` / absolute — silent skip ανά attachment.
            guard let sourceURL = try? mediaStorage.getMediaFileURL(relativePath: attachment.relativePath),
                  let destURL = try? PathAsfaleia.asfalhs_resolved_url(
                    relativePath: attachment.relativePath,
                    baseDirectory: attachmentsDir
                  ) else {
                continue
            }
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                try? FileManager.default.createDirectory(
                    at: destURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if !FileManager.default.fileExists(atPath: destURL.path) {
                    try? FileManager.default.copyItem(at: sourceURL, to: destURL)
                }
            }
        }
    }

    // MARK: - Hash persistence (A09 across restarts)

    /// Φόρτωση hashes — καλείται μόνο μέσα σε `me_prosbasi_vault` ή default vault.
    private func fortosi_hashes_apo_disk_unlocked() {
        defer { hashesFortomenoi = true }
        guard let vaultURL = vaultDirectoryURL else {
            lastKnownHashes = [:]
            return
        }
        do {
            let storeURL = try PathAsfaleia.asfalhs_resolved_url(
                relativePath: Self.hashStoreRelativePath,
                baseDirectory: vaultURL
            )
            guard FileManager.default.fileExists(atPath: storeURL.path),
                  let data = try? Data(contentsOf: storeURL),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
                lastKnownHashes = [:]
                return
            }
            lastKnownHashes = decoded
        } catch {
            lastKnownHashes = [:]
        }
    }

    private func apothikeusi_hashes_sto_disk(vaultURL: URL) throws {
        let storeURL = try PathAsfaleia.asfalhs_resolved_url(
            relativePath: Self.hashStoreRelativePath,
            baseDirectory: vaultURL
        )
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(lastKnownHashes)
        try data.write(to: storeURL, options: .atomic)
    }

    // MARK: - Scoped access

    private func me_prosbasi_vault<T>(
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
