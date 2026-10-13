import Foundation
import Dispatch

#if os(iOS) && canImport(CoreMedia) && canImport(CoreVideo) && canImport(VideoToolbox)
@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
@preconcurrency import VideoToolbox

/// Encodes DAT raw camera frames into the H.264 Annex-B format expected by the
/// existing rolling buffer and remuxer.
///
/// The DAT medium stream is 504 × 896. A resolution change during a stream is
/// rejected because the current buffer contract cannot signal a new H.264 track
/// format. Input admission is bounded; overload terminates the stream instead of
/// silently dropping frames.
final class MetaDATH264Encoder: @unchecked Sendable {
    enum EncoderError: Error, LocalizedError, Sendable {
        case compressionSessionCreation(OSStatus)
        case compressionConfiguration(OSStatus)
        case compressionPreparation(OSStatus)
        case inputWithoutPixelBuffer
        case unexpectedFrameDimensions(width: Int, height: Int)
        case invalidPresentationTimestamp
        case tooManyFramesInFlight
        case frameDropped
        case encoding(OSStatus)
        case missingOutputData
        case invalidNALUnits
        case missingParameterSet(OSStatus)

        var errorDescription: String? {
            switch self {
            case .compressionSessionCreation(let status):
                return "Δεν δημιουργήθηκε ο H.264 encoder (\(status))."
            case .compressionConfiguration(let status):
                return "Δεν ρυθμίστηκε ο H.264 encoder (\(status))."
            case .compressionPreparation(let status):
                return "Δεν προετοιμάστηκε ο H.264 encoder (\(status))."
            case .inputWithoutPixelBuffer:
                return "Το DAT raw frame δεν περιέχει εικόνα για τον H.264 encoder."
            case .unexpectedFrameDimensions(let width, let height):
                return "Το DAT frame άλλαξε ανάλυση σε \(width)×\(height)· η τρέχουσα ροή διακόπηκε για να μη μπει ασύμβατο δείγμα στο clip."
            case .invalidPresentationTimestamp:
                return "Το DAT frame δεν έχει έγκυρο presentation timestamp."
            case .tooManyFramesInFlight:
                return "Ο H.264 encoder δεν προλαβαίνει τα DAT frames· η ροή διακόπηκε χωρίς σιωπηλή απώλεια καρέ."
            case .frameDropped:
                return "Το VideoToolbox απέρριψε DAT frame κατά την κωδικοποίηση."
            case .encoding(let status):
                return "Απέτυχε η H.264 κωδικοποίηση DAT frame (\(status))."
            case .missingOutputData:
                return "Ο H.264 encoder επέστρεψε frame χωρίς δεδομένα."
            case .invalidNALUnits:
                return "Ο H.264 encoder επέστρεψε μη έγκυρα NAL units."
            case .missingParameterSet(let status):
                return "Λείπουν H.264 parameter sets για Annex-B frame (\(status))."
            }
        }
    }

