import Foundation
import AVFoundation
import CoreVideo

/// Παράγει MP4 μέσω AVAssetWriter και ελέγχει το αποτέλεσμα με AVFoundation.
/// Χρησιμοποιείται όταν τα buffered samples δεν είναι έγκυρα H.264 NAL (simulation / μη-DAT stream).
///
/// **Stage-4 contract:** `grapsePlayablePlaceholderMP4` παραμένει η σταθερή playable διαδρομή.
/// Το πραγματικό DAT remux ζει στο `H264AnnexBRemuxer` και καλείται από `RollingBufferService`.
public enum PlayableClipExporter {
    /// Ελάχιστη διάρκεια εξαγωγής σε δευτερόλεπτα.
    public static let elaxistiDiarkeiaDeuterolepta: Double = 0.1
    /// Frames ανά δευτερόλεπτο για placeholder clip.
    public static let plaisiaAnaDeuterolepto: Int = 10
    /// Πλάτος placeholder καρέ.
    public static let platosEikonas: Int = 320
    /// Ύψος placeholder καρέ.
    public static let ypsosEikonas: Int = 240
    /// Upper bound for a generated placeholder, preventing accidental unbounded frame allocation.
    public static let maximumPlaceholderDurationSeconds: Double = 300

    /// Συντονιστής A05: δοκιμάζει remux· σε αποτυχία → Stage-4 placeholder με AVFoundation validation.
    /// - Returns: `(isSimulationPlaceholder: Bool)` — `false` μόνο μετά επιτυχές remux.
    public static func grapsePlayableClipApoSamples(
        samples: [BufferedSample],
        durationSeconds: Double,
        destinationURL: URL,
        preferRemuxWhenNALPresent: Bool = true
    ) async throws -> Bool {
        try Task.checkCancellation()
        let exeiNAL = samples.contains { sample in
            guard !sample.isAudio else { return false }
            let bytes = [UInt8](sample.data.prefix(4))
            return bytes.count >= 4
                && bytes[0] == 0x00 && bytes[1] == 0x00
                && ((bytes[2] == 0x00 && bytes[3] == 0x01) || bytes[2] == 0x01)
        }

        if preferRemuxWhenNALPresent && exeiNAL {
            do {
                try await H264AnnexBRemuxer.eksagogiPlayableMP4(
                    samples: samples,
                    destinationURL: destinationURL
                )
                return false
            } catch {
                // Cancellation is a control signal; do not turn it into a generated clip.
                try Task.checkCancellation()
                // Honest fallback — όχι silent fake remux success.
                try await grapsePlayablePlaceholderMP4(
                    durationSeconds: durationSeconds,
                    destinationURL: destinationURL
                )
                return true
            }
        }

        try await grapsePlayablePlaceholderMP4(
            durationSeconds: durationSeconds,
            destinationURL: destinationURL
        )
        return true
    }

    /// Γράφει playable H.264 MP4 με σταθερό χρώμα καρέ για την αιτούμενη διάρκεια.
    /// - Parameters:
    ///   - durationSeconds: Διάρκεια clip (θα περιοριστεί σε ≥ 0.1s).
    ///   - destinationURL: Προορισμός αρχείου `.mp4` (πρέπει να μην υπάρχει).
    public static func grapsePlayablePlaceholderMP4(
        durationSeconds: Double,
        destinationURL: URL
    ) async throws {
        try Task.checkCancellation()
        guard durationSeconds.isFinite, durationSeconds <= maximumPlaceholderDurationSeconds else {
            throw NSError(domain: "R0lling.Buffer", code: 3009, userInfo: [
                NSLocalizedDescriptionKey: "Η διάρκεια του placeholder clip πρέπει να είναι πεπερασμένη και έως 5 λεπτά."
            ])
        }
        let diarkeia = max(elaxistiDiarkeiaDeuterolepta, durationSeconds)
        let synoloPlaision = max(1, Int(ceil(diarkeia * Double(plaisiaAnaDeuterolepto))))

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        var outputVerified = false
        defer {
            if !outputVerified {
                try? FileManager.default.removeItem(at: destinationURL)
            }
        }

        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)
        defer {
            if writer.status != .completed { writer.cancelWriting() }
        }
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: platosEikonas,
            AVVideoHeightKey: ypsosEikonas
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let pixelAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: platosEikonas,
            kCVPixelBufferHeightKey as String: ypsosEikonas
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: pixelAttributes
        )

        guard writer.canAdd(input) else {
            throw NSError(
                domain: "R0lling.Buffer",
                code: 3003,
                userInfo: [NSLocalizedDescriptionKey: "Αδυναμία προσθήκης video input στο AVAssetWriter."]
            )
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? NSError(
                domain: "R0lling.Buffer",
                code: 3004,
                userInfo: [NSLocalizedDescriptionKey: "Αποτυχία εκκίνησης AVAssetWriter."]
            )
        }
        writer.startSession(atSourceTime: .zero)

        let timescale: CMTimeScale = 600
        for index in 0..<synoloPlaision {
            try Task.checkCancellation()
            let readinessDeadline = ProcessInfo.processInfo.systemUptime + 10
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing,
                      ProcessInfo.processInfo.systemUptime < readinessDeadline else {
                    writer.cancelWriting()
                    throw writer.error ?? NSError(domain: "R0lling.Buffer", code: 3090, userInfo: [
                        NSLocalizedDescriptionKey: "Το video writer απέτυχε ή υπερέβη το όριο αναμονής."
                    ])
                }
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            let presentation = CMTime(value: CMTimeValue(index * (Int(timescale) / plaisiaAnaDeuterolepto)), timescale: timescale)
            guard let buffer = dimiourgiaPixelBuffer(red: 20, green: 24, blue: 48) else {
                throw NSError(
                    domain: "R0lling.Buffer",
                    code: 3005,
                    userInfo: [NSLocalizedDescriptionKey: "Αποτυχία δημιουργίας pixel buffer."]
                )
            }
            if !adaptor.append(buffer, withPresentationTime: presentation) {
                throw writer.error ?? NSError(
                    domain: "R0lling.Buffer",
                    code: 3006,
                    userInfo: [NSLocalizedDescriptionKey: "Αποτυχία εγγραφής frame στο MP4."]
                )
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        try Task.checkCancellation()

        guard writer.status == .completed else {
            throw writer.error ?? NSError(
                domain: "R0lling.Buffer",
                code: 3007,
                userInfo: [NSLocalizedDescriptionKey: "Το AVAssetWriter δεν ολοκλήρωσε το playable MP4."]
            )
        }

        let asset = AVURLAsset(url: destinationURL)
        guard try await asset.load(.isPlayable) else {
            throw NSError(
                domain: "R0lling.Buffer",
                code: 3008,
                userInfo: [NSLocalizedDescriptionKey: "Το AVFoundation δεν αναγνωρίζει το εξαγόμενο αρχείο ως playable MP4."]
            )
        }
        outputVerified = true
    }

    /// Δημιουργεί ARGB pixel buffer με σταθερό χρώμα (Discord-dark placeholder).
    private static func dimiourgiaPixelBuffer(red: UInt8, green: UInt8, blue: UInt8) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            platosEikonas,
            ypsosEikonas,
            kCVPixelFormatType_32ARGB,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let width = CVPixelBufferGetWidth(buffer)

        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let offset = x * 4
                row[offset] = 255
                row[offset + 1] = red
                row[offset + 2] = green
                row[offset + 3] = blue
            }
        }
        return buffer
    }
}
