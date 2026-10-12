import SwiftUI

/// Κύρια ημερήσια οθόνη με ημερολόγιο, μετρήσεις υγείας και εργαλεία παραγωγικότητας.
public struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @Binding private var quickAction: TodayQuickAction?
    @State private var composerText: String = ""
    @State private var selectedTags: String = ""
    @State private var entryProsEpeksergasia: JournalEntry?
    @State private var isFileImporterPresented = false
    @State private var isTodayDetailsExpanded = false
    @State private var isShareComposerPresented = false
    @State private var isDatePickerPresented = false
    @FocusState private var composerIsFocused: Bool
    private let onOpenSettings: () -> Void
    private let onOpenHealth: () -> Void

    public init(
        quickAction: Binding<TodayQuickAction?> = .constant(nil),
        onOpenSettings: @escaping () -> Void = {},
        onOpenHealth: @escaping () -> Void = {}
    ) {
        self._quickAction = quickAction
        self.onOpenSettings = onOpenSettings
        self.onOpenHealth = onOpenHealth
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerView

                ScrollView {
                    LazyVStack(spacing: 16) {
                        if appState.isStreaming && isSelectedDayToday {
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
                            activeFocusDeadline: isSelectedDayToday ? appState.deepWorkEndsAt : nil,
                            completedFocusSecondsToday: appState.completedFocusSecondsToday,
                            entryCount: appState.todayEntries.count,
                            daySummaryTitle: selectedDaySummaryTitle
                        )

                        TodayHealthSummaryCard(
                            snapshot: appState.liveHealthSnapshot,
                            didCompleteAuthorizationRequest: appState.didCompleteHealthKitAccessRequest,
                            onRequestAuth: {
                                Task { await appState.requestHealthKitAccess() }
                            },
                            onOpenHealth: onOpenHealth
                        )

                        if isSelectedDayToday {
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
                        }

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
                    .padding(.bottom, appState.isStreaming && isSelectedDayToday ? 150 : 90)
                }

                if isSelectedDayToday {
                    composerBar
                } else {
                    historicalDayFooter
                }
            }

            if appState.isStreaming && isSelectedDayToday {
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
        .sheet(isPresented: $isShareComposerPresented) {
            TodayShareComposerView(
                entries: appState.todayEntries,
                health: appState.liveHealthSnapshot
            )
        }
        .sheet(isPresented: $isDatePickerPresented) {
            NavigationStack {
                DatePicker(
                    "Επιλογή ημερομηνίας",
                    selection: $appState.selectedDate,
                    in: Date.distantPast...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(R0llingTheme.accentLavender)
                .padding(.horizontal, 16)
                .navigationTitle("Ημερολόγιο")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Σήμερα") {
                            appState.selectedDate = Date()
                            isDatePickerPresented = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Τέλος") { isDatePickerPresented = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task(id: quickAction) {
            guard let quickAction else { return }
            if !isSelectedDayToday {
                appState.selectedDate = Date()
                await appState.refreshEntries()
            }
            switch quickAction {
            case .newNote:
                composerIsFocused = true
            case .importFile:
                isFileImporterPresented = true
            }
            self.quickAction = nil
        }
        .onChange(of: appState.selectedDate) { _, selectedDate in
            let normalizedDate = Calendar.current.startOfDay(for: selectedDate)
            guard normalizedDate == selectedDate else {
                appState.selectedDate = normalizedDate
                return
            }
            Task { await appState.refreshEntries() }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    if isSelectedDayToday {
                        Button {
                            isShareComposerPresented = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(R0llingTheme.textPrimary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Κοινοποίηση σημερινών δεδομένων")
                        .accessibilityHint("Ανοίγει την προεπισκόπηση και τις επιλογές κοινοποίησης.")
                    } else {
                        Button {
                            appState.selectedDate = Date()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(R0llingTheme.textPrimary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Επιστροφή στις σημερινές καταγραφές")
                    }

                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(R0llingTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(R0llingTheme.bgElevated, in: Circle())
                            .overlay(Circle().stroke(R0llingTheme.borderSubtle, lineWidth: 0.8))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ρυθμίσεις")
                    .accessibilityHint("Ανοίγει τις ρυθμίσεις της εφαρμογής.")
                }
                .padding(4)
                .r0llingBevelSurface(cornerRadius: 28)
            }
            dateAndGlassesRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(R0llingTheme.bgPrimary)
    }

    private var dateAndGlassesRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            datePickerButton(font: .largeTitle.weight(.bold), lineLimit: 2, fixedWidth: false)
            glassesStatusControls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var glassesPrimaryActionButton: some View {
        Button(action: {
            Task { await appState.toggleGlassesPrimaryAction() }
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(appState.isStreaming ? R0llingTheme.statusSuccess : R0llingTheme.textMuted)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(R0llingTheme.bgElevated, lineWidth: 1.5))
                    .offset(x: -5, y: 5)
            }
            .r0llingBevelSurface(cornerRadius: 22)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(glassesControlAccessibilityLabel)
        .accessibilityValue(appState.glassesState.statusDescription)
        .accessibilityHint(glassesControlAccessibilityHint)
        .disabled(appState.glassesState.isConnectionAttemptInProgress)
    }

    private var glassesStatusControls: some View {
        HStack(spacing: 8) {
            glassesPrimaryActionButton
            glassesStatusChip
        }
    }

    private var glassesStatusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(glassesStatusColor)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(appState.glassesState.statusDescription)
                .font(.caption2.weight(.semibold))
                .foregroundColor(R0llingTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .r0llingBevelSurface(cornerRadius: 17)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Κατάσταση γυαλιών")
        .accessibilityValue(appState.glassesState.statusDescription)
    }

    private var glassesStatusColor: Color {
        if appState.isStreaming { return R0llingTheme.statusSuccess }
        if appState.glassesState.isConnectionAttemptInProgress { return R0llingTheme.accentAmber }
        if appState.glassesState.isConnected { return R0llingTheme.accentCyan }
        return R0llingTheme.textMuted
    }

    private func datePickerButton(font: Font, lineLimit: Int, fixedWidth: Bool) -> some View {
        Button {
            isDatePickerPresented = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(selectedDateTitle)
                    .font(font)
                    .foregroundColor(R0llingTheme.textPrimary)
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: fixedWidth, vertical: false)
                    .accessibilityAddTraits(.isHeader)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundColor(R0llingTheme.textSecondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Επιλογή ημερομηνίας, \(selectedDateTitle)")
        .accessibilityHint("Ανοίγει το ημερολόγιο για προβολή καταγραφών άλλης ημέρας.")
    }

    private var isSelectedDayToday: Bool {
        Calendar.current.isDateInToday(appState.selectedDate)
    }

    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.setLocalizedDateFormatFromTemplate(isSelectedDayToday ? "dMMMM" : "EEEEdMMMM")
        let formattedDate = formatter.string(from: appState.selectedDate)
        return isSelectedDayToday ? "Σήμερα, \(formattedDate)" : formattedDate
    }

    private var selectedDaySummaryTitle: String {
        guard !isSelectedDayToday else { return "Η σημερινή εικόνα" }
        return "Η εικόνα για \(selectedDateTitle)"
    }

    private var historicalDayFooter: some View {
        Button {
            appState.selectedDate = Date()
        } label: {
            Label("Επιστροφή στο σήμερα για νέα καταγραφή", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(R0llingTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(RoundedRectangle(cornerRadius: 18))
                .r0llingBevelSurface(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .accessibilityHint("Η προβολή ιστορικού είναι μόνο για ανάγνωση.")
    }

    private var glassesControlAccessibilityLabel: String {
        switch GlassesPrimaryAction.resolve(isStreaming: appState.isStreaming, state: appState.glassesState) {
        case .waitForConnection: "Σύνδεση γυαλιών σε εξέλιξη"
        case .startStreaming: "Έναρξη ροής γυαλιών"
        case .stopStreaming:
            appState.isSimulationMode ? "Διακοπή δοκιμαστικής ροής" : "Διακοπή ζωντανής ροής"
        case .connectThenStartStreaming: "Σύνδεση γυαλιών και έναρξη ροής"
        }
    }

    private var glassesControlAccessibilityHint: String {
        switch GlassesPrimaryAction.resolve(isStreaming: appState.isStreaming, state: appState.glassesState) {
        case .waitForConnection: "Περίμενε να ολοκληρωθεί η σύνδεση."
        case .startStreaming:
            appState.isSimulationMode
                ? "Ξεκινά δοκιμαστική ροή με συνθετικά δεδομένα."
                : "Ξεκινά τη ροή από τα συνδεδεμένα γυαλιά."
        case .stopStreaming: "Σταματά την τρέχουσα ροή."
        case .connectThenStartStreaming:
            appState.isSimulationMode
                ? "Συνδέει την προσομοίωση και ξεκινά ροή συνθετικών δεδομένων."
                : "Συνδέει τα γυαλιά και ξεκινά τη ροή."
        }
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

            Text(isSelectedDayToday ? "ΚΑΜΙΑ ΚΑΤΑΓΡΑΦΗ ΣΗΜΕΡΑ" : "ΚΑΜΙΑ ΚΑΤΑΓΡΑΦΗ ΑΥΤΗ ΤΗ ΜΕΡΑ")
                .font(.headline.weight(.heavy).monospaced())
                .foregroundColor(R0llingTheme.textPrimary)
                .tracking(1.2)

            Text(isSelectedDayToday
                ? "Ξεκίνα τη ροή από τα Meta Glasses, σημείωσε μια σκέψη, ή επισύναψε φωτογραφία/βίντεο από Photos."
                : "Δεν υπάρχουν καταγραφές για αυτή την ημερομηνία. Επέστρεψε στο σήμερα για νέα καταγραφή.")
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
