import SwiftUI

// MARK: - [01] Chief of Staff Card View

public struct ChiefOfStaffCardView: View {
    @State private var tasks: [ChiefOfStaffTask] = [
        ChiefOfStaffTask(title: "Ολοκλήρωση Sovereign Life OS architecture", priority: .high),
        ChiefOfStaffTask(title: "Έλεγχος Bevel telemetry concentric rings", priority: .medium),
        ChiefOfStaffTask(title: "Συγχρονισμός Obsidian Vault Zettelkasten", priority: .low)
    ]
    @State private var isDebriefing: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Επιτελείο Jarvis", systemImage: "sparkles.square.filled.on.square")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("LOCAL LAN")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(R0llingTheme.accentPurple.opacity(0.2))
                    .foregroundColor(R0llingTheme.accentLavender)
                    .clipShape(Capsule())
            }

            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    HStack(spacing: 12) {
                        Button {
                            toggleTask(task)
                        } label: {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? R0llingTheme.statusSuccess : R0llingTheme.accentLavender)
                                .font(.system(size: 16))
                        }
                        Text(task.title)
                            .font(.system(size: 13, weight: .regular))
                            .strikethrough(task.isCompleted, color: R0llingTheme.borderSubtle)
                            .foregroundColor(task.isCompleted ? R0llingTheme.textMuted : R0llingTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 3)
                }
            }

            Button {
                R0llingTheme.triggerHapticFeedback()
                isDebriefing.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                    Text("Εκτέλεση Voice Debrief")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(R0llingTheme.accentPurple)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
        )
    }

    private func toggleTask(_ task: ChiefOfStaffTask) {
        R0llingTheme.triggerHapticFeedback()
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].isCompleted.toggle()
        }
    }
}

// MARK: - [02] Zettelkasten Chip Strip View

public struct ZettelkastenChipStripView: View {
    public let connections: [ZettelkastenConnection]
    public let onSelect: ((ZettelkastenConnection) -> Void)?

