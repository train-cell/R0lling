import SwiftUI

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

// MARK: - [15] Bevel-Style Daily Indicator Card

public struct BevelConcentricTelemetryCard: View {
    public let score: CognitiveTelemetryScore
    public let activeFocusDeadline: Date?
    public let completedFocusSecondsToday: TimeInterval?
    public let entryCount: Int
    public let daySummaryTitle: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var cardWidth: CGFloat = 0

    public init(
        score: CognitiveTelemetryScore = CognitiveTelemetryScore(cognitiveStrain: 0, focusMinutes: 0, readinessPercent: nil),
        activeFocusDeadline: Date? = nil,
        completedFocusSecondsToday: TimeInterval? = nil,
        entryCount: Int = 0,
        daySummaryTitle: String = "Η σημερινή εικόνα"
    ) {
        self.score = score
        self.activeFocusDeadline = activeFocusDeadline
        self.completedFocusSecondsToday = completedFocusSecondsToday
        self.entryCount = entryCount
        self.daySummaryTitle = daySummaryTitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Ημερήσιοι δείκτες")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(R0llingTheme.textSecondary)
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
                Text(daySummaryTitle)
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
        let focus = "\(displayedScore.focusMinutes)λ"
        let readiness = displayedScore.readinessPercent.map { "\($0)%" } ?? "—"
        let readinessDetail = displayedScore.readinessPercent == nil ? "χωρίς δεδομένα εισόδου" : "καταγραφές + εστίαση"
        let readinessProgress = Double(displayedScore.readinessPercent ?? 0) / 100

        return Group {
            if compact {
                VStack(spacing: 8) {
                    compactMetric(title: "Νοητική επιβάρυνση", value: strain, detail: "ευρετική κλίμακα · αναφορά 21", progress: displayedScore.cognitiveStrain / 21, color: R0llingTheme.todayCognitiveLoadRingEnd)
                    compactMetric(title: "Εστίαση", value: focus, detail: "αναφορά: 120λ", progress: Double(displayedScore.focusMinutes) / 120, color: R0llingTheme.todayFocusRingEnd)
                    compactMetric(title: "Ημερήσια βαθμολογία", value: readiness, detail: readinessDetail, progress: readinessProgress, color: R0llingTheme.todayReadinessRingEnd)
                }
            } else {
                HStack(spacing: 4) {
                    BevelMetricRingGauge(title: "Νοητική επιβάρυνση", value: strain, detail: "ευρετική κλίμακα · αναφορά 21", progress: displayedScore.cognitiveStrain / 21, startColor: R0llingTheme.todayCognitiveLoadRingStart, endColor: R0llingTheme.todayCognitiveLoadRingEnd)
                    metricDivider
                    BevelMetricRingGauge(title: "Εστίαση", value: focus, detail: "αναφορά: 120λ", progress: Double(displayedScore.focusMinutes) / 120, startColor: R0llingTheme.todayFocusRingStart, endColor: R0llingTheme.todayFocusRingEnd)
                    metricDivider
                    BevelMetricRingGauge(title: "Ημερήσια βαθμολογία", value: readiness, detail: readinessDetail, progress: readinessProgress, startColor: R0llingTheme.todayReadinessRingStart, endColor: R0llingTheme.todayReadinessRingEnd)
                }
            }
        }
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(R0llingTheme.bgElevated)
                .padding(.horizontal, -18)
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
    let startColor: Color
    let endColor: Color

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
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
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
                            gradient: Gradient(colors: [startColor.opacity(0.76), endColor]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(5)
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
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
                .font(.caption)
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

            if appState.deepWorkPersistenceNeedsRecovery {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Το αποθηκευμένο ιστορικό εστίασης δεν μπορεί να διαβαστεί. Τα αρχικά δεδομένα παραμένουν ανέπαφα και οι νέες συνεδρίες είναι προσωρινά απενεργοποιημένες.")
                        .font(.footnote)
                        .foregroundColor(R0llingTheme.accentAmber)
                    Button {
                        appState.isDeepWorkRecoveryConfirmationPresented = true
                    } label: {
                        Text("Επαναφορά ιστορικού εστίασης")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .r0llingBevelCapsule()
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Συνεδρία εστίασης 25 λεπτών")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(R0llingTheme.textSecondary)
            }

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
            .disabled(!appState.deepWorkSessionRestored || appState.deepWorkPersistenceNeedsRecovery)
        }
        .task(id: appState.deepWorkEndsAt) {
            guard let deadline = appState.deepWorkEndsAt else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(max(0, deadline.timeIntervalSinceNow) * 1_000_000_000))
                try Task.checkCancellation()
                if appState.deepWorkEndsAt == deadline { await appState.completeDeepWork() }
            } catch { /* View disappearance or manual completion cancels the wait. */ }
        }
        .alert("Επαναφορά ιστορικού εστίασης;", isPresented: $appState.isDeepWorkRecoveryConfirmationPresented) {
            Button("Διαγραφή και επαναφορά", role: .destructive) {
                Task { await appState.discardCorruptDeepWorkPersistence() }
            }
            Button("Άκυρο", role: .cancel) {}
        } message: {
            Text("Το μη αναγνώσιμο αποθηκευμένο ιστορικό θα διαγραφεί. Χωρίς επαναφορά, τα δεδομένα θα παραμείνουν ανέπαφα και οι νέες συνεδρίες θα συνεχίσουν να είναι απενεργοποιημένες.")
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
    @State private var isSleepReportPresented = false

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
        let accessPresentation = HealthKitAccessPresentation.resolve(
            hasMeasurements: snapshot.hasReadings,
            didCompleteRequest: didCompleteAuthorizationRequest
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Μετρήσεις Apple Health")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                if accessPresentation == .measurementsAvailable {
                    Text(accessPresentation.statusText)
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(R0llingTheme.statusSuccess.opacity(0.15))
                        .foregroundColor(R0llingTheme.statusSuccess)
                        .clipShape(Capsule())
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(accessPresentation.statusText)
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundColor(R0llingTheme.textMuted)
                        if accessPresentation.shouldShowRequestButton {
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
                        } else if let explanation = accessPresentation.explanation {
                            Text(explanation)
                                .font(.caption2)
                                .foregroundColor(R0llingTheme.textSecondary)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            adaptiveMetricGrid

            if snapshot.sleepQueryFailed == true {
                Label(
                    "Δεν ήταν δυνατή η ανάκτηση δεδομένων ύπνου από το HealthKit. Δοκίμασε ξανά αργότερα.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundColor(R0llingTheme.accentAmber)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .r0llingBevelSurface(cornerRadius: 12)
                .accessibilityHint("Η αποτυχία ερωτήματος δεν σημαίνει ότι λείπουν καταγεγραμμένα δεδομένα ύπνου.")
            }

            Text("Οι κάθετες μπάρες δείχνουν θέση στην κλίμακα εμφάνισης, όχι κλινική αξιολόγηση.")
                .font(.caption2)
                .foregroundColor(R0llingTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $isSleepReportPresented) {
            if let report = snapshot.sleepReport {
                SleepReportView(report: report)
            }
        }
    }

    @ViewBuilder
    private var adaptiveMetricGrid: some View {
        if dynamicTypeSize.isAccessibilitySize {
            makeMetricGrid(columnCount: 1, minimumTileWidth: nil)
        } else {
            ViewThatFits(in: .horizontal) {
                makeMetricGrid(columnCount: 2, minimumTileWidth: 118)
                makeMetricGrid(columnCount: 1, minimumTileWidth: nil)
            }
        }
    }

    private func makeMetricGrid(columnCount: Int, minimumTileWidth: CGFloat?) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columnCount),
            spacing: 10
        ) {
            metricTile(
                abbrev: "RR",
                systemImage: "lungs.fill",
                value: formattedMeasurement(snapshot.respiratoryRate, format: "%.1f"),
                unit: "rpm",
                metadata: snapshot.respiratoryRateMetadata,
                hasValue: hasValidMeasurement(snapshot.respiratoryRate),
                gaugeProgress: HealthMetricDisplayScale.progress(for: snapshot.respiratoryRate, within: 0...60),
                color: R0llingTheme.healthMonitorGaugeGreen,
                spokenMetricName: "Αναπνευστικός ρυθμός",
                minimumWidth: minimumTileWidth
            )
            metricTile(
                abbrev: "RHR",
                systemImage: "heart.fill",
                value: snapshot.restingHRBpm.map { String($0) } ?? "—",
                unit: "bpm",
                metadata: snapshot.restingHRMetadata,
                hasValue: snapshot.restingHRBpm != nil,
                gaugeProgress: HealthMetricDisplayScale.progress(for: snapshot.restingHRBpm.map { Double($0) }, within: 0...220),
                color: R0llingTheme.healthMonitorGaugeGreen,
                spokenMetricName: "Καρδιακός ρυθμός ηρεμίας",
                minimumWidth: minimumTileWidth
            )
            metricTile(
                abbrev: "HRV",
                systemImage: "waveform.path.ecg",
                value: formattedMeasurement(snapshot.hrvMs, format: "%.0f"),
                unit: "ms",
                metadata: snapshot.hrvMetadata,
                hasValue: hasValidMeasurement(snapshot.hrvMs),
                gaugeProgress: HealthMetricDisplayScale.progress(for: snapshot.hrvMs, within: 0...200),
                color: R0llingTheme.healthMonitorGaugeGreen,
                spokenMetricName: "Μεταβλητότητα καρδιακού ρυθμού",
                minimumWidth: minimumTileWidth
            )
            metricTile(
                abbrev: "SpO2",
                systemImage: "drop.fill",
                value: formattedMeasurement(snapshot.bloodOxygenPercent, format: "%.1f"),
                unit: "%",
                metadata: snapshot.bloodOxygenMetadata,
                hasValue: hasValidMeasurement(snapshot.bloodOxygenPercent),
                gaugeProgress: HealthMetricDisplayScale.progress(for: snapshot.bloodOxygenPercent, within: 0...100),
                color: R0llingTheme.healthMonitorGaugeBlue,
                spokenMetricName: "Κορεσμός οξυγόνου στο αίμα",
                minimumWidth: minimumTileWidth
            )
            metricTile(
                abbrev: "Temp",
                systemImage: "thermometer.medium",
                value: formattedMeasurement(snapshot.bodyTemperatureCelsius, format: "%.1f"),
                unit: "°C",
                metadata: snapshot.bodyTemperatureMetadata,
                hasValue: hasValidMeasurement(snapshot.bodyTemperatureCelsius),
                gaugeProgress: HealthMetricDisplayScale.progress(for: snapshot.bodyTemperatureCelsius, within: 30...43),
                color: R0llingTheme.healthMonitorGaugeGreen,
                spokenMetricName: "Θερμοκρασία σώματος",
                minimumWidth: minimumTileWidth
            )
            metricTile(
                abbrev: "Sleep",
                systemImage: "bed.double.fill",
                value: sleepDisplay.value,
                unit: sleepDisplay.unit,
                metadata: snapshot.sleepMetadata,
                hasValue: snapshot.sleepHours.map { $0.isFinite && $0 >= 0 && $0 <= Double(Int.max / 60) } == true,
                gaugeProgress: HealthMetricDisplayScale.progress(for: snapshot.sleepHours, within: 0...12),
                color: R0llingTheme.healthMonitorGaugeGreen,
                spokenMetricName: "Διάρκεια ύπνου",
                minimumWidth: minimumTileWidth,
                action: snapshot.sleepReport == nil ? nil : { isSleepReportPresented = true }
            )
        }
    }

