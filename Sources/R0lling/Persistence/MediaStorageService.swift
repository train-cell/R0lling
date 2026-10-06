import Foundation

/// Διαχείριση αποθήκευσης αρχείων πολυμέσων (Photos, Videos, Clips, Audio)
public actor MediaStorageService: MediaStorageProtocol {
    private let baseMediaDirectory: URL

    public init(baseDirectory: URL? = nil) {
        if let dir = baseDirectory {
            self.baseMediaDirectory = dir
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.baseMediaDirectory = docs.appendingPathComponent("R0lling/Media", isDirectory: true)
        }
        createSubdirectoriesIfNeeded()
    }

    private func createSubdirectoriesIfNeeded() {
        for type in MediaType.allCases {
            let subDir = baseMediaDirectory.appendingPathComponent(type.folderName, isDirectory: true)
            try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        }
    }

    public func saveMediaFile(data: Data, originalFilename: String, mediaType: MediaType) throws -> MediaAttachment {
        createSubdirectoriesIfNeeded()

        // Έλεγχος διαθέσιμου χώρου (τουλάχιστον 50MB ελεύθερα)
        let minSpace: Int64 = 50 * 1024 * 1024
        guard availableFreeDiskSpace() > minSpace else {
            throw NSError(domain: "R0lling.MediaStorage", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Ανεπαρκής ελεύθερος χώρος αποθήκευσης στη συσκευή."])
        }

        let id = UUID()
        let fileExtension = (originalFilename as NSString).pathExtension
        let safeExtension = fileExtension.isEmpty ? defaultExtension(for: mediaType) : fileExtension
        let filename = "\(id.uuidString).\(safeExtension)"
        let relativePath = "\(mediaType.folderName)/\(filename)"
        let destinationURL = baseMediaDirectory.appendingPathComponent(relativePath)

        try data.write(to: destinationURL, options: .atomic)

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

    public func getMediaFileURL(relativePath: String) -> URL {
        return baseMediaDirectory.appendingPathComponent(relativePath)
    }

    public func deleteMediaFile(relativePath: String) throws {
        let fileURL = getMediaFileURL(relativePath: relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    public func availableFreeDiskSpace() -> Int64 {
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
