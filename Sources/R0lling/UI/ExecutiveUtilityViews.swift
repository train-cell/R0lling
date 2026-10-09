import SwiftUI

// MARK: - [EXECUTIVE 01] Sovereign Interactive To-Do List

public struct SovereignToDoListView: View {
    @State private var newTaskTitle: String = ""
    @State private var taskExtractionText: String = ""
    @State private var selectedPriority: TaskPriority = .medium
    @EnvironmentObject private var appState: AppState
    @AppStorage("r0lling.executive.tasks") private var storedTasks: Data = Data()
    @State private var tasks: [ChiefOfStaffTask] = []
    @State private var tasksLoaded = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("To-Do List & Καθήκοντα", systemImage: "checklist")
                    .font(.headline.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("\(tasks.filter { !$0.isCompleted }.count) ΕΚΚΡΕΜΟΤΗΤΕΣ")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(R0llingTheme.accentCyan)
            }

            // Input Row
            HStack(spacing: 8) {
                TextField("Νέα εκκρεμότητα...", text: $newTaskTitle)
                    .font(.footnote)
                    .foregroundColor(R0llingTheme.textPrimary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .r0llingBevelInsetSurface(cornerRadius: 10)

                Picker("Προτεραιότητα", selection: $selectedPriority) {
                    Text("Υψηλή").tag(TaskPriority.high)
                    Text("Μέτρια").tag(TaskPriority.medium)
                    Text("Χαμηλή").tag(TaskPriority.low)
                }
                .pickerStyle(.menu)
                .tint(R0llingTheme.accentLavender)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .r0llingBevelCapsule()

                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .r0llingBevelCapsule()
                }
                .accessibilityLabel("Προσθήκη εργασίας")
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Τοπική μετατροπή κειμένου: γράψε μία εργασία ανά γραμμή. Δεν αποστέλλεται σε AI.")
                        .font(.caption)
                        .foregroundColor(R0llingTheme.textSecondary)

                    TextEditor(text: $taskExtractionText)
                        .font(.footnote)
                        .foregroundColor(R0llingTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 76, maxHeight: 120)
                        .padding(6)
                        .r0llingBevelInsetSurface(cornerRadius: 12)
                        .accessibilityLabel("Κείμενο για τοπική μετατροπή σε εργασίες")

                    Button(action: extractTasksFromText) {
                        Label("Προσθήκη εργασιών από κείμενο", systemImage: "text.badge.plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(R0llingTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .r0llingBevelCapsule()
                    }
                    .buttonStyle(.plain)
                    .disabled(taskExtractionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 8)
            } label: {
                Label("Μετατροπή κειμένου σε εργασίες", systemImage: "text.badge.plus")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(R0llingTheme.accentLavender)
            }
            .tint(R0llingTheme.accentLavender)

            // Task List
            VStack(spacing: 6) {
                ForEach(tasks) { task in
                    HStack(spacing: 10) {
                        Button {
                            toggleTask(task)
                        } label: {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? R0llingTheme.statusSuccess : priorityColor(task.priority))
                            .font(.body)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(task.isCompleted ? "Σήμανση ως εκκρεμούς: \(task.title)" : "Ολοκλήρωση εργασίας: \(task.title)")

                        Text(task.title)
                            .font(.footnote)
                            .strikethrough(task.isCompleted, color: R0llingTheme.borderSubtle)
                            .foregroundColor(task.isCompleted ? R0llingTheme.textMuted : R0llingTheme.textPrimary)

                        Spacer()

                        Circle()
                            .fill(priorityColor(task.priority))
                            .frame(width: 6, height: 6)

                        Button {
                            deleteTask(task)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(R0llingTheme.textMuted)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Διαγραφή εργασίας: \(task.title)")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .disabled(!tasksLoaded)
        .task {
            do {
                if storedTasks.isEmpty { tasks = [] }
                else { tasks = try JSONDecoder().decode([ChiefOfStaffTask].self, from: storedTasks) }
                tasksLoaded = true
            } catch { appState.showToast("Αδυναμία φόρτωσης καθηκόντων. Τα αποθηκευμένα δεδομένα διατηρήθηκαν.") }
        }
        .onChange(of: tasks) { _, value in
            guard tasksLoaded else { return }
            do { storedTasks = try JSONEncoder().encode(value) }
            catch { appState.showToast("Αποτυχία αποθήκευσης καθηκόντων.") }
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 18)
    }

    private func addTask() {
        let clean = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        R0llingTheme.triggerHapticFeedback()
        tasks.append(ChiefOfStaffTask(title: clean, priority: selectedPriority))
        newTaskTitle = ""
    }

    private func extractTasksFromText() {
        let source = taskExtractionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, tasksLoaded else { return }

        Task {
            let parsedTasks = await appState.chiefOfStaff.parseTasks(from: source)
            var knownTitles = Set(tasks.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            let additions = parsedTasks.filter { task in
                let normalizedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !normalizedTitle.isEmpty && knownTitles.insert(normalizedTitle).inserted
            }
            guard !additions.isEmpty else {
                appState.showToast("Δεν βρέθηκαν νέες εργασίες για προσθήκη.")
                return
            }
            tasks.append(contentsOf: additions)
            taskExtractionText = ""
            appState.showToast("Προστέθηκαν \(additions.count) εργασίες.")
        }
    }

    private func toggleTask(_ task: ChiefOfStaffTask) {
        R0llingTheme.triggerHapticFeedback()
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].isCompleted.toggle()
        }
    }

    private func deleteTask(_ task: ChiefOfStaffTask) {
        R0llingTheme.triggerHapticFeedback()
        tasks.removeAll(where: { $0.id == task.id })
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high: return R0llingTheme.statusError
        case .medium: return R0llingTheme.accentCyan
        case .low: return R0llingTheme.accentLavender
        }
    }
}

// MARK: - [EXECUTIVE 02] Σημειωματάριο (Quick Scratchpad)

public struct SovereignScratchpadView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isSaving = false
    @State private var noteContent: String = ""
    @State private var isSaved: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Σημειωματάριο & Σκέψεις", systemImage: "note.text")
                    .font(.headline.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("\(noteContent.count) ΧΑΡΑΚΤΗΡΕΣ")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(R0llingTheme.accentLavender)
            }

            TextEditor(text: $noteContent)
                .onChange(of: noteContent) { _, _ in isSaved = false }
                .disabled(isSaving)
                .frame(minHeight: 90)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(R0llingTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .r0llingBevelInsetSurface(cornerRadius: 12)

            HStack {
                if isSaved {
                    Label("Αποθηκεύτηκε στο ημερολόγιο", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(R0llingTheme.statusSuccess)
                }
                Spacer()
                Button {
                    R0llingTheme.triggerHapticFeedback()
                    isSaving = true
                    Task { @MainActor in
                        isSaved = await appState.addNote(text: noteContent)
                        isSaving = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Αποθήκευση Σημείωσης")
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .foregroundColor(R0llingTheme.textPrimary)
                    .r0llingBevelCapsule()
                }
                .disabled(isSaving || noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 18)
    }
}

// MARK: - [EXECUTIVE 03] Χρονόμετρο & Lap Timer

public struct SovereignStopwatchTimerView: View {
    @State private var elapsedTime: TimeInterval = 0.0
    @State private var isRunning: Bool = false
    @State private var laps: [TimeInterval] = []
    @State private var timer: Timer?
    @State private var startedAtUptime: TimeInterval?
    @State private var accumulatedTime: TimeInterval = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Χρονόμετρο Υψηλής Ακρίβειας", systemImage: "stopwatch.fill")
                    .font(.headline.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("PRECISION HUD")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(R0llingTheme.accentCyan)
            }

            // Large Digital Display
            Text(formattedTime(elapsedTime))
                .font(.system(.largeTitle, design: .monospaced).weight(.heavy))
                .foregroundColor(R0llingTheme.accentCyan)
                .padding(.vertical, 4)

            // Controls
            HStack(spacing: 16) {
                Button(action: resetOrLap) {
                    Text(isRunning ? "Lap" : "Reset")
                        .font(.system(.footnote, design: .monospaced).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundColor(R0llingTheme.textSecondary)
                        .r0llingBevelCapsule()
                }
                .buttonStyle(.plain)

                Button(action: toggleStartStop) {
                    Text(isRunning ? "Stop" : "Start")
                        .font(.system(.footnote, design: .monospaced).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundColor(isRunning ? R0llingTheme.statusError : R0llingTheme.statusSuccess)
                        .r0llingBevelCapsule()
                }
                .buttonStyle(.plain)
            }

            // Lap Records
            if !laps.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(laps.enumerated().reversed().prefix(3)), id: \.offset) { index, lapTime in
                        HStack {
                            Text("Lap \(index + 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(R0llingTheme.textMuted)
                            Spacer()
                            Text(formattedTime(lapTime))
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundColor(R0llingTheme.accentLavender)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .onDisappear { stopTimer() }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 18)
    }

    private func toggleStartStop() {
        R0llingTheme.triggerHapticFeedback()
        if isRunning { stopTimer() } else {
            startedAtUptime = ProcessInfo.processInfo.systemUptime
            isRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task { @MainActor in
                    if let start = startedAtUptime {
                        elapsedTime = accumulatedTime + ProcessInfo.processInfo.systemUptime - start
                    }
                }
            }
        }
    }

    /// Uses monotonic elapsed time and releases the timer on stop or disappearance.
    private func stopTimer() {
        if let start = startedAtUptime {
            elapsedTime = accumulatedTime + ProcessInfo.processInfo.systemUptime - start
        }
        accumulatedTime = elapsedTime
        startedAtUptime = nil
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func resetOrLap() {
        R0llingTheme.triggerHapticFeedback()
        if isRunning {
            laps.append(elapsedTime)
        } else {
            elapsedTime = 0.0
            accumulatedTime = 0
            laps.removeAll()
        }
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let fraction = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, fraction)
    }
}
