import Foundation

/// Διαχείριση αποθήκευσης αρχείων πολυμέσων (Photos, Videos, Clips, Audio)
public actor MediaStorageService: MediaStorageProtocol {
    private let baseMediaDirectory: URL
    /// Αν `true`, αγνοεί τον έλεγχο δίσκου (μόνο unit tests).
    private let paradekampseElegxoXorou: Bool

    public init(baseDirectory: URL? = nil, paradekampseElegxoXorou: Bool = false) {
        self.paradekampseElegxoXorou = paradekampseElegxoXorou
        if let dir = baseDirectory {
            self.baseMediaDirectory = dir
        } else if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.baseMediaDirectory = docs.appendingPathComponent("R0lling/Media", isDirectory: true)
        } else {
            // Fail-soft: χωρίς Documents (σπάνιο) → temp, όχι force-unwrap crash.
            self.baseMediaDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("R0lling/Media", isDirectory: true)
        }
        createSubdirectoriesIfNeeded()
    }

    private nonisolated func createSubdirectoriesIfNeeded() {
        for type in MediaType.allCases {
            let subDir = baseMediaDirectory.appendingPathComponent(type.folderName, isDirectory: true)
            try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        }
    }

    public func saveMediaFile(data: Data, originalFilename: String, mediaType: MediaType) throws -> MediaAttachment {
        guard !data.isEmpty else {
            throw MediaApothikeusiError.kenoDedomena
        }

        createSubdirectoriesIfNeeded()

        if !paradekampseElegxoXorou {
            let diathesima = availableFreeDiskSpace()
            guard diathesima > ELAXISTOS_ELEUTHEROS_XOROS_BYTES else {
                throw MediaApothikeusiError.anepikisXoros(
                    diathesima: diathesima,
                    apaitoumena: ELAXISTOS_ELEUTHEROS_XOROS_BYTES
                )
            }
        }

        let id = UUID()
        let fileExtension = (originalFilename as NSString).pathExtension
        let safeExtension = fileExtension.isEmpty ? defaultExtension(for: mediaType) : fileExtension
        let filename = "\(id.uuidString).\(safeExtension)"
        let relativePath = "\(mediaType.folderName)/\(filename)"
        let destinationURL = baseMediaDirectory.appendingPathComponent(relativePath)

        do {
            try data.write(to: destinationURL, options: .atomic)
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
            mediaType: mediaType,
            byteSize: Int64(data.count),
            durationSeconds: nil,
            captureTimestamp: Date(),
            width: nil,
            height: nil,
            hasAudio: (mediaType == .audio || mediaType == .clip || mediaType == .video)
        )

        return attachment
    }

    public nonisolated func getMediaFileURL(relativePath: String) throws -> URL {
        try PathAsfaleia.asfalhs_resolved_url(
            relativePath: relativePath,
            baseDirectory: baseMediaDirectory
        )
    }

    public func deleteMediaFile(relativePath: String) throws {
        let fileURL = try getMediaFileURL(relativePath: relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    public nonisolated func availableFreeDiskSpace() -> Int64 {
        do {
            let values = try baseMediaDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 1_000_000_000
        } catch {
            return 1_000_000_000 // Fallback safe estimate: 1GB
        }
    }

    public func cleanupOrphanedFiles(activeRelativePaths: Set<String>) throws -> Int {
        var removedCount = 0
        let fileManager = FileManager.default

        for type in MediaType.allCases {
            let subDir = baseMediaDirectory.appendingPathComponent(type.folderName, isDirectory: true)
            guard let fileURLs = try? fileManager.contentsOfDirectory(at: subDir, includingPropertiesForKeys: nil) else {
                continue
            }

            for fileURL in fileURLs {
                let relPath = "\(type.folderName)/\(fileURL.lastPathComponent)"
                if !activeRelativePaths.contains(relPath) {
                    try? fileManager.removeItem(at: fileURL)
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
