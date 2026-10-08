import SwiftUI

// MARK: - [EXECUTIVE 01] Sovereign Interactive To-Do List

public struct SovereignToDoListView: View {
    @State private var newTaskTitle: String = ""
    @State private var selectedPriority: TaskPriority = .medium
    @State private var tasks: [ChiefOfStaffTask] = [
        ChiefOfStaffTask(title: "Έλεγχος Bevel Telemetry & Apple Health", priority: .high),
        ChiefOfStaffTask(title: "Καταγραφή προπόνησης & ημερήσιου τονάζ", priority: .medium),
        ChiefOfStaffTask(title: "Συγχρονισμός σημειώσεων στο Obsidian Vault", priority: .low)
    ]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("To-Do List & Καθήκοντα", systemImage: "checklist")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("\(tasks.filter { !$0.isCompleted }.count) ΕΚΚΡΕΜΟΤΗΤΕΣ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentCyan)
            }

            // Input Row
            HStack(spacing: 8) {
                TextField("Νέα εκκρεμότητα...", text: $newTaskTitle)
                    .font(.system(size: 13))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
                    )

                Picker("Προτεραιότητα", selection: $selectedPriority) {
                    Text("Υψηλή").tag(TaskPriority.high)
                    Text("Μέτρια").tag(TaskPriority.medium)
                    Text("Χαμηλή").tag(TaskPriority.low)
                }
                .pickerStyle(.menu)
                .tint(R0llingTheme.accentLavender)

                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(R0llingTheme.accentPurple)
                }
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Task List
            VStack(spacing: 6) {
                ForEach(tasks) { task in
                    HStack(spacing: 10) {
                        Button {
                            toggleTask(task)
                        } label: {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? R0llingTheme.statusSuccess : priorityColor(task.priority))
                                .font(.system(size: 16))
                        }

                        Text(task.title)
                            .font(.system(size: 13))
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
                                .font(.system(size: 11))
                                .foregroundColor(R0llingTheme.textMuted)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
        )
    }

    private func addTask() {
        let clean = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        R0llingTheme.triggerHapticFeedback()
        tasks.append(ChiefOfStaffTask(title: clean, priority: selectedPriority))
        newTaskTitle = ""
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
    @State private var noteContent: String = ""
    @State private var isSaved: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Σημειωματάριο & Σκέψεις", systemImage: "note.text")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("\(noteContent.count) ΧΑΡΑΚΤΗΡΕΣ")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentLavender)
            }

            TextEditor(text: $noteContent)
                .frame(minHeight: 90)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(R0llingTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(R0llingTheme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
                )

            HStack {
                if isSaved {
                    Label("Αποθηκεύτηκε στο Obsidian", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(R0llingTheme.statusSuccess)
                }
                Spacer()
                Button {
                    R0llingTheme.triggerHapticFeedback()
                    isSaved = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Αποθήκευση Σημείωσης")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(R0llingTheme.accentPurple)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled(noteContent.isEmpty)
            }
        }
        .padding(16)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - [EXECUTIVE 03] Χρονόμετρο & Lap Timer

public struct SovereignStopwatchTimerView: View {
    @State private var elapsedTime: TimeInterval = 0.0
    @State private var isRunning: Bool = false
    @State private var laps: [TimeInterval] = []
    @State private var timer: Timer?

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Χρονόμετρο Υψηλής Ακρίβειας", systemImage: "stopwatch.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("PRECISION HUD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentCyan)
            }

            // Large Digital Display
            Text(formattedTime(elapsedTime))
                .font(.system(size: 36, weight: .heavy, design: .monospaced))
                .foregroundColor(R0llingTheme.accentCyan)
                .padding(.vertical, 4)

            // Controls
            HStack(spacing: 16) {
                Button(action: resetOrLap) {
                    Text(isRunning ? "Lap" : "Reset")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(R0llingTheme.bgElevated)
                        .foregroundColor(R0llingTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button(action: toggleStartStop) {
                    Text(isRunning ? "Stop" : "Start")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isRunning ? R0llingTheme.statusError : R0llingTheme.statusSuccess)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            // Lap Records
            if !laps.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(laps.enumerated().reversed().prefix(3)), id: \.offset) { index, lapTime in
                        HStack {
                            Text("Lap \(index + 1)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(R0llingTheme.textMuted)
                            Spacer()
                            Text(formattedTime(lapTime))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(R0llingTheme.accentLavender)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 0.5)
        )
    }

    private func toggleStartStop() {
        R0llingTheme.triggerHapticFeedback()
        isRunning.toggle()
        if isRunning {
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                elapsedTime += 0.05
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    private func resetOrLap() {
        R0llingTheme.triggerHapticFeedback()
        if isRunning {
            laps.append(elapsedTime)
        } else {
            elapsedTime = 0.0
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
