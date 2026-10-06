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
            guard let fileURL = try? await mediaStorage.getMediaFileURL(relativePath: att.relativePath) else { continue }
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }

            let asset = AVURLAsset(url: fileURL)
            let videoTracks = asset.tracks(withMediaType: .video)
            guard let sourceVideo = videoTracks.first else { continue }

            let duration = asset.duration
            guard duration.isNumeric && duration.seconds > 0 else { continue }

            let timeRange = CMTimeRange(start: .zero, duration: duration)
            try compositionVideo.insertTimeRange(timeRange, of: sourceVideo, at: cursor)

            if let compositionAudio,
               let sourceAudio = asset.tracks(withMediaType: .audio).first {
                try? compositionAudio.insertTimeRange(timeRange, of: sourceAudio, at: cursor)
            }

            cursor = CMTimeAdd(cursor, duration)
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

        try await exportSession(exporter)

        let exportedData = try Data(contentsOf: tempURL)
        try? FileManager.default.removeItem(at: tempURL)

        // Post-write moov guard — fail closed όπως PlayableClipExporter.
        let probe = exportedData.prefix(2_000_000)
        let probeText = String(decoding: probe, as: UTF8.self)
        let hasMoov = probe.contains("moov".data(using: .ascii)!) || probeText.contains("moov")
        guard hasMoov else {
            throw NSError(
                domain: "R0lling.HighlightReel",
                code: 3105,
                userInfo: [NSLocalizedDescriptionKey: "Highlight Reel export χωρίς moov atom — απορρίφθηκε."]
            )
        }

        let filename = "highlight_reel_\(Int(Date().timeIntervalSince1970)).mp4"
        let savedAttachment = try await mediaStorage.saveMediaFile(
            data: exportedData,
            originalFilename: filename,
            mediaType: .video
        )
        let targetURL = try await mediaStorage.getMediaFileURL(relativePath: savedAttachment.relativePath)

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
                    continuation.resume(
                        throwing: NSError(
                            domain: "R0lling.HighlightReel",
                            code: 3107,
                            userInfo: [NSLocalizedDescriptionKey: "Highlight Reel export ακυρώθηκε."]
                        )
                    )
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
    }
}
