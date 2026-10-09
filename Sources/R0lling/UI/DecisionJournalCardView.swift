import SwiftUI

/// Private 90-day decision journal backed by the encrypted local vault.
public struct DecisionJournalCardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @State private var isWorking = false
    @State private var records: [DecisionRecord] = []
    @State private var decisionDraft = ""
    @State private var assumptionsDraft = ""
    @State private var confidence = 70.0
    @State private var reviewDraft = ""
    @State private var reviewingID: UUID?
    @State private var message: String?
    @State private var authenticationGeneration = UUID()
    @State private var operationTask: Task<Void, Never>?
    @State private var authorization: EncryptedDiaryStore.Authorization?

    private let store = EncryptedDiaryStore.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ΗΜΕΡΟΛΟΓΙΟ ΑΠΟΦΑΣΕΩΝ · ΑΝΑΣΚΟΠΗΣΗ 90 ΗΜΕΡΩΝ", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 10 * typeScale, weight: .bold, design: .monospaced))
                .foregroundColor(R0llingTheme.accentLavender)

            if isUnlocked {
                editor
                    .transition(.opacity.combined(with: .move(edge: .top)))
                if isWorking {
                    ProgressView("Αποθήκευση στο κρυπτογραφημένο vault…")
                        .font(.system(size: 11 * typeScale))
                        .tint(R0llingTheme.accentCyan)
                }
                if records.isEmpty {
                    Text("Δεν υπάρχουν ακόμη αποφάσεις.")
                        .font(.system(size: 11 * typeScale))
                        .foregroundColor(R0llingTheme.textSecondary)
                } else {
                    TimelineView(.periodic(from: Date(), by: 3_600)) { context in
                        VStack(spacing: 8) {
                            ForEach(records) { record in
                                decisionRow(record, now: context.date)
                            }
                        }
                    }
                }
                Button("Κλείδωμα ημερολογίου", systemImage: "lock.fill", action: lockAndClear)
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
                            Text(isAuthenticating ? "Έλεγχος ταυτότητας…" : "Άνοιγμα ιδιωτικού ημερολογίου αποφάσεων")
                                .font(.system(size: 12 * typeScale, weight: .semibold))
                                .foregroundColor(R0llingTheme.textPrimary)
                            Text("Οι αποφάσεις και οι παραδοχές τους αποθηκεύονται κρυπτογραφημένες σε αυτή τη συσκευή.")
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

            if let message {
                Text(message)
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
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: isUnlocked)
        .padding(14)
        .r0llingBevelSurface(cornerRadius: 16)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Ποια απόφαση πήρες;", text: $decisionDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(minHeight: 44, alignment: .center)
                .r0llingBevelInsetSurface(cornerRadius: 10)
                .privacySensitive()

            Text("Κύριες παραδοχές · μία ανά γραμμή")
                .font(.system(size: 10 * typeScale, weight: .medium))
                .foregroundColor(R0llingTheme.textSecondary)
            TextEditor(text: $assumptionsDraft)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 64, maxHeight: 110)
                .padding(6)
                .r0llingBevelInsetSurface(cornerRadius: 10)
                .accessibilityLabel("Κύριες παραδοχές της απόφασης")
                .privacySensitive()

            HStack {
                Text("Βεβαιότητα")
                    .font(.system(size: 11 * typeScale))
                    .foregroundColor(R0llingTheme.textSecondary)
                Slider(value: $confidence, in: 0...100, step: 1)
                    .tint(R0llingTheme.accentLavender)
                    .accessibilityLabel("Ποσοστό βεβαιότητας")
                Text("\(Int(confidence))%")
                    .font(.system(size: 11 * typeScale, weight: .semibold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentCyan)
                    .frame(minWidth: 34, alignment: .trailing)
            }

            HStack {
                Text("Ανασκόπηση σε 90 ημέρες")
                    .font(.system(size: 10 * typeScale, design: .monospaced))
                    .foregroundColor(R0llingTheme.textSecondary)
                Spacer()
                Button(action: saveDecision) {
                    Label("Καταχώριση", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11 * typeScale, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(R0llingTheme.accentLavender)
                .disabled(isWorking || decisionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || assumptionsDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func decisionRow(_ record: DecisionRecord, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.decisionText)
                        .font(.system(size: 12 * typeScale, weight: .semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(record.confidencePercent)% βεβαιότητα · \(record.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 9 * typeScale, design: .monospaced))
                        .foregroundColor(R0llingTheme.accentCyan)
                }
                Spacer()
                Button(role: .destructive) {
                    deleteDecision(record.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11 * typeScale))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Διαγραφή απόφασης")
                .disabled(isWorking)
            }

            ForEach(Array(record.coreAssumptions.enumerated()), id: \.offset) { _, assumption in
                Label(assumption, systemImage: "circle.small")
                    .font(.system(size: 10 * typeScale))
                    .foregroundColor(R0llingTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if record.isReviewed {
                Label("Ανασκόπηση ολοκληρώθηκε", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 10 * typeScale, weight: .semibold))
                    .foregroundColor(R0llingTheme.statusSuccess)
                if let outcome = record.outcomeReview {
                    Text(outcome)
                        .font(.system(size: 11 * typeScale))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .privacySensitive()
                }
            } else if record.reviewDate <= now {
                if reviewingID == record.id {
                    TextEditor(text: $reviewDraft)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 58, maxHeight: 100)
                        .padding(5)
                        .r0llingBevelInsetSurface(cornerRadius: 9)
                        .accessibilityLabel("Αποτέλεσμα ανασκόπησης")
                        .privacySensitive()

                    Button("Ολοκλήρωση ανασκόπησης", systemImage: "checkmark", action: { reviewDecision(record.id) })
                        .font(.system(size: 10 * typeScale, weight: .semibold))
                        .disabled(isWorking || reviewDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("Ώρα για ανασκόπηση", systemImage: "clock.arrow.circlepath") {
                        reviewingID = record.id
                        reviewDraft = ""
                    }
                    .font(.system(size: 10 * typeScale, weight: .semibold))
                    .tint(R0llingTheme.accentLavender)
                }
            } else {
                Text("Αναθεώρηση: \(record.reviewDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 10 * typeScale, design: .monospaced))
                    .foregroundColor(R0llingTheme.textSecondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(R0llingTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .privacySensitive()
    }

    private func unlock() {
        guard !isAuthenticating, scenePhase == .active else { return }
        isAuthenticating = true
        message = nil
        let generation = UUID()
        authenticationGeneration = generation

        Task { @MainActor in
            var grantedAuthorization: EncryptedDiaryStore.Authorization?
            do {
                let granted = try await store.authorize(reason: "Άνοιγμα ημερολογίου αποφάσεων")
                grantedAuthorization = granted
                guard generation == authenticationGeneration, scenePhase == .active else {
                    await store.lock(granted)
                    return
                }
                let loadedRecords = try await store.decisionRecords(using: granted)
                guard generation == authenticationGeneration, scenePhase == .active else {
                    await store.lock(granted)
                    return
                }
                authorization = granted
                records = loadedRecords
                isUnlocked = true
                message = nil
            } catch {
                if let grantedAuthorization { await store.lock(grantedAuthorization) }
                guard generation == authenticationGeneration else { return }
                message = error.localizedDescription
            }
            isAuthenticating = false
        }
    }

    private func saveDecision() {
        guard isUnlocked, !isWorking else { return }
        isWorking = true
        message = nil
        let generation = authenticationGeneration
        let cleanTitle = decisionDraft
        let assumptions = assumptionsDraft
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let now = Date()
        let reviewDate = Calendar.current.date(byAdding: .day, value: 90, to: now) ?? now.addingTimeInterval(90 * 86_400)
        guard let authorization else { isWorking = false; return }
        let record = DecisionRecord(
            decisionText: cleanTitle,
            coreAssumptions: assumptions,
            confidencePercent: Int(confidence),
            createdAt: now,
            reviewDate: reviewDate
        )

        operationTask = Task { @MainActor in
            do {
                guard generation == authenticationGeneration, isUnlocked else { return }
                _ = try await store.saveDecision(record, using: authorization)
                let updatedRecords = try await store.decisionRecords(using: authorization)
                guard generation == authenticationGeneration, isUnlocked else { return }
                records = updatedRecords
                decisionDraft = ""
                assumptionsDraft = ""
                confidence = 70
            } catch {
                guard generation == authenticationGeneration, isUnlocked else { return }
                message = error.localizedDescription
            }
            guard generation == authenticationGeneration, isUnlocked else { return }
            isWorking = false
        }
    }

    private func reviewDecision(_ id: UUID) {
        guard isUnlocked, !isWorking else { return }
        isWorking = true
        message = nil
        let generation = authenticationGeneration
        let outcome = reviewDraft
        guard let authorization else { isWorking = false; return }

        operationTask = Task { @MainActor in
            do {
                guard generation == authenticationGeneration, isUnlocked else { return }
                _ = try await store.reviewDecision(id: id, outcome: outcome, using: authorization)
                let updatedRecords = try await store.decisionRecords(using: authorization)
                guard generation == authenticationGeneration, isUnlocked else { return }
                records = updatedRecords
                reviewingID = nil
                reviewDraft = ""
            } catch {
                guard generation == authenticationGeneration, isUnlocked else { return }
                message = error.localizedDescription
            }
            guard generation == authenticationGeneration, isUnlocked else { return }
            isWorking = false
        }
    }

    private func deleteDecision(_ id: UUID) {
        guard isUnlocked, !isWorking else { return }
        isWorking = true
        message = nil
        let generation = authenticationGeneration
        guard let authorization else { isWorking = false; return }

        operationTask = Task { @MainActor in
            do {
                guard generation == authenticationGeneration, isUnlocked else { return }
                try await store.deleteDecision(id: id, using: authorization)
                let updatedRecords = try await store.decisionRecords(using: authorization)
                guard generation == authenticationGeneration, isUnlocked else { return }
                records = updatedRecords
                if reviewingID == id {
                    reviewingID = nil
                    reviewDraft = ""
                }
            } catch {
                guard generation == authenticationGeneration, isUnlocked else { return }
                message = error.localizedDescription
            }
            guard generation == authenticationGeneration, isUnlocked else { return }
            isWorking = false
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
        isWorking = false
        records.removeAll(keepingCapacity: false)
        decisionDraft = ""
        assumptionsDraft = ""
        reviewDraft = ""
        reviewingID = nil
        message = nil
        confidence = 70
    }
}
