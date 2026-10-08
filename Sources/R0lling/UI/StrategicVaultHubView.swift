import SwiftUI

/// Καρτέλα Στρατηγείου & Κρυπτογραφικού Vault (Strategic Decisions & Sovereign Security Hub)
public struct StrategicVaultHubView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Στρατηγείο & Ασφαλές Vault")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(R0llingTheme.textPrimary)
                    Text("ZERO-KNOWLEDGE // AIR-GAPPED DEFENSES")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(R0llingTheme.accentCyan)
                }
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18))
                    .foregroundColor(R0llingTheme.statusSuccess)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(R0llingTheme.bgSurface)

            ScrollView {
                LazyVStack(spacing: 16) {
                    // Air-Gapped Firewall Status Pill
                    AirGappedStatusBanner()

                    // Zero-Knowledge Encrypted Diary (FaceID Locked)
                    EncryptedDiaryCardView(secretContent: "Στρατηγικό σχέδιο εξαγοράς και αρχιτεκτονικής L4NE Sovereign Core.")

                    // Strategic Decision Journal (90-Day Audit)
                    DecisionRecordCardView(decision: DecisionRecord(
                        decisionText: "Μετάβαση σε 100% On-Device Sovereign OS",
                        coreAssumptions: ["Μηδενικό cloud latency", "Απόλυτη προστασία IP"],
                        confidencePercent: 95
                    ))

                    // Personal Board of Advisors (Marcus Aurelius, Jobs, Munger)
                    AdvisoryBoardCardView()

                    // Stoic Principles & Daily Compass
                    StoicPrinciplesCardView()

                    // Future Letterbox Capsule
                    FutureLetterboxWidgetCard()
                }
                .padding(16)
            }
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
    }
}

public struct AirGappedStatusBanner: View {
    public var body: some View {
        HStack {
            Circle().fill(R0llingTheme.statusSuccess).frame(width: 8, height: 8)
            Text("AIR-GAPPED FIREWALL: ACTIVE (0 B OUTBOUND)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(R0llingTheme.statusSuccess)
            Spacer()
            Text("LAN ONLY")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(R0llingTheme.textMuted)
        }
        .padding(12)
        .background(R0llingTheme.bgSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(R0llingTheme.borderSubtle, lineWidth: 0.5))
    }
}

public struct AdvisoryBoardCardView: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Προσωπικό Συμβούλιο (Board of Advisors)", systemImage: "person.3.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("COUNCIL")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
            }

            VStack(alignment: .leading, spacing: 8) {
                AdvisorRow(name: "Μάρκος Αυρήλιος", advice: "«Έλεγξε μόνο ό,τι εξαρτάται από τη δική σου κρίση.»")
                AdvisorRow(name: "Steve Jobs", advice: "«Αφαίρεσε το περιττό. Κάνε το απλό και μαγικό.»")
                AdvisorRow(name: "Charlie Munger", advice: "«Αντίστρεψε πάντα. Πώς θα εξασφάλιζες την αποτυχία;»")
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

public struct AdvisorRow: View {
    let name: String
    let advice: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(R0llingTheme.accentCyan)
            Text(advice)
                .font(.system(size: 12))
                .foregroundColor(R0llingTheme.textSecondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(R0llingTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

public struct StoicPrinciplesCardView: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Στωική Πυξίδα & Αρχές", systemImage: "compass.drawing")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("AMOR FATI")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
            }
            Text("«Μην απαιτείς τα πράγματα να συμβαίνουν όπως θέλεις, αλλά αποδέξου τα όπως συμβαίνουν.»")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(R0llingTheme.textPrimary)
            Text("Επίκτητος · Εγχειρίδιον")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(R0llingTheme.textMuted)
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

public struct FutureLetterboxWidgetCard: View {
    public var body: some View {
        HStack {
            Image(systemName: "lock.seal.fill")
                .font(.system(size: 24))
                .foregroundColor(R0llingTheme.accentPurple)

            VStack(alignment: .leading, spacing: 2) {
                Text("Σφραγισμένο Μήνυμα στο Μέλλον")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Text("⏳ Ξεκλείδωμα σε 48 ημέρες")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
            }
            Spacer()
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
