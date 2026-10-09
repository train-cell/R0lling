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
                    Text("Στρατηγείο — Προεπισκόπηση")
                        .font(.title2.weight(.bold))
                        .foregroundColor(R0llingTheme.textPrimary)
                    Text("Vault και ιδέες σε εξέλιξη")
                        .font(.footnote)
                        .foregroundColor(R0llingTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18))
                    .foregroundColor(R0llingTheme.statusSuccess)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(R0llingTheme.bgPrimary)

            ScrollView {
                LazyVStack(spacing: 16) {
                    // Shows the currently selected AI route; this is not a network-isolation claim.
                    AirGappedStatusBanner()

                    // Local encrypted diary with an actual biometric unlock gate.
                    EncryptedDiaryCardView()

                    // Real private decision log, including due-date-gated reviews.
                    DecisionJournalCardView()

                    // Future letters use the same encrypted store and local unlock policy.
                    FutureLetterboxWidgetCard()

                    // The remaining strategic cards are static previews.
                    PrototypeNotice()

                    // Pre-Mortem Project Inversion (Charlie Munger)
                    PreMortemInversionCardView()

                    // Personal Board of Advisors (Marcus Aurelius, Jobs, Munger)
                    AdvisoryBoardCardView()

                    // Stoic Principles & Daily Compass
                    StoicPrinciplesCardView()

                }
                .padding(16)
            }
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
    }
}