    public init(
        connections: [ZettelkastenConnection] = [
            ZettelkastenConnection(targetNoteTitle: "Second Brain Architecture", relativeVaultPath: "Notes/Brain.md", similarityScore: 0.92),
            ZettelkastenConnection(targetNoteTitle: "Stoic Mindfulness", relativeVaultPath: "Notes/Stoic.md", similarityScore: 0.78),
            ZettelkastenConnection(targetNoteTitle: "Swift Concurrency", relativeVaultPath: "Notes/Swift.md", similarityScore: 0.84)
        ],
        onSelect: ((ZettelkastenConnection) -> Void)? = nil
    ) {
        self.connections = connections
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "link.badge.plus")
                    .foregroundColor(R0llingTheme.accentLavender)
                    .font(.system(size: 12))
                Text("ZETTELKASTEN CONNECTIONS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(connections) { item in
                        Button {
                            R0llingTheme.triggerHapticFeedback()
                            onSelect?(item)
                        } label: {
                            HStack(spacing: 6) {
                                Text("[[\(item.targetNoteTitle)]]")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(R0llingTheme.textPrimary)
                                Text("\(Int(item.similarityScore * 100))%")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(R0llingTheme.accentCyan)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(R0llingTheme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(R0llingTheme.accentLavender.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - [05] Daily Podcast Player Card

public struct DailyPodcastPlayerCard: View {
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.35

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(R0llingTheme.primaryButtonGradient)
                        .frame(width: 48, height: 48)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ΠΡΟΣΩΠΙΚΟ MORNING BRIEF")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(R0llingTheme.accentLavender)
                    Text("Ημερήσια Ανασκόπηση")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(R0llingTheme.textPrimary)
                }

                Spacer()

                Button {
                    isPlaying.toggle()
                    R0llingTheme.triggerHapticFeedback()
                } label: {
                    Circle()
                        .fill(R0llingTheme.accentPurple)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        )
                }
            }

            VStack(spacing: 4) {
                Slider(value: $progress)
                    .tint(R0llingTheme.accentCyan)
                HStack {
                    Text("01:14")
                    Spacer()
                    Text("03:00")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(R0llingTheme.textMuted)
            }
        }
        .padding(16)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - [15] Bevel Concentric Telemetry Card

public struct BevelConcentricTelemetryCard: View {
    public let score: CognitiveTelemetryScore

    public init(score: CognitiveTelemetryScore = CognitiveTelemetryScore(cognitiveStrain: 9.4, focusMinutes: 85, readinessPercent: 88)) {
        self.score = score
    }

    public var body: some View {
        HStack(spacing: 20) {
            ZStack {
                // Outer Ring: Strain (Cyan)
                Circle().stroke(R0llingTheme.borderSubtle, lineWidth: 6).frame(width: 90, height: 90)
                Circle().trim(from: 0, to: CGFloat(min(1.0, score.cognitiveStrain / 21.0)))
                    .stroke(R0llingTheme.accentCyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))

                // Middle Ring: Deep Work (Twitch Purple)
                Circle().stroke(R0llingTheme.borderSubtle, lineWidth: 6).frame(width: 72, height: 72)
                Circle().trim(from: 0, to: CGFloat(min(1.0, Double(score.focusMinutes) / 120.0)))
                    .stroke(R0llingTheme.accentPurple, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))

                // Inner Ring: Readiness (Emerald)
                Circle().stroke(R0llingTheme.borderSubtle, lineWidth: 6).frame(width: 54, height: 54)
                Circle().trim(from: 0, to: CGFloat(Double(score.readinessPercent) / 100.0))
                    .stroke(R0llingTheme.statusSuccess, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-90))
            }

            VStack(alignment: .leading, spacing: 6) {
                TelemetryMetricRow(label: "Cognitive Strain", val: String(format: "%.1f", score.cognitiveStrain), color: R0llingTheme.accentCyan)
                TelemetryMetricRow(label: "Deep Work", val: "\(score.focusMinutes)m", color: R0llingTheme.accentPurple)
                TelemetryMetricRow(label: "Readiness", val: "\(score.readinessPercent)%", color: R0llingTheme.statusSuccess)
            }
        }
        .padding(16)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
        )
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

// MARK: - [13] Deep Work Sentinel Card

public struct DeepWorkSentinelCard: View {
    @State private var timeRemaining: Int = 1500
    @State private var sessionGoal: String = "Σχεδιασμός L4NE Sovereign App"
    @State private var isRunning: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(R0llingTheme.borderSubtle, lineWidth: 8)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(R0llingTheme.accentPurple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("25:00")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(R0llingTheme.textPrimary)
                    Text("DEEP WORK")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(R0llingTheme.accentLavender)
                }
            }

            Text(sessionGoal)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(R0llingTheme.textSecondary)

            Button {
                isRunning.toggle()
                R0llingTheme.triggerHapticFeedback()
            } label: {
                Text(isRunning ? "Παύση Συνεδρίας" : "Έναρξη Εστίασης")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(R0llingTheme.bgElevated)
                    .foregroundColor(R0llingTheme.accentCyan)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(R0llingTheme.accentCyan.opacity(0.3), lineWidth: 0.5)
                    )
            }
        }
        .padding(16)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - [37] Binaural Synthesizer Card View

public struct BinauralSynthesizerCardView: View {
    @State private var isActive: Bool = false
    @State private var selectedHz: Double = 40.0

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Binaural Beats Hub", systemImage: "headphones")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("\(Int(selectedHz)) Hz GAMMA")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentCyan)
            }

            HStack(spacing: 12) {
                Button {
                    isActive.toggle()
                    R0llingTheme.triggerHapticFeedback()
                } label: {
                    Circle()
                        .fill(isActive ? R0llingTheme.accentCyan : R0llingTheme.bgElevated)
                        .frame(width: 44, height: 44)
                        .overlay(Image(systemName: isActive ? "speaker.wave.3.fill" : "play.fill")
                            .foregroundColor(isActive ? .black : .white))
                }

                Slider(value: $selectedHz, in: 4...40, step: 1)
                    .tint(R0llingTheme.accentCyan)
            }
        }
        .padding(16)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - [39] Gym Volume Logger Card View

