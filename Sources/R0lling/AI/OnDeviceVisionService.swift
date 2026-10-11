import Foundation
#if canImport(Vision)
import Vision

private final class OCRContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResumed = false

    func resume(_ continuation: CheckedContinuation<[String], Never>, returning words: [String]) {
        lock.lock()
        let shouldResume = !hasResumed
        hasResumed = true
        lock.unlock()
        guard shouldResume else { return }
        continuation.resume(returning: words)
    }
}
#endif

/// Τοπική αναγνώριση κειμένου και πινακίδων στα καρέ των clips (100% on-device χωρίς cloud)
public struct OnDeviceVisionService: Sendable {
    public init() {}

    /// Εξαγωγή λέξεων/πινακίδων από δεδομένα εικόνας JPEG/PNG
    public func recognizeTextFromImage(imageData: Data) async -> [String] {
        #if canImport(Vision)
        return await withCheckedContinuation { continuation in
            let completion = OCRContinuationGate()
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion.resume(continuation, returning: [])
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
                completion.resume(continuation, returning: Array(Set(extractedKeywords)).prefix(6).map { String($0) })
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(data: imageData, options: [:])
            do {
                try handler.perform([request])
            } catch {
                // Vision's completion handler is not guaranteed to run if scheduling fails.
                // Always resume once so malformed images cannot hang callers or double-resume.
                completion.resume(continuation, returning: [])
            }
        }
        #else
        return []
        #endif
    }
}
