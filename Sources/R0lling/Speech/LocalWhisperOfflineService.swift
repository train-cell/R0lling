import Foundation

/// Stub τοπικής απομαγνητοφώνησης (χωρίς bundled Whisper weights).
/// Δεν παρουσιάζεται ως πραγματικό Whisper/ANE μέχρι να υπάρχει πραγματικό model asset.
public actor LocalWhisperOfflineService {

    public enum ModelQuantization: String, Sendable {
        case q4_0 = "ggml-tiny-q4_0.bin"
        case q5_1 = "ggml-base-q5_1.bin"
        case fp16 = "ggml-tiny-fp16.bin"
    }

    public struct TranscriptionSegment: Sendable {
        public let text: String
        public let startSeconds: Double
        public let endSeconds: Double
        public let confidence: Float
        public let language: String
        /// `true` όταν δεν υπάρχει πραγματικό μοντέλο — ποτέ ψευδές transcript.
        public let isStubUnavailable: Bool

        public init(
            text: String,
            startSeconds: Double,
            endSeconds: Double,
            confidence: Float = 0.0,
            language: String = "el",
            isStubUnavailable: Bool = true
        ) {
            self.text = text
            self.startSeconds = startSeconds
            self.endSeconds = endSeconds
            self.confidence = confidence
            self.language = language
            self.isStubUnavailable = isStubUnavailable
        }
    }

    public enum WhisperStubError: Error, LocalizedError, Sendable {
        case modelWeightsNotBundled(String)

        public var errorDescription: String? {
            switch self {
            case .modelWeightsNotBundled(let name):
                return "Local Whisper μη διαθέσιμο: δεν υπάρχει bundled model (\(name)). Χρησιμοποίησε iOS Speech."
            }
        }
    }

    private var requestedModel: ModelQuantization = .q4_0
    /// Πάντα false μέχρι να υπάρχει πραγματικό asset στο bundle.
    private var hasRealModelWeights: Bool = false

    public init() {}

    /// Δηλώνει ποιο quantization θα φορτωνόταν — fail-closed χωρίς πραγματικά weights.
    public func loadModel(quantization: ModelQuantization = .q4_0) async throws {
        self.requestedModel = quantization
        self.hasRealModelWeights = false
        throw WhisperStubError.modelWeightsNotBundled(quantization.rawValue)
    }

    /// Δεν εφευρίσκει κείμενο. Stub → άδειο transcript + `isStubUnavailable`.
    public func transcribe(pcmData: Data, languageCode: String = "el") async -> TranscriptionSegment {
        let sampleCount = pcmData.count / 2
        let duration = Double(sampleCount) / 16000.0
        _ = requestedModel
        _ = hasRealModelWeights
        return TranscriptionSegment(
            text: "",
            startSeconds: 0.0,
            endSeconds: max(0, duration),
            confidence: 0.0,
            language: languageCode,
            isStubUnavailable: true
        )
    }

    /// Έτοιμο μόνο με πραγματικά model weights (προς το παρόν πάντα false).
    public func isReady() -> Bool {
        return hasRealModelWeights
    }
}