public struct EncryptedDiaryCardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1
    @State private var isUnlocked: Bool = false
    @State private var isAuthenticating: Bool = false
    @State private var isSaving: Bool = false
    @State private var isLoading: Bool = false
    @State private var authorization: EncryptedDiaryStore.Authorization?
    @State private var authenticationMessage: String?
    @State private var authenticationGeneration = UUID()
    @State private var operationTask: Task<Void, Never>?
    @State private var entries: [EncryptedDiaryStore.Entry] = []
    @State private var draft = ""
    @State private var editingEntryID: UUID?
    @FocusState private var isEditorFocused: Bool
    private let diary = EncryptedDiaryStore.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ΙΔΙΩΤΙΚΟ ΗΜΕΡΟΛΟΓΙΟ", systemImage: isUnlocked ? "lock.open.fill" : "lock.shield.fill")
                    .font(.system(size: 10 * typeScale, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
                Spacer()
                if isUnlocked {
                Button("Κλείδωμα", systemImage: "lock.fill", action: lockAndClear)
                        .font(.system(size: 11 * typeScale, weight: .semibold))
                        .foregroundColor(R0llingTheme.textSecondary)
                    .frame(minHeight: 44)
                }
            }

            if isUnlocked {
                diaryEditor
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button(action: unlock) {
                    HStack(spacing: 12) {
                        Image(systemName: "faceid")
                            .font(.system(size: 25 * typeScale))
                            .foregroundColor(R0llingTheme.accentCyan)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isAuthenticating ? "Έλεγχος ταυτότητας…" : "Ξεκλείδωμα με βιομετρικά")
                                .font(.system(size: 12 * typeScale, weight: .semibold))
                                .foregroundColor(R0llingTheme.textPrimary)
                            Text("Οι εγγραφές αποθηκεύονται κρυπτογραφημένες σε αυτή τη συσκευή.")
                                .font(.system(size: 10 * typeScale))
                                .foregroundColor(R0llingTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
                .accessibilityHint("Απαιτείται βιομετρικός έλεγχος για προβολή του ιδιωτικού ημερολογίου.")
            }

            if let authenticationMessage {
                Text(authenticationMessage)
                    .font(.system(size: 11 * typeScale))
                    .foregroundColor(R0llingTheme.statusError)
                    .accessibilityLabel(authenticationMessage)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                authenticationGeneration = UUID()
                lockAndClear()
            }
        }
        .onDisappear {
            authenticationGeneration = UUID()
            lockAndClear()
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: isUnlocked)
        .padding(14)
        .r0llingBevelSurface(cornerRadius: 16)
    }

    private var diaryEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Τοπικό vault · AES-GCM · Keychain")
                .font(.system(size: 10 * typeScale, design: .monospaced))
                .foregroundColor(R0llingTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $draft)
                    .focused($isEditorFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 84, maxHeight: 150)
                    .r0llingBevelInsetSurface(cornerRadius: 10)
                    .accessibilityLabel(editingEntryID == nil ? "Νέα ιδιωτική εγγραφή" : "Επεξεργασία ιδιωτικής εγγραφής")
                    .privacySensitive()

                HStack {
                    if editingEntryID != nil {
                        Button("Ακύρωση", action: clearDraft)
                            .font(.system(size: 11 * typeScale, weight: .medium))
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                    Spacer()
                    Button(action: saveDraft) {
                        Label(editingEntryID == nil ? "Αποθήκευση" : "Ενημέρωση", systemImage: "lock.doc.fill")
                            .font(.system(size: 11 * typeScale, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(R0llingTheme.accentLavender)
                    .disabled(isSaving || isLoading || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if isLoading {
                ProgressView("Φόρτωση κρυπτογραφημένων εγγραφών…")
                    .font(.system(size: 11 * typeScale))
                    .tint(R0llingTheme.accentCyan)
            } else if entries.isEmpty {
                Text("Δεν υπάρχουν ακόμη εγγραφές. Το περιεχόμενο παραμένει κρυπτογραφημένο στο δίσκο.")
                    .font(.system(size: 11 * typeScale))
                    .foregroundColor(R0llingTheme.textSecondary)
            } else {
                ForEach(entries) { entry in
                    diaryEntryRow(entry)
                }
            }

            Text("Το κλειδί είναι δεμένο με αυτή τη συσκευή. Το ημερολόγιο δεν περιλαμβάνεται στο backup.")
                .font(.system(size: 10 * typeScale))
                .foregroundColor(R0llingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func diaryEntryRow(_ entry: EncryptedDiaryStore.Entry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                editingEntryID = entry.id
                draft = entry.content
                isEditorFocused = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 9 * typeScale, weight: .medium, design: .monospaced))
                        .foregroundColor(R0llingTheme.accentCyan)
                    Text(entry.content)
                        .font(.system(size: 12 * typeScale))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Άνοιγμα για επεξεργασία")

            Button(role: .destructive) {
                deleteEntry(entry.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12 * typeScale))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Διαγραφή εγγραφής")
            .disabled(isSaving || isLoading)
        }
        .padding(10)
        .background(R0llingTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .privacySensitive()
    }

    private func unlock() {
        guard !isAuthenticating, scenePhase == .active else { return }
        isAuthenticating = true
        authenticationMessage = nil
        let generation = UUID()
        authenticationGeneration = generation

        Task { @MainActor in
            isLoading = true
            var grantedAuthorization: EncryptedDiaryStore.Authorization?
            do {
                let granted = try await diary.authorize(reason: "Ξεκλείδωμα ιδιωτικού ημερολογίου")
                grantedAuthorization = granted
                guard generation == authenticationGeneration, scenePhase == .active else {
                    await diary.lock(granted)
                    return
                }
                let loadedEntries = try await diary.entries(using: granted)
                guard generation == authenticationGeneration, scenePhase == .active else {
                    await diary.lock(granted)
                    return
                }
                authorization = granted
                entries = loadedEntries
                isUnlocked = true
                authenticationMessage = nil
            } catch {
                if let grantedAuthorization { await diary.lock(grantedAuthorization) }
                guard generation == authenticationGeneration else { return }
                authenticationMessage = error.localizedDescription
            }
            isLoading = false
            isAuthenticating = false
        }
    }

    private func saveDraft() {
        guard isUnlocked, !isSaving else { return }
        isSaving = true
        authenticationMessage = nil
        let content = draft
        let editingID = editingEntryID
        let generation = authenticationGeneration
        guard let authorization else { isSaving = false; return }

        operationTask = Task { @MainActor in
            do {
                guard generation == authenticationGeneration, isUnlocked else { return }
                _ = try await diary.save(content: content, editing: editingID, using: authorization)
                let savedEntries = try await diary.entries(using: authorization)
                guard generation == authenticationGeneration, isUnlocked else { return }
                entries = savedEntries
                clearDraft()
            } catch {
                guard generation == authenticationGeneration, isUnlocked else { return }
                authenticationMessage = error.localizedDescription
            }
            guard generation == authenticationGeneration, isUnlocked else { return }
            isSaving = false
        }
    }

    private func deleteEntry(_ id: UUID) {
        guard isUnlocked, !isSaving else { return }
        isSaving = true
        authenticationMessage = nil
        let generation = authenticationGeneration
        guard let authorization else { isSaving = false; return }

        operationTask = Task { @MainActor in
            do {
                guard generation == authenticationGeneration, isUnlocked else { return }
                try await diary.delete(id: id, using: authorization)
                let remainingEntries = try await diary.entries(using: authorization)
                guard generation == authenticationGeneration, isUnlocked else { return }
                entries = remainingEntries
                if editingEntryID == id { clearDraft() }
            } catch {
                guard generation == authenticationGeneration, isUnlocked else { return }
                authenticationMessage = error.localizedDescription
            }
            guard generation == authenticationGeneration, isUnlocked else { return }
            isSaving = false
        }
    }

    private func clearDraft() {
        draft = ""
        editingEntryID = nil
        isEditorFocused = false
    }

    private func lockAndClear() {
        authenticationGeneration = UUID()
        let currentAuthorization = authorization
        authorization = nil
        if let currentAuthorization {
            Task { await diary.lock(currentAuthorization) }
        }
        operationTask?.cancel()
        operationTask = nil
        isUnlocked = false
        isAuthenticating = false
        entries.removeAll(keepingCapacity: false)
        clearDraft()
        authenticationMessage = nil
        isLoading = false
        isSaving = false
    }
}

public struct DecisionRecordCardView: View {
    public let decision: DecisionRecord

    public init(decision: DecisionRecord) {
        self.decision = decision
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("STRATEGIC DECISION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
                Spacer()
                Text("\(decision.confidencePercent)% CONFIDENCE")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentCyan)
            }

            Text(decision.decisionText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(R0llingTheme.textPrimary)

            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(R0llingTheme.textMuted)
                Text("Αναθεώρηση σε 90 ημέρες")
                    .font(.system(size: 11))
                    .foregroundColor(R0llingTheme.textSecondary)
            }
        }
        .padding(14)
        .r0llingBevelSurface(cornerRadius: 16)
    }
}

public struct PreMortemInversionCardView: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Pre-Mortem Inversion (Charlie Munger)", systemImage: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("INVERSION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
            }
            Text("«Αντίστρεψε πάντα: Πώς εξασφαλίζεις ότι η αρχιτεκτονική αποτυγχάνει; Εξάλειψε αυτά τα 3 σημεία πριν ξεκινήσεις.»")
                .font(.system(size: 12))
                .foregroundColor(R0llingTheme.textSecondary)
        }
        .padding(14)
        .r0llingBevelSurface(cornerRadius: 16)
    }
}

