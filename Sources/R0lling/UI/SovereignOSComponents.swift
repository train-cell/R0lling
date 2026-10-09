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
        .r0llingBevelSurface(cornerRadius: 18)
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

    private var hasSelectionAction: Bool {
        if case .some = onSelect { return true }
        return false
    }

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
                        .disabled(!hasSelectionAction)
                        .accessibilityHint(hasSelectionAction ? "Άνοιγμα συνδεδεμένης σημείωσης" : "Δείγμα σύνδεσης, χωρίς ενεργή ενέργεια")
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
        .r0llingBevelSurface(cornerRadius: 18)
    }
}

// MARK: - [15] Bevel-Style Daily Indicator Card

public struct BevelConcentricTelemetryCard: View {
    public let score: CognitiveTelemetryScore
    public let activeFocusDeadline: Date?
    public let completedFocusSecondsToday: TimeInterval?
    public let entryCount: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var cardWidth: CGFloat = 0

    public init(
        score: CognitiveTelemetryScore = CognitiveTelemetryScore(cognitiveStrain: 0, focusMinutes: 0, readinessPercent: nil),
        activeFocusDeadline: Date? = nil,
        completedFocusSecondsToday: TimeInterval? = nil,
        entryCount: Int = 0
    ) {
        self.score = score
        self.activeFocusDeadline = activeFocusDeadline
        self.completedFocusSecondsToday = completedFocusSecondsToday
        self.entryCount = entryCount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Ημερήσιοι δείκτες")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
            }

