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

    public init(
        fileURL: URL,
        relativePath: String,
        duration: Double,
        hasAudio: Bool,
        frameCount: Int,
        timestamp: Date = Date(),
        isPlayable: Bool = true,
        isSimulationPlaceholder: Bool = false,
        byteSize: Int64 = 0
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
    }
}

public struct BufferedSample: Sendable {
    public let timestampSeconds: Double
    public let isKeyframe: Bool
    public let isAudio: Bool
    public let data: Data

    public init(timestampSeconds: Double, isKeyframe: Bool, isAudio: Bool, data: Data) {
        self.timestampSeconds = timestampSeconds
        self.isKeyframe = isKeyframe
        self.isAudio = isAudio
        self.data = data
    }
}

public protocol RollingBufferServiceProtocol: Sendable {
    var currentState: BufferState { get async }
    var availableDuration: Double { get async }
    func startBuffering(targetSeconds: Double) async throws
    func stopBuffering() async
    func appendSample(sample: BufferedSample) async
    func triggerClip(requestedSeconds: Double) async throws -> ClipExportResult
    func clearBuffer() async
}
