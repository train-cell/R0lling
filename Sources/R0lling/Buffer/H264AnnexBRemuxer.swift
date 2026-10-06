import Foundation
import AVFoundation
import CoreMedia

/// Remux / passthrough pipeline για πραγματικά Annex-B H.264 samples από Meta DAT stream.
///
/// **Honesty:** Χωρίς SPS/PPS πετάει σαφές error — δεν παράγει ψευδο-MP4.
/// Το `RollingBufferService` πέφτει τότε στο Stage-4 playable placeholder.
public enum H264AnnexBRemuxer {
    /// Error domain για remux failures.
    public static let errorDomain = "R0lling.Buffer.Remux"
    /// Λείπουν SPS/PPS από το Annex-B stream.
    public static let kodikosElleipsisSPSPPS: Int = 3010
    /// Μη υποστηριζόμενο remux σε αυτό το build.
    public static let kodikosRemuxMiDiathesimo: Int = 3009
    /// Αποτυχία AVAssetWriter / sample packing.
    public static let kodikosWriterApotyxia: Int = 3011
    /// Ελάχιστο πλήθος video samples για απόπειρα remux.
    public static let elaxistaVideoSamples: Int = 2

    /// Προσπαθεί remux των buffered Annex-B samples σε playable MP4.
    public static func eksagogiPlayableMP4(
        samples: [BufferedSample],
        destinationURL: URL
    ) async throws {
        let videoSamples = samples.filter { !$0.isAudio }
        guard videoSamples.count >= elaxistaVideoSamples else {
            throw NSError(
                domain: errorDomain,
                code: kodikosElleipsisSPSPPS,
                userInfo: [NSLocalizedDescriptionKey:
                    "Ανεπαρκή video samples για H.264 remux (\(videoSamples.count)). Απαιτείται Meta DAT elementary stream."]
            )
        }

        guard let sps = vresNAL(samples: videoSamples, nalType: 7),
              let pps = vresNAL(samples: videoSamples, nalType: 8) else {
            throw NSError(
                domain: errorDomain,
                code: kodikosElleipsisSPSPPS,
                userInfo: [NSLocalizedDescriptionKey:
                    "Incomplete H.264 Annex-B: λείπουν SPS (type 7) ή PPS (type 8). " +
                    "Σύνδεσε MetaWearablesDAT + Gen 2 — βλ. docs/LANE_CLIP_META.md."]
            )
        }

        #if canImport(AVFoundation)
        try await grapsePassthroughMP4(
            videoSamples: videoSamples,
            sps: sps,
            pps: pps,
            destinationURL: destinationURL
        )
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosRemuxMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey:
                "H.264 remux μη διαθέσιμο: AVFoundation δεν υπάρχει σε αυτό το build."]
        )
        #endif
    }

    /// Επιστρέφει το πρώτο NAL unit του δοσμένου τύπου (χωρίς start code).
    public static func vresNAL(samples: [BufferedSample], nalType: UInt8) -> Data? {
        for sample in samples {
            for nal in spaseAnnexB(sample.data) {
                guard let first = nal.first else { continue }
                if (first & 0x1F) == nalType {
                    return nal
                }
            }
        }
        return nil
    }

    /// Χωρίζει Annex-B bitstream σε NAL units (χωρίς start codes).
    public static func spaseAnnexB(_ data: Data) -> [Data] {
        let bytes = [UInt8](data)
        var nals: [Data] = []
        var i = 0
        var start: Int?

        func mikosStartCode(at index: Int) -> Int? {
            if index + 3 < bytes.count,
               bytes[index] == 0x00, bytes[index + 1] == 0x00,
               bytes[index + 2] == 0x00, bytes[index + 3] == 0x01 {
                return 4
            }
            if index + 2 < bytes.count,
               bytes[index] == 0x00, bytes[index + 1] == 0x00,
               bytes[index + 2] == 0x01 {
                return 3
            }
            return nil
        }

        while i < bytes.count {
            if let sc = mikosStartCode(at: i) {
                if let s = start {
                    nals.append(Data(bytes[s..<i]))
                }
                i += sc
                start = i
            } else {
                i += 1
            }
        }
        if let s = start, s < bytes.count {
            nals.append(Data(bytes[s..<bytes.count]))
        }
        return nals
    }

    #if canImport(AVFoundation)
    private static func grapsePassthroughMP4(
        videoSamples: [BufferedSample],
        sps: Data,
        pps: Data,
        destinationURL: URL
    ) async throws {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        var formatDesc: CMFormatDescription?
        let createStatus = ftiakseFormatDescription(sps: sps, pps: pps, out: &formatDesc)

        guard createStatus == noErr, let formatDescription = formatDesc else {
            throw NSError(
                domain: errorDomain,
                code: kodikosElleipsisSPSPPS,
                userInfo: [NSLocalizedDescriptionKey:
                    "Αποτυχία CMVideoFormatDescription από SPS/PPS (OSStatus \(createStatus))."]
            )
        }

        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: nil,
            sourceFormatHint: formatDescription
        )
        videoInput.expectsMediaDataInRealTime = false

        guard writer.canAdd(videoInput) else {
            throw NSError(
                domain: errorDomain,
                code: kodikosWriterApotyxia,
                userInfo: [NSLocalizedDescriptionKey: "AVAssetWriter δεν δέχεται H.264 passthrough input."]
            )
        }
        writer.add(videoInput)

        guard writer.startWriting() else {
            throw writer.error ?? NSError(
                domain: errorDomain,
                code: kodikosWriterApotyxia,
                userInfo: [NSLocalizedDescriptionKey: "Αποτυχία εκκίνησης AVAssetWriter για remux."]
            )
        }

        let baseTime = videoSamples.first!.timestampSeconds
        writer.startSession(atSourceTime: .zero)
        let timescale: CMTimeScale = 600

        for sample in videoSamples {
            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }

            let relative = max(0.0, sample.timestampSeconds - baseTime)
            let pts = CMTime(seconds: relative, preferredTimescale: timescale)
            let avccData = metatropiAnnexBSeAVCC(sample.data)
            let blockBuffer = try ftiakseCopiedBlockBuffer(avccData)
            var timing = CMSampleTimingInfo(
                duration: CMTime(value: 20, timescale: timescale),
                presentationTimeStamp: pts,
                decodeTimeStamp: .invalid
            )
            var sampleBuffer: CMSampleBuffer?
            var sampleSize = avccData.count
            let sbStatus = CMSampleBufferCreateReady(
                allocator: kCFAllocatorDefault,
                dataBuffer: blockBuffer,
                formatDescription: formatDescription,
                sampleCount: 1,
                sampleTimingEntryCount: 1,
                sampleTimingArray: &timing,
                sampleSizeEntryCount: 1,
                sampleSizeArray: &sampleSize,
                sampleBufferOut: &sampleBuffer
            )
            guard sbStatus == noErr, let sb = sampleBuffer else {
                throw NSError(
                    domain: errorDomain,
                    code: kodikosWriterApotyxia,
                    userInfo: [NSLocalizedDescriptionKey: "Αποτυχία CMSampleBufferCreateReady (OSStatus \(sbStatus))."]
                )
            }
            if !videoInput.append(sb) {
                throw writer.error ?? NSError(
                    domain: errorDomain,
                    code: kodikosWriterApotyxia,
                    userInfo: [NSLocalizedDescriptionKey: "Αποτυχία append H.264 sample στο remux writer."]
                )
            }
        }

        videoInput.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            throw writer.error ?? NSError(
                domain: errorDomain,
                code: kodikosWriterApotyxia,
                userInfo: [NSLocalizedDescriptionKey: "Το H.264 remux δεν ολοκληρώθηκε."]
            )
        }

        let data = try Data(contentsOf: destinationURL)
        guard data.range(of: Data("moov".utf8)) != nil else {
            throw NSError(
                domain: errorDomain,
                code: kodikosWriterApotyxia,
                userInfo: [NSLocalizedDescriptionKey: "Remux MP4 χωρίς moov — μη playable."]
            )
        }
    }

    private static func ftiakseFormatDescription(
        sps: Data,
        pps: Data,
        out: inout CMFormatDescription?
    ) -> OSStatus {
        return sps.withUnsafeBytes { spsRaw -> OSStatus in
            pps.withUnsafeBytes { ppsRaw -> OSStatus in
                guard let spsBase = spsRaw.bindMemory(to: UInt8.self).baseAddress,
                      let ppsBase = ppsRaw.bindMemory(to: UInt8.self).baseAddress else {
                    return -1
                }
                var pointers: [UnsafePointer<UInt8>] = [spsBase, ppsBase]
                var sizes: [Int] = [sps.count, pps.count]
                return pointers.withUnsafeBufferPointer { pointerBuffer in
                    sizes.withUnsafeBufferPointer { sizeBuffer in
                        guard let pointerBase = pointerBuffer.baseAddress,
                              let sizeBase = sizeBuffer.baseAddress else {
                            return OSStatus(-1)
                        }
                        return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: 2,
                            parameterSetPointers: pointerBase,
                            parameterSetSizes: sizeBase,
                            nalUnitHeaderLength: 4,
                            formatDescriptionOut: &out
                        )
                    }
                }
            }
        }
    }

    private static func metatropiAnnexBSeAVCC(_ data: Data) -> Data {
        let nals = spaseAnnexB(data)
        guard !nals.isEmpty else { return data }
        var out = Data()
        for nal in nals {
            var length = UInt32(nal.count).bigEndian
            withUnsafeBytes(of: &length) { out.append(contentsOf: $0) }
            out.append(nal)
        }
        return out
    }

    /// Δημιουργεί CMBlockBuffer με αντιγραφή bytes (ασφαλές lifetime).
    private static func ftiakseCopiedBlockBuffer(_ data: Data) throws -> CMBlockBuffer {
        var blockBuffer: CMBlockBuffer?
        let status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: data.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: data.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr, let buffer = blockBuffer else {
            throw NSError(
                domain: errorDomain,
                code: kodikosWriterApotyxia,
                userInfo: [NSLocalizedDescriptionKey: "Αποτυχία CMBlockBufferCreateWithMemoryBlock."]
            )
        }
        let replaceStatus = data.withUnsafeBytes { raw -> OSStatus in
            guard let base = raw.baseAddress else { return -1 }
            return CMBlockBufferReplaceDataBytes(
                with: base,
                blockBuffer: buffer,
                offsetIntoDestination: 0,
                dataLength: data.count
            )
        }
        guard replaceStatus == noErr else {
            throw NSError(
                domain: errorDomain,
                code: kodikosWriterApotyxia,
                userInfo: [NSLocalizedDescriptionKey: "Αποτυχία CMBlockBufferReplaceDataBytes."]
            )
        }
        return buffer
    }
    #endif
}
