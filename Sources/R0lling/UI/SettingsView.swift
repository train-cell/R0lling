import SwiftUI
import UniformTypeIdentifiers

/// Οθόνη ρυθμίσεων (Settings View)
public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var bufferDurationSelection: Double = 10.0
    @State private var simulationMode: Bool = true
    @State private var selectedAIProvider: AIProviderType = .directAPI
    @State private var directEndpointURL: String = "https://api.openai.com/v1"
    @State private var directModelName: String = "gpt-4o-mini"
    @State private var directAPIKey: String = ""
    @State private var hermesEndpointURL: String = "https://127.0.0.1:8080/v1"
    @State private var hermesToken: String = ""
    @State private var deixeiEpilogiVault: Bool = false
    @State private var deixeiEpilogiBackup: Bool = false

    public var body: some View {
        NavigationView {
            Form {
                // Section 1: Meta Glasses Gen 2
                Section(header: Text("Meta Glasses Gen 2")) {
                    HStack {
                        Text("Κατάσταση:")
                        Spacer()
                        Text(appState.glassesState.statusDescription)
                            .foregroundColor(appState.glassesState.isLive ? R0llingTheme.statusLive : R0llingTheme.accentLavender)
                            .bold()
                    }

                    Button(action: {
                        Task {
                            await appState.toggleGlassesConnection()
                        }
                    }) {
                        Text(appState.glassesState == .disconnected ? "Σύνδεση Γυαλιών" : "Αποσύνδεση")
                            .foregroundColor(R0llingTheme.stravaOrange)
                    }

                    Toggle("Simulation Mode (Δοκιμή χωρίς γυαλιά)", isOn: $simulationMode)
                        .onChange(of: simulationMode) { _, val in
                            Task {
                                await appState.glassesAdapter.toggleSimulationMode(enabled: val)
                                // R3-003: Αν το SDK λείπει, το adapter επιβάλλει simulation.
                                let actual = await appState.glassesAdapter.isSimulationMode
                                if val == false && actual == true {
                                    simulationMode = true
                                    appState.showToast("Real DAT mode μη διαθέσιμο χωρίς MetaWearablesDAT SDK.")
                                }
                            }
                        }

                    if !MetaGlassesAdapter.einaiDatSDKDiathesimo {
                        Text("DAT SDK: μη συνδεδεμένο — μόνο Simulation.")
                            .font(.system(size: 12))
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                }

                // Section 2: Rolling Buffer
                Section(header: Text("Κυκλικός Buffer (Rolling Buffer)")) {
                    Picker("Διάρκεια Buffer", selection: $bufferDurationSelection) {
                        Text("5 Δευτερόλεπτα").tag(5.0)
                        Text("10 Δευτερόλεπτα").tag(10.0)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    HStack {
                        Text("Τρέχων Buffer:")
                        Spacer()
                        Text(String(format: "%.1fs διαθέσιμα", appState.bufferDuration))
                            .foregroundColor(R0llingTheme.bevelCyan)
                    }
                }

                // Section 3: AI Configuration
                Section(header: Text("Πάροχος Τεχνητής Νοημοσύνης (AI)")) {
                    Picker("Ενεργός Πάροχος", selection: $selectedAIProvider) {
                        Text("Direct AI API").tag(AIProviderType.directAPI)
                        Text("Hermes (Home PC)").tag(AIProviderType.hermes)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedAIProvider) { _, val in
                        appState.activeProvider = val
                    }

                    if selectedAIProvider == .directAPI {
                        TextField("Base URL", text: $directEndpointURL)
                        TextField("Model Name", text: $directModelName)
                        SecureField("API Key", text: $directAPIKey)
                    } else {
                        TextField("Hermes Gateway URL (Home PC)", text: $hermesEndpointURL)
                        SecureField("Hermes Bearer Token", text: $hermesToken)
                    }

                    Button("Αποθήκευση Ρυθμίσεων AI") {
                        let newSettings = AISettings(
                            activeProvider: selectedAIProvider,
                            directAPIBaseURL: directEndpointURL,
                            directAPIModel: directModelName,
                            hermesBaseURL: hermesEndpointURL
                        )
                        Task {
                            do {
                                try await appState.aiRouter.validateDirectURL(directEndpointURL)
                                try await appState.aiRouter.validateHermesURL(hermesEndpointURL)
                            } catch {
                                appState.showToast("Μη έγκυρο AI URL: \(error.localizedDescription)")
                                return
                            }
                            await appState.aiRouter.updateSettings(newSettings)
                            do {
                                if !directAPIKey.isEmpty {
                                    try await appState.aiRouter.storeSecret(
                                        value: directAPIKey,
                                        forKey: newSettings.directAPIKeyKeychainKey
                                    )
                                }
                                if !hermesToken.isEmpty {
                                    try await appState.aiRouter.storeSecret(
                                        value: hermesToken,
                                        forKey: newSettings.hermesTokenKeychainKey
                                    )
                                }
                                appState.showToast("Οι ρυθμίσεις AI αποθηκεύτηκαν (Keychain).")
                            } catch {
                                appState.showToast("Ρυθμίσεις OK· Keychain σφάλμα: \(error.localizedDescription)")
                            }
                        }
                    }
                    .foregroundColor(R0llingTheme.stravaOrange)
                }

                // Section 4: Obsidian Vault (A08 Files picker + A09 conflict UI)
                Section(header: Text("Obsidian Vault")) {
                    Text(appState.obsidianVaultDisplayPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(R0llingTheme.textSecondary)
                        .lineLimit(3)

                    Button("Επιλογή Vault (Files / iCloud)") {
                        deixeiEpilogiVault = true
                    }
                    .foregroundColor(R0llingTheme.bevelCyan)

                    Button("Επαναφορά τοπικού Vault") {
                        Task {
                            await appState.epanekkinisi_proepilegmenou_obsidian_vault()
                        }
                    }
                    .foregroundColor(R0llingTheme.textSecondary)

                    Button("Εξαγωγή Όλων στο Obsidian Τώρα") {
                        Task {
                            // CQ-P0-002: fail-closed toast μέσω AppState helper.
                            guard let r = await appState.exportBatchToObsidian() else { return }
                            if r.conflictsDetected.isEmpty {
                                appState.showToast("Εξήχθησαν \(r.exportedFilesCount) αρχεία στο Obsidian.")
                            } else {
                                appState.showToast(
                                    "Export: \(r.exportedFilesCount) OK, \(r.conflictsDetected.count) conflicts (sidecar)."
                                )
                            }
                        }
                    }
                    .foregroundColor(R0llingTheme.stravaOrange)

                    if !appState.teleutaiaObsidianConflicts.isEmpty {
                        Text("Conflicts:")
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(appState.teleutaiaObsidianConflicts, id: \.self) { path in
                            Text("• \(path)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(R0llingTheme.statusLive)
                        }
                    }
                }

                // Section 5: Backup & Restore (A15)
                Section(header: Text("Αντίγραφα Ασφαλείας (Backup)")) {
                    Button("Δημιουργία Πλήρους Backup Bundle") {
                        Task {
                            await appState.dimiourgia_backup_bundle()
                        }
                    }

                    Button("Επαναφορά από Backup Bundle…") {
                        deixeiEpilogiBackup = true
                    }
                }

                // Section 6: App Info
                Section(header: Text("Πληροφορίες")) {
                    HStack {
                        Text("Έκδοση:")
                        Spacer()
                        Text("R0lling 1.0.0 (Build 2026.10)")
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                    HStack {
                        Text("Αρχιτεκτονική:")
                        Spacer()
                        Text("Local-First Swift 6 / iOS 17.2+")
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                }
            }
            .navigationTitle("Ρυθμίσεις")
            .fileImporter(
                isPresented: $deixeiEpilogiVault,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        await appState.efarmogi_epilogis_obsidian_vault(url)
                    }
                case .failure(let error):
                    appState.showToast("Επιλογή vault απέτυχε: \(error.localizedDescription)")
                }
            }
            .fileImporter(
                isPresented: $deixeiEpilogiBackup,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        await appState.epanafora_apo_backup_bundle(url)
                    }
                case .failure(let error):
                    appState.showToast(AppErrorTaxonomy.minimaXristi(gia: error))
                }
            }
        }
    }
}
