import SwiftUI

/// Καρτέλα Δημιουργίας & Δεύτερου Εγκεφάλου (Creative Studio & Obsidian Zettelkasten Hub)
public struct CreativeStudioHubView: View {
    @EnvironmentObject private var appState: AppState
    @State private var rawIdeaText: String = ""
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Δημιουργικό Studio & Νους")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(R0llingTheme.textPrimary)
                    Text("OBSIDIAN ZETTELKASTEN // MULTI-FORMAT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(R0llingTheme.accentPurple)
                }
                Spacer()
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundColor(R0llingTheme.accentLavender)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(R0llingTheme.bgSurface)

            ScrollView {
                LazyVStack(spacing: 16) {
                    // Obsidian Zettelkasten Live Strip
                    ZettelkastenChipStripView()

                    // ECE Engineering Solver & Datapath Resolver
                    ECEEngineeringSolverCardView()

                    // Multi-Platform Content Transformer Card
                    ContentTransformerCardView()

                    // Dominant Hex Moodboard Swatches Card
                    MoodboardSwatchesCardView()

                    // Logic Fallacy & Bias Auditor Card
                    LogicFallacyAuditorCardView()

                    // Subconscious Dream Correlation Card
                    DreamCorrelationCardView()
                }
                .padding(16)
            }
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
    }
}

public struct ECEEngineeringSolverCardView: View {
    @State private var instruction: String = "lw $t0, 4($s1)"
    @State private var signals: String = "MemtoReg=1, ALUSrc=1, RegWrite=1 (5 Cycles)"

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("ECE Systems & Datapath Resolver", systemImage: "cpu.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("RISC-V // MIPS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentPurple)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(instruction)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentCyan)
                Text("Ανάλυση Σημάτων: \(signals)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(R0llingTheme.textSecondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(R0llingTheme.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

public struct ContentTransformerCardView: View {
    @State private var selectedFormat: Int = 0
    @State private var sourceIdea: String = "Η συνέπεια ξεπερνά την ένταση μακροπρόθεσμα."

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Multi-Platform Transformer", systemImage: "arrow.triangle.branch")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("ONE-TAP EXPORT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentCyan)
            }

            Picker("Format", selection: $selectedFormat) {
                Text("X Thread").tag(0)
                Text("LinkedIn").tag(1)
                Text("Newsletter").tag(2)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                if selectedFormat == 0 {
                    Text("1/3 \(sourceIdea)")
                    Text("2/3 Μικρά atomic βήματα καθημερινά οδηγούν σε εκθετικά αποτελέσματα.")
                    Text("3/3 Καταγεγραμμένο στο R0lling Sovereign OS.")
                } else if selectedFormat == 1 {
                    Text("💡 Στρατηγικό Insight:")
                    Text(sourceIdea)
                    Text("#Engineering #Execution #Sovereignty")
                } else {
                    Text("## Εβδομαδιαίο Insight")
                    Text(sourceIdea)
                    Text("*Αρχείο: L4NE Sovereign Architecture.*")
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(R0llingTheme.textSecondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(R0llingTheme.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                R0llingTheme.triggerHapticFeedback()
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc.fill")
                    Text("Αντιγραφή Μορφοποίησης")
                }
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(R0llingTheme.accentPurple)
                .foregroundColor(.white)
                .clipShape(Capsule())
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

public struct MoodboardSwatchesCardView: View {
    let colors = ["#16161D", "#7742DC", "#00E5FF", "#A78BFA", "#55D6A4"]

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Moodboard & Hex Extractor", systemImage: "paintpalette.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("5 DOMINANT SWATCHES")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
            }

            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { hex in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: UInt(hex.dropFirst(), radix: 16) ?? 0))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(R0llingTheme.borderSubtle, lineWidth: 1))
                        Text(hex)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(R0llingTheme.textMuted)
                    }
                }
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

public struct LogicFallacyAuditorCardView: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Έλεγχος Λογικών Πλανών (Auditor)", systemImage: "shield.lefthalf.filled")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("RATIONAL COMPASS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentCyan)
            }
            Text("«Πάντα αποτυγχάνω αφού έχω ήδη ξοδέψει τόσο χρόνο...»")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(R0llingTheme.accentLavender)

            HStack {
                Text("Εντοπίστηκε:")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(R0llingTheme.statusError)
                Text("Sunk Cost Fallacy & Black-or-White Thinking")
                    .font(.system(size: 11))
                    .foregroundColor(R0llingTheme.textSecondary)
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

public struct DreamCorrelationCardView: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Υποσυνείδητα Μοτίβα Ονείρων", systemImage: "moon.stars.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("CLUSTER 76%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
            }
            Text("Συσχέτιση: Όνειρα με νερό/ωκεανό συσχετίζονται με κατανάλωση καφεΐνης μετά τις 16:00.")
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
