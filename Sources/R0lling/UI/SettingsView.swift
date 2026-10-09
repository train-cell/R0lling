import SwiftUI
import UniformTypeIdentifiers

/// Οθόνη ρυθμίσεων (Settings View)
public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("r0lling.buffer.targetSeconds") private var bufferDurationSelection: Double = 10.0
    @State private var simulationMode: Bool = true
    @State private var selectedAIProvider: AIProviderType = .directAPI
    @State private var directEndpointURL: String = "https://api.openai.com/v1"
    @State private var directModelName: String = "gpt-4o-mini"
    @State private var directAPIKeychainKey = "r0lling.direct_api_key"
    @State private var directAPIKey: String = ""
    @State private var hermesEndpointURL: String = "https://127.0.0.1:8080/v1"
    @State private var hermesTokenKeychainKey = "r0lling.hermes_token"
    @State private var hermesToken: String = ""
    @State private var hasDirectAPIKey: Bool = false
    @State private var hasHermesToken: Bool = false
    @State private var credentialRemovalKey: String?
    @State private var credentialRemovalLabel = ""
    @State private var showCredentialRemovalConfirmation = false
    @State private var includeJournal: Bool = false
    @State private var includeMemory: Bool = false
    @State private var includeLocation: Bool = false
    @State private var contextLimit: Int = 5
    @State private var deixeiEpilogiVault: Bool = false
    @State private var deixeiEpilogiBackup: Bool = false
    @State private var emfaniseEksagogiBackup: Bool = false

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
                            .foregroundColor(R0llingTheme.accentPurple)
                    }

                    if MetaDATStreamBridge.einaiLiveYlopoiimeno {
                        Toggle("Simulation Mode (Δοκιμή χωρίς γυαλιά)", isOn: $simulationMode)
                            .onChange(of: simulationMode) { _, val in
                                Task {
                                    await appState.glassesAdapter.toggleSimulationMode(enabled: val)
                                    simulationMode = await appState.glassesAdapter.isSimulationMode
                                }
                            }
                    } else {
                        Label("SIMULATION ONLY", systemImage: "eyeglasses")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundColor(R0llingTheme.statusWarning)
                        Text("Το live Meta DAT bridge δεν είναι υλοποιημένο σε αυτό το build.")
                            .font(.caption)
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
                    .disabled(appState.isStreaming)
                    .onChange(of: bufferDurationSelection) { _, selectedSeconds in
                        Task {
                            await appState.glassesAdapter.setBufferTargetSeconds(selectedSeconds)
                        }
                    }

                    Text(appState.isStreaming
                         ? "Η επιλογή εφαρμόζεται αφού σταματήσει η τρέχουσα ροή."
                         : "Η διάρκεια εφαρμόζεται στην επόμενη ροή γυαλιών.")
                        .font(.caption)
                        .foregroundColor(R0llingTheme.textSecondary)

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


                    if selectedAIProvider == .directAPI {
                        TextField("Base URL", text: $directEndpointURL)
                        TextField("Model Name", text: $directModelName)
                        SecureField("API Key", text: $directAPIKey)
                        if hasDirectAPIKey {
                            Button("Αφαίρεση αποθηκευμένου API key", role: .destructive) {
                                requestCredentialRemoval(
                                    key: directAPIKeychainKey,
                                    label: "Direct AI API key"
                                )
                            }
                        }
                    } else {
                        TextField("Hermes Gateway URL (Home PC)", text: $hermesEndpointURL)
                        SecureField("Hermes Bearer Token", text: $hermesToken)
                        if hasHermesToken {
                            Button("Αφαίρεση αποθηκευμένου Hermes token", role: .destructive) {
                                requestCredentialRemoval(
                                    key: hermesTokenKeychainKey,
                                    label: "Hermes token"
                                )
                            }
                        }
                    }

                    Toggle("Ημερολόγιο στο chat AI", isOn: $includeJournal)
                    Toggle("Agent memory στο chat AI", isOn: $includeMemory)
                    Toggle("Τοποθεσία σημειώσεων στο context", isOn: $includeLocation)
                    Stepper("Έως \(contextLimit) καταγραφές", value: $contextLimit, in: 0...5)
                    Text("Κάθε ερώτηση αποστέλλεται στον επιλεγμένο πάροχο. Το ημερολόγιο και η Agent memory προστίθενται στο chat μόνο όταν ενεργοποιηθούν εδώ. Η τοποθεσία περιλαμβάνεται μόνο για σημειώσεις στις οποίες έχεις προσθέσει όνομα τοποθεσίας. Οι ενέργειες σύνοψης και ανάκλησης αποστέλλουν τις αντίστοιχες καταγραφές.")
                        .font(.caption)

                    Button("Αποθήκευση Ρυθμίσεων AI") {
                        let newSettings = AISettings(
                            activeProvider: selectedAIProvider,
                            directAPIBaseURL: directEndpointURL,
                            directAPIModel: directModelName,
                            directAPIKeyKeychainKey: directAPIKeychainKey,
                            hermesBaseURL: hermesEndpointURL,
                            hermesTokenKeychainKey: hermesTokenKeychainKey,
                            includeJournalInChat: includeJournal,
                            includeAgentMemoryInChat: includeMemory,
                            includeLocationInContext: includeLocation,
                            maxContextEntries: contextLimit
                        )
                        Task {
                            do {
                                try await appState.aiRouter.validateEndpointForSaving(
                                    provider: selectedAIProvider,
                                    directBaseURL: directEndpointURL,
                                    hermesBaseURL: hermesEndpointURL
                                )
                            } catch {
                                appState.showToast("Μη έγκυρο AI URL: \(error.localizedDescription)")
                                return
                            }
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
                                await appState.aiRouter.updateSettings(newSettings)
                                appState.activeProvider = newSettings.activeProvider
                                directAPIKey = ""
                                hermesToken = ""
                                hasDirectAPIKey = await appState.aiRouter.hasSecret(
                                    forKey: newSettings.directAPIKeyKeychainKey
                                )
                                hasHermesToken = await appState.aiRouter.hasSecret(
                                    forKey: newSettings.hermesTokenKeychainKey
                                )
                                appState.showToast("Οι ρυθμίσεις AI αποθηκεύτηκαν.")
                            } catch {
                                appState.showToast("Αποτυχία αποθήκευσης credentials: \(error.localizedDescription)")
                            }
                        }
                    }
                    .foregroundColor(R0llingTheme.accentPurple)
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
                    .foregroundColor(R0llingTheme.accentPurple)

                    if !appState.teleutaiaObsidianConflicts.isEmpty {
                        Text("Conflicts:")
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(appState.teleutaiaObsidianConflicts, id: \.self) { path in
                            Text("• \(path)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(R0llingTheme.statusError)
                        }
                    }
                }

                // Section 5: Backup & Restore (A15)
                Section(header: Text("Αντίγραφα Ασφαλείας (Backup)")) {
                    Text("Το bundle περιέχει μη κρυπτογραφημένο JSON, media και Agent memory. Φύλαξέ το σε προστατευμένη τοποθεσία.")
                        .font(.caption)
                    Button("Εξαγωγή backup σε Files…") {
                        Task {
                            await appState.dimiourgia_backup_bundle()
                        }
                    }
                    .foregroundColor(R0llingTheme.accentPurple)

                    Button("Επαναφορά από Backup Bundle…") {
                        deixeiEpilogiBackup = true
                    }
                    .foregroundColor(R0llingTheme.bevelCyan)
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
                        Text("Swift 5 mode / iOS 17.2+")
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                }
            }
            .r0llingFormSurface()
            .navigationTitle("Ρυθμίσεις")
            .confirmationDialog(
                "Να αφαιρεθεί το αποθηκευμένο \(credentialRemovalLabel);",
                isPresented: $showCredentialRemovalConfirmation,
                titleVisibility: .visible
            ) {
                Button("Αφαίρεση credential", role: .destructive) {
                    guard let key = credentialRemovalKey else { return }
                    Task {
                        do {
                            try await appState.aiRouter.deleteSecret(forKey: key)
                            if key == directAPIKeychainKey {
                                hasDirectAPIKey = false
                            } else if key == hermesTokenKeychainKey {
                                hasHermesToken = false
                            }
                            appState.showToast("Το αποθηκευμένο credential αφαιρέθηκε.")
                        } catch {
                            appState.showToast("Αποτυχία αφαίρεσης credential: \(error.localizedDescription)")
                        }
                    }
                }
                Button("Άκυρο", role: .cancel) {}
            }
            #if canImport(UIKit)
            .onChange(of: appState.pendingBackupExportURL) { _, backupURL in
                emfaniseEksagogiBackup = backupURL != nil
            }
            .sheet(isPresented: $emfaniseEksagogiBackup) {
                if let backupURL = appState.pendingBackupExportURL {
                    BackupBundleExportPicker(bundleURL: backupURL) { didExport in
                        appState.finishBackupExport(didExport: didExport)
                        emfaniseEksagogiBackup = false
                    }
                    .ignoresSafeArea()
                }
            }
            #endif
            .task {
                let settings = await appState.aiRouter.currentSettings()
                selectedAIProvider = settings.activeProvider
                directEndpointURL = settings.directAPIBaseURL
                directModelName = settings.directAPIModel
                directAPIKeychainKey = settings.directAPIKeyKeychainKey
                hermesEndpointURL = settings.hermesBaseURL
                hermesTokenKeychainKey = settings.hermesTokenKeychainKey
                includeJournal = settings.includeJournalInChat
                includeMemory = settings.includeAgentMemoryInChat
                includeLocation = settings.includeLocationInContext
                contextLimit = max(0, min(5, settings.maxContextEntries))
                simulationMode = await appState.glassesAdapter.isSimulationMode
                await appState.glassesAdapter.setBufferTargetSeconds(bufferDurationSelection)
                hasDirectAPIKey = await appState.aiRouter.hasSecret(forKey: settings.directAPIKeyKeychainKey)
                hasHermesToken = await appState.aiRouter.hasSecret(forKey: settings.hermesTokenKeychainKey)
            }
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
                allowedContentTypes: [.folder, .r0llingBackupBundle],
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

    private func requestCredentialRemoval(key: String, label: String) {
        credentialRemovalKey = key
        credentialRemovalLabel = label
        showCredentialRemovalConfirmation = true
    }
}