            if let activeFocusDeadline {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let displayedScore = score.includingActiveFocus(
                        deadline: activeFocusDeadline,
                        at: context.date,
                        completedFocusSeconds: completedFocusSecondsToday
                    )
                    VStack(alignment: .leading, spacing: 16) {
                        metricRings(for: displayedScore)
                        dailySnapshot(for: displayedScore)
                    }
                }
            } else {
                metricRings(for: score)
                dailySnapshot(for: score)
            }

            Text("Εκτίμηση από καταγραφές και χρόνο εστίασης · όχι μέτρηση υγείας")
                .font(.caption2)
                .foregroundColor(R0llingTheme.textSecondary)
        }
        .padding(18)
        .r0llingBevelSurface(cornerRadius: 22)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { cardWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in cardWidth = width }
            }
        }
    }

    private func dailySnapshot(for displayedScore: CognitiveTelemetryScore) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(R0llingTheme.accentAmber)
                .frame(width: 38, height: 38)
                .r0llingBevelInsetSurface(cornerRadius: 12)

            VStack(alignment: .leading, spacing: 3) {
                Text("Η σημερινή εικόνα")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Text("\(entryCount) \(entryCount == 1 ? "καταγραφή" : "καταγραφές") · \(displayedScore.focusMinutes) λεπτά εστίασης")
                    .font(.caption)
                    .foregroundColor(R0llingTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(R0llingTheme.borderSubtle)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func metricRings(for displayedScore: CognitiveTelemetryScore) -> some View {
        let compact = dynamicTypeSize.isAccessibilitySize || (cardWidth > 0 && cardWidth < 340)
        let strain = String(format: "%.1f", displayedScore.cognitiveStrain)
        let focus = "\(displayedScore.focusMinutes)m"
        let readiness = displayedScore.readinessPercent.map { "\($0)%" } ?? "—"
        let readinessDetail = displayedScore.readinessPercent == nil ? "no input data" : "entries + focus"
        let readinessProgress = Double(displayedScore.readinessPercent ?? 0) / 100

        return Group {
            if compact {
                VStack(spacing: 8) {
                    compactMetric(title: "Cognitive strain", value: strain, detail: "heuristic / 21", progress: displayedScore.cognitiveStrain / 21, color: R0llingTheme.accentAmber)
                    compactMetric(title: "Focus", value: focus, detail: "of 120m ref.", progress: Double(displayedScore.focusMinutes) / 120, color: R0llingTheme.accentLime)
                    compactMetric(title: "Daily score", value: readiness, detail: readinessDetail, progress: readinessProgress, color: R0llingTheme.accentCyan)
                }
            } else {
                HStack(spacing: 4) {
                    BevelMetricRingGauge(title: "Cognitive strain", value: strain, detail: "heuristic / 21", progress: displayedScore.cognitiveStrain / 21, color: R0llingTheme.accentAmber)
                    metricDivider
                    BevelMetricRingGauge(title: "Focus", value: focus, detail: "of 120m ref.", progress: Double(displayedScore.focusMinutes) / 120, color: R0llingTheme.accentLime)
                    metricDivider
                    BevelMetricRingGauge(title: "Daily score", value: readiness, detail: readinessDetail, progress: readinessProgress, color: R0llingTheme.accentCyan)
                }
            }
        }
    }

    private func compactMetric(
        title: String,
        value: String,
        detail: String,
        progress: Double,
        color: Color
    ) -> some View {
        let boundedProgress = progress.isFinite ? min(max(progress, 0), 1) : 0
        return HStack(spacing: 12) {
            ZStack {
                Circle().stroke(R0llingTheme.borderSubtle, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: boundedProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(R0llingTheme.textSecondary)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.headline.monospacedDigit().weight(.semibold))
                .foregroundColor(R0llingTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(detail)")
    }
}

private struct BevelMetricRingGauge: View {
    let title: String
    let value: String
    let detail: String
    let progress: Double
    let color: Color

    private var boundedProgress: Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [R0llingTheme.bgElevated, R0llingTheme.bgPrimary],
                            center: .center,
                            startRadius: 10,
                            endRadius: 42
                        )
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 3, x: 0, y: 2)
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.8))
                Circle()
                    .stroke(Color.black.opacity(0.42), lineWidth: 10)
                    .padding(4)
                Circle()
                    .stroke(R0llingTheme.borderSubtle.opacity(0.8), lineWidth: 8)
                    .padding(5)
                Circle()
                    .trim(from: 0, to: boundedProgress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color.opacity(0.76), color]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(5)
                Text(value)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(3)
            }
            .frame(width: 88, height: 88)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(R0llingTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption2)
                .foregroundColor(R0llingTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value), \(detail)")
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
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = appState.deepWorkEndsAt.map { min(1500, max(0, Int(ceil($0.timeIntervalSince(context.date))))) } ?? 1500
                ZStack {
                    Circle()
                        .stroke(R0llingTheme.borderSubtle, lineWidth: 8)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: CGFloat(1500 - remaining) / 1500)
                        .stroke(R0llingTheme.accentPurple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(R0llingTheme.textPrimary)
                        Text("DEEP WORK")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(R0llingTheme.accentLavender)
                    }
                }

            }

            Text("Συνεδρία εστίασης 25 λεπτών")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(R0llingTheme.textSecondary)

            Button {
                Task { await appState.toggleDeepWork() }
                R0llingTheme.triggerHapticFeedback()
            } label: {
                Text(appState.deepWorkEndsAt != nil ? "Ολοκλήρωση Συνεδρίας" : "Έναρξη Εστίασης")
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
            .disabled(!appState.deepWorkSessionRestored)
        }
        .task(id: appState.deepWorkEndsAt) {
            guard let deadline = appState.deepWorkEndsAt else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(max(0, deadline.timeIntervalSinceNow) * 1_000_000_000))
                try Task.checkCancellation()
                if appState.deepWorkEndsAt == deadline { await appState.completeDeepWork() }
            } catch { /* View disappearance or manual completion cancels the wait. */ }
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 18)
    }
}

// MARK: - [37] Binaural Synthesizer Card View