    @ViewBuilder
    private func metricTile(
        abbrev: String,
        systemImage: String,
        value: String,
        unit: String,
        metadata: HealthKitReadingMetadata?,
        hasValue: Bool,
        gaugeProgress: Double?,
        color: Color,
        spokenMetricName: String,
        minimumWidth: CGFloat?,
        action: (() -> Void)? = nil
    ) -> some View {
        let tile = BevelMetricTile(
            abbrev: abbrev,
            systemImage: systemImage,
            value: value,
            unit: unit,
            status: measurementStatus(for: metadata, hasValue: hasValue),
            color: color,
            spokenMetricName: spokenMetricName,
            gaugeProgress: gaugeProgress
        )
        if let minimumWidth, let action {
            Button(action: action) {
                tile.frame(minWidth: minimumWidth)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Ανοίγει τις καταγεγραμμένες φάσεις ύπνου.")
        } else if let minimumWidth {
            tile.frame(minWidth: minimumWidth)
        } else if let action {
            Button(action: action) {
                tile
            }
            .buttonStyle(.plain)
            .accessibilityHint("Ανοίγει τις καταγεγραμμένες φάσεις ύπνου.")
        } else {
            tile
        }
    }

    private var sleepDisplay: (value: String, unit: String) {
        guard let hours = snapshot.sleepHours,
              hours.isFinite,
              hours >= 0,
              hours <= Double(Int.max / 60) else {
            return ("—", "")
        }
        let totalMinutes = Int((hours * 60).rounded())
        return ("\(totalMinutes / 60)h \(totalMinutes % 60)m", "")
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

    private func hasValidMeasurement(_ value: Double?) -> Bool {
        guard let value else { return false }
        return value.isFinite && value >= 0
    }

    private func formattedMeasurement(_ value: Double?, format: String) -> String {
        guard hasValidMeasurement(value), let value else { return "—" }
        return String(format: format, value)
    }
}

/// Compact Bevel-style Home preview. The values remain recent HealthKit readings,
/// not measurements for a journal date selected in the past.
public struct TodayHealthSummaryCard: View {
    public let snapshot: HealthKitTelemetrySnapshot
    public var didCompleteAuthorizationRequest: Bool
    public var onRequestAuth: (() -> Void)?
    public var onOpenHealth: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        snapshot: HealthKitTelemetrySnapshot,
        didCompleteAuthorizationRequest: Bool = false,
        onRequestAuth: (() -> Void)? = nil,
        onOpenHealth: (() -> Void)? = nil
    ) {
        self.snapshot = snapshot
        self.didCompleteAuthorizationRequest = didCompleteAuthorizationRequest
        self.onRequestAuth = onRequestAuth
        self.onOpenHealth = onOpenHealth
    }

    public var body: some View {
        let access = HealthKitAccessPresentation.resolve(
            hasMeasurements: snapshot.hasReadings,
            didCompleteRequest: didCompleteAuthorizationRequest
        )

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Health Monitor")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button("Όλες οι μετρήσεις", action: { onOpenHealth?() })
                    .font(.caption.weight(.semibold))
                    .foregroundColor(R0llingTheme.accentLavender)
                    .frame(minHeight: 44)
                    .accessibilityHint("Ανοίγει τις λεπτομερείς μετρήσεις Apple Health.")
            }

            VStack(alignment: .leading, spacing: 12) {
                metricGrid

                Text("Πρόσφατες μετρήσεις Apple Health · όχι κλινική αξιολόγηση")
                    .font(.caption2)
                    .foregroundColor(R0llingTheme.textMuted)

                if !snapshot.hasReadings {
                    if access.shouldShowRequestButton {
                        Button(action: { onRequestAuth?() }) {
                            Text("ΑΙΤΗΜΑ ΠΡΟΣΒΑΣΗΣ")
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundColor(R0llingTheme.textPrimary)
                                .r0llingBevelCapsule()
                        }
                        .buttonStyle(.plain)
                    } else if let explanation = access.explanation {
                        Text(explanation)
                            .font(.caption)
                            .foregroundColor(R0llingTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(14)
            .r0llingBevelSurface(cornerRadius: 18)
        }
    }

    @ViewBuilder
    private var metricGrid: some View {
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            metricTile(
                abbrev: "HRV",
                systemImage: "waveform.path.ecg",
                value: formatted(snapshot.hrvMs, format: "%.0f"),
                unit: "ms",
                metadata: snapshot.hrvMetadata,
                color: R0llingTheme.healthMonitorGaugeGreen,
                scale: HealthMetricDisplayScale.progress(for: snapshot.hrvMs, within: 0...200),
                spokenName: "Μεταβλητότητα καρδιακού ρυθμού"
            )
            metricTile(
                abbrev: "RHR",
                systemImage: "heart.fill",
                value: snapshot.restingHRBpm.map { String($0) } ?? "—",
                unit: "bpm",
                metadata: snapshot.restingHRMetadata,
                color: R0llingTheme.healthMonitorGaugeGreen,
                scale: HealthMetricDisplayScale.progress(for: snapshot.restingHRBpm.map { Double($0) }, within: 0...220),
                spokenName: "Καρδιακός ρυθμός ηρεμίας"
            )
            metricTile(
                abbrev: "SLEEP",
                systemImage: "bed.double.fill",
                value: sleepText,
                unit: "",
                metadata: snapshot.sleepMetadata,
                color: R0llingTheme.healthMonitorGaugeGreen,
                scale: HealthMetricDisplayScale.progress(for: snapshot.sleepHours, within: 0...12),
                spokenName: "Διάρκεια ύπνου"
            )
        }
    }

    private func metricTile(
        abbrev: String,
        systemImage: String,
        value: String,
        unit: String,
        metadata: HealthKitReadingMetadata?,
        color: Color,
        scale: Double?,
        spokenName: String
    ) -> some View {
        let hasValue = value != "—"
        return BevelMetricTile(
            abbrev: abbrev,
            systemImage: systemImage,
            value: value,
            unit: unit,
            status: readingStatus(metadata, hasValue: hasValue),
            color: color,
            spokenMetricName: spokenName,
            gaugeProgress: scale
        )
    }

    private var sleepText: String {
        guard let hours = snapshot.sleepHours, hours.isFinite, hours >= 0, hours < Double(Int.max / 60) else {
            return "—"
        }
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }

    private func formatted(_ value: Double?, format: String) -> String {
        guard let value, value.isFinite, value >= 0 else { return "—" }
        return String(format: format, value)
    }

    private func readingStatus(_ metadata: HealthKitReadingMetadata?, hasValue: Bool) -> String {
        guard hasValue else { return "Χωρίς πρόσφατη μέτρηση" }
        guard let metadata else { return "Δεν υπάρχει ώρα ή πηγή" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "el")
        let age = formatter.localizedString(for: metadata.measuredAt, relativeTo: snapshot.queriedAt)
        return "\(age) · \(metadata.sourceName.isEmpty ? "Άγνωστη πηγή" : metadata.sourceName)"
    }
}

public struct BevelMetricTile: View {
    public let abbrev: String
    public let systemImage: String?
    public let value: String
    public let unit: String
    public let status: String
    public let color: Color
    public let spokenMetricName: String?
    public let gaugeProgress: Double?

    public init(
        abbrev: String,
        systemImage: String? = nil,
        value: String,
        unit: String,
        status: String,
        color: Color,
        spokenMetricName: String? = nil,
        gaugeProgress: Double? = nil
    ) {
        self.abbrev = abbrev
        self.systemImage = systemImage
        self.value = value
        self.unit = unit
        self.status = status
        self.color = color
        self.spokenMetricName = spokenMetricName
        self.gaugeProgress = gaugeProgress
    }

    public var body: some View {
        HStack(spacing: 9) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(R0llingTheme.textMuted)
                    }
                    Text(abbrev)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(R0llingTheme.textMuted)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
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
                    .foregroundColor(R0llingTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            BevelMetricRangeGauge(progress: gaugeProgress, color: color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .center)
        .r0llingBevelSurface(cornerRadius: 14, fillColor: R0llingTheme.healthMonitorTileSurface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let name = spokenMetricName ?? abbrev
        let spokenValue = value == "—" ? "Δεν υπάρχει τιμή" : "\(value) \(unit)"
        let scaleNote = gaugeProgress == nil
            ? ""
            : " Η μπάρα δείχνει θέση στην κλίμακα εμφάνισης, όχι κλινικό εύρος."
        return "\(name). \(spokenValue). \(status).\(scaleNote)"
    }
}

private struct BevelMetricRangeGauge: View {
    let progress: Double?
    let color: Color

    private var boundedProgress: Double? {
        guard let progress, progress.isFinite else { return nil }
        return min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Capsule()
                    .fill(R0llingTheme.healthMonitorGaugeTrack)
                    .frame(width: 7, height: geometry.size.height)

                if let progress = boundedProgress {
                    let inset: CGFloat = 6
                    let trackHeight = max(0, geometry.size.height - inset * 2)
                    Capsule()
                        .fill(color)
                        .frame(width: 5, height: trackHeight)

                    Capsule()
                        .fill(color)
                        .frame(width: 8, height: 3)
                        .position(x: geometry.size.width / 2, y: inset)

                    Capsule()
                        .fill(color)
                        .frame(width: 8, height: 3)
                        .position(x: geometry.size.width / 2, y: geometry.size.height - inset)

                    Circle()
                        .fill(R0llingTheme.bgElevated)
                        .overlay(Circle().stroke(color, lineWidth: 2))
                        .frame(width: 10, height: 10)
                        .position(
                            x: geometry.size.width / 2,
                            y: inset + trackHeight * (1 - progress)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 16, height: 64)
        .accessibilityHidden(true)
    }
}
