import Foundation
#if canImport(Vision)
import Vision
#endif

/// Τοπική αναγνώριση κειμένου και πινακίδων στα καρέ των clips (100% on-device χωρίς cloud)
public struct OnDeviceVisionService: Sendable {
    public init() {}

    /// Εξαγωγή λέξεων/πινακίδων από δεδομένα εικόνας JPEG/PNG
    public func recognizeTextFromImage(imageData: Data) async -> [String] {
        #if canImport(Vision)
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var extractedKeywords: [String] = []
                for obs in observations {
                    if let candidate = obs.topCandidates(1).first {
                        let words = candidate.string.components(separatedBy: CharacterSet.alphanumerics.inverted)
                        for w in words where w.count >= 4 {
                            extractedKeywords.append(w.lowercased())
                        }
                    }
                }
                continuation.resume(returning: Array(Set(extractedKeywords)).prefix(6).map { String($0) })
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(data: imageData, options: [:])
            try? handler.perform([request])
        }
        #else
        return []
        #endif
    }
}