public struct BinauralSynthesizerCardView: View {
    @State private var synthesizer = BinauralFocusSynthesizer()
    @State private var selectedBeat: BinauralFocusSynthesizer.BeatType = .gamma40Hz
    @State private var isPlaying = false
    @State private var playbackError: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Binaural beats", systemImage: "headphones")
                    .font(.headline.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text(isPlaying ? "ΑΝΑΠΑΡΑΓΩΓΗ" : "ΠΑΥΣΗ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isPlaying ? R0llingTheme.accentCyan : R0llingTheme.textSecondary)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await togglePlayback() }
                } label: {
                    Label(isPlaying ? "Διακοπή" : "Αναπαραγωγή", systemImage: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .r0llingBevelCapsule()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Διακοπή binaural ήχου" : "Αναπαραγωγή binaural ήχου")

                Menu {
                    ForEach(BinauralFocusSynthesizer.BeatType.allCases, id: \.self) { beat in
                        Button(beat.rawValue) {
                            Task { await selectBeat(beat) }
                        }
                    }
                } label: {
                    Label(selectedBeat.rawValue, systemImage: "waveform")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .r0llingBevelInsetSurface(cornerRadius: 18)
                }
                .accessibilityLabel("Επιλογή binaural beat")
            }

            Text("Χρειάζονται στερεοφωνικά ακουστικά. Δεν αποτελεί θεραπεία ή μέτρηση εστίασης.")
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(R0llingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let playbackError {
                Text(playbackError)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(R0llingTheme.accentAmber)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 18)
        .onDisappear {
            Task { try? await synthesizer.stopPlayback() }
        }
    }

    @MainActor
    private func togglePlayback() async {
        do {
            if isPlaying {
                try await synthesizer.stopPlayback()
                isPlaying = false
            } else {
                try await synthesizer.setBeat(selectedBeat)
                try await synthesizer.startPlayback()
                isPlaying = true
            }
            playbackError = nil
        } catch {
            isPlaying = false
            playbackError = error.localizedDescription
        }
    }

    @MainActor
    private func selectBeat(_ beat: BinauralFocusSynthesizer.BeatType) async {
        do {
            try await synthesizer.setBeat(beat)
            selectedBeat = beat
            playbackError = nil
        } catch {
            playbackError = error.localizedDescription
        }
    }
}

// MARK: - [39] Gym Volume Logger Card View

public struct GymVolumeLoggerCardView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Iron Volume Logger", systemImage: "figure.strengthtraining.traditional")
                    .font(.headline.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("ΠΡΟΕΠΙΣΚΟΠΗΣΗ")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(R0llingTheme.accentLavender)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    volumePlaceholder
                    Spacer(minLength: 0)
                    Text("Δεν έχουν καταγραφεί σετ.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(R0llingTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 12) {
                    volumePlaceholder
                    Text("Δεν έχουν καταγραφεί σετ.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(R0llingTheme.textSecondary)
                }
            }
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 18)
    }

    private var volumePlaceholder: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("TOTAL TONNAGE")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(R0llingTheme.textMuted)
            Text("— kg")
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundColor(R0llingTheme.textSecondary)
        }
    }
}

// MARK: - [41] HealthKit Telemetry Card View (Bevel Health Monitor Grid IMG_0482)

public struct HealthKitTelemetryCardView: View {
    public let snapshot: HealthKitTelemetrySnapshot
    public var didCompleteAuthorizationRequest: Bool
    public var onRequestAuth: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var metricGridWidth: CGFloat = 0

    public init(
        snapshot: HealthKitTelemetrySnapshot = HealthKitTelemetrySnapshot(),
        didCompleteAuthorizationRequest: Bool = false,
        onRequestAuth: (() -> Void)? = nil
    ) {
        self.snapshot = snapshot
        self.didCompleteAuthorizationRequest = didCompleteAuthorizationRequest
        self.onRequestAuth = onRequestAuth
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Μετρήσεις Apple Health", systemImage: "heart.text.square.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                if snapshot.hasReadings {
                    Text("ΜΕΤΡΗΣΕΙΣ ΔΙΑΘΕΣΙΜΕΣ")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(R0llingTheme.statusSuccess.opacity(0.15))
                        .foregroundColor(R0llingTheme.statusSuccess)
                        .clipShape(Capsule())
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(didCompleteAuthorizationRequest ? "ΧΩΡΙΣ ΜΕΤΡΗΣΕΙΣ" : "ΔΕΝ ΕΧΕΙ ΓΙΝΕΙ ΑΙΤΗΜΑ")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundColor(R0llingTheme.textMuted)
                        Button(action: {
                            R0llingTheme.triggerHapticFeedback()
                            onRequestAuth?()
                        }) {
                            Text("ΑΙΤΗΜΑ ΠΡΟΣΒΑΣΗΣ")
                                .font(.system(.caption2, design: .monospaced).weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(minHeight: 44)
                                .foregroundColor(R0llingTheme.textPrimary)
                                .r0llingBevelCapsule()
                        }
                    }
                }
            }

