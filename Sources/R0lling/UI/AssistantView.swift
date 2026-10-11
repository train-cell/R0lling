import SwiftUI
import PhotosUI

/// Οθόνη προσωπικού AI βοηθού (Assistant & Jarvis Hub)
public struct AssistantView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inputPrompt: String = ""
    @State private var isShowingMemorySheet: Bool = false
    @State private var isShowingGameSheet: Bool = false
    @State private var selectedVisionPhoto: PhotosPickerItem?

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Quick Action Toolbar
            quickActionsBar

            if let estimate = appState.pendingNutritionEstimate {
                mealNutritionReview(estimate)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            // Chat Messages Stream
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.chatMessages, id: \.id) { msg in
                            ChatMessageBubble(isUser: msg.isUser, text: msg.text, timestamp: msg.timestamp)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: appState.chatMessages.count) {
                    if let last = appState.chatMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input Bar
            chatComposer
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
        .sheet(isPresented: $isShowingMemorySheet) {
            AgentMemorySheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $isShowingGameSheet) {
            ObservationGameSheet()
                .environmentObject(appState)
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Προσωπικός Βοηθός")
                    .font(.title3.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)

                Text("Πάροχος: \(appState.activeProvider == .hermes ? "Hermes (Home PC)" : "Direct AI API")")
                    .font(.caption)
                    .foregroundColor(R0llingTheme.accentLavender)
            }

            Spacer()

            Button(action: { isShowingMemorySheet = true }) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundColor(R0llingTheme.accentLavender)
                    .frame(width: 44, height: 44)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Circle())
                    .r0llingBevelCapsule()
            }
            .accessibilityLabel("Μνήμη βοηθού")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(R0llingTheme.bgPrimary)
    }

    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                    Button(action: {
                        Task {
                            await appState.executeWhatAmISeeing()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                            Text("Τι βλέπω;")
                        }
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(R0llingTheme.primaryButtonGradient)
                        .clipShape(Capsule())
                        .r0llingBevelCapsule()
                    }

                    PhotosPicker(
                        selection: $selectedVisionPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 5) {
                            Image(systemName: "photo")
                            Text("Ανάλυση φωτογραφίας")
                        }
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(R0llingTheme.bgElevated)
                        .clipShape(Capsule())
                        .r0llingBevelCapsule()
                        .overlay(Capsule().stroke(R0llingTheme.borderSubtle, lineWidth: 1))
                    }
                    .onChange(of: selectedVisionPhoto) { _, item in
                        guard let item else { return }
                        Task { await analyzeSelectedVisionPhoto(item) }
                    }
                    .accessibilityLabel("Ανάλυση φωτογραφίας από Photos")

                    if appState.pendingVisionNote != nil {
                        Button(action: {
                            Task { await appState.savePendingVisionNote() }
                        }) {
                            Label(
                                appState.pendingVisionNoteIsSaved ? "Αποθηκεύτηκε" : "Αποθήκευση",
                                systemImage: appState.pendingVisionNoteIsSaved ? "checkmark" : "square.and.arrow.down"
                            )
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundColor(R0llingTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(minHeight: 44)
                                .background(R0llingTheme.bgElevated)
                                .clipShape(Capsule())
                                .r0llingBevelCapsule()
                                .overlay(Capsule().stroke(R0llingTheme.borderSubtle, lineWidth: 1))
                        }
                        .accessibilityLabel("Αποθήκευση αποτελέσματος Vision στο ημερολόγιο")
                        .disabled(appState.isSavingVisionNote || appState.pendingVisionNoteIsSaved)

                        Button(action: { appState.speakPendingVisionNote() }) {
                            Label("Εκφώνηση", systemImage: "speaker.wave.2")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundColor(R0llingTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(minHeight: 44)
                                .background(R0llingTheme.bgElevated)
                                .clipShape(Capsule())
                                .r0llingBevelCapsule()
                                .overlay(Capsule().stroke(R0llingTheme.borderSubtle, lineWidth: 1))
                        }
                        .accessibilityLabel("Εκφώνηση αποτελέσματος Vision")
                        .disabled(appState.isSavingVisionNote)

                        Button(action: { appState.discardPendingVisionNote() }) {
                            Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                                .foregroundColor(R0llingTheme.textMuted)
                                .padding(10)
                                .frame(width: 44, height: 44)
                                .background(R0llingTheme.bgElevated)
                                .clipShape(Circle())
                                .r0llingBevelCapsule()
                        }
                        .accessibilityLabel("Απόρριψη αποτελέσματος Vision")
                        .disabled(appState.isSavingVisionNote)
                    }

                    Button(action: {
                        Task {
                            await appState.executeRecall(query: inputPrompt.isEmpty ? "τι ήθελα να θυμηθώ;" : inputPrompt)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(R0llingTheme.bevelCyan)
                            Text("Ανάκληση")
                        }
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(R0llingTheme.bgElevated)
                        .clipShape(Capsule())
                        .r0llingBevelCapsule()
                    }

                    Button(action: {
                        appState.cancelActiveAIRequest()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(R0llingTheme.statusError)
                            Text("Άκυρο")
                        }
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(R0llingTheme.bgElevated)
                        .clipShape(Capsule())
                        .r0llingBevelCapsule()
                    }

                    Button(action: {
                        Task {
                            do {
                                let s = try await appState.aiRouter.summarizeDay(entries: appState.todayEntries)
                            appState.chatMessages.append((
                                id: UUID(),
                                isUser: false,
                                text: "📋 **Ημερήσια Σύνοψη:**\n\(s)",
                                timestamp: Date()
                            ))
                        } catch {
                            appState.chatMessages.append((
                                id: UUID(),
                                isUser: false,
                                text: "Σφάλμα σύνοψης ημέρας: \(error.localizedDescription)",
                                timestamp: Date()
                            ))
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.clipboard.fill")
                            .foregroundColor(R0llingTheme.bevelCyan)
                        Text("Σύνοψη ημέρας")
                    }
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                    .r0llingBevelCapsule()
                }

                Button(action: {
                    Task {
                        await appState.createDailyHighlightReel()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "film.fill")
                            .foregroundColor(R0llingTheme.accentPurple)
                        Text("🎬 Highlight Reel")
                    }
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                    .r0llingBevelCapsule()
                }

                Button(action: {
                    Task {
                        await appState.playDailyPodcast()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(R0llingTheme.bevelEmerald)
                        Text("🎙️ Podcast")
                    }
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                    .r0llingBevelCapsule()
                }

                Button(action: {
                    Task {
                        await appState.exportObsidianCanvas()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3.fill")
                            .foregroundColor(R0llingTheme.bevelCyan)
                        Text("🎨 Canvas")
                    }
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                    .r0llingBevelCapsule()
                }

                Button(action: {
                    Task {
                        await appState.exportKnowledgeGraphToObsidian()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .foregroundColor(R0llingTheme.accentLavender)
                        Text("🧠 Graph")
                    }
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                    .r0llingBevelCapsule()
                }

                // Mirror: FeatureReadinessRegistry.mirror.ready == false (TLS + frame pipeline)
                if FeatureReadinessRegistry.mirror.ready {
                    Button(action: {
                        appState.toggleMirrorStreaming()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: appState.isMirrorStreaming ? "airplayvideo.fill" : "airplayvideo")
                            Text(appState.isMirrorStreaming ? "🪞 On (\(appState.activeMirrorClientsCount))" : "🪞 Mirror")
                        }
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundColor(appState.isMirrorStreaming ? R0llingTheme.bevelEmerald : R0llingTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(R0llingTheme.bgElevated)
                        .clipShape(Capsule())
                        .r0llingBevelCapsule()
                    }
                }

                Button(action: { isShowingGameSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundColor(R0llingTheme.bevelAmber)
                        Text("Παιχνίδι")
                    }
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                    .r0llingBevelCapsule()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
        }
        .background(R0llingTheme.bgSurface.opacity(0.8))
    }

    private func mealNutritionReview(_ estimate: MealNutritionVisionLogger.NutritionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ενδεικτική εκτίμηση γεύματος")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(R0llingTheme.textPrimary)
                Spacer()
                Text("~\(Int(estimate.totalCalories)) kcal")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(R0llingTheme.accentCyan)
            }
            Text("\(estimate.mealType.rawValue) · \(estimate.timestamp.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(R0llingTheme.textMuted)

            ForEach(estimate.items) { item in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(item.name)
                        Spacer(minLength: 8)
                        Text("~\(Int(item.estimatedGrams)) g · ~\(Int(item.calories)) kcal")
                            .monospacedDigit()
                    }
                    Text("Πρ. ~\(String(format: "%.1f", item.proteinGrams)) g · Υδ. ~\(String(format: "%.1f", item.carbsGrams)) g · Λιπ. ~\(String(format: "%.1f", item.fatGrams)) g")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundStyle(R0llingTheme.textSecondary)
            }

            Text("Σύνολο: Πρ. ~\(String(format: "%.1f", estimate.totalProtein)) g · Υδ. ~\(String(format: "%.1f", estimate.totalCarbs)) g · Λιπ. ~\(String(format: "%.1f", estimate.totalFat)) g")
                .font(.caption.weight(.medium))
                .foregroundStyle(R0llingTheme.textSecondary)

            Text("Βασίζεται σε αναγνωρισμένους όρους OCR και σταθερές ευρετικές τιμές. Δεν είναι μέτρηση· έλεγξέ την πριν την αποθήκευση.")
                .font(.caption2)
                .foregroundStyle(R0llingTheme.textMuted)

            HStack(spacing: 10) {
                Button {
                    Task { await appState.savePendingNutritionEstimate() }
                } label: {
                    Label(
                        appState.pendingNutritionEstimateIsSaved ? "Αποθηκεύτηκε" : "Αποθήκευση εκτίμησης",
                        systemImage: appState.pendingNutritionEstimateIsSaved ? "checkmark" : "square.and.arrow.down"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(R0llingTheme.textPrimary)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                    .r0llingBevelCapsule()
                }
                .buttonStyle(.plain)
                .disabled(appState.isSavingNutritionEstimate || appState.pendingNutritionEstimateIsSaved)
                .accessibilityLabel("Αποθήκευση ενδεικτικής εκτίμησης γεύματος στο ημερολόγιο")
                .accessibilityHint("Η αποθήκευση γίνεται μόνο μετά από αυτή την επιβεβαίωση.")

                Button {
                    appState.discardPendingNutritionEstimate()
                } label: {
                    Text(appState.pendingNutritionEstimateIsSaved ? "Κλείσιμο" : "Απόρριψη")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(R0llingTheme.textSecondary)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .disabled(appState.isSavingNutritionEstimate)
                .accessibilityLabel(appState.pendingNutritionEstimateIsSaved ? "Κλείσιμο εκτίμησης γεύματος" : "Απόρριψη εκτίμησης γεύματος")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .r0llingBevelSurface(cornerRadius: 18)
        .accessibilityElement(children: .contain)
    }

    private var chatComposer: some View {
        HStack(spacing: 10) {
            TextField("Ρώτησε κάτι τον βοηθό...", text: $inputPrompt)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundColor(R0llingTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .r0llingBevelInsetSurface(cornerRadius: 14)
                .onSubmit {
                    let prompt = inputPrompt
                    guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    inputPrompt = ""
                    Task {
                        await appState.sendMessageToAssistant(prompt: prompt)
                    }
                }

            Button(action: {
                let prompt = inputPrompt
                inputPrompt = ""
                Task {
                    await appState.sendMessageToAssistant(prompt: prompt)
                }
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? LinearGradient(colors: [R0llingTheme.bgElevated, R0llingTheme.bgElevated], startPoint: .top, endPoint: .bottom)
                            : R0llingTheme.primaryButtonGradient
                    )
                    .clipShape(Circle())
                    .r0llingBevelCapsule()
            }
            .accessibilityLabel("Αποστολή μηνύματος")
            .disabled(inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .r0llingBevelSurface(cornerRadius: 18)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(R0llingTheme.bgPrimary)
    }

    private func analyzeSelectedVisionPhoto(_ item: PhotosPickerItem) async {
        defer { selectedVisionPhoto = nil }
        do {
            guard let imported = try await item.loadTransferable(type: ImportedVisionPhoto.self) else {
                appState.showToast("Αδυναμία φόρτωσης φωτογραφίας από Photos.")
                return
            }
            defer { try? FileManager.default.removeItem(at: imported.url) }
            let imageData = try imported.loadVisionData()
            await appState.executeWhatAmISeeing(imageData: imageData)
        } catch {
            appState.showToast("Αποτυχία ανάγνωσης φωτογραφίας: \(error.localizedDescription)")
        }
    }
}

public struct ChatMessageBubble: View {
    public let isUser: Bool
    public let text: String
    public let timestamp: Date

    public var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(isUser ? R0llingTheme.accentPurple : R0llingTheme.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isUser ? Color.clear : R0llingTheme.borderSubtle, lineWidth: 1)
                    )
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }

}

public struct AgentMemorySheet: View {
    private enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var memoryNotes: String = ""
    @State private var userPreferences: String = ""
    @State private var openLoops: String = ""
    @State private var loadState: LoadState = .idle
    @State private var loadErrorMessage: String?

    public var body: some View {
        NavigationView {
            Form {
                if loadState == .loading {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Φόρτωση μνήμης…")
                                .foregroundColor(R0llingTheme.textSecondary)
                        }
                    }
                } else if loadState == .failed {
                    Section {
                        Label(
                            loadErrorMessage ?? "Η μνήμη δεν φορτώθηκε.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundColor(R0llingTheme.statusWarning)
                        Button("Δοκιμή ξανά", systemImage: "arrow.clockwise") {
                            loadMemory()
                        }
                    }
                }
                Section(header: Text("Μνήμη Βοηθού (Memory.md)")) {
                    TextEditor(text: $memoryNotes)
                        .frame(height: 120)
                        .disabled(loadState != .loaded)
                }
                Section(header: Text("Προτιμήσεις Χρήστη (Preferences.md)")) {
                    TextEditor(text: $userPreferences)
                        .frame(height: 100)
                        .disabled(loadState != .loaded)
                }
                Section(header: Text("Εκκρεμότητες (Open-loops.md)")) {
                    TextEditor(text: $openLoops)
                        .frame(height: 100)
                        .disabled(loadState != .loaded)
                }
            }
            .r0llingFormSurface()
            .navigationTitle("Μνήμη Agent")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Κλείσιμο") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") {
                        let mem = AgentMemory(
                            memoryNotes: memoryNotes,
                            userPreferences: userPreferences,
                            openLoops: openLoops,
                            lastUpdated: Date()
                        )
                        Task {
                            // CQ-P0-005: μην dismiss σε αποτυχία αποθήκευσης.
                            do {
                                try await appState.agentManager.saveAgentMemory(mem)
                                dismiss()
                            } catch {
                                appState.showToast("Σφάλμα αποθήκευσης μνήμης: \(error.localizedDescription)")
                            }
                        }
                    }
                    .disabled(loadState != .loaded)
                }
            }
            .onAppear {
                if loadState == .idle { loadMemory() }
            }
        }
    }

    private func loadMemory() {
        loadState = .loading
        loadErrorMessage = nil
        Task {
            do {
                let loaded = try await appState.agentManager.loadAgentMemory()
                memoryNotes = loaded.memoryNotes
                userPreferences = loaded.userPreferences
                openLoops = loaded.openLoops
                loadState = .loaded
            } catch {
                loadErrorMessage = error.localizedDescription
                loadState = .failed
            }
        }
    }
}

public struct ObservationGameSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isEvaluating: Bool = false

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Score & Streak
                HStack(spacing: 16) {
                    Label("\(appState.scavengerStreak)d Σερί", systemImage: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundColor(R0llingTheme.accentCyan)

                    Label("\(appState.gameScore) πόντοι", systemImage: "star.fill")
                        .font(.headline.weight(.bold))
                        .foregroundColor(R0llingTheme.accentLavender)

                    Text(sessionStateLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(R0llingTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(R0llingTheme.bgElevated)
                        .clipShape(Capsule())
                        .r0llingBevelCapsule()
                }

                if !appState.scavengerBadges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(appState.scavengerBadges, id: \.self) { badge in
                                Text(badge)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(R0llingTheme.bgElevated)
                                    .clipShape(Capsule())
                                    .r0llingBevelCapsule()
                            }
                        }
                    }
                }

                if let mission = appState.currentMission {
                    VStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.largeTitle)
                            .foregroundColor(R0llingTheme.accentPurple)

                        Text("Τρέχουσα Αποστολή:")
                            .font(.body)
                            .foregroundColor(R0llingTheme.textSecondary)

                        Text(mission.prompt)
                            .font(.title3.weight(.bold))
                            .foregroundColor(R0llingTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if mission.isCompleted {
                            Text("Ολοκληρώθηκε")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(R0llingTheme.bevelEmerald)
                        }
                    }
                    .r0llingCard()
                } else {
                    Text("Καμία ενεργή αποστολή — πάτησε «Επόμενη Αποστολή».")
                        .font(.subheadline)
                        .foregroundColor(R0llingTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if let evaluation = appState.lastGameEvaluation {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(evaluationHonestyLabel(evaluation))
                            .font(.caption.weight(.bold))
                            .foregroundColor(R0llingTheme.accentLavender)
                        Text(evaluation.feedback)
                            .font(.footnote)
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if isEvaluating {
                    ProgressView("Αξιολόγηση Vision AI…")
                        .tint(R0llingTheme.accentLavender)
                }

                Spacer()

                VStack(spacing: 12) {
                    if appState.isSimulationMode {
                        Label(
                            "Η κάμερα γυαλιών δεν είναι διαθέσιμη σε Simulation. Επίλεξε φωτογραφία.",
                            systemImage: "eyeglasses"
                        )
                        .font(.footnote.weight(.medium))
                        .foregroundColor(R0llingTheme.statusWarning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(R0llingTheme.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityAddTraits(.isStaticText)
                    }

                    Button(action: {
                        Task { await trexeAxiologisiGyalion() }
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text(appState.isSimulationMode ? "Κάμερα μη διαθέσιμη (Simulation)" : "Έλεγχος με Κάμερα Γυαλιών")
                        }
                        .font(.headline.weight(.bold))
                        .foregroundColor(appState.isSimulationMode ? R0llingTheme.textSecondary : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isEvaluating || appState.isSimulationMode ? R0llingTheme.bgElevated : R0llingTheme.accentPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isEvaluating || appState.isSimulationMode || appState.currentMission?.isCompleted == true)
                    .accessibilityLabel(appState.isSimulationMode ? "Κάμερα γυαλιών μη διαθέσιμη σε Simulation" : "Έλεγχος αποστολής με κάμερα γυαλιών")

                    // A14 fallback χωρίς γυαλιά: Photos picker → ίδια fail-closed αξιολόγηση.
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Επιλογή Φωτογραφίας (χωρίς γυαλιά)")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(R0llingTheme.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isEvaluating || appState.currentMission?.isCompleted == true)
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        guard let newItem else { return }
                        Task { await trexeAxiologisiPicker(newItem) }
                    }

                    Button(action: {
                        Task {
                            guard !isEvaluating else { return }
                            isEvaluating = true
                            defer { isEvaluating = false }
                            // G5-002: streak μόνο σε επιτυχία — manual ρητά όχι AI.
                            let epityxia = await appState.confirmGameManually()
                            guard epityxia else { return }
                            _ = appState.recordGameStreakAfterSuccess()
                        }
                    }) {
                        Text("Χειροκίνητη Επιβεβαίωση (Χωρίς AI)")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                    .disabled(isEvaluating)

                    Button(action: {
                        Task {
                            await appState.playNextMission()
                        }
                    }) {
                        Text("Επόμενη Αποστολή ➡️")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(R0llingTheme.accentLavender)
                    }
                    .disabled(isEvaluating)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(R0llingTheme.bgPrimary.ignoresSafeArea())
            .navigationTitle("Παιχνίδι Παρατήρησης")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Κλείσιμο") { dismiss() }
                }
            }
        }
    }

    private var sessionStateLabel: String {
        switch appState.gameSessionState {
        case .idle: return "Idle"
        case .active: return "Active"
        case .evaluating: return "Evaluating"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    private func evaluationHonestyLabel(_ evaluation: ObservationEvaluationResult) -> String {
        switch evaluation.source {
        case .aiVision:
            return evaluation.success ? "Αξιολόγηση AI · +\(evaluation.awardedPoints)" : "Αξιολόγηση AI · αποτυχία"
        case .manual:
            return "Χειροκίνητη (όχι AI) · +\(evaluation.awardedPoints)"
        case .unavailable:
            return "AI μη διαθέσιμο · 0 πόντοι (fail-closed)"
        }
    }

    private func trexeAxiologisiGyalion() async {
        guard !isEvaluating else { return }
        isEvaluating = true
        defer { isEvaluating = false }
        // G5-002: streak μόνο σε επιτυχή αξιολόγηση — όχι σε fail/error.
        let epityxia = await appState.evaluateGameCapture()
        guard epityxia else { return }
        _ = appState.recordGameStreakAfterSuccess()
    }

    private func trexeAxiologisiPicker(_ item: PhotosPickerItem) async {
        guard !isEvaluating else { return }
        isEvaluating = true
        defer {
            isEvaluating = false
            selectedPhotoItem = nil
        }
        do {
            guard let imported = try await item.loadTransferable(type: ImportedVisionPhoto.self) else {
                appState.showToast("Αδυναμία φόρτωσης φωτογραφίας.")
                return
            }
            defer { try? FileManager.default.removeItem(at: imported.url) }
            let data = try imported.loadVisionData()
            let epityxia = await appState.evaluateGameCapture(imageData: data)
            guard epityxia else { return }
            _ = appState.recordGameStreakAfterSuccess()
        } catch {
            appState.showToast("Σφάλμα φωτογραφίας: \(error.localizedDescription)")
        }
    }
}
