import SwiftUI

// Disconnected Sovereign OS demo cards moved from UI/SovereignOSComponents.swift.
// They have no product caller and contain sample tasks/playback values, so they
// stay out of product surfaces under the Experimental freeze/orphan policy.
// Wiring either card requires a real data source and documented behavior first.

// MARK: - [01] Chief of Staff Card View

public struct ChiefOfStaffCardView: View {
    @State private var tasks: [ChiefOfStaffTask] = [
        ChiefOfStaffTask(title: "Ολοκλήρωση Sovereign Life OS architecture", priority: .high),
        ChiefOfStaffTask(title: "Έλεγχος Bevel telemetry concentric rings", priority: .medium),
        ChiefOfStaffTask(title: "Συγχρονισμός Obsidian Vault Zettelkasten", priority: .low)
    ]
    @State private var isDebriefing: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Επιτελείο Jarvis", systemImage: "sparkles.square.filled.on.square")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Text("LOCAL LAN")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(R0llingTheme.accentPurple.opacity(0.2))
                    .foregroundColor(R0llingTheme.accentLavender)
                    .clipShape(Capsule())
            }

            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    HStack(spacing: 12) {
                        Button {
                            toggleTask(task)
                        } label: {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? R0llingTheme.statusSuccess : R0llingTheme.accentLavender)
                                .font(.system(size: 16))
                        }
                        Text(task.title)
                            .font(.system(size: 13, weight: .regular))
                            .strikethrough(task.isCompleted, color: R0llingTheme.borderSubtle)
                            .foregroundColor(task.isCompleted ? R0llingTheme.textMuted : R0llingTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 3)
                }
            }

            Button {
                R0llingTheme.triggerHapticFeedback()
                isDebriefing.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                    Text("Εκτέλεση Voice Debrief")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(R0llingTheme.accentPurple)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 18)
    }

    private func toggleTask(_ task: ChiefOfStaffTask) {
        R0llingTheme.triggerHapticFeedback()
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].isCompleted.toggle()
        }
    }
}

// MARK: - [05] Daily Podcast Player Card

public struct DailyPodcastPlayerCard: View {
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.35

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(R0llingTheme.primaryButtonGradient)
                        .frame(width: 48, height: 48)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ΠΡΟΣΩΠΙΚΟ MORNING BRIEF")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(R0llingTheme.accentLavender)
                    Text("Ημερήσια Ανασκόπηση")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(R0llingTheme.textPrimary)
                }

                Spacer()

                Button {
                    isPlaying.toggle()
                    R0llingTheme.triggerHapticFeedback()
                } label: {
                    Circle()
                        .fill(R0llingTheme.accentPurple)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        )
                }
            }

            VStack(spacing: 4) {
                Slider(value: $progress)
                    .tint(R0llingTheme.accentCyan)
                HStack {
                    Text("01:14")
                    Spacer()
                    Text("03:00")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(R0llingTheme.textMuted)
            }
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 18)
    }
}
