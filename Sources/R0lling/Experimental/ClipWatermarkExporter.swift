import Foundation

#if canImport(AVFoundation) && canImport(QuartzCore) && canImport(CoreText)
@preconcurrency import AVFoundation
import CoreText
import QuartzCore
#endif

/// Εξαγωγέας clips για κοινή χρήση με ορατό timestamp, τοποθεσία και brand.
/// Παραμένει readiness-gated μέχρι να επαληθευτεί το rendered αποτέλεσμα σε Apple runtime.
public enum ClipWatermarkExportError: LocalizedError, Sendable {
    case unavailable
    case invalidSource
    case missingVideoTrack
    case invalidDuration
    case invalidVideoDimensions
    case exportSessionUnavailable
    case unsupportedOutputFormat
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Η εξαγωγή clip με watermark δεν είναι διαθέσιμη σε αυτή την πλατφόρμα. Το αρχικό αρχείο δεν τροποποιήθηκε."
        case .invalidSource:
            return "Το αρχικό clip δεν υπάρχει ή δεν είναι έγκυρο αρχείο."
        case .missingVideoTrack:
            return "Το αρχικό αρχείο δεν περιέχει video track."
        case .invalidDuration:
            return "Το αρχικό video δεν έχει έγκυρη διάρκεια."
        case .invalidVideoDimensions:
            return "Δεν ήταν δυνατός ο προσδιορισμός των διαστάσεων του video."
        case .exportSessionUnavailable:
            return "Το AVFoundation δεν μπόρεσε να δημιουργήσει export session."
        case .unsupportedOutputFormat:
            return "Το AVFoundation δεν υποστηρίζει συμβατή μορφή εξαγωγής για αυτό το clip."
        case let .exportFailed(reason):
            return "Η εξαγωγή clip με watermark απέτυχε: \(reason)"
        }
    }
}

public struct ClipWatermarkExporter: Sendable {
    public init() {}

    public struct WatermarkOptions: Sendable {
        public let dateString: String
        public let locationName: String?
        public let brandLabel: String

        public init(dateString: String = Date().formattedGreekHeader(), locationName: String? = nil) {
            self.dateString = dateString
            self.locationName = locationName
            self.brandLabel = "R0lling"
        }
    }

    /// Δημιουργεί στοιχεία υδατογραφήματος από την εγγραφή του ημερολογίου.
    public func generateWatermarkMetadata(for entry: JournalEntry) -> WatermarkOptions {
        WatermarkOptions(
            dateString: "\(entry.dateKey) \(entry.formattedTime)",
            locationName: entry.locationName
        )
    }

    /// Γράφει νέο playable video με Core Animation overlay και διατηρεί το αρχικό αρχείο.
    /// Η έξοδος είναι προσωρινό αρχείο που προορίζεται για share/export.
    public func prepareShareableClipURL(
        sourceClipURL: URL,
        options: WatermarkOptions
    ) async throws -> URL {
        try Task.checkCancellation()

        #if canImport(AVFoundation) && canImport(QuartzCore) && canImport(CoreText)
        guard sourceClipURL.isFileURL,
              let values = try? sourceClipURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true,
              (values.fileSize ?? 0) > 0 else {
            throw ClipWatermarkExportError.invalidSource
        }

        let asset = AVURLAsset(url: sourceClipURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw ClipWatermarkExportError.missingVideoTrack
        }
        let duration = try await asset.load(.duration)
        guard duration.isNumeric, duration.seconds.isFinite, duration.seconds > 0 else {
            throw ClipWatermarkExportError.invalidDuration
        }

        // AVMutableVideoComposition(propertiesOf:) reads both the duration and tracks synchronously.
        // Load them first so its generated instructions include the asset's complete time range.
        let videoComposition = AVMutableVideoComposition(propertiesOf: asset)
        let renderSize = videoComposition.renderSize
        guard renderSize.width.isFinite,
              renderSize.height.isFinite,
              renderSize.width > 0,
              renderSize.height > 0 else {
            throw ClipWatermarkExportError.invalidVideoDimensions
        }

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.masksToBounds = true

        let videoLayer = CALayer()
        videoLayer.frame = parentLayer.bounds
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(Self.makeWatermarkLayer(size: renderSize, options: options))
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw ClipWatermarkExportError.exportSessionUnavailable
        }
        exporter.videoComposition = videoComposition
        exporter.shouldOptimizeForNetworkUse = true

