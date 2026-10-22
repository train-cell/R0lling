import SwiftUI

// Moved unchanged on 2026-10-13 from UI/Components.swift and UI/SovereignOSComponents.swift. These types have no product caller,
// so they live under Experimental/ per the orphan policy in docs/GOAL_100_FEATURE_MATRIX.md §6.

/// Bevel-style Concentric 3-Ring Visualization (Buffer, Captures Target, Vault Status)
public struct BevelConcentricRingsView: View {
    public let bufferRatio: Double    // 0.0 ... 1.0 (Ring 1: Outer Cyan)
    public let clipsRatio: Double     // 0.0 ... 1.0 (Ring 2: Middle Purple)
    public let batteryRatio: Double   // 0.0 ... 1.0 (Ring 3: Inner Emerald)

    public init(bufferRatio: Double = 0, clipsRatio: Double = 0, batteryRatio: Double = 0) {
        self.bufferRatio = min(max(bufferRatio, 0.0), 1.0)
        self.clipsRatio = min(max(clipsRatio, 0.0), 1.0)
        self.batteryRatio = min(max(batteryRatio, 0.0), 1.0)
    }

    public var body: some View {
        ZStack {
            // Ring 1: Buffer Health (Outer - warm amber)
            Circle()
                .stroke(R0llingTheme.accentAmber.opacity(0.18), lineWidth: 8)
                .frame(width: 96, height: 96)
            Circle()
                .trim(from: 0.0, to: CGFloat(bufferRatio))
                .stroke(
                    R0llingTheme.accentAmber,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 96, height: 96)

            // Ring 2: Clips Target (Middle - lime)
            Circle()
                .stroke(R0llingTheme.accentLime.opacity(0.18), lineWidth: 8)
                .frame(width: 74, height: 74)
            Circle()
                .trim(from: 0.0, to: CGFloat(clipsRatio))
                .stroke(
                    R0llingTheme.accentLime,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 74, height: 74)

            // Ring 3: Hardware Battery / Vault (Inner - periwinkle)
            Circle()
                .stroke(R0llingTheme.accentCyan.opacity(0.18), lineWidth: 8)
                .frame(width: 52, height: 52)
            Circle()
                .trim(from: 0.0, to: CGFloat(batteryRatio))
                .stroke(
                    R0llingTheme.accentCyan,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 52, height: 52)

            // Central Icon
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(R0llingTheme.accentLavender)
        }
        .frame(width: 104, height: 104)
    }
}

/// Hero Telemetry Card (Bevel 3-Metrics Summary + Strava Athletic Card)
public struct BevelTelemetryCard: View {
    public let bufferDuration: Double
    public let todayClipsCount: Int
    public let isStreaming: Bool
    public var isSimulation: Bool = true
    public let glassesStatus: String

    public init(
        bufferDuration: Double,
        todayClipsCount: Int,
        isStreaming: Bool,
        glassesStatus: String
    ) {
        self.bufferDuration = bufferDuration
        self.todayClipsCount = todayClipsCount
        self.isStreaming = isStreaming
        self.glassesStatus = glassesStatus
    }

    public var body: some View {
        VStack(spacing: 14) {
            // Top Status Bar: Hardware Chip & Telemetry Pill
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isStreaming ? R0llingTheme.accentPurple : R0llingTheme.bevelEmerald)
                        .frame(width: 8, height: 8)
                    Text(glassesStatus.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(R0llingTheme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(R0llingTheme.bgElevated)
                .clipShape(Capsule())
                .r0llingBevelCapsule()

                Spacer()

                // Strava Style "ACTIVE TELEMETRY"
                Text("POV ROLLING BUFFER")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(R0llingTheme.textMuted)
                    .tracking(1.2)
            }

            // Middle: Concentric Rings + 3 Key Metrics
            HStack(spacing: 20) {
                // Bevel 3-Ring Chart
                BevelConcentricRingsView(
                    bufferRatio: min(bufferDuration / 10.0, 1.0),
                    clipsRatio: min(Double(todayClipsCount) / 10.0, 1.0),
                    batteryRatio: 0
                )

                // 3 Metrics Breakdown
                VStack(alignment: .leading, spacing: 10) {
                    // Metric 1: Buffer
                    HStack(spacing: 8) {
                        Circle()
                            .fill(R0llingTheme.bevelCyan)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("BUFFER CAPACITY")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(R0llingTheme.textMuted)
                            Text(String(format: "%.1fs / 10.0s", bufferDuration))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(R0llingTheme.textPrimary)
                        }
                    }

                    // Metric 2: Today Clips
                    HStack(spacing: 8) {
                        Circle()
                            .fill(R0llingTheme.accentPurple)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("TODAY'S CLIPS")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(R0llingTheme.textMuted)
                            Text("\(todayClipsCount) CLIPS CAPTURED")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(R0llingTheme.textPrimary)
                        }
                    }

                    // Metric 3: Resolution & Storage
                    HStack(spacing: 8) {
                        Circle()
                            .fill(R0llingTheme.bevelEmerald)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("VIDEO STREAM")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(R0llingTheme.textMuted)
                            Text(isSimulation ? "SYNTHETIC BUFFER" : "FORMAT UNAVAILABLE")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(R0llingTheme.textPrimary)
                        }
                    }
                }

                Spacer()
            }

            // Coaching Target Strip (Bevel-style target range)
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(R0llingTheme.accentLavender)
                    .font(.system(size: 12))
                Text("Rolling Target: 10s Circular Ring actively caching keyframes in RAM.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(R0llingTheme.textSecondary)
                Spacer()
            }
            .padding(10)
            .background(R0llingTheme.bgElevated.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 20, fillColor: R0llingTheme.heroCardFill)
    }
}

public struct TelemetryMetricRow: View {
    public let label: String
    public let val: String
    public let color: Color

    public init(label: String, val: String, color: Color) {
        self.label = label
        self.val = val
        self.color = color
    }

    public var body: some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 11)).foregroundColor(R0llingTheme.textMuted)
            Spacer()
            Text(val).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(R0llingTheme.textPrimary)
        }
    }
}
