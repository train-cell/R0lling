import Foundation
import ImageIO
import CoreMedia

/// Υλοποίηση του Κυκλικού Buffer 5–10 δευτερολέπτων με Keyframe Alignment και ασφαλές Concurrency.
/// R3-002: Το export παράγει placeholder/remux MP4 και αποδέχεται επιτυχία μόνο μετά από AVFoundation validation.
/// A05: Remux πραγματικού Annex-B όταν υπάρχουν SPS/PPS· αλλιώς Stage-4 playable placeholder.
/// A06: Warm-up (μικρότερη πραγματική διάρκεια) · disconnect = νέα generation χωρίς ένωση κενών.
/// A07: pause/resume χωρίς ψευδή continuous background.
public actor RollingBufferService: RollingBufferServiceProtocol {
    private var samples: [BufferedSample] = []
    private var isBufferingActive: Bool = false
    private var isPaused: Bool = false
    private var isExporting: Bool = false
    private var targetDurationSeconds: Double = 10.0
    private var currentStreamGeneration: UInt64 = 0
    private let mediaStorage: MediaStorageProtocol
    private let maxMemoryLimitBytes: Int = 25 * 1024 * 1024 // 25 MB

    public init(mediaStorage: MediaStorageProtocol) {
        self.mediaStorage = mediaStorage
    }

    public var streamGeneration: UInt64 {
        currentStreamGeneration
    }

    var targetWindowSeconds: Double {
        targetDurationSeconds
    }

    public var currentState: BufferState {
        if isExporting {
            return .exporting(progress: 0.5)
        }
        if isPaused {
            return .paused
        }
        if !isBufferingActive {
            return .idle
        }
        return .active(durationAvailable: availableDuration)
    }

    public var availableDuration: Double {
        guard let first = samples.first, let last = samples.last, last.timestampSeconds >= first.timestampSeconds else {
            return 0.0
        }
        return last.timestampSeconds - first.timestampSeconds
    }

    public func startBuffering(targetSeconds: Double) {
        let validTarget = targetSeconds.isFinite ? targetSeconds : 10.0
        self.targetDurationSeconds = max(3.0, min(15.0, validTarget))
        self.isBufferingActive = true
        self.isPaused = false
        // Νέα ροή = νέα generation (A06: μην ενώσεις κενά με προηγούμενο session).
        self.currentStreamGeneration &+= 1
        self.samples.removeAll(keepingCapacity: true)
    }

    public func stopBuffering() {
        self.isBufferingActive = false
        self.isPaused = false
    }

    public func pauseBuffering() {
        guard isBufferingActive else { return }
        self.isPaused = true
    }

    public func resumeBuffering() {
        guard isBufferingActive else { return }
        self.isPaused = false
    }

    public func markStreamInterrupted(reason: String) {
        _ = reason
        self.isBufferingActive = false
        self.isPaused = false
        self.samples.removeAll(keepingCapacity: true)
        self.currentStreamGeneration &+= 1
    }

    public func clearBuffer() {
        self.samples.removeAll(keepingCapacity: true)
    }

    /// A11: ομοιόμορφα κατανεμημένα video keyframes από το rolling window (JPEG/sim data).
    /// Κενό αν δεν υπάρχει buffer — το AppState πέφτει σε `capturePhoto`.
    public func snapshotVisionKeyframes(
        maxCount: Int = OpenAIChatRequestBuilder.maxVisionFrames,
        windowSeconds: Double = 5.0
    ) -> [Data] {
        let limit = max(1, min(maxCount, OpenAIChatRequestBuilder.maxVisionFrames))
        guard let latest = samples.last else { return [] }

        let cutoff = latest.timestampSeconds - max(1.0, windowSeconds)
        let videoKeyframes = samples.filter {
            !$0.isAudio && $0.isKeyframe && $0.timestampSeconds >= cutoff && CGImageSourceCreateWithData($0.data as CFData, nil) != nil
        }
        guard !videoKeyframes.isEmpty else { return [] }

        if limit == 1 { return [videoKeyframes.last!.data] }
        if videoKeyframes.count <= limit {
            return videoKeyframes.map(\.data)
        }

        var selected: [Data] = []
        for i in 0..<limit {
            let idx = Int(Double(i) * Double(videoKeyframes.count - 1) / Double(limit - 1))
            selected.append(videoKeyframes[idx].data)
        }
        return selected
    }

    public func appendSample(sample: BufferedSample) {
        guard isBufferingActive, !isPaused,
              sample.timestampSeconds.isFinite,
              !sample.data.isEmpty,
              sample.data.count <= maxMemoryLimitBytes else { return }
        // Αγνόησε samples από παλιό stream generation (A06 gap safety).
        let gen = sample.streamGeneration == 0 ? currentStreamGeneration : sample.streamGeneration
        guard gen == currentStreamGeneration else { return }
        // Timestamps drive trimming, keyframe selection, and MP4 presentation order.
        // Drop late packets instead of corrupting the insertion-ordered rolling window.
        guard samples.last.map({ sample.timestampSeconds >= $0.timestampSeconds }) ?? true else { return }

        let tagged = BufferedSample(
            timestampSeconds: sample.timestampSeconds,
            isKeyframe: sample.isKeyframe,
            isAudio: sample.isAudio,
            data: sample.data,
            streamGeneration: currentStreamGeneration
        )
        samples.append(tagged)
        trimOldSamples()
    }

    /// Διατήρηση μόνο του παραθύρου [T - targetDurationSeconds, T]
    private func trimOldSamples() {
        guard let latest = samples.last else { return }
        let cutoffTime = latest.timestampSeconds - (targetDurationSeconds + 1.0) // 1.0s safety headroom

        if let firstValidIndex = samples.firstIndex(where: { $0.timestampSeconds >= cutoffTime && $0.isKeyframe }) {
            if firstValidIndex > 0 {
                samples.removeSubrange(0..<firstValidIndex)
            }
        } else {
            samples.removeAll(where: { $0.timestampSeconds < cutoffTime })
        }

        var totalBytes = samples.reduce(0) { $0 + $1.data.count }
        while totalBytes > maxMemoryLimitBytes && !samples.isEmpty {
            let removed = samples.removeFirst()
            totalBytes -= removed.data.count
        }
    }

    /// Εξαγωγή του κυλιόμενου clip ως playable MP4 (A05 + A06 warm-up).
    public func triggerClip(requestedSeconds: Double) async throws -> ClipExportResult {
        try Task.checkCancellation()
        guard !isExporting else {
            throw NSError(
                domain: "R0lling.Buffer",
                code: 3012,
                userInfo: [NSLocalizedDescriptionKey: "Εξαγωγή clip ήδη σε εξέλιξη — δοκίμασε ξανά σε λίγο."]
            )
        }
        guard !samples.isEmpty else {
            throw NSError(
                domain: "R0lling.Buffer",
                code: 3001,
                userInfo: [NSLocalizedDescriptionKey: "Ο buffer είναι κενός. Δεν υπάρχουν διαθέσιμα καρέ."]
            )
        }

        isExporting = true
        defer { isExporting = false }

        let latestTimestamp = samples.last!.timestampSeconds
        let validRequest = requestedSeconds.isFinite ? max(0.1, requestedSeconds) : targetDurationSeconds
        let targetDuration = min(validRequest, targetDurationSeconds)
        let requestedStartTime = latestTimestamp - targetDuration
        let exportGeneration = currentStreamGeneration

        // 1. Keyframe Alignment
        let videoKeyframes = samples.filter { !$0.isAudio && $0.isKeyframe }
        let sliceStartTime: Double
        if let matchedKeyframe = videoKeyframes.last(where: { $0.timestampSeconds <= requestedStartTime }) {
            sliceStartTime = matchedKeyframe.timestampSeconds
        } else if let firstKeyframe = videoKeyframes.first {
            // A06 warm-up: μικρότερη πραγματική διάρκεια από το πρώτο keyframe
            sliceStartTime = firstKeyframe.timestampSeconds
        } else {
            sliceStartTime = samples.first!.timestampSeconds
        }

        // 2. Snapshot — ανεξάρτητο αντίγραφο ώστε να μην μπλοκάρεται ο ενεργός buffer
        let clipSamples = samples.filter { $0.timestampSeconds >= sliceStartTime && $0.timestampSeconds <= latestTimestamp }
        let measuredDuration = latestTimestamp - sliceStartTime
        guard measuredDuration.isFinite else {
            throw NSError(domain: "R0lling.Buffer", code: 3013, userInfo: [
                NSLocalizedDescriptionKey: "Μη έγκυρη διάρκεια buffer για εξαγωγή clip."
            ])
        }
        let actualDuration = max(0.1, measuredDuration)

        guard !clipSamples.isEmpty else {
            throw NSError(
                domain: "R0lling.Buffer",
                code: 3002,
                userInfo: [NSLocalizedDescriptionKey: "Δεν βρέθηκαν επαρκή δείγματα για εξαγωγή clip."]
            )
        }

        let frameCount = clipSamples.filter { !$0.isAudio }.count
        let exeiPragmatikoNAL = periexeiH264NAL(samples: clipSamples)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("r0lling_clip_\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        var isSimulationPlaceholder = true

        if exeiPragmatikoNAL {
            // A05: απόπειρα πραγματικού remux — σε αποτυχία SPS/PPS πέφτουμε στο Stage-4 placeholder.
            do {
                try await H264AnnexBRemuxer.eksagogiPlayableMP4(
                    samples: clipSamples,
                    destinationURL: tempURL
                )
                isSimulationPlaceholder = false
            } catch {
                // Preserve task cancellation instead of silently generating a replacement clip.
                try Task.checkCancellation()
                try await PlayableClipExporter.grapsePlayablePlaceholderMP4(
                    durationSeconds: actualDuration,
                    destinationURL: tempURL
                )
                isSimulationPlaceholder = true
            }
        } else {
            // R3-002 Stage-4 path: placeholder με σωστή διάρκεια, επαληθευμένο από AVFoundation.
            try await PlayableClipExporter.grapsePlayablePlaceholderMP4(
                durationSeconds: actualDuration,
                destinationURL: tempURL
            )
            isSimulationPlaceholder = true
        }

        try Task.checkCancellation()
        try Task.checkCancellation()
        let attachment = try await mediaStorage.saveMediaFile(
            from: tempURL,
            originalFilename: "clip_\(Int(Date().timeIntervalSince1970)).mp4",
            mediaType: .clip
        )

        let fileURL = try mediaStorage.getMediaFileURL(relativePath: attachment.relativePath)

        return ClipExportResult(
            fileURL: fileURL,
            relativePath: attachment.relativePath,
            duration: actualDuration,
            // Both current writer paths emit video-only MP4s; source audio samples
            // are not muxed yet, so don't report a track that isn't in the file.
            hasAudio: false,
            frameCount: frameCount,
            timestamp: Date(),
            isPlayable: true,
            isSimulationPlaceholder: isSimulationPlaceholder,
            byteSize: attachment.byteSize,
            streamGeneration: exportGeneration
        )
    }

    /// Ελέγχει αν τα video samples μοιάζουν με Annex-B / AVC NAL (πραγματικό codec stream).
    private func periexeiH264NAL(samples: [BufferedSample]) -> Bool {
        for sample in samples where !sample.isAudio && sample.isKeyframe {
            let bytes = [UInt8](sample.data.prefix(8))
            if bytes.count >= 4 {
                if bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0x00 && bytes[3] == 0x01 {
                    return true
                }
                if bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0x01 {
                    return true
                }
            }
        }
        return false
    }
}
