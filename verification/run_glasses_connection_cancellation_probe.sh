#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-glasses-cancel.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

cat > "$scratch_dir/RuntimeShims.swift" <<'SWIFT'
import Foundation

public enum BufferState: Sendable, Equatable { case idle, active(durationAvailable: Double), paused, exporting(progress: Double), error(String) }
public struct ClipExportResult: Sendable, Equatable {
    public let fileURL: URL; public let relativePath: String; public let duration: Double
    public let hasAudio: Bool; public let frameCount: Int; public let timestamp: Date
    public let isPlayable: Bool; public let isSimulationPlaceholder: Bool; public let byteSize: Int64
    public let streamGeneration: UInt64
}
public struct BufferedSample: Sendable {
    public let timestampSeconds: Double; public let isKeyframe: Bool; public let isAudio: Bool
    public let data: Data; public let streamGeneration: UInt64
    public init(timestampSeconds: Double, isKeyframe: Bool, isAudio: Bool, data: Data, streamGeneration: UInt64 = 0) {
        self.timestampSeconds = timestampSeconds; self.isKeyframe = isKeyframe; self.isAudio = isAudio
        self.data = data; self.streamGeneration = streamGeneration
    }
}
public protocol RollingBufferServiceProtocol: AnyObject, Sendable {
    var currentState: BufferState { get async }
    var availableDuration: Double { get async }
    var streamGeneration: UInt64 { get async }
    func startBuffering(targetSeconds: Double) async throws
    func stopBuffering() async
    func pauseBuffering() async
    func resumeBuffering() async
    func markStreamInterrupted(reason: String) async
    func appendSample(sample: BufferedSample) async
    func triggerClip(requestedSeconds: Double) async throws -> ClipExportResult
    func clearBuffer() async
}
// Mirrors the non-DAT (no MWDATCore) surface of Sources/R0lling/Glasses/MetaDATStreamBridge.swift
// that MetaGlassesAdapter uses outside its `#if canImport(MWDATCore)` blocks.
public enum MetaDATStreamBridge {
    public static let einaiSDKDiathesimo = false
    public static let einaiLiveYlopoiimeno = false
    public static let errorDomain = "R0lling.Glasses.DAT"
    public static let kodikosSDKMiDiathesimo = 4010
    public static let kodikosSessionApotyxia = 4011
    public struct LiveSessionHandle: Sendable {
        public let deviceName: String
        public let batteryPercent: Int?
    }
    private static func unavailable() -> NSError {
        NSError(domain: errorDomain, code: kodikosSDKMiDiathesimo, userInfo: [NSLocalizedDescriptionKey: "DAT unavailable in probe"])
    }
    public static func anoixeLiveSession() async throws -> LiveSessionHandle { throw unavailable() }
    public static func kleiseLiveSession() async {}
    public static func zitaCameraPermissionMetaAIHandoff() async throws { throw unavailable() }
    public static func arxiseLiveCameraStream() async throws { throw unavailable() }
    public static func stamataLiveCameraStream() async {}
    public static func diavaseEpomenoVideoFrame() async throws -> BufferedSample? { throw unavailable() }
    public static func diavaseEpomenoAudioSample() async throws -> BufferedSample? { throw unavailable() }
    public static func diavaseEpomenoIMU() async throws -> HeadGestureDetector.IMUSample? { throw unavailable() }
}
SWIFT

swiftc -strict-concurrency=complete \
  "$scratch_dir/RuntimeShims.swift" \
  "$repo_root/Sources/R0lling/Glasses/MetaGlassesProtocol.swift" \
  "$repo_root/Sources/R0lling/Glasses/GlassesStreamLifecycle.swift" \
  "$repo_root/Sources/R0lling/Glasses/HeadGestureDetector.swift" \
  "$repo_root/Sources/R0lling/Glasses/MetaGlassesAdapter.swift" \
  "$repo_root/verification/glasses_connection_cancellation_probe.swift" \
  -o "$scratch_dir/glasses-probe"

timeout 5 "$scratch_dir/glasses-probe"