        let outputType: AVFileType
        let outputExtension: String
        if exporter.supportedFileTypes.contains(.mp4) {
            outputType = .mp4
            outputExtension = "mp4"
        } else if exporter.supportedFileTypes.contains(.mov) {
            outputType = .mov
            outputExtension = "mov"
        } else {
            throw ClipWatermarkExportError.unsupportedOutputFormat
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("r0lling_watermarked_\(UUID().uuidString).\(outputExtension)")
        exporter.outputURL = outputURL
        exporter.outputFileType = outputType

        do {
            try Task.checkCancellation()
            try await Self.export(exporter)
            try Task.checkCancellation()

            let exportedAsset = AVURLAsset(url: outputURL)
            guard try await exportedAsset.load(.isPlayable),
                  !(try await exportedAsset.loadTracks(withMediaType: .video)).isEmpty else {
                throw ClipWatermarkExportError.exportFailed("Το αποτέλεσμα δεν αναγνωρίζεται ως playable video.")
            }
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
        #else
        _ = sourceClipURL
        _ = options
        throw ClipWatermarkExportError.unavailable
        #endif
    }

    #if canImport(AVFoundation) && canImport(QuartzCore) && canImport(CoreText)
    private static func makeWatermarkLayer(size: CGSize, options: WatermarkOptions) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: size)
        layer.masksToBounds = true

        let verticalMargin = max(14, size.height * 0.045)
        let horizontalMargin = max(14, size.width * 0.045)
        // Margin plus banner stay inside the bottom quarter, so small clips keep their center visible.
        let bannerHeight = max(1, min(max(size.height * 0.14, 48), 84, size.height * 0.25 - verticalMargin))
        let banner = CALayer()
        banner.frame = CGRect(
            x: horizontalMargin,
            y: verticalMargin,
            width: max(1, size.width - horizontalMargin * 2),
            height: bannerHeight
        )
        banner.backgroundColor = CGColor(gray: 0.04, alpha: 0.70)
        banner.cornerRadius = bannerHeight / 2
        layer.addSublayer(banner)

        let inset = max(14, bannerHeight * 0.24)
        let contentFrame = banner.bounds.insetBy(dx: inset, dy: bannerHeight * 0.14)
        let brand = CATextLayer()
        brand.frame = CGRect(x: contentFrame.minX, y: contentFrame.midY, width: contentFrame.width, height: contentFrame.height / 2)
        brand.string = boundedText(options.brandLabel, maximumLength: 48)
        brand.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, max(11, bannerHeight * 0.22), nil)
        brand.fontSize = max(11, bannerHeight * 0.22)
        brand.foregroundColor = CGColor(gray: 1, alpha: 1)
        brand.alignmentMode = .left
        brand.truncationMode = .end
        brand.contentsScale = 2
        banner.addSublayer(brand)

        let detail = CATextLayer()
        detail.frame = CGRect(x: contentFrame.minX, y: contentFrame.minY, width: contentFrame.width, height: contentFrame.height / 2)
        let detailParts = [options.dateString, options.locationName]
            .compactMap { $0 }
            .map { boundedText($0, maximumLength: 96) }
            .filter { !$0.isEmpty }
        detail.string = detailParts.joined(separator: " · ")
        detail.font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, max(9, bannerHeight * 0.17), nil)
        detail.fontSize = max(9, bannerHeight * 0.17)
        detail.foregroundColor = CGColor(gray: 0.94, alpha: 1)
        detail.alignmentMode = .left
        detail.truncationMode = .end
        detail.contentsScale = 2
        banner.addSublayer(detail)
        return layer
    }

    private static func boundedText(_ value: String, maximumLength: Int) -> String {
        String(value.unicodeScalars.filter { !CharacterSet.newlines.contains($0) }.prefix(maximumLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func export(_ exporter: AVAssetExportSession) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                exporter.exportAsynchronously {
                    switch exporter.status {
                    case .completed:
                        continuation.resume()
                    case .failed:
                        continuation.resume(throwing: ClipWatermarkExportError.exportFailed(
                            exporter.error?.localizedDescription ?? "Άγνωστο σφάλμα AVFoundation."
                        ))
                    case .cancelled:
                        continuation.resume(throwing: CancellationError())
                    default:
                        continuation.resume(throwing: ClipWatermarkExportError.exportFailed(
                            "Άγνωστη κατάσταση AVFoundation export."
                        ))
                    }
                }
            }
        } onCancel: {
            exporter.cancelExport()
        }
    }
    #endif
}
