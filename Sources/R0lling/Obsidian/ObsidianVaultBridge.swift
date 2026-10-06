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

/// Γέφυρα συγχρονισμού και εξαγωγής Markdown με το Obsidian Vault
public actor ObsidianVaultBridge {
    private var vaultDirectoryURL: URL?
    private var lastKnownHashes: [String: String] = [:] // relativePath: sha256

    public init(vaultURL: URL? = nil) {
        if let url = vaultURL {
            self.vaultDirectoryURL = url
        } else if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.vaultDirectoryURL = docs.appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
        } else {
            self.vaultDirectoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
        }
    }

    public func setVaultURL(_ url: URL) {
        self.vaultDirectoryURL = url
    }

    public var currentVaultURL: URL? {
        return vaultDirectoryURL
    }

    /// Εξαγωγή μίας καταχώρισης στο αντίστοιχο ημερήσιο Markdown αρχείο (YYYY/MM/YYYY-MM-DD.md).
    /// R3-005: Σε hash mismatch ΔΕΝ υπεργράφει — γράφει sidecar `.r0lling-conflict.md`.
    @discardableResult
    public func exportEntry(_ entry: JournalEntry, mediaStorage: MediaStorageProtocol) async throws -> ObsidianSingleExportResult {
        guard let vaultURL = vaultDirectoryURL else {
            throw NSError(domain: "R0lling.Obsidian", code: 6001, userInfo: [NSLocalizedDescriptionKey: "Δεν έχει οριστεί φάκελος Obsidian Vault."])
        }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: entry.timestamp)
        let month = String(format: "%02d", calendar.component(.month, from: entry.timestamp))
        let dayString = entry.dateKey // YYYY-MM-DD

        let yearMonthDir = vaultURL.appendingPathComponent("\(year)/\(month)", isDirectory: true)
        try FileManager.default.createDirectory(at: yearMonthDir, withIntermediateDirectories: true)

        let noteURL = yearMonthDir.appendingPathComponent("\(dayString).md")
        let relativeNotePath = "\(year)/\(month)/\(dayString).md"

        // Έλεγχος εξωτερικών αλλαγών αν το αρχείο υπάρχει ήδη και έχουμε καταγεγραμμένο hash
        if FileManager.default.fileExists(atPath: noteURL.path) {
            let existingData = try Data(contentsOf: noteURL)
            let existingHash = existingData.sha256Hash
            if let recordedHash = lastKnownHashes[relativeNotePath], recordedHash != existingHash {
                let existingContent = String(data: existingData, encoding: .utf8) ?? ""
                let attemptedMerge = mergeEntryIntoMarkdown(
                    existingContent: existingContent,
                    entry: entry,
                    dayTitle: dayString
                )
                let sidecarName = "\(dayString).r0lling-conflict.md"
                let sidecarURL = yearMonthDir.appendingPathComponent(sidecarName)
                let sidecarRelative = "\(year)/\(month)/\(sidecarName)"
                let sidecarBody = """
                # R0lling Conflict — \(dayString)

                Εξωτερική τροποποίηση ανιχνεύθηκε. Το πρωτότυπο `\(dayString).md` **δεν** υπεργράφηκε.

                ---
                ## Προτεινόμενη συγχώνευση R0lling (μη εφαρμοσμένη)

                \(attemptedMerge)
                """
                try sidecarBody.write(to: sidecarURL, atomically: true, encoding: .utf8)
                print("[ObsidianVaultBridge] Conflict στο \(relativeNotePath) → sidecar \(sidecarRelative)")
                return ObsidianSingleExportResult(
                    noteURL: noteURL,
                    hadConflict: true,
                    conflictSidecarRelativePath: sidecarRelative
                )
            }
        }

        // Εξαγωγή/Αντιγραφή πολυμέσων στον υποφάκελο Attachments του Vault
        let attachmentsDir = vaultURL.appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

        for attachment in entry.attachments {
            // SEC-002: reject `..` / absolute — silent skip ανά attachment (vault export συνεχίζει).
            guard let sourceURL = try? await mediaStorage.getMediaFileURL(relativePath: attachment.relativePath),
                  let destURL = try? PathAsfaleia.asfalhs_resolved_url(
                    relativePath: attachment.relativePath,
                    baseDirectory: attachmentsDir
                  ) else {
                continue
            }
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                try? FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: destURL.path) {
                    try? FileManager.default.copyItem(at: sourceURL, to: destURL)
                }
            }
        }

        var existingContent = ""
        if FileManager.default.fileExists(atPath: noteURL.path) {
            existingContent = (try? String(contentsOf: noteURL, encoding: .utf8)) ?? ""
        }

        let updatedContent = mergeEntryIntoMarkdown(existingContent: existingContent, entry: entry, dayTitle: dayString)
        try updatedContent.write(to: noteURL, atomically: true, encoding: .utf8)

        lastKnownHashes[relativeNotePath] = updatedContent.sha256Hash
        return ObsidianSingleExportResult(noteURL: noteURL, hadConflict: false, conflictSidecarRelativePath: nil)
    }

    /// Εξαγωγή συνόλου εγγραφών (Batch Export)
    public func exportBatch(entries: [JournalEntry], mediaStorage: MediaStorageProtocol) async throws -> ObsidianExportResult {
        var exportedCount = 0
        var modifiedList: [String] = []
        var conflictsList: [String] = []

        let grouped = Dictionary(grouping: entries, by: { $0.dateKey })

        for (_, dayEntries) in grouped {
            for entry in dayEntries {
                let outcome = try await exportEntry(entry, mediaStorage: mediaStorage)
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

    /// Συνδυασμός εγγραφής στο υπάρχον Markdown χωρίς να χαθούν υπάρχουσες χειροκίνητες σημειώσεις
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
}