            // Two columns on normal widths; one column for narrow screens / accessibility text.
            LazyVGrid(columns: metricColumns, spacing: 10) {
                BevelMetricTile(
                    abbrev: "RR",
                    value: snapshot.respiratoryRate.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "rpm",
                    status: measurementStatus(for: snapshot.respiratoryRateMetadata, hasValue: snapshot.respiratoryRate != nil),
                    color: R0llingTheme.accentCyan,
                    spokenMetricName: "Αναπνευστικός ρυθμός"
                )
                BevelMetricTile(
                    abbrev: "RHR",
                    value: snapshot.restingHRBpm.map { String($0) } ?? "—",
                    unit: "bpm",
                    status: measurementStatus(for: snapshot.restingHRMetadata, hasValue: snapshot.restingHRBpm != nil),
                    color: R0llingTheme.accentLavender,
                    spokenMetricName: "Καρδιακός ρυθμός ηρεμίας"
                )
                BevelMetricTile(
                    abbrev: "HRV",
                    value: snapshot.hrvMs.map { String(format: "%.0f", $0) } ?? "—",
                    unit: "ms",
                    status: measurementStatus(for: snapshot.hrvMetadata, hasValue: snapshot.hrvMs != nil),
                    color: R0llingTheme.accentCyan,
                    spokenMetricName: "Μεταβλητότητα καρδιακού ρυθμού"
                )
                BevelMetricTile(
                    abbrev: "SpO2",
                    value: snapshot.bloodOxygenPercent.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "%",
                    status: measurementStatus(for: snapshot.bloodOxygenMetadata, hasValue: snapshot.bloodOxygenPercent != nil),
                    color: R0llingTheme.statusSuccess,
                    spokenMetricName: "Κορεσμός οξυγόνου στο αίμα"
                )
                BevelMetricTile(
                    abbrev: "TEMP",
                    value: snapshot.bodyTemperatureCelsius.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "°C",
                    status: measurementStatus(for: snapshot.bodyTemperatureMetadata, hasValue: snapshot.bodyTemperatureCelsius != nil),
                    color: R0llingTheme.accentAmber,
                    spokenMetricName: "Θερμοκρασία σώματος"
                )
                BevelMetricTile(
                    abbrev: "SLEEP",
                    value: snapshot.sleepHours.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "hrs",
                    status: measurementStatus(for: snapshot.sleepMetadata, hasValue: snapshot.sleepHours != nil),
                    color: R0llingTheme.accentPurple,
                    spokenMetricName: "Διάρκεια ύπνου"
                )
            }
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { metricGridWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { _, newWidth in metricGridWidth = newWidth }
                }
            }
        }
        .padding(14)
        .r0llingBevelSurface(cornerRadius: 18)
    }

    private var metricColumns: [GridItem] {
        let count = (metricGridWidth > 0 && metricGridWidth < 330) || dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    private func measurementStatus(for metadata: HealthKitReadingMetadata?, hasValue: Bool) -> String {
        guard hasValue else { return "Χωρίς πρόσφατη μέτρηση" }
        guard let metadata else { return "Δεν υπάρχει ώρα ή πηγή" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "el")
        let age = formatter.localizedString(for: metadata.measuredAt, relativeTo: snapshot.queriedAt)
        let source = metadata.sourceName.isEmpty ? "Άγνωστη πηγή" : metadata.sourceName
        return "\(age) · \(source)"
    }
}

public struct BevelMetricTile: View {
    public let abbrev: String
    public let value: String
    public let unit: String
    public let status: String
    public let color: Color
    public let spokenMetricName: String?

    public init(
        abbrev: String,
        value: String,
        unit: String,
        status: String,
        color: Color,
        spokenMetricName: String? = nil
    ) {
        self.abbrev = abbrev
        self.value = value
        self.unit = unit
        self.status = status
        self.color = color
        self.spokenMetricName = spokenMetricName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(abbrev)
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(R0llingTheme.textMuted)
                Spacer()
                Circle().fill(color).frame(width: 5, height: 5)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(unit)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(R0llingTheme.textMuted)
                    .lineLimit(1)
            }
            Text(status)
                .font(.caption2.weight(.semibold))
                .foregroundColor(color)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .r0llingBevelSurface(cornerRadius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let name = spokenMetricName ?? abbrev
        let spokenValue = value == "—" ? "Δεν υπάρχει τιμή" : "\(value) \(unit)"
        return "\(name). \(spokenValue). \(status)"
    }
}
