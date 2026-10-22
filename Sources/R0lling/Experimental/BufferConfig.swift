import Foundation

// Moved unchanged on 2026-10-13 from Core/Models.swift. These types have no product caller,
// so they live under Experimental/ per the orphan policy in docs/GOAL_100_FEATURE_MATRIX.md §6.

/// Ρυθμίσεις για τον κυκλικό buffer
public struct BufferConfig: Codable, Sendable, Equatable {
    public var targetDurationSeconds: Double
    public var enableAudio: Bool
    public var maxMemoryMegabytes: Int

    public init(
        targetDurationSeconds: Double = 10.0,
        enableAudio: Bool = true,
        maxMemoryMegabytes: Int = 30
    ) {
        self.targetDurationSeconds = targetDurationSeconds
        self.enableAudio = enableAudio
        self.maxMemoryMegabytes = maxMemoryMegabytes
    }
}