public struct AirGappedStatusBanner: View {
    @EnvironmentObject private var appState: AppState
    public var body: some View {
        HStack {
            Circle().fill(R0llingTheme.statusSuccess).frame(width: 8, height: 8)
            Text("AI REQUESTS: ON DEMAND")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(R0llingTheme.statusSuccess)
            Spacer()
            Text(appState.activeProvider == .hermes ? "HERMES" : "CLOUD AI")
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
        .r0llingBevelSurface(cornerRadius: 18)
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
        .r0llingBevelSurface(cornerRadius: 18)
    }
}

public struct FutureLetterboxWidgetCard: View {
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1
    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @State private var isSaving = false
    @State private var letters: [EncryptedDiaryStore.FutureLetterPreview] = []
    @State private var titleHint = ""
    @State private var payloadText = ""
    @State private var unlockDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now.addingTimeInterval(604_800)
    @State private var authenticationMessage: String?
    @State private var authenticationGeneration = UUID()
    @State private var operationTask: Task<Void, Never>?
    @State private var authorization: EncryptedDiaryStore.Authorization?

    private let store = EncryptedDiaryStore.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ΣΦΡΑΓΙΣΜΕΝΑ ΓΡΑΜΜΑΤΑ", systemImage: isUnlocked ? "lock.open.fill" : "lock.seal.fill")
                .font(.system(size: 10 * typeScale, weight: .bold, design: .monospaced))
                .foregroundColor(R0llingTheme.accentLavender)

