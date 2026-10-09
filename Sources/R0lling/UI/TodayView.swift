import SwiftUI

/// Κύρια οθόνη ημερήσιας ροής (Today View) με Strava Activity Feed & Bevel 3-Ring Telemetry
public struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @Binding private var quickAction: TodayQuickAction?
    @State private var composerText: String = ""
    @State private var selectedTags: String = ""
    @State private var entryProsEpeksergasia: JournalEntry?
    @State private var isFileImporterPresented = false
    @State private var isTodayDetailsExpanded = false
    @FocusState private var composerIsFocused: Bool

    public init(quickAction: Binding<TodayQuickAction?> = .constant(nil)) {
        self._quickAction = quickAction
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerView

                ScrollView {
                    LazyVStack(spacing: 16) {
                        if appState.isStreaming {
                            LiveViewfinderCard(
                                isStreaming: appState.isStreaming,
                                isSimulation: appState.isSimulationMode,
                                bufferDuration: appState.bufferDuration,
                                onClipTap: {
                                    Task {
                                        await appState.triggerClip(seconds: 10.0)
                                    }
                                }
                            )
                        }

                        // Sovereign Life OS — Bevel 3-Ring Concentric Telemetry
                        BevelConcentricTelemetryCard(
                            score: appState.cognitiveTelemetry,
                            activeFocusDeadline: appState.deepWorkEndsAt,
                            completedFocusSecondsToday: appState.completedFocusSecondsToday,
                            entryCount: appState.todayEntries.count
                        )

                        HealthKitTelemetryCardView(
                            snapshot: appState.liveHealthSnapshot,
                            didCompleteAuthorizationRequest: appState.didCompleteHealthKitAccessRequest,
                            onRequestAuth: {
                                Task { await appState.requestHealthKitAccess() }
                            }
                        )

                        DisclosureGroup(isExpanded: $isTodayDetailsExpanded) {
                            VStack(spacing: 12) {
                                DeepWorkSentinelCard()
                                SovereignToDoListView()
                                SovereignScratchpadView()
                                SovereignStopwatchTimerView()
                            }
                            .padding(.top, 12)
                        } label: {
                            Label("Εργαλεία", systemImage: "slider.horizontal.3")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(R0llingTheme.textPrimary)
                        }
                        .tint(R0llingTheme.accentLavender)
                        .padding(14)
                        .r0llingBevelSurface(cornerRadius: 18)

                        if !appState.timeCapsuleMemories.isEmpty {
                            timeCapsuleBanner
                        }

                        if appState.todayEntries.isEmpty {
                            emptyStateView
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Καταγραφές")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(R0llingTheme.textPrimary)
                                    Spacer()
                                    Text("\(appState.todayEntries.count) καταγραφές")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(R0llingTheme.textSecondary)
                                }
                                .padding(.horizontal, 4)

                                ForEach(appState.todayEntries) { entry in
                                    TimelineEntryCard(
                                        entry: entry,
                                        einaiObsidianSync: false,
                                        onFavoriteToggle: {
                                            Task { await appState.toggleFavorite(entry: entry) }
                                        },
                                        onDelete: {
                                            Task { await appState.deleteEntry(id: entry.id) }
                                        },
                                        onEdit: {
                                            entryProsEpeksergasia = entry
                                        },
                                        resolveMediaURL: { relativePath in
                                            await appState.resolveMediaURL(relativePath: relativePath)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, appState.isStreaming ? 150 : 90)
                }

                composerBar
            }

            if appState.isStreaming {
                FloatingClipBar(
                    bufferDuration: appState.bufferDuration,
                    isStreaming: appState.isStreaming,
                    isSimulation: appState.isSimulationMode,
                    onClipTapped: {
                        Task {
                            await appState.triggerClip(seconds: 10.0)
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 78)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
        .sheet(item: $entryProsEpeksergasia) { entry in
            EntryEditorSheet(
                entry: entry,
                onSave: { updated in
                    entryProsEpeksergasia = nil
                    Task { await appState.updateEntry(updated) }
                },
                onCancel: { entryProsEpeksergasia = nil }
            )
        }
        .task(id: quickAction) {
            guard let quickAction else { return }
            switch quickAction {
            case .newNote:
                composerIsFocused = true
            case .importFile:
                isFileImporterPresented = true
            }
            self.quickAction = nil
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("R0lling")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(R0llingTheme.textSecondary)
                Spacer()
                Button(action: {
                    Task {
                        if appState.glassesState.isLive {
                            await appState.toggleLiveStream()
                        } else {
                            await appState.toggleGlassesConnection()
                            if !appState.isStreaming {
                                await appState.toggleLiveStream()
                            }
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isStreaming ? R0llingTheme.statusSuccess : R0llingTheme.textMuted)
                            .frame(width: 8, height: 8)
                        Image(systemName: "eyeglasses")
                            .font(.body.weight(.semibold))
                        Text(appState.isStreaming ? (appState.isSimulationMode ? "Δοκιμαστική ροή" : "Ζωντανή ροή") : appState.glassesState.statusDescription)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .r0llingBevelCapsule()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appState.isStreaming ? "Ζωντανή ροή γυαλιών" : "Κατάσταση σύνδεσης γυαλιών")
            }
            HStack(spacing: 8) {
                Text("Σήμερα, \(compactGreekDate)")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(R0llingTheme.bgPrimary)
    }

    private var compactGreekDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter.string(from: Date())
    }

    private var timeCapsuleBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(R0llingTheme.bevelCyan)
                    .font(.system(size: 13, weight: .bold))
                Text("ΣΑΝ ΣΗΜΕΡΑ — TIME CAPSULE")
                    .font(.caption.weight(.heavy).monospaced())
                    .foregroundColor(R0llingTheme.bevelCyan)
                    .tracking(1.0)
                Spacer()
            }
            ForEach(appState.timeCapsuleMemories) { mem in
                Text("⏳ \(mem.displayText): «\(mem.entry.content)»")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(R0llingTheme.textPrimary)
            }
        }
        .padding(14)
        .r0llingBevelSurface(cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(R0llingTheme.bevelCyan.opacity(0.3), lineWidth: 1)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(R0llingTheme.bgElevated)
                    .frame(width: 80, height: 80)
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(R0llingTheme.accentPurple)
            }
            .padding(.top, 30)

            Text("ΚΑΜΙΑ ΚΑΤΑΓΡΑΦΗ ΣΗΜΕΡΑ")
                .font(.headline.weight(.heavy).monospaced())
                .foregroundColor(R0llingTheme.textPrimary)
                .tracking(1.2)

            Text("Ξεκίνα τη ροή από τα Meta Glasses, σημείωσε μια σκέψη, ή επισύναψε φωτογραφία/βίντεο από Photos.")
                .font(.body)
                .foregroundColor(R0llingTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 20)
    }

    private var composerBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                dictationButton
                mediaPickerButton
                composerTextField.frame(minWidth: 150, maxWidth: .infinity)
                sendNoteButton
            }
            VStack(spacing: 8) {
                composerTextField
                HStack(spacing: 8) {
                    dictationButton
                    mediaPickerButton
                    Spacer(minLength: 0)
                    sendNoteButton
                }
            }
        }
        .padding(10)
        .r0llingBevelSurface(cornerRadius: 22)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var dictationButton: some View {
        Button(action: {
            R0llingTheme.triggerHapticFeedback()
            appState.toggleSpeechDictation()
        }) {
            Image(systemName: appState.isListeningSpeech ? "waveform" : "mic.fill")
                .font(.system(.body, weight: .bold))
                .foregroundColor(appState.isListeningSpeech ? .white : R0llingTheme.accentPurple)
                .frame(width: 44, height: 44)
                .background(appState.isListeningSpeech ? R0llingTheme.accentPurple : R0llingTheme.bgElevated)
                .r0llingBevelCapsule()
        }
        .accessibilityLabel(appState.isListeningSpeech ? "Διακοπή υπαγόρευσης" : "Έναρξη υπαγόρευσης")
        .accessibilityHint(appState.isListeningSpeech ? "Σταματά την υπαγόρευση σημείωσης" : "Υπαγορεύστε μια σημείωση δραστηριότητας")
    }

    private var mediaPickerButton: some View {
        PhotosMediaPickerButton(
            isFileImporterPresented: $isFileImporterPresented,
            onImport: { fileURL, filename, mediaType in
                let note = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
                await appState.attachMediaFile(
                    from: fileURL,
                    originalFilename: filename,
                    mediaType: mediaType,
                    noteText: note.isEmpty ? nil : note
                )
                if !note.isEmpty { composerText = "" }
            },
            onError: { minima in appState.showToast(minima) }
        )
    }

    private var composerTextField: some View {
        TextField("Σημείωση δραστηριότητας...", text: $composerText)
            .font(.body.weight(.medium))
            .foregroundColor(R0llingTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .r0llingBevelInsetSurface(cornerRadius: 16)
            .focused($composerIsFocused)
            .onSubmit(submitComposerNote)
    }

    private var sendNoteButton: some View {
        Button(action: submitComposerNote) {
            Image(systemName: "arrow.up")
                .font(.system(.body, weight: .black))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? LinearGradient(colors: [R0llingTheme.bgElevated, R0llingTheme.bgElevated], startPoint: .top, endPoint: .bottom)
                        : R0llingTheme.primaryButtonGradient
                )
                .r0llingBevelCapsule()
        }
        .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityLabel("Αποθήκευση σημείωσης")
        .accessibilityHint(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Γράψτε μια σημείωση για να ενεργοποιηθεί"
            : "Αποθηκεύει τη σημείωση δραστηριότητας")
    }

    private func submitComposerNote() {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        composerText = ""
        Task { await appState.addNote(text: text) }
    }
}
