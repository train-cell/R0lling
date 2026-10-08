import SwiftUI
import PhotosUI

/// Οθόνη προσωπικού AI βοηθού (Assistant & Jarvis Hub)
public struct AssistantView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inputPrompt: String = ""
    @State private var isShowingMemorySheet: Bool = false
    @State private var isShowingGameSheet: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Quick Action Toolbar
            quickActionsBar

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
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)

                Text("Συνδεδεμένος: \(appState.activeProvider == .hermes ? "Hermes (Home PC)" : "Direct AI API")")
                    .font(.system(size: 12))
                    .foregroundColor(R0llingTheme.accentLavender)
            }

            Spacer()

            Button(action: { isShowingMemorySheet = true }) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundColor(R0llingTheme.accentLavender)
                    .padding(8)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(R0llingTheme.bgSurface)
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
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(R0llingTheme.primaryButtonGradient)
                        .clipShape(Capsule())
                        .shadow(color: R0llingTheme.accentPurple.opacity(0.3), radius: 6, x: 0, y: 2)
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(R0llingTheme.bgElevated)
                        .clipShape(Capsule())
                    }

                    Button(action: {
                        appState.cancelActiveAIRequest()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(R0llingTheme.statusError)
                            Text("Άκυρο")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(R0llingTheme.bgElevated)
                        .clipShape(Capsule())
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(appState.isMirrorStreaming ? R0llingTheme.bevelEmerald : R0llingTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(R0llingTheme.bgElevated)
                        .clipShape(Capsule())
                    }
                }

                Button(action: { isShowingGameSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundColor(R0llingTheme.bevelAmber)
                        Text("Παιχνίδι")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(R0llingTheme.bgSurface.opacity(0.8))
    }

    private var chatComposer: some View {
        HStack(spacing: 10) {
            TextField("Ρώτησε κάτι τον βοηθό...", text: $inputPrompt)
                .font(.system(size: 15))
                .foregroundColor(R0llingTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(R0llingTheme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    .shadow(
                        color: inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.clear
                            : R0llingTheme.accentPurple.opacity(0.35),
                        radius: 6, x: 0, y: 2
                    )
            }
            .disabled(inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(R0llingTheme.bgSurface)
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
                    .font(.system(size: 15))
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
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var memoryNotes: String = ""
    @State private var userPreferences: String = ""
    @State private var openLoops: String = ""

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Μνήμη Βοηθού (Memory.md)")) {
                    TextEditor(text: $memoryNotes)
                        .frame(height: 120)
                }
                Section(header: Text("Προτιμήσεις Χρήστη (Preferences.md)")) {
                    TextEditor(text: $userPreferences)
                        .frame(height: 100)
                }
                Section(header: Text("Εκκρεμότητες (Open-loops.md)")) {
                    TextEditor(text: $openLoops)
                        .frame(height: 100)
                }
            }
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
                }
            }
            .onAppear {
                Task {
                    if let loaded = try? await appState.agentManager.loadAgentMemory() {
                        memoryNotes = loaded.memoryNotes
                        userPreferences = loaded.userPreferences
                        openLoops = loaded.openLoops
                    }
                }
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(R0llingTheme.accentCyan)

                    Label("\(appState.gameScore) πόντοι", systemImage: "star.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(R0llingTheme.accentLavender)

                    Text(sessionStateLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(R0llingTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(R0llingTheme.bgElevated)
                        .clipShape(Capsule())
                }

                if !appState.scavengerBadges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(appState.scavengerBadges, id: \.self) { badge in
                                Text(badge)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(R0llingTheme.bgElevated)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if let mission = appState.currentMission {
                    VStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 40))
                            .foregroundColor(R0llingTheme.accentPurple)

                        Text("Τρέχουσα Αποστολή:")
                            .font(.system(size: 15))
                            .foregroundColor(R0llingTheme.textSecondary)

                        Text(mission.prompt)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(R0llingTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if mission.isCompleted {
                            Text("Ολοκληρώθηκε")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(R0llingTheme.bevelEmerald)
                        }
                    }
                    .r0llingCard()
                } else {
                    Text("Καμία ενεργή αποστολή — πάτησε «Επόμενη Αποστολή».")
                        .font(.system(size: 14))
                        .foregroundColor(R0llingTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if let evaluation = appState.lastGameEvaluation {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(evaluationHonestyLabel(evaluation))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(R0llingTheme.accentLavender)
                        Text(evaluation.feedback)
                            .font(.system(size: 13))
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
                    Button(action: {
                        Task { await trexeAxiologisiGyalion() }
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Έλεγχος με Κάμερα Γυαλιών")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isEvaluating ? R0llingTheme.bgElevated : R0llingTheme.accentPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isEvaluating || appState.currentMission?.isCompleted == true)

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
                        .font(.system(size: 15, weight: .semibold))
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
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                    .disabled(isEvaluating)

                    Button(action: {
                        Task {
                            await appState.playNextMission()
                        }
                    }) {
                        Text("Επόμενη Αποστολή ➡️")
                            .font(.system(size: 15, weight: .semibold))
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
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                appState.showToast("Αδυναμία φόρτωσης φωτογραφίας.")
                return
            }
            let epityxia = await appState.evaluateGameCapture(imageData: data)
            guard epityxia else { return }
            _ = appState.recordGameStreakAfterSuccess()
        } catch {
            appState.showToast("Σφάλμα φωτογραφίας: \(error.localizedDescription)")
        }
    }
}
