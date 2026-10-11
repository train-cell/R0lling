import Foundation

public struct JournalEntry {
    public let dateKey = "2026-10-10"
    public let formattedTime = "12:00"
    public let locationName: String? = nil
}

extension Date {
    public func formattedGreekHeader() -> String { "today" }
}

@main
struct ClipWatermarkContractProbe {
    static func main() async {
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-watermark-source-\(UUID().uuidString).mov")
        let options = ClipWatermarkExporter.WatermarkOptions(dateString: "2026-10-10 12:00")
        guard options.brandLabel == "R0lling" else {
            fatalError("Watermark metadata must not claim specific glasses hardware")
        }
        do {
            _ = try await ClipWatermarkExporter().prepareShareableClipURL(sourceClipURL: sourceURL, options: options)
            fatalError("A missing source clip must not produce a shareable watermark export")
        } catch is ClipWatermarkExportError {
            print("PASS: invalid watermark source fails closed")
        } catch {
            fatalError("Unexpected watermark failure: \(error)")
        }
    }
}
