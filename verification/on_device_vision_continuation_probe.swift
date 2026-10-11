import Foundation
import Vision

@main
struct OnDeviceVisionContinuationProbe {
    static func main() async {
        let result = await OnDeviceVisionService().recognizeTextFromImage(imageData: Data([0x00]))
        precondition(result.isEmpty)
        print("PASS: OCR continuation completed for \(CommandLine.arguments.last ?? "normal")")
    }
}
