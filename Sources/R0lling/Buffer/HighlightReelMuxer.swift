import Foundation
import AVFoundation

/// Μηχανή αυτόματης σύνθεσης ημερήσιου Highlight Reel (Montage όλων των clips της ημέρας).
/// G5-001: Απαγορεύεται byte-concatenation MP4 (μη playable) — μόνο AVMutableComposition + export.
public actor HighlightReelMuxer {
    private let mediaStorage: MediaStorageProtocol

    public init(mediaStorage: MediaStorageProtocol) {
        self.mediaStorage = mediaStorage
    }

    public struct ReelExportResult: Sendable {
        public let fileURL: URL
        public let relativePath: String
        public let totalClipsIncluded: Int
        public let totalDurationSeconds: Double
        public let isPlayable: Bool
    }

    /// Συνένωση όλων των clips της ημέρας σε ένα ενιαίο Highlight Reel μέσω AVFoundation composition.
    public func createDailyHighlightReel(for dateEntries: [JournalEntry]) async throws -> ReelExportResult {
        try Task.checkCancellation()
        var clipAttachments: [MediaAttachment] = []
        for entry in dateEntries {
            for att in entry.attachments where att.mediaType == .clip {
                clipAttachments.append(att)
            }
        }

        guard !clipAttachments.isEmpty else {
            throw NSError(
                domain: "R0lling.HighlightReel",
                code: 3101,
                userInfo: [NSLocalizedDescriptionKey: "Δεν βρέθηκαν clips για τη σημερινή ημέρα."]
            )
        }

        let composition = AVMutableComposition()
        guard let compositionVideo = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(
                domain: "R0lling.HighlightReel",
                code: 3103,
                userInfo: [NSLocalizedDescriptionKey: "Αδυναμία δημιουργίας video track για Highlight Reel."]
            )
        }
        let compositionAudio = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero
        var includedCount = 0

        for att in clipAttachments {
            try Task.checkCancellation()
            let fileURL = try mediaStorage.getMediaFileURL(relativePath: att.relativePath)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw NSError(domain: "R0lling.HighlightReel", code: 3109, userInfo: [
                    NSLocalizedDescriptionKey: "Λείπει clip από το ημερήσιο reel: \(att.relativePath)"
                ])
            }

            let asset = AVURLAsset(url: fileURL)
            let videoTracks = asset.tracks(withMediaType: .video)
            guard let sourceVideo = videoTracks.first else {
                throw NSError(domain: "R0lling.HighlightReel", code: 3110, userInfo: [
                    NSLocalizedDescriptionKey: "Το clip δεν περιέχει video track: \(att.relativePath)"
                ])
            }

            let timeRange = sourceVideo.timeRange
            guard timeRange.isValid && timeRange.duration.isNumeric && timeRange.duration.seconds > 0 else {
                throw NSError(domain: "R0lling.HighlightReel", code: 3111, userInfo: [
                    NSLocalizedDescriptionKey: "Μη έγκυρη διάρκεια clip: \(att.relativePath)"
                ])
            }

            try compositionVideo.insertTimeRange(timeRange, of: sourceVideo, at: cursor)

            if let sourceAudio = asset.tracks(withMediaType: .audio).first {
                let audioRange = CMTimeRangeGetIntersection(timeRange, sourceAudio.timeRange)
                guard audioRange.isValid && audioRange.duration.isNumeric && audioRange.duration.seconds > 0 else {
                    throw NSError(domain: "R0lling.HighlightReel", code: 3112, userInfo: [
                        NSLocalizedDescriptionKey: "Το audio track δεν επικαλύπτεται με το video clip: \(att.relativePath)"
                    ])
                }
                guard let compositionAudio else {
                    throw NSError(domain: "R0lling.HighlightReel", code: 3113, userInfo: [
                        NSLocalizedDescriptionKey: "Αδυναμία δημιουργίας audio track για το reel."
                    ])
                }
                let offset = CMTimeSubtract(audioRange.start, timeRange.start)
                try compositionAudio.insertTimeRange(
                    audioRange,
                    of: sourceAudio,
                    at: CMTimeAdd(cursor, offset)
                )
            }

            cursor = CMTimeAdd(cursor, timeRange.duration)
            includedCount += 1
        }

        guard includedCount > 0, cursor.seconds > 0 else {
            throw NSError(
                domain: "R0lling.HighlightReel",
                code: 3102,
                userInfo: [NSLocalizedDescriptionKey: "Αποτυχία ανάγνωσης/composition αρχείων clips."]
            )
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("r0lling_highlight_\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.removeItem(at: tempURL)
        }

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(
                domain: "R0lling.HighlightReel",
                code: 3104,
                userInfo: [NSLocalizedDescriptionKey: "AVAssetExportSession μη διαθέσιμο για Highlight Reel."]
            )
        }
        exporter.outputURL = tempURL
        exporter.outputFileType = .mp4

        try Task.checkCancellation()
        try await exportSession(exporter)
        try Task.checkCancellation()

        let exportedAsset = AVURLAsset(url: tempURL)
        guard try await exportedAsset.load(.isPlayable) else {
            throw NSError(
                domain: "R0lling.HighlightReel",
                code: 3105,
                userInfo: [NSLocalizedDescriptionKey: "Το AVFoundation δεν αναγνωρίζει το Highlight Reel ως playable video."]
            )
        }

        try Task.checkCancellation()
        let filename = "highlight_reel_\(Int(Date().timeIntervalSince1970)).mp4"
        let savedAttachment = try await mediaStorage.saveMediaFile(
            from: tempURL,
            originalFilename: filename,
            mediaType: .video
        )
        let targetURL = try mediaStorage.getMediaFileURL(relativePath: savedAttachment.relativePath)

        return ReelExportResult(
            fileURL: targetURL,
            relativePath: savedAttachment.relativePath,
            totalClipsIncluded: includedCount,
            totalDurationSeconds: cursor.seconds,
            isPlayable: true
        )
    }

    /// Async wrapper για AVAssetExportSession (iOS 17+ / macOS compatible).
    private func exportSession(_ exporter: AVAssetExportSession) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                exporter.exportAsynchronously {
                    switch exporter.status {
                    case .completed:
                        continuation.resume()
                    case .failed:
                        let err = exporter.error ?? NSError(
                            domain: "R0lling.HighlightReel",
                            code: 3106,
                            userInfo: [NSLocalizedDescriptionKey: "Highlight Reel export απέτυχε."]
                        )
                        continuation.resume(throwing: err)
                    case .cancelled:
                        continuation.resume(throwing: CancellationError())
                    default:
                        continuation.resume(
                            throwing: NSError(
                                domain: "R0lling.HighlightReel",
                                code: 3108,
                                userInfo: [NSLocalizedDescriptionKey: "Highlight Reel export σε άγνωστη κατάσταση."]
                            )
                        )
                    }
                }
            }
        } onCancel: {
            exporter.cancelExport()
        }
    }
}
