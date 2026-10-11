import Foundation

public enum MediaType: String, Codable, CaseIterable, Sendable {
    case photo = "photo", video = "video", clip = "clip", audio = "audio"

    var folderName: String {
        switch self {
        case .photo: "Photos"
        case .video: "Videos"
        case .clip: "Clips"
        case .audio: "Audio"
        }
    }
}

public enum EntrySource: String, Codable, Sendable { case manual }

public struct MediaAttachment: Codable, Sendable {
    public let id: UUID
    public var relativePath: String
    public var originalFilename: String
    public var mediaType: MediaType
    public var byteSize: Int64
    public var durationSeconds: Double?
    public var captureTimestamp: Date
    public var width: Int?
    public var height: Int?
    public var hasAudio: Bool

    public init(
        id: UUID = UUID(),
        relativePath: String,
        originalFilename: String? = nil,
        mediaType: MediaType,
        byteSize: Int64,
        durationSeconds: Double? = nil,
        captureTimestamp: Date = Date(),
        width: Int? = nil,
        height: Int? = nil,
        hasAudio: Bool = false
    ) {
        self.id = id
        self.relativePath = relativePath
        self.originalFilename = originalFilename ?? URL(fileURLWithPath: relativePath).lastPathComponent
        self.mediaType = mediaType
        self.byteSize = byteSize
        self.durationSeconds = durationSeconds
        self.captureTimestamp = captureTimestamp
        self.width = width
        self.height = height
        self.hasAudio = hasAudio
    }
}

public struct JournalEntry: Codable, Sendable {
    public let id: UUID
    public var timestamp: Date
    public var timeZoneIdentifier: String
    public var title: String?
    public var content: String
    public var source: EntrySource
    public var tags: [String]
    public var locationName: String?
    public var attachments: [MediaAttachment]
    public var isFavorite: Bool
    public var lastModified: Date

    public init(id: UUID = UUID(), content: String, attachments: [MediaAttachment] = []) {
        self.id = id
        self.timestamp = Date()
        self.timeZoneIdentifier = "UTC"
        self.title = nil
        self.content = content
        self.source = .manual
        self.tags = []
        self.locationName = nil
        self.attachments = attachments
        self.isFavorite = false
        self.lastModified = Date()
    }
}

public struct AgentMemory: Codable, Sendable {
    let memoryNotes: String
    let userPreferences: String
    let openLoops: String
}

public actor AgentFolderManager {
    func loadAgentMemory() throws -> AgentMemory {
        AgentMemory(memoryNotes: "", userPreferences: "", openLoops: "")
    }

    func saveAgentMemory(_ memory: AgentMemory) throws {}
}

public protocol JournalStorageProtocol: Sendable {
    func saveEntry(_ entry: JournalEntry) async throws
    func updateEntryIfPresent(_ entry: JournalEntry) async throws -> Bool
    func appendAttachmentIfPresent(_ attachment: MediaAttachment, toEntryID id: UUID) async throws -> JournalEntry?
    func insertEntriesIfAbsentAtomically(_ entries: [JournalEntry]) async throws -> Set<UUID>
    func deleteEntry(id: UUID) async throws
    func getEntry(id: UUID) async throws -> JournalEntry?
    func getEntriesForDate(_ date: Date) async throws -> [JournalEntry]
    func getAllEntries() async throws -> [JournalEntry]
    func searchEntries(query: String, tag: String?, source: EntrySource?) async throws -> [JournalEntry]
    func getDatesWithEntries() async throws -> Set<String>
}

public protocol MediaStorageProtocol: Sendable {
    func saveMediaFile(data: Data, originalFilename: String, mediaType: MediaType) async throws -> MediaAttachment
    func saveMediaFile(from sourceURL: URL, originalFilename: String, mediaType: MediaType) async throws -> MediaAttachment
    func getMediaFileURL(relativePath: String) throws -> URL
    func deleteMediaFile(relativePath: String) async throws
    func availableFreeDiskSpace() -> Int64
    func cleanupOrphanedFiles(activeRelativePaths: Set<String>) async throws -> Int
}

