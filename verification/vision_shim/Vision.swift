import Foundation

public class VNRequest {
    public var results: [Any]? = []
    public init() {}
}

public enum VNRequestTextRecognitionLevel: Sendable {
    case accurate
}

public final class VNRecognizeTextRequest: VNRequest {
    public typealias CompletionHandler = (VNRequest, Error?) -> Void
    public let completionHandler: CompletionHandler
    public var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    public var usesLanguageCorrection = false

    public init(completionHandler: @escaping CompletionHandler) {
        self.completionHandler = completionHandler
        super.init()
    }
}

public struct VNRecognizedTextObservation {
    public init() {}
    public func topCandidates(_ maximum: Int) -> [VNRecognizedText] { [] }
}

public struct VNRecognizedText {
    public let string = ""
    public init() {}
}

public final class VNImageRequestHandler: @unchecked Sendable {
    public init(data: Data, options: [String: Any]) {}

    public func perform(_ requests: [VNRecognizeTextRequest]) throws {
        guard let request = requests.first else { return }
        switch ProcessInfo.processInfo.arguments.last {
        case "throw-before-callback":
            throw URLError(.badURL)
        case "callback-then-throw":
            request.completionHandler(request, nil)
            throw URLError(.badURL)
        default:
            request.completionHandler(request, nil)
        }
    }
}
