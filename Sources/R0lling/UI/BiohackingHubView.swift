import SwiftUI

/// Καρτέλα Βιο-Απόδοσης (Biohacking, Workouts & Autonomic Recovery Hub)
public struct BiohackingHubView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSubtab: Int = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Βιο-Απόδοση & Ανάκαμψη")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(R0llingTheme.textPrimary)
                    Text("LIVE APPLE HEALTH & NEURO-PACING")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(R0llingTheme.accentCyan)
                }
                Spacer()
                Circle()
                    .fill(appState.isHealthKitAuthorized ? R0llingTheme.statusSuccess : R0llingTheme.accentLavender)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(R0llingTheme.bgSurface)

            ScrollView {
                LazyVStack(spacing: 16) {
                    // Full Bevel 2x3 Health Monitor Grid
                    HealthKitTelemetryCardView(
                        snapshot: appState.liveHealthSnapshot,
                        isAuthorized: appState.isHealthKitAuthorized,
                        onRequestAuth: {
                            Task {
                                await appState.requestHealthKitAccess()
                            }
                        }
                    )

                    // Autophagy & Fasting Stage Card
                    FastingAutophagyCardView()

                    // Gym Barbell Velocity & Iron Volume
                    GymVolumeLoggerCardView()

                    // Deep Work & Binaural Waves
                    BinauralSynthesizerCardView()

                    // Box Breathing 4x4 & Cold Plunge
                    BoxBreathingWidgetCard()

                    // Circadian Sunlight & Caffeine Window
                    CircadianSunlightCardView()
                }
                .padding(16)
            }
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
    }
}

public struct FastingAutophagyCardView: View {
    @State private var hoursFasted: Double = 16.5

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Νηστεία & Κυτταρική Αυτοφαγία", systemImage: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("AUTOPHAGY ACTIVE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentCyan)
            }

            HStack {
                Text(String(format: "%.1f hrs", hoursFasted))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentCyan)
                Spacer()
                Text("Ζώνη 3: Ενεργή απομάκρυνση κατεστραμμένων πρωτεϊνών")
                    .font(.system(size: 11))
                    .foregroundColor(R0llingTheme.textSecondary)
                    .multilineTextAlignment(.trailing)
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

public struct BoxBreathingWidgetCard: View {
    @State private var phaseText: String = "Εισπνοή (4s)"
    @State private var isAnimating: Bool = false

    public var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(R0llingTheme.borderSubtle, lineWidth: 4)
                    .frame(width: 50, height: 50)
                Circle()
                    .fill(R0llingTheme.accentCyan.opacity(0.3))
                    .frame(width: isAnimating ? 42 : 24, height: isAnimating ? 42 : 24)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: isAnimating)
            }
            .onAppear { isAnimating = true }

            VStack(alignment: .leading, spacing: 2) {
                Text("Box Breathing 4x4")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Text(phaseText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
            }
            Spacer()
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

public struct CircadianSunlightCardView: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Κιρκάδιος Ήλιος & Καφεΐνη", systemImage: "sun.max.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("CUTOFF: 16:00")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
            }
            Text("Έκθεση σε φυσικό φως: 20 min ολοκληρώθηκαν. Παράθυρο καφεΐνης κλείνει σε 2 ώρες.")
                .font(.system(size: 12))
                .foregroundColor(R0llingTheme.textSecondary)
        }
        .padding(14)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}