    private static let expectedWidth = 504
    private static let expectedHeight = 896
    private static let expectedFrameRate = 24
    private static let maxInFlightFrames = 2
    private static let annexBStartCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]

    private let workQueue = DispatchQueue(label: "R0lling.MetaDAT.H264Encoder", qos: .userInitiated)
    private let stateLock = NSLock()
    private let onEncodedSample: @Sendable (BufferedSample) -> Void
    private let onFailure: @Sendable (EncoderError) -> Void
    private var compressionSession: VTCompressionSession?
    private var inFlightFrames = 0
    private var submittedFrameCount = 0
    private var isClosed = false
    private var didReportFailure = false

    init(
        onEncodedSample: @escaping @Sendable (BufferedSample) -> Void,
        onFailure: @escaping @Sendable (EncoderError) -> Void
    ) throws {
        self.onEncodedSample = onEncodedSample
        self.onFailure = onFailure
        try createCompressionSession()
    }

    func encode(_ sampleBuffer: CMSampleBuffer) {
        switch reserveInputSlot() {
        case .ignored:
            return
        case .overflow:
            reportFailure(.tooManyFramesInFlight)
            return
        case .reserved:
            break
        }

        workQueue.async { [self] in
            guard let session = compressionSession else {
                releaseInputSlot()
                reportFailure(.compressionSessionCreation(kVTInvalidSessionErr))
                return
            }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                releaseInputSlot()
                reportFailure(.inputWithoutPixelBuffer)
                return
            }

            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            guard width == Self.expectedWidth, height == Self.expectedHeight else {
                releaseInputSlot()
                reportFailure(.unexpectedFrameDimensions(width: width, height: height))
                return
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            guard presentationTime.isValid, presentationTime.isNumeric else {
                releaseInputSlot()
                reportFailure(.invalidPresentationTimestamp)
                return
            }

            var infoFlags = VTEncodeInfoFlags()
            let duration = CMTime(value: 1, timescale: CMTimeScale(Self.expectedFrameRate))
            let frameProperties: CFDictionary? = submittedFrameCount == 0
                ? [kVTEncodeFrameOptionKey_ForceKeyFrame: kCFBooleanTrue] as CFDictionary
                : nil
            submittedFrameCount += 1
            let status = VTCompressionSessionEncodeFrame(
                session,
                imageBuffer: pixelBuffer,
                presentationTimeStamp: presentationTime,
                duration: duration,
                frameProperties: frameProperties,
                sourceFrameRefcon: nil,
                infoFlagsOut: &infoFlags
            )
            if status != noErr {
                releaseInputSlot()
                reportFailure(.encoding(status))
            }
        }
    }

    func finish() async {
        closeInput()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            workQueue.async { [self] in
                if let session = compressionSession {
                    _ = VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
                    VTCompressionSessionInvalidate(session)
                    compressionSession = nil
                }
                continuation.resume()
            }
        }
    }

    /// Keep the synchronous lock operation outside async contexts. The lock is
    /// released before `finish()` suspends while draining VideoToolbox callbacks.
    private func closeInput() {
        stateLock.lock()
        isClosed = true
        stateLock.unlock()
    }

    private enum InputReservation {
        case ignored
        case reserved
        case overflow
    }

    private func reserveInputSlot() -> InputReservation {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isClosed, !didReportFailure else { return .ignored }
        guard inFlightFrames < Self.maxInFlightFrames else { return .overflow }
        inFlightFrames += 1
        return .reserved
    }

    private func releaseInputSlot() {
        stateLock.lock()
        inFlightFrames = max(0, inFlightFrames - 1)
        stateLock.unlock()
    }

    private func reportFailure(_ error: EncoderError) {
        stateLock.lock()
        guard !didReportFailure else {
            stateLock.unlock()
            return
        }
        didReportFailure = true
        stateLock.unlock()
        onFailure(error)
    }

    private func createCompressionSession() throws {
        var createdSession: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(Self.expectedWidth),
            height: Int32(Self.expectedHeight),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: Self.outputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &createdSession
        )
        guard status == noErr, let createdSession else {
            throw EncoderError.compressionSessionCreation(status)
        }

        let settings: [(CFString, CFTypeRef)] = [
            (kVTCompressionPropertyKey_RealTime, kCFBooleanTrue),
            (kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse),
            (kVTCompressionPropertyKey_ExpectedFrameRate, NSNumber(value: Self.expectedFrameRate)),
            (kVTCompressionPropertyKey_MaxKeyFrameInterval, NSNumber(value: Self.expectedFrameRate))
        ]
        for (key, value) in settings {
            let settingStatus = VTSessionSetProperty(createdSession, key: key, value: value)
            guard settingStatus == noErr else {
                VTCompressionSessionInvalidate(createdSession)
                throw EncoderError.compressionConfiguration(settingStatus)
            }
        }

        let prepareStatus = VTCompressionSessionPrepareToEncodeFrames(createdSession)
        guard prepareStatus == noErr else {
            VTCompressionSessionInvalidate(createdSession)
            throw EncoderError.compressionPreparation(prepareStatus)
        }
        compressionSession = createdSession
    }

    private static let outputCallback: VTCompressionOutputCallback = {
        outputReference, _, status, flags, sampleBuffer in
        guard let outputReference else { return }
        let encoder = Unmanaged<MetaDATH264Encoder>.fromOpaque(outputReference).takeUnretainedValue()
        encoder.didEncode(status: status, flags: flags, sampleBuffer: sampleBuffer)
    }

    private func didEncode(status: OSStatus, flags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) {
        defer { releaseInputSlot() }
        guard status == noErr else {
            reportFailure(.encoding(status))
            return
        }
        guard !flags.contains(.frameDropped) else {
            reportFailure(.frameDropped)
            return
        }
        guard let sampleBuffer else {
            reportFailure(.missingOutputData)
            return
        }

        do {
            let annexB = try Self.makeAnnexB(sampleBuffer)
            onEncodedSample(BufferedSample(
                timestampSeconds: annexB.timestampSeconds,
                isKeyframe: annexB.isKeyframe,
                isAudio: false,
                data: annexB.data
            ))
        } catch let error as EncoderError {
            reportFailure(error)
        } catch {
            reportFailure(.invalidNALUnits)
        }
    }

    private static func makeAnnexB(_ sampleBuffer: CMSampleBuffer) throws -> (data: Data, timestampSeconds: Double, isKeyframe: Bool) {
        guard CMSampleBufferDataIsReady(sampleBuffer),
              let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            throw EncoderError.missingOutputData
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestamp = CMTimeGetSeconds(presentationTime)
        guard presentationTime.isValid, presentationTime.isNumeric, timestamp.isFinite else {
            throw EncoderError.invalidPresentationTimestamp
        }

        var parameterSetPointer: UnsafePointer<UInt8>?
        var parameterSetSize = 0
        var parameterSetCount = 0
        var nalLengthSize: Int32 = 0
        let parameterStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: 0,
            parameterSetPointerOut: &parameterSetPointer,
            parameterSetSizeOut: &parameterSetSize,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: &nalLengthSize
        )
        guard parameterStatus == noErr else {
            throw EncoderError.missingParameterSet(parameterStatus)
        }
        guard nalLengthSize > 0, nalLengthSize <= 4 else {
            throw EncoderError.invalidNALUnits
        }

        let byteCount = CMBlockBufferGetDataLength(blockBuffer)
        guard byteCount > 0 else { throw EncoderError.missingOutputData }
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let copyStatus = bytes.withUnsafeMutableBytes { destination in
            guard let baseAddress = destination.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
            return CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: byteCount,
                destination: baseAddress
            )
        }
        guard copyStatus == kCMBlockBufferNoErr else { throw EncoderError.encoding(copyStatus) }

        let keyframe = isKeyframe(sampleBuffer)
        var annexB = Data()
        if keyframe {
            let sps = try parameterSet(at: 0, formatDescription: formatDescription)
            let pps = try parameterSet(at: 1, formatDescription: formatDescription)
            annexB.append(contentsOf: annexBStartCode)
            annexB.append(sps)
            annexB.append(contentsOf: annexBStartCode)
            annexB.append(pps)
        }

        let lengthFieldBytes = Int(nalLengthSize)
        var offset = 0
        while offset < bytes.count {
            guard bytes.count - offset >= lengthFieldBytes else { throw EncoderError.invalidNALUnits }
            var nalLength = 0
            for index in 0..<lengthFieldBytes {
                nalLength = (nalLength << 8) | Int(bytes[offset + index])
            }
            offset += lengthFieldBytes
            guard nalLength > 0, nalLength <= bytes.count - offset else { throw EncoderError.invalidNALUnits }
            annexB.append(contentsOf: annexBStartCode)
            annexB.append(contentsOf: bytes[offset..<(offset + nalLength)])
            offset += nalLength
        }

        guard !annexB.isEmpty else { throw EncoderError.missingOutputData }
        return (annexB, timestamp, keyframe)
    }

    private static func parameterSet(at index: Int, formatDescription: CMFormatDescription) throws -> Data {
        var pointer: UnsafePointer<UInt8>?
        var size = 0
        var count = 0
        var nalLengthSize: Int32 = 0
        let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: index,
            parameterSetPointerOut: &pointer,
            parameterSetSizeOut: &size,
            parameterSetCountOut: &count,
            nalUnitHeaderLengthOut: &nalLengthSize
        )
        guard status == noErr, let pointer, size > 0 else {
            throw EncoderError.missingParameterSet(status)
        }
        return Data(bytes: pointer, count: size)
    }

    private static func isKeyframe(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[CFString: Any]],
              let notSync = attachments.first?[kCMSampleAttachmentKey_NotSync] as? Bool else {
            return true
        }
        return !notSync
    }
}
#endif
