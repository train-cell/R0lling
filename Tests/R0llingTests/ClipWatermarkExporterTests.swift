import XCTest
@testable import R0lling

#if canImport(AVFoundation) && canImport(CoreVideo) && canImport(CoreGraphics)
import AVFoundation
import CoreGraphics
import CoreVideo
#endif

final class ClipWatermarkExporterTests: XCTestCase {
    func testWatermarkExportNeverReturnsMissingSourceAsIfItWereRendered() async {
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-watermark-source-\(UUID().uuidString).mov")
        let options = ClipWatermarkExporter.WatermarkOptions(dateString: "2026-10-10 12:00")

        do {
            let outputURL = try await ClipWatermarkExporter().prepareShareableClipURL(
                sourceClipURL: sourceURL,
                options: options
            )
            XCTAssertNotEqual(outputURL, sourceURL)
            XCTFail("Exporting a missing source must not succeed")
        } catch {
            XCTAssertTrue(error is ClipWatermarkExportError)
        }
    }

    func testWatermarkBrandDoesNotClaimSpecificGlassesHardware() {
        XCTAssertEqual(ClipWatermarkExporter.WatermarkOptions(dateString: "today").brandLabel, "R0lling")
    }

    #if canImport(AVFoundation) && canImport(CoreVideo) && canImport(CoreGraphics)
    func testAppleExportProducesPlayableVideoWithVisibleOverlay() async throws {
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("watermark-fixture-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        try await Self.makeWhiteVideo(at: sourceURL)

        let outputURL = try await ClipWatermarkExporter().prepareShareableClipURL(
            sourceClipURL: sourceURL,
            options: .init(dateString: "2026-10-10 12:00", locationName: "Athens")
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        XCTAssertNotEqual(outputURL, sourceURL)
        let exportedAsset = AVURLAsset(url: outputURL)
        let isPlayable = try await exportedAsset.load(.isPlayable)
        let videoTracks = try await exportedAsset.loadTracks(withMediaType: .video)
        XCTAssertTrue(isPlayable)
        XCTAssertFalse(videoTracks.isEmpty)

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: outputURL))
        generator.appliesPreferredTrackTransform = true
        let frame = try generator.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: nil)
        let pixels = Self.pixelSummary(in: frame)
        XCTAssertGreaterThan(pixels.darkBottom, 500, "Expected the translucent watermark banner at the lower edge")
        XCTAssertLessThan(pixels.darkTop, 500, "The watermark banner should not be at the upper edge")
        XCTAssertGreaterThan(pixels.brightCenter, 5_000, "The source video should remain visible outside the banner")
        XCTAssertLessThan(pixels.darkCenter, 500, "The watermark must not obscure the center of the frame")
    }

    func testAppleExportKeepsPortraitOrientationAndEdgeOverlay() async throws {
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("watermark-portrait-fixture-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        try await Self.makeWhiteVideo(at: sourceURL, portrait: true)

        let outputURL = try await ClipWatermarkExporter().prepareShareableClipURL(
            sourceClipURL: sourceURL,
            options: .init(dateString: "2026-10-10 12:00")
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: outputURL))
        generator.appliesPreferredTrackTransform = true
        let frame = try generator.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: nil)
        XCTAssertLessThan(frame.width, frame.height, "The exported frame should remain portrait")
        let pixels = Self.pixelSummary(in: frame)
        XCTAssertGreaterThan(pixels.darkBottom, 500)
        XCTAssertLessThan(pixels.darkTop, 500)
        XCTAssertGreaterThan(pixels.brightCenter, 5_000)
        XCTAssertLessThan(pixels.darkCenter, 500)
    }

    private static func makeWhiteVideo(at url: URL, portrait: Bool = false) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let width = 320
        let height = 240
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        input.expectsMediaDataInRealTime = false
        if portrait {
            input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: CGFloat(height), ty: 0)
        }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(input) else {
            throw ClipWatermarkExportError.exportFailed("Δεν μπορεί να δημιουργηθεί test video track.")
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? ClipWatermarkExportError.exportFailed("Δεν ξεκίνησε το test video writer.")
        }
        writer.startSession(atSourceTime: .zero)

        for frameIndex in 0..<30 {
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            guard let pool = adaptor.pixelBufferPool else {
                throw ClipWatermarkExportError.exportFailed("Δεν δημιουργήθηκε pixel buffer pool.")
            }
            var buffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
            guard status == kCVReturnSuccess, let buffer else {
                throw ClipWatermarkExportError.exportFailed("Δεν δημιουργήθηκε test video frame.")
            }
            CVPixelBufferLockBaseAddress(buffer, [])
            guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
                CVPixelBufferUnlockBaseAddress(buffer, [])
                throw ClipWatermarkExportError.exportFailed("Δεν είναι προσβάσιμα τα pixels του test frame.")
            }
            baseAddress.initializeMemory(
                as: UInt8.self,
                repeating: 0xFF,
                count: CVPixelBufferGetBytesPerRow(buffer) * height
            )
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frameIndex), timescale: 30)) else {
                throw writer.error ?? ClipWatermarkExportError.exportFailed("Δεν γράφτηκε test video frame.")
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? ClipWatermarkExportError.exportFailed("Δεν ολοκληρώθηκε το test video.")
        }
    }

    private static func pixelSummary(in image: CGImage) -> (darkBottom: Int, darkTop: Int, brightCenter: Int, darkCenter: Int) {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return (0, 0, 0, 0) }
        var darkBottom = 0
        var darkTop = 0
        var brightCenter = 0
        var darkCenter = 0
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let luminance = (Int(pixels[index]) + Int(pixels[index + 1]) + Int(pixels[index + 2])) / 3
                if y < height / 4 {
                    if luminance < 200 { darkBottom += 1 }
                } else if y >= height * 3 / 4 {
                    if luminance < 200 { darkTop += 1 }
                } else if luminance >= 200 {
                    brightCenter += 1
                } else {
                    darkCenter += 1
                }
            }
        }
        return (darkBottom, darkTop, brightCenter, darkCenter)
    }
    #endif
}