            if isUnlocked {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Τίτλος για το μέλλον", text: $titleHint)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(minHeight: 44, alignment: .center)
                        .r0llingBevelInsetSurface(cornerRadius: 10)
                        .privacySensitive()

                    DatePicker(
                        "Ημερομηνία ξεκλειδώματος",
                        selection: $unlockDate,
                        in: Date()...Date.distantFuture,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .font(.system(size: 11 * typeScale))
                    .tint(R0llingTheme.accentLavender)

                    TextEditor(text: $payloadText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 72, maxHeight: 120)
                        .padding(6)
                        .r0llingBevelInsetSurface(cornerRadius: 10)
                        .accessibilityLabel("Μήνυμα για το μέλλον")
                        .privacySensitive()

                    HStack {
                        Text("Κρυπτογραφημένο στη συσκευή · εκτός backup")
                            .font(.system(size: 9 * typeScale))
                            .foregroundColor(R0llingTheme.textSecondary)
                        Spacer()
                        Button(action: sealLetter) {
                            Label("Σφράγισμα", systemImage: "lock.fill")
                                .font(.system(size: 11 * typeScale, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(R0llingTheme.accentLavender)
                        .disabled(isSaving || titleHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || payloadText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if isSaving {
                    ProgressView("Αποθήκευση κρυπτογραφημένου γράμματος…")
                        .font(.system(size: 11 * typeScale))
                        .tint(R0llingTheme.accentCyan)
                }

                if letters.isEmpty {
                    Text("Δεν έχεις ακόμη σφραγίσει κάποιο γράμμα.")
                        .font(.system(size: 11 * typeScale))
                        .foregroundColor(R0llingTheme.textSecondary)
                } else {
                    TimelineView(.periodic(from: Date(), by: 60)) { context in
                        VStack(spacing: 8) {
                            ForEach(letters) { letter in
                                futureLetterRow(letter, now: context.date)
                            }
                        }
                        .task(id: Int(context.date.timeIntervalSince1970 / 60)) {
                            await refreshLetters(generation: authenticationGeneration)
                        }
                    }
                }

                Button("Κλείδωμα γραμματοκιβωτίου", systemImage: "lock.fill", action: lockAndClear)
                    .font(.system(size: 10 * typeScale, weight: .medium))
                    .foregroundColor(R0llingTheme.textSecondary)
                    .frame(minHeight: 44)
            } else {
                Button(action: unlock) {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 23 * typeScale))
                            .foregroundColor(R0llingTheme.accentCyan)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isAuthenticating ? "Έλεγχος ταυτότητας…" : "Άνοιγμα γραμματοκιβωτίου")
                                .font(.system(size: 12 * typeScale, weight: .semibold))
                                .foregroundColor(R0llingTheme.textPrimary)
                            Text("Τα γράμματα αποθηκεύονται κρυπτογραφημένα και εμφανίζονται στην ημερομηνία που όρισες.")
                                .font(.system(size: 10 * typeScale))
                                .foregroundColor(R0llingTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
            }

            if let authenticationMessage {
                Text(authenticationMessage)
                    .font(.system(size: 11 * typeScale))
                    .foregroundColor(R0llingTheme.statusError)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                authenticationGeneration = UUID()
                lockAndClear()
            }
        }
        .onDisappear {
            authenticationGeneration = UUID()
            lockAndClear()
        }
        .padding(14)
        .r0llingBevelSurface(cornerRadius: 16)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: isUnlocked)
    }

    private func futureLetterRow(_ letter: EncryptedDiaryStore.FutureLetterPreview, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(letter.titleHint)
                        .font(.system(size: 12 * typeScale, weight: .semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                    if letter.unlockDate > now {
                        Text("\(countdown(to: letter.unlockDate, now: now)) · \(letter.unlockDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 10 * typeScale, design: .monospaced))
                            .foregroundColor(R0llingTheme.accentLavender)
                    } else {
                        Label("Το γράμμα ξεκλειδώθηκε", systemImage: "lock.open.fill")
                            .font(.system(size: 10 * typeScale, weight: .semibold))
                            .foregroundColor(R0llingTheme.statusSuccess)
                    }
                }
                Spacer()
                Button(role: .destructive) {
                    deleteLetter(letter.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11 * typeScale))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Διαγραφή γράμματος")
                .disabled(isSaving)
            }

            if letter.unlockDate <= now, let payloadText = letter.payloadText {
                Text(payloadText)
                    .font(.system(size: 12 * typeScale))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .privacySensitive()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(R0llingTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .privacySensitive()
    }

    private func countdown(to date: Date, now: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSince(now)))
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        if days > 0 { return "Ξεκλειδώνει σε \(days) ημ. και \(hours) ώρ." }
        let minutes = (remaining % 3_600) / 60
        return "Ξεκλειδώνει σε \(hours) ώρ. και \(minutes) λεπ."
    }

    @MainActor
    private func refreshLetters(generation: UUID) async {
        guard generation == authenticationGeneration, isUnlocked, scenePhase == .active else { return }
        guard let authorization else { return }
        do {
            let refreshed = try await store.futureLetters(using: authorization)
            guard generation == authenticationGeneration, isUnlocked, scenePhase == .active else { return }
            letters = refreshed
        } catch {
            guard generation == authenticationGeneration, isUnlocked else { return }
            authenticationMessage = error.localizedDescription
        }
    }

    private func unlock() {
        guard !isAuthenticating, scenePhase == .active else { return }
        isAuthenticating = true
        authenticationMessage = nil
        let generation = UUID()
        authenticationGeneration = generation

        Task { @MainActor in
            var grantedAuthorization: EncryptedDiaryStore.Authorization?
            do {
                let granted = try await store.authorize(reason: "Άνοιγμα σφραγισμένων γραμμάτων")
                grantedAuthorization = granted
                guard generation == authenticationGeneration, scenePhase == .active else {
                    await store.lock(granted)
                    return
                }
                let storedLetters = try await store.futureLetters(using: granted)
                guard generation == authenticationGeneration, scenePhase == .active else {
                    await store.lock(granted)
                    return
                }
                authorization = granted
                letters = storedLetters
                isUnlocked = true
                authenticationMessage = nil
            } catch {
                if let grantedAuthorization { await store.lock(grantedAuthorization) }
                guard generation == authenticationGeneration else { return }
                authenticationMessage = error.localizedDescription
            }
            isAuthenticating = false
        }
    }

    private func sealLetter() {
        guard isUnlocked, !isSaving else { return }
        isSaving = true
        authenticationMessage = nil
        let generation = authenticationGeneration
        let title = titleHint
        let content = payloadText
        let date = unlockDate
        guard let authorization else { isSaving = false; return }

        operationTask = Task { @MainActor in
            do {
                guard generation == authenticationGeneration, isUnlocked else { return }
                _ = try await store.sealFutureLetter(titleHint: title, unlockDate: date, payloadText: content, using: authorization)
                let storedLetters = try await store.futureLetters(using: authorization)
                guard generation == authenticationGeneration, isUnlocked else { return }
                letters = storedLetters
                titleHint = ""
                payloadText = ""
                unlockDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now.addingTimeInterval(604_800)
            } catch {
                guard generation == authenticationGeneration, isUnlocked else { return }
                authenticationMessage = error.localizedDescription
            }
            guard generation == authenticationGeneration, isUnlocked else { return }
            isSaving = false
        }
    }

    private func deleteLetter(_ id: UUID) {
        guard isUnlocked, !isSaving else { return }
        isSaving = true
        authenticationMessage = nil
        let generation = authenticationGeneration
        guard let authorization else { isSaving = false; return }

        operationTask = Task { @MainActor in
            do {
                guard generation == authenticationGeneration, isUnlocked else { return }
                try await store.deleteFutureLetter(id: id, using: authorization)
                let storedLetters = try await store.futureLetters(using: authorization)
                guard generation == authenticationGeneration, isUnlocked else { return }
                letters = storedLetters
            } catch {
                guard generation == authenticationGeneration, isUnlocked else { return }
                authenticationMessage = error.localizedDescription
            }
            guard generation == authenticationGeneration, isUnlocked else { return }
            isSaving = false
        }
    }

    private func lockAndClear() {
        authenticationGeneration = UUID()
        let currentAuthorization = authorization
        authorization = nil
        if let currentAuthorization {
            Task { await store.lock(currentAuthorization) }
        }
        operationTask?.cancel()
        operationTask = nil
        isUnlocked = false
        isAuthenticating = false
        isSaving = false
        letters.removeAll(keepingCapacity: false)
        titleHint = ""
        payloadText = ""
        authenticationMessage = nil
    }
}