public protocol BackupRestoreProtocol: Sendable {
    func createBackupBundle() async throws -> URL
    func restoreFromBackupBundle(bundleURL: URL) async throws -> (restoredEntries: Int, restoredMedia: Int)
}

public enum MediaApothikeusiError: Error, Sendable, Equatable {
    case anepikisXoros(diathesima: Int64, apaitoumena: Int64)
    case kenoDedomena
    case egrafiApetixe(minima: String)
    case unsafeRelativePath(relativePath: String)
}

public let ELAXISTOS_ELEUTHEROS_XOROS_BYTES: Int64 = 50 * 1024 * 1024

enum R0llingFileProtection {
    static let atomicWriteOptions: Data.WritingOptions = [.atomic]
    static func apply(to url: URL) throws {}
}

enum PathAsfaleia {
    static func asfalhs_resolved_url(relativePath: String, baseDirectory: URL) throws -> URL {
        let result = baseDirectory.appendingPathComponent(relativePath).standardizedFileURL
        let root = baseDirectory.standardizedFileURL.path + "/"
        guard result.path.hasPrefix(root) else { throw NSError(domain: "Path", code: 1) }
        return result
    }
}

enum AppErrorTaxonomy {
    static let backupDomain = "Backup"
    static let backupMissingManifest = 1
    static let backupInvalidManifest = 2
    static let backupPathRejected = 3
    static let backupAgentRestoreFailed = 4

    static func makeError(domain: String, code: Int, message: String, underlying: Error? = nil) -> NSError {
        NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    static func minimaXristi(gia error: Error) -> String { String(describing: error) }
}

extension URLResourceKey {
    static var volumeAvailableCapacityForImportantUsageKey: URLResourceKey { .fileSizeKey }
}

extension URLResourceValues {
    var volumeAvailableCapacityForImportantUsage: Int64? { 1_000_000_000 }
}

actor ProbeJournal: JournalStorageProtocol {
    private var entries: [UUID: JournalEntry] = [:]

    func saveEntry(_ entry: JournalEntry) { entries[entry.id] = entry }

    func updateEntryIfPresent(_ entry: JournalEntry) -> Bool {
        guard entries[entry.id] != nil else { return false }
        entries[entry.id] = entry
        return true
    }

    func appendAttachmentIfPresent(_ attachment: MediaAttachment, toEntryID id: UUID) -> JournalEntry? {
        guard var entry = entries[id] else { return nil }
        entry.attachments.append(attachment)
        entries[id] = entry
        return entry
    }

    func insertEntriesIfAbsentAtomically(_ values: [JournalEntry]) -> Set<UUID> {
        var inserted = Set<UUID>()
        for entry in values where entries[entry.id] == nil {
            entries[entry.id] = entry
            inserted.insert(entry.id)
        }
        return inserted
    }

    func deleteEntry(id: UUID) { entries.removeValue(forKey: id) }
    func getEntry(id: UUID) -> JournalEntry? { entries[id] }
    func getEntriesForDate(_ date: Date) -> [JournalEntry] { [] }
    func getAllEntries() -> [JournalEntry] { Array(entries.values) }
    func searchEntries(query: String, tag: String?, source: EntrySource?) -> [JournalEntry] { [] }
    func getDatesWithEntries() -> Set<String> { [] }
}

public actor MediaReferenceMutationGate {
    public init() {}

    public func withExclusiveAccess<T: Sendable>(
        _ operation: @MainActor @Sendable () async throws -> T
    ) async throws -> T {
        try await operation()
    }
}

@main
struct Probe {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupCapacityProbe-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let photosSource = root.appendingPathComponent("photo.jpg")
        try Data(repeating: 0x31, count: 1024).write(to: photosSource)
        let photosRequired = MediaImportPreflight.requiredFreeSpace(payloadBytes: 1024)!
        let validatedPhotoSize = try MediaImportPreflight.validatePhotosStagingSource(
            at: photosSource,
            availableBytes: photosRequired
        )
        precondition(validatedPhotoSize == 1024)
        do {
            _ = try MediaImportPreflight.validatePhotosStagingSource(
                at: photosSource,
                availableBytes: photosRequired - 1
            )
            fatalError("Photos staging should reject insufficient space for its temp and managed copies")
        } catch let error as MediaApothikeusiError {
            precondition(error == .anepikisXoros(diathesima: photosRequired - 1, apaitoumena: photosRequired))
        }

