import SwiftUI

/// Καρτέλα Βιο-Απόδοσης (Biohacking, Workouts & Autonomic Recovery Hub)
public struct BiohackingHubView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isPreviewsExpanded = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Βιο-Απόδοση & Ανάκαμψη")
                        .font(.title2.weight(.bold))
                        .foregroundColor(R0llingTheme.textPrimary)
                    Text("HealthKit και εργαλεία ευεξίας")
                        .font(.footnote)
                        .foregroundColor(R0llingTheme.textSecondary)
                }
                Spacer()
                Circle()
                    .fill(appState.liveHealthSnapshot.hasReadings ? R0llingTheme.statusSuccess : R0llingTheme.accentLavender)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(
                        appState.liveHealthSnapshot.hasReadings
                            ? "Μετρήσεις Apple Health διαθέσιμες"
                            : "Δεν υπάρχουν διαθέσιμες μετρήσεις Apple Health"
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(R0llingTheme.bgPrimary)

            ScrollView {
                LazyVStack(spacing: 16) {
                    // Bevel Health Monitor grid using only real, available HealthKit samples.
                    HealthKitTelemetryCardView(
                        snapshot: appState.liveHealthSnapshot,
                        didCompleteAuthorizationRequest: appState.didCompleteHealthKitAccessRequest,
                        onRequestAuth: {
                            Task {
                                await appState.requestHealthKitAccess()
                            }
                        }
                    )

                    // Local tools with working controls and no fabricated health readings.
                    BinauralSynthesizerCardView()
                    BoxBreathingWidgetCard()

                    DisclosureGroup(isExpanded: $isPreviewsExpanded) {
                        LazyVStack(spacing: 14) {
                            PrototypeNotice()
                            SwimCadenceLactateCardView()
                            AutonomicToneCardView()
                            FastingAutophagyCardView()
                            GymVolumeLoggerCardView()
                            CircadianSunlightCardView()
                        }
                        .padding(.top, 10)
                    } label: {
                        Label("Προεπισκοπήσεις λειτουργιών", systemImage: "sparkles")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(R0llingTheme.textPrimary)
                    }
                    .tint(R0llingTheme.accentLavender)
                    .padding(14)
                    .r0llingBevelSurface(cornerRadius: 18)
                }
                .padding(16)
            }
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
    }
}

public struct SwimCadenceLactateCardView: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Κολύμβηση: Cadence & DPS Pacer", systemImage: "figure.pool.swim")
                    .font(.headline.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("ΠΡΟΕΠΙΣΚΟΠΗΣΗ")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(R0llingTheme.accentCyan)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    swimMetric("CADENCE", value: "—", unit: "SPM", color: R0llingTheme.accentCyan)
                    Spacer(minLength: 0)
                    swimMetric("DISTANCE / STROKE", value: "—", unit: "m/str", color: R0llingTheme.statusSuccess)
                    Spacer(minLength: 0)
                    swimMetric("LACTATE", value: "—", unit: "mmol", color: R0llingTheme.accentLavender)
                }
                VStack(alignment: .leading, spacing: 12) {
                    swimMetric("CADENCE", value: "—", unit: "SPM", color: R0llingTheme.accentCyan)
                    swimMetric("DISTANCE / STROKE", value: "—", unit: "m/str", color: R0llingTheme.statusSuccess)
                    swimMetric("LACTATE", value: "—", unit: "mmol", color: R0llingTheme.accentLavender)
                }
            }
            Text("Δεν υπάρχει συνδεδεμένη πηγή για αυτές τις μετρήσεις.")
                .font(.footnote)
                .foregroundColor(R0llingTheme.textSecondary)
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 18)
    }

    private func swimMetric(_ title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundColor(R0llingTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundColor(color)
                Text(unit)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(R0llingTheme.textMuted)
            }
        }
    }
}

public struct AutonomicToneCardView: View {
    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(R0llingTheme.textMuted)
                    Text("ΑΥΤΟΝΟΜΟΣ ΤΟΝΟΣ · ΜΗ ΔΙΑΘΕΣΙΜΟ")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundColor(R0llingTheme.textMuted)
                }
                Text("Δεν υπάρχει συνδεδεμένη μέτρηση για εκτίμηση ανάκαμψης ή αυτόνομου τόνου.")
                    .font(.footnote)
                    .foregroundColor(R0llingTheme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .r0llingBevelSurface(cornerRadius: 16)
    }
}

public struct FastingAutophagyCardView: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Νηστεία & Κυτταρική Αυτοφαγία", systemImage: "flame.fill")
                    .font(.headline.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("ΠΡΟΕΠΙΣΚΟΠΗΣΗ")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(R0llingTheme.accentCyan)
            }

            HStack {
                Text("— hrs")
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundColor(R0llingTheme.accentCyan)
                Spacer()
                Text("Ο χρόνος νηστείας δεν καταγράφεται από την εφαρμογή.")
                    .font(.footnote)
                    .foregroundColor(R0llingTheme.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 18)
    }
}

public struct BoxBreathingWidgetCard: View {
    @State private var isRunning = false
    @State private var cycleStart = Date()

    public var body: some View {
        HStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let phase = phaseState(at: context.date)
                ZStack {
                    Circle()
                        .stroke(R0llingTheme.borderSubtle, lineWidth: 4)
                        .frame(width: 50, height: 50)
                    Circle()
                        .fill(R0llingTheme.accentCyan.opacity(0.3))
                        .frame(width: phase.expanded ? 42 : 24, height: phase.expanded ? 42 : 24)
                        .animation(.easeInOut(duration: 4), value: phase.expanded)
                }
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Box Breathing 4x4")
                    .font(.headline.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(isRunning ? phaseState(at: context.date).title : "Έτοιμο")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(R0llingTheme.accentLavender)
                }
            }
            Spacer(minLength: 4)
            Button {
                if isRunning {
                    isRunning = false
                } else {
                    cycleStart = Date()
                    isRunning = true
                }
            } label: {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(.body, design: .default).weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .r0llingBevelCapsule()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRunning ? "Παύση box breathing" : "Έναρξη box breathing")
            .accessibilityHint("Οδηγός τεσσάρων φάσεων, τέσσερα δευτερόλεπτα ανά φάση")
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 18)
    }

    private func phaseState(at date: Date) -> (title: String, expanded: Bool) {
        guard isRunning else { return ("Έτοιμο", false) }
        let elapsed = max(0, date.timeIntervalSince(cycleStart))
        let phaseIndex = Int(elapsed / 4) % 4
        switch phaseIndex {
        case 0: return ("Εισπνοή · 4s", true)
        case 1: return ("Κράτημα · 4s", true)
        case 2: return ("Εκπνοή · 4s", false)
        default: return ("Κράτημα · 4s", false)
        }
    }
}

public struct CircadianSunlightCardView: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Κιρκάδιος Ήλιος & Καφεΐνη", systemImage: "sun.max.fill")
                    .font(.headline.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("ΠΡΟΕΠΙΣΚΟΠΗΣΗ")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(R0llingTheme.accentLavender)
            }
            Text("Η έκθεση σε φως και η κατανάλωση καφεΐνης δεν παρακολουθούνται.")
                .font(.footnote)
                .foregroundColor(R0llingTheme.textSecondary)
        }
        .padding(14)
        .r0llingBevelSurface(cornerRadius: 16)
    }
}