public struct GymVolumeLoggerCardView: View {
    @State private var totalVolumeKg: Double = 4250.0

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Iron Volume Logger", systemImage: "figure.strengthtraining.traditional")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("REST: 90s")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.statusSuccess)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("TOTAL TONNAGE")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(R0llingTheme.textMuted)
                    Text(String(format: "%.0f kg", totalVolumeKg))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(R0llingTheme.statusSuccess)
                }
                Spacer()
                Text("«Squats 120kg x 6»")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
            }
        }
        .padding(16)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - [41] HealthKit Telemetry Card View (Bevel Health Monitor Grid IMG_0482)

public struct HealthKitTelemetryCardView: View {
    public let snapshot: HealthKitTelemetrySnapshot
    public var isAuthorized: Bool
    public var onRequestAuth: (() -> Void)?

    public init(
        snapshot: HealthKitTelemetrySnapshot = HealthKitTelemetrySnapshot(),
        isAuthorized: Bool = true,
        onRequestAuth: (() -> Void)? = nil
    ) {
        self.snapshot = snapshot
        self.isAuthorized = isAuthorized
        self.onRequestAuth = onRequestAuth
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Apple Health Recovery Monitor", systemImage: "heart.text.square.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                if isAuthorized {
                    Text("LIVE WATCH SYNC")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(R0llingTheme.statusSuccess.opacity(0.15))
                        .foregroundColor(R0llingTheme.statusSuccess)
                        .clipShape(Capsule())
                } else {
                    Button(action: {
                        R0llingTheme.triggerHapticFeedback()
                        onRequestAuth?()
                    }) {
                        Text("ΣΥΝΔΕΣΗ")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(R0llingTheme.accentPurple)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }

            // Bevel 2x3 Metrics Grid (IMG_0482 compliance)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                BevelMetricTile(abbrev: "HRV", value: "\(Int(snapshot.hrvMs))", unit: "ms", status: "Optimal", color: R0llingTheme.accentCyan)
                BevelMetricTile(abbrev: "RHR", value: "\(snapshot.restingHRBpm)", unit: "bpm", status: "Optimal", color: R0llingTheme.accentLavender)
                BevelMetricTile(abbrev: "SpO2", value: String(format: "%.1f", snapshot.bloodOxygenPercent), unit: "%", status: "Normal", color: R0llingTheme.statusSuccess)
                BevelMetricTile(abbrev: "RR", value: String(format: "%.1f", snapshot.respiratoryRate), unit: "rpm", status: "Normal", color: R0llingTheme.accentCyan)
                BevelMetricTile(abbrev: "SCORE", value: "\(snapshot.recoveryScore)", unit: "/100", status: "Ready", color: R0llingTheme.statusSuccess)
                BevelMetricTile(abbrev: "SLEEP", value: "7.8", unit: "hrs", status: "Good", color: R0llingTheme.accentPurple)
            }
        }
        .padding(14)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}

public struct BevelMetricTile: View {
    public let abbrev: String
    public let value: String
    public let unit: String
    public let status: String
    public let color: Color

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(abbrev)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.textMuted)
                Spacer()
                Circle().fill(color).frame(width: 5, height: 5)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.textPrimary)
                Text(unit)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(R0llingTheme.textMuted)
            }
            Text(status)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(8)
        .background(R0llingTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(R0llingTheme.borderSubtle.opacity(0.4), lineWidth: 0.5)
        )
    }
}