        let bytes = Data("media-payload".utf8)
        let sourceMedia = MediaStorageService(
            baseDirectory: root.appendingPathComponent("SourceMedia"),
            paradekampseElegxoXorou: true,
            availableFreeDiskSpaceProvider: { 1_000_000_000 }
        )
        let sourceJournal = ProbeJournal()
        let attachment = try await sourceMedia.saveMediaFile(
            data: bytes,
            originalFilename: "a.jpg",
            mediaType: .photo
        )
        let entry = JournalEntry(content: "backup row", attachments: [attachment])
        await sourceJournal.saveEntry(entry)
        let creator = BackupRestoreEngine(storage: sourceJournal, mediaStorage: sourceMedia)
        let bundle = try await creator.createBackupBundle()

        let required = Int64(bytes.count) + ELAXISTOS_ELEUTHEROS_XOROS_BYTES
        let lowCapacity = required - 1
        let tooSmallMedia = MediaStorageService(
            baseDirectory: root.appendingPathComponent("SourceMedia"),
            paradekampseElegxoXorou: true,
            availableFreeDiskSpaceProvider: { lowCapacity }
        )
        let tooSmallCreator = BackupRestoreEngine(storage: sourceJournal, mediaStorage: tooSmallMedia)
        do {
            _ = try await tooSmallCreator.createBackupBundle()
            fatalError("backup creation ignored the free-space reserve")
        } catch let error as MediaApothikeusiError {
            guard error == .anepikisXoros(diathesima: lowCapacity, apaitoumena: required) else {
                throw error
            }
        }

        let targetJournal = ProbeJournal()
        let targetMedia = MediaStorageService(
            baseDirectory: root.appendingPathComponent("TargetMedia"),
            paradekampseElegxoXorou: true,
            availableFreeDiskSpaceProvider: { lowCapacity }
        )
        let restorer = BackupRestoreEngine(storage: targetJournal, mediaStorage: targetMedia)
        do {
            _ = try await restorer.restoreFromBackupBundle(bundleURL: bundle)
            fatalError("restore ignored the free-space reserve")
        } catch let error as MediaApothikeusiError {
            guard error == .anepikisXoros(diathesima: lowCapacity, apaitoumena: required) else {
                throw error
            }
        }
        guard await targetJournal.getAllEntries().isEmpty else {
            fatalError("journal mutated when restore capacity was insufficient")
        }
        let targetURL = try targetMedia.getMediaFileURL(relativePath: attachment.relativePath)
        guard !FileManager.default.fileExists(atPath: targetURL.path) else {
            fatalError("media copied when restore capacity was insufficient")
        }

        let sufficientJournal = ProbeJournal()
        let sufficientMedia = MediaStorageService(
            baseDirectory: root.appendingPathComponent("SufficientMedia"),
            paradekampseElegxoXorou: true,
            availableFreeDiskSpaceProvider: { 1_000_000_000 }
        )
        let sufficientRestore = BackupRestoreEngine(storage: sufficientJournal, mediaStorage: sufficientMedia)
        let result = try await sufficientRestore.restoreFromBackupBundle(bundleURL: bundle)
        guard result.restoredEntries == 1,
              result.restoredMedia == 1,
              await sufficientJournal.getEntry(id: entry.id)?.attachments.first?.byteSize == Int64(bytes.count) else {
            fatalError("sufficient-capacity schema-v1 compatibility round trip failed")
        }

        print("PASS: backup/restore reserve guards and sufficient-capacity schema-v1 round trip")
    }
}
