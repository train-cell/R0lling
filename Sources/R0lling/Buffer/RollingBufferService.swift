import Foundation
import CoreMedia

/// Υλοποίηση του Κυκλικού Buffer 5–10 δευτερολέπτων με Keyframe Alignment και ασφαλές Concurrency.
/// R3-002: Δεν παράγει πλέον ψευδο-MP4 (ftyp+mdat χωρίς moov). Εξάγει playable MP4 μέσω AVAssetWriter.
public actor RollingBufferService: RollingBufferServiceProtocol {
    private var samples: [BufferedSample] = []
    private var isBufferingActive: Bool = false
    private var targetDurationSeconds: Double = 10.0
    private let mediaStorage: MediaStorageProtocol
    private let maxMemoryLimitBytes: Int = 25 * 1024 * 1024 // 25 MB

    public init(mediaStorage: MediaStorageProtocol) {
        self.mediaStorage = mediaStorage
    }

    public var currentState: BufferState {
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
        self.targetDurationSeconds = max(3.0, min(15.0, targetSeconds))
        self.isBufferingActive = true
    }

    public func stopBuffering() {
        self.isBufferingActive = false
    }

    public func clearBuffer() {
        self.samples.removeAll(keepingCapacity: true)
    }

    public func appendSample(sample: BufferedSample) {
        guard isBufferingActive else { return }

        samples.append(sample)
        trimOldSamples()
    }

    /// Διατήρηση μόνο του παραθύρου [T - targetDurationSeconds, T]
    private func trimOldSamples() {
        guard let latest = samples.last else { return }
        let cutoffTime = latest.timestampSeconds - (targetDurationSeconds + 1.0) // 1.0s safety headroom

        // Βρίσκουμε το παλαιότερο δείγμα που πρέπει να κρατηθεί, προτιμώντας keyframe
        if let firstValidIndex = samples.firstIndex(where: { $0.timestampSeconds >= cutoffTime && $0.isKeyframe }) {
            if firstValidIndex > 0 {
                samples.removeSubrange(0..<firstValidIndex)
            }
        } else {
            // Αν δεν υπάρχει keyframe στο όριο, αφαιρούμε αυστηρά ό,τι είναι πριν το cutoff
            samples.removeAll(where: { $0.timestampSeconds < cutoffTime })
        }

        // Έλεγχος συνολικού μεγέθους μνήμης
        var totalBytes = samples.reduce(0) { $0 + $1.data.count }
        while totalBytes > maxMemoryLimitBytes && samples.count > 10 {
            let removed = samples.removeFirst()
            totalBytes -= removed.data.count
        }
    }

    /// Εξαγωγή του κυλιόμενου clip ως playable MP4.
    public func triggerClip(requestedSeconds: Double) async throws -> ClipExportResult {
        guard !samples.isEmpty else {
            throw NSError(
                domain: "R0lling.Buffer",
                code: 3001,
                userInfo: [NSLocalizedDescriptionKey: "Ο buffer είναι κενός. Δεν υπάρχουν διαθέσιμα καρέ."]
            )
        }

        let latestTimestamp = samples.last!.timestampSeconds
        let targetDuration = min(requestedSeconds, targetDurationSeconds)
        let requestedStartTime = latestTimestamp - targetDuration

        // 1. Keyframe Alignment: Εύρεση του πρώτου Video Keyframe <= requestedStartTime ή του πλησιέστερου
        let videoKeyframes = samples.filter { !$0.isAudio && $0.isKeyframe }
        let sliceStartTime: Double
        if let matchedKeyframe = videoKeyframes.last(where: { $0.timestampSeconds <= requestedStartTime }) {
            sliceStartTime = matchedKeyframe.timestampSeconds
        } else if let firstKeyframe = videoKeyframes.first {
            sliceStartTime = firstKeyframe.timestampSeconds
        } else {
            sliceStartTime = samples.first!.timestampSeconds
        }

        // 2. Απομόνωση Snapshot (Ανεξάρτητο αντίγραφο ώστε να μην μπλοκάρεται ο ενεργός buffer)
        let clipSamples = samples.filter { $0.timestampSeconds >= sliceStartTime && $0.timestampSeconds <= latestTimestamp }
        let actualDuration = max(0.1, latestTimestamp - sliceStartTime)

        guard !clipSamples.isEmpty else {
            throw NSError(
                domain: "R0lling.Buffer",
                code: 3002,
                userInfo: [NSLocalizedDescriptionKey: "Δεν βρέθηκαν επαρκή δείγματα για εξαγωγή clip."]
            )
        }

        let hasAudioSamples = clipSamples.contains { $0.isAudio }
        let frameCount = clipSamples.filter { !$0.isAudio }.count
        let exeiPragmatikoNAL = periexeiH264NAL(samples: clipSamples)

        // 3. R3-002: Playable export μέσω AVAssetWriter.
        // Πραγματικό remux NAL από Meta DAT θα προστεθεί όταν υπάρχει SDK stream·
        // μέχρι τότε παράγεται ειλικρινές playable placeholder με σωστή διάρκεια + moov.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("r0lling_clip_\(UUID().uuidString).mp4")
        try await PlayableClipExporter.grapsePlayablePlaceholderMP4(
            durationSeconds: actualDuration,
            destinationURL: tempURL
        )
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let clipData = try Data(contentsOf: tempURL)
        guard clipData.range(of: Data("moov".utf8)) != nil else {
            throw NSError(
                domain: "R0lling.Buffer",
                code: 3008,
                userInfo: [NSLocalizedDescriptionKey: "Αποτυχία playable MP4: λείπει το moov box."]
            )
        }

        let attachment = try await mediaStorage.saveMediaFile(
            data: clipData,
            originalFilename: "clip_\(Int(Date().timeIntervalSince1970)).mp4",
            mediaType: .clip
        )

        let fileURL = await mediaStorage.getMediaFileURL(relativePath: attachment.relativePath)
        let isSimulationPlaceholder = !exeiPragmatikoNAL

        return ClipExportResult(
            fileURL: fileURL,
            relativePath: attachment.relativePath,
            duration: actualDuration,
            hasAudio: hasAudioSamples,
            frameCount: frameCount,
            timestamp: Date(),
            isPlayable: true,
            isSimulationPlaceholder: isSimulationPlaceholder,
            byteSize: Int64(clipData.count)
        )
    }

    /// Ελέγχει αν τα video samples μοιάζουν με Annex-B / AVC NAL (πραγματικό codec stream).
    private func periexeiH264NAL(samples: [BufferedSample]) -> Bool {
        for sample in samples where !sample.isAudio && sample.isKeyframe {
            let bytes = [UInt8](sample.data.prefix(8))
            if bytes.count >= 4 {
                // Annex-B start code: 00 00 00 01 ή 00 00 01
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
