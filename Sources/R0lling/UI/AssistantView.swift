import SwiftUI

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
                .onChange(of: appState.chatMessages.count) { _ in
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(R0llingTheme.accentPurple)
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
                        Text("Σύνοψη ημέρας")
                    }
                    .font(.system(size: 13, weight: .medium))
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
                        Text("🎬 Highlight Reel")
                    }
                    .font(.system(size: 13, weight: .medium))
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
                        Text("🎙️ Podcast")
                    }
                    .font(.system(size: 13, weight: .medium))
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
                        Text("🎨 Canvas")
                    }
                    .font(.system(size: 13, weight: .medium))
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
                        Text("🧠 Graph")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                }

                Button(action: {
                    appState.toggleMirrorStreaming()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: appState.isMirrorStreaming ? "airplayvideo.fill" : "airplayvideo")
                        Text(appState.isMirrorStreaming ? "🪞 On (\(appState.activeMirrorClientsCount))" : "🪞 Mirror")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(appState.isMirrorStreaming ? .green : R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                }

                Button(action: { isShowingGameSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gamecontroller.fill")
                        Text("Παιχνίδι Παρατήρησης")
                    }
                    .font(.system(size: 13, weight: .medium))
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
                    .background(inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? R0llingTheme.bgElevated : R0llingTheme.accentPurple)
                    .clipShape(Circle())
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
            .navigationBarItems(
                leading: Button("Κλείσιμο") { dismiss() },
                trailing: Button("Αποθήκευση") {
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
            )
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

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Score & Streak
                HStack(spacing: 16) {
                    Label("\(appState.scavengerStreak)d Σερί", systemImage: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)

                    Label("\(appState.gameScore) πόντοι", systemImage: "star.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(R0llingTheme.accentLavender)
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
                    }
                    .r0llingCard()
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            // G5-002: streak μόνο σε επιτυχή αξιολόγηση — όχι σε fail/error.
                            let epityxia = await appState.evaluateGameCapture()
                            guard epityxia else { return }
                            appState.streakManager.recordMissionCompleted()
                            appState.scavengerStreak = appState.streakManager.currentStreak
                            appState.scavengerBadges = appState.streakManager.badges
                        }
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Έλεγχος με Κάμερα Γυαλιών")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(R0llingTheme.accentPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: {
                        Task {
                            await appState.gameEngine.confirmManually()
                            appState.gameScore = await appState.gameEngine.getScore()
                            appState.streakManager.recordMissionCompleted()
                            appState.scavengerStreak = appState.streakManager.currentStreak
                            appState.scavengerBadges = appState.streakManager.badges
                            await appState.playNextMission()
                        }
                    }) {
                        Text("Χειροκίνητη Επιβεβαίωση (Χωρίς AI)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(R0llingTheme.textSecondary)
                    }

                    Button(action: {
                        Task {
                            await appState.playNextMission()
                        }
                    }) {
                        Text("Επόμενη Αποστολή ➡️")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(R0llingTheme.accentLavender)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .background(R0llingTheme.bgPrimary.ignoresSafeArea())
            .navigationTitle("Παιχνίδι Παρατήρησης")
            .navigationBarItems(trailing: Button("Κλείσιμο") { dismiss() })
        }
    }
}
