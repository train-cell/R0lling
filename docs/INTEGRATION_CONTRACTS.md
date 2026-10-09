> Current status (2026-10-09): This document contains historical assertions or design targets. It is not evidence for the current checkout. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) and [FINDINGS_REMEDIATION.md](FINDINGS_REMEDIATION.md). Earlier “100%”, module counts, CI/head references and security/readiness claims are superseded.

# R0lling — Συμβόλαια Διασύνδεσης (Integration Contracts) v1.0

**Έργο:** `R0lling`  
**Ημερομηνία:** 6 Οκτωβρίου 2026  
**Γλώσσα & Πλατφόρμα:** Swift 6 / iOS 17.2+  

---

## 1. Domain Models (`R0lling.Core`)

```swift
import Foundation

public enum EntrySource: String, Codable, Sendable {
    case manual = "manual"
    case glasses = "glasses"
    case glassesClip = "glasses_clip"
    case voice = "voice"
    case importFile = "import"
    case ai = "ai"
}

public enum MediaType: String, Codable, Sendable {
    case photo = "photo"
    case video = "video"
    case clip = "clip"
    case audio = "audio"
}

public struct MediaAttachment: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let relativePath: String
    public let mediaType: MediaType
    public let byteSize: Int64
    public let durationSeconds: Double?
    public let captureTimestamp: Date
    public let width: Int?
    public let height: Int?
    public let hasAudio: Bool

    public init(
        id: UUID = UUID(),
        relativePath: String,
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
        self.mediaType = mediaType
        self.byteSize = byteSize
        self.durationSeconds = durationSeconds
        self.captureTimestamp = captureTimestamp
        self.width = width
        self.height = height
        self.hasAudio = hasAudio
    }
}

public struct JournalEntry: Identifiable, Codable, Sendable, Equatable {
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

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        timeZoneIdentifier: String = TimeZone.current.identifier,
        title: String? = nil,
        content: String,
        source: EntrySource = .manual,
        tags: [String] = [],
        locationName: String? = nil,
        attachments: [MediaAttachment] = [],
        isFavorite: Bool = false,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.timeZoneIdentifier = timeZoneIdentifier
        self.title = title
        self.content = content
        self.source = source
        self.tags = tags
        self.locationName = locationName
        self.attachments = attachments
        self.isFavorite = isFavorite
        self.lastModified = lastModified
    }
}
```

---

## 2. Rolling Buffer Contract (`R0lling.Buffer`)

```swift
import AVFoundation

public enum BufferState: Sendable, Equatable {
    case idle
    case active(durationAvailable: Double)
    case paused
    case exporting(progress: Double)
    case error(String)
}

public struct ClipExportResult: Sendable {
    public let fileURL: URL
    public let relativePath: String
    public let duration: Double
    public let hasAudio: Bool
    public let frameCount: Int
    public let timestamp: Date
}

public protocol RollingBufferServiceProtocol: AnyObject, Sendable {
    var state: BufferState { get }
    var currentBufferDuration: Double { get }
    func startBuffering(targetDuration: Double) async throws
    func stopBuffering() async
    func appendVideoSample(_ sampleBuffer: CMSampleBuffer) async
    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) async
    func triggerClip(requestedSeconds: Double) async throws -> ClipExportResult
    func clearBuffer() async
}
```

---

## 3. Glasses Adapter Contract (`R0lling.Glasses`)

```swift
public enum GlassesConnectionState: Sendable, Equatable {
    case disconnected
    case searching
    case connecting
    case connected(deviceName: String, batteryLevel: Int?)
    case streaming(fps: Double, isBuffering: Bool)
    case error(String)
}

public protocol MetaGlassesAdapterProtocol: AnyObject, Sendable {
    var connectionState: GlassesConnectionState { get }
    var isSimulationMode: Bool { get }
    func pairDevice() async throws
    func disconnect() async
    func startLiveStream() async throws
    func stopLiveStream() async
    func captureHighResPhoto() async throws -> URL
    func setSimulationMode(_ enabled: Bool) async
}
```

---

## 4. Speech & Voice Command Contract (`R0lling.Speech`)

```swift
public enum VoiceCommandType: Sendable, Equatable {
    case clip(seconds: Double)
    case note(text: String)
    case whatAmISeeing
    case unknown(raw: String)
}

public protocol VoiceCommandParserProtocol: Sendable {
    func parse(transcript: String) -> VoiceCommandType?
    func scrubGreekAndEnglish(raw: String) -> String
}

public protocol SpeechTranscriptionServiceProtocol: AnyObject, Sendable {
    func startListening() async throws
    func stopListening() async -> String?
    var onCommandRecognized: (@Sendable (VoiceCommandType) -> Void)? { get set }
}
```

---

## 5. AI Router & Connectors (`R0lling.AI`)

```swift
public enum AIProviderType: String, Codable, Sendable {
    case hermes = "hermes"
    case directAPI = "direct_api"
}

public struct AIRequestPayload: Sendable {
    public let prompt: String
    public let systemPrompt: String?
    public let imageBase64: String?
    public let contextEntries: [JournalEntry]
    public let agentMemoryContext: String?
}

public struct AIResponseResult: Sendable {
    public let reply: String
    public let tokensUsed: Int?
    public let referencedEntryIDs: [UUID]
}

public protocol AIConnectorProtocol: Sendable {
    var providerType: AIProviderType { get }
    func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult
    func describeImage(imageData: Data, question: String?) async throws -> String
    func summarizeDay(entries: [JournalEntry]) async throws -> String
}
```

---

## 6. Obsidian Bridge & Agent Memory (`R0lling.Obsidian`)

```swift
public struct ObsidianExportResult: Sendable {
    public let exportedFileCount: Int
    public let modifiedFiles: [String]
    public let conflictsDetected: [String]
}

public protocol ObsidianVaultBridgeProtocol: Sendable {
    func setVaultURL(_ url: URL) async throws
    func exportEntry(_ entry: JournalEntry) async throws -> URL
    func exportBatch(entries: [JournalEntry]) async throws -> ObsidianExportResult
    func syncAgentMemory(memory: String, preferences: String, openLoops: String) async throws
    func detectExternalModifications(date: Date) async throws -> Bool
}
```
