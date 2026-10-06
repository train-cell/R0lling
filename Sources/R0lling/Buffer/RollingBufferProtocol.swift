import Foundation
import CoreMedia

public enum BufferState: Sendable, Equatable {
    case idle
    case active(durationAvailable: Double)
    case paused
    case exporting(progress: Double)
    case error(String)
}

/// Αποτέλεσμα εξαγωγής clip με ρητή δήλωση playability (R3-002).
public struct ClipExportResult: Sendable, Equatable {
    public let fileURL: URL
    public let relativePath: String
    public let duration: Double
    public let hasAudio: Bool
    public let frameCount: Int
    public let timestamp: Date
    /// `true` μόνο όταν το αρχείο είναι δομικά playable MP4 (περιέχει moov / AVAssetWriter).
    public let isPlayable: Bool
    /// `true` όταν το media είναι placeholder (simulation / χωρίς πραγματικό NAL stream).
    public let isSimulationPlaceholder: Bool
    /// Πραγματικό μέγεθος αρχείου σε bytes.
    public let byteSize: Int64
    /// Generation του stream session από το οποίο προήλθε το clip (A06 gap safety).
    public let streamGeneration: UInt64

    public init(
        fileURL: URL,
        relativePath: String,
        duration: Double,
        hasAudio: Bool,
        frameCount: Int,
        timestamp: Date = Date(),
        isPlayable: Bool = true,
        isSimulationPlaceholder: Bool = false,
        byteSize: Int64 = 0,
        streamGeneration: UInt64 = 0
    ) {
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.duration = duration
        self.hasAudio = hasAudio
        self.frameCount = frameCount
        self.timestamp = timestamp
        self.isPlayable = isPlayable
        self.isSimulationPlaceholder = isSimulationPlaceholder
        self.byteSize = byteSize
        self.streamGeneration = streamGeneration
    }
}

public struct BufferedSample: Sendable {
    public let timestampSeconds: Double
    public let isKeyframe: Bool
    public let isAudio: Bool
    public let data: Data
    /// Stream generation — samples από παλιό session αγνοούνται μετά disconnect.
    public let streamGeneration: UInt64

    public init(
        timestampSeconds: Double,
        isKeyframe: Bool,
        isAudio: Bool,
        data: Data,
        streamGeneration: UInt64 = 0
    ) {
        self.timestampSeconds = timestampSeconds
        self.isKeyframe = isKeyframe
        self.isAudio = isAudio
        self.data = data
        self.streamGeneration = streamGeneration
    }
}

public protocol RollingBufferServiceProtocol: AnyObject, Sendable {
    var currentState: BufferState { get async }
    var availableDuration: Double { get async }
    /// Μοναδικό ID session ροής — αυξάνεται σε disconnect / gap (A06).
    var streamGeneration: UInt64 { get async }
    func startBuffering(targetSeconds: Double) async throws
    func stopBuffering() async
    /// A07: παύση χωρίς clear (samples παραμένουν για clip μέχρι clear).
    func pauseBuffering() async
    /// Επανεκκίνηση μετά από pause — ίδια generation αν δεν έγινε interrupt.
    func resumeBuffering() async
    /// A06: disconnect / stream loss — clear + νέα generation (χωρίς ένωση κενών).
    func markStreamInterrupted(reason: String) async
    func appendSample(sample: BufferedSample) async
    func triggerClip(requestedSeconds: Double) async throws -> ClipExportResult
    func clearBuffer() async
}
