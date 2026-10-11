import Foundation

public struct OnDeviceVisionAnalysisResult: Sendable, Equatable {
    public let recognizedText: [String]
    public let cloudDescription: String?
    public let cloudFailureMessage: String?

    public var hasUsableResult: Bool {
        cloudDescription != nil || !recognizedText.isEmpty
    }

    public init(
        recognizedText: [String],
        cloudDescription: String?,
        cloudFailureMessage: String?
    ) {
        self.recognizedText = recognizedText
        self.cloudDescription = cloudDescription
        self.cloudFailureMessage = cloudFailureMessage
    }
}

/// Runs local OCR before optional provider vision so local text remains useful offline.
public enum OnDeviceVisionAnalysisPipeline {
    public static func analyze(
        imageData: Data,
        recognizeText: @escaping @Sendable (Data) async -> [String],
        prepareForCloud: @escaping @Sendable (Data) async throws -> Data = { $0 },
        describeWithCloud: @escaping @Sendable (Data) async throws -> String
    ) async throws -> OnDeviceVisionAnalysisResult {
        try Task.checkCancellation()
        let recognizedText = await recognizeText(imageData)
        try Task.checkCancellation()

        do {
            let cloudImage = try await prepareForCloud(imageData)
            try Task.checkCancellation()
            let description = try await describeWithCloud(cloudImage)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            try Task.checkCancellation()
            return OnDeviceVisionAnalysisResult(
                recognizedText: recognizedText,
                cloudDescription: description.isEmpty ? nil : description,
                cloudFailureMessage: nil
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            return OnDeviceVisionAnalysisResult(
                recognizedText: recognizedText,
                cloudDescription: nil,
                cloudFailureMessage: error.localizedDescription
            )
        }
    }
}
