import SwiftUI
import UniformTypeIdentifiers

/// Telemetry & Diagnostics Dashboard (Developer & Power-User Observability)
/// Emfanizei se pragmatiko xrono ta simvanta tou in-memory ring buffer me filtra katigorias/stathmis,
/// metrics diarkeias, eksagwgi plirous JSON diagnwstikou bundle kai epivevaiwsi katharismou.
public struct TelemetryDashboardView: View {
    @State private var epilegmeniKatigoria: R0llingTelemetry.Katigoria? = nil
    @State private var epilegmeniStathmi: R0llingTelemetry.StathmiLog? = nil
    @State private var simvanta: [R0llingTelemetry.TelemetrySimvan] = []
    @State private var deixeiEpivevaiwsiKatharismou: Bool = false
    @State private var diagnwstikoJSONKeimeno: String = ""
    @State private var emfaniseKopiasteToast: Bool = false
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    private let telemetry = R0llingTelemetry.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Filtra & Epiloges
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    // Katigoria Filter
                    Picker("Κατηγορία", selection: $epilegmeniKatigoria) {
                        Text("Όλες οι Κατηγορίες").tag(R0llingTelemetry.Katigoria?.none)
                        ForEach(R0llingTelemetry.Katigoria.allCases, id: \.self) { kat in
                            Text(kat.rawValue).tag(R0llingTelemetry.Katigoria?.some(kat))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(minHeight: 44)
                    .padding(.horizontal, 10)
                    .background(R0llingTheme.bgElevated)
                    .cornerRadius(10)

                    // Stathmi Filter
                    Picker("Στάθμη", selection: $epilegmeniStathmi) {
                        Text("Όλες οι Στάθμες").tag(R0llingTelemetry.StathmiLog?.none)
                        ForEach(R0llingTelemetry.StathmiLog.allCases, id: \.self) { stathmi in
                            Text(stathmi.rawValue).tag(R0llingTelemetry.StathmiLog?.some(stathmi))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(minHeight: 44)
                    .padding(.horizontal, 10)
                    .background(R0llingTheme.bgElevated)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Metrites & Energeies
                HStack {
                    Text("\(simvanta.count) συμβάντα (όριο: 250)")
                        .font(.system(size: 12 * typeScale, weight: .medium, design: .monospaced))
                        .foregroundColor(R0llingTheme.textSecondary)

                    Spacer()

                    // Koumpi Eksagwgis JSON
                    if let data = telemetry.paragogiDiagnwstikouJSON(),
                       let jsonString = String(data: data, encoding: .utf8) {
                        ShareLink(
                            item: jsonString,
                            subject: Text("R0lling Telemetry Diagnostic Bundle"),
                            message: Text("Εξαγωγή διαγνωστικών συμβάντων telemetry σε JSON.")
                        ) {
                            Label("Εξαγωγή JSON", systemImage: "square.and.arrow.up")
                                .font(.system(size: 12 * typeScale, weight: .semibold))
                                .foregroundColor(R0llingTheme.accentCyan)
                        }
                        .frame(minHeight: 44)
                    }

                    // Koumpi Katharismou
                    Button(action: {
                        deixeiEpivevaiwsiKatharismou = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14 * typeScale))
                            .foregroundColor(R0llingTheme.statusError)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Καθαρισμός Buffer Τηλεμετρίας")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            .background(R0llingTheme.bgSurface)

            Divider()
                .background(R0llingTheme.borderSubtle)

            // MARK: - Lista Simvantwn
            if simvanta.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 40))
                        .foregroundColor(R0llingTheme.textMuted)
                    Text("Δεν υπάρχουν καταγεγραμμένα συμβάντα με τα επιλεγμένα φίλτρα.")
                        .font(.system(size: 13 * typeScale))
                        .foregroundColor(R0llingTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(simvanta.reversed()) { simvan in
                            grammiSimvantos(simvan)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
        .navigationTitle("Τηλεμετρία & Logs")
        .r0llingFormSurface()
        .confirmationDialog(
            "Είστε σίγουροι ότι θέλετε να καθαρίσετε το buffer τηλεμετρίας;",
            isPresented: $deixeiEpivevaiwsiKatharismou,
            titleVisibility: .visible
        ) {
            Button("Καθαρισμός Όλων", role: .destructive) {
                telemetry.katharismosBuffer()
                ananeosiSimvantwn()
            }
            Button("Άκυρο", role: .cancel) {}
        }
        .onAppear {
            ananeosiSimvantwn()
        }
        .onChange(of: epilegmeniKatigoria) { _, _ in
            ananeosiSimvantwn()
        }
        .onChange(of: epilegmeniStathmi) { _, _ in
            ananeosiSimvantwn()
        }
    }

    // MARK: - Grammi Simvantos
    private func grammiSimvantos(_ simvan: R0llingTelemetry.TelemetrySimvan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                // Badge Stathmis
                badgeStathmis(simvan.stathmi)

                // Katigoria Tag
                Text(simvan.katigoria.rawValue)
                    .font(.system(size: 10 * typeScale, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(R0llingTheme.bgElevated)
                    .foregroundColor(R0llingTheme.textPrimary)
                    .cornerRadius(4)

                Spacer()

                // Xronosigmh
                Text(morfopoihshXronou(simvan.xronosigmh))
                    .font(.system(size: 10 * typeScale, design: .monospaced))
                    .foregroundColor(R0llingTheme.textSecondary)

                // Diarkeia Ms
                if let ms = simvan.diarkeiaMs {
                    Text("\(String(format: "%.1f", ms))ms")
                        .font(.system(size: 10 * typeScale, weight: .semibold, design: .monospaced))
                        .foregroundColor(R0llingTheme.accentAmber)
                        .padding(.horizontal, 4)
                        .background(R0llingTheme.bgInset)
                        .cornerRadius(3)
                }
            }

            // Minima Simvantos
            Text(simvan.minima)
                .font(.system(size: 12 * typeScale, design: .monospaced))
                .foregroundColor(R0llingTheme.textPrimary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(minHeight: 44, alignment: .leading)
        .background(R0llingTheme.bgSurface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(R0llingTheme.borderSubtle.opacity(0.6), lineWidth: 1)
        )
    }

    // MARK: - Badge Stathmis
    private func badgeStathmis(_ stathmi: R0llingTelemetry.StathmiLog) -> some View {
        let (xroma, fontXroma): (Color, Color) = {
            switch stathmi {
            case .debug:
                return (R0llingTheme.bgElevated, R0llingTheme.textSecondary)
            case .info:
                return (R0llingTheme.statusLive.opacity(0.2), R0llingTheme.statusLive)
            case .notice:
                return (R0llingTheme.accentPurple.opacity(0.2), R0llingTheme.accentLavender)
            case .warning:
                return (R0llingTheme.statusWarning.opacity(0.2), R0llingTheme.statusWarning)
            case .error, .fault:
                return (R0llingTheme.statusError.opacity(0.2), R0llingTheme.statusError)
            }
        }()

        return Text(stathmi.rawValue)
            .font(.system(size: 9 * typeScale, weight: .heavy, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(xroma)
            .foregroundColor(fontXroma)
            .cornerRadius(4)
    }

    // MARK: - Helpers
    private func ananeosiSimvantwn() {
        simvanta = telemetry.laveFiltraSimvanta(
            katigoria: epilegmeniKatigoria,
            stathmi: epilegmeniStathmi
        )
    }

    private func morfopoihshXronou(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
