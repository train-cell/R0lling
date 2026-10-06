import SwiftUI

/// Κύρια οθόνη ημερήσιας ροής (Today View) με Discord-style timeline & Twitch clip floating action
public struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @State private var composerText: String = ""
    @State private var selectedTags: String = ""

    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Top Header
                headerView

                // Timeline Scroll
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // «Σαν Σήμερα» Time Capsule Banner
                        if !appState.timeCapsuleMemories.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(R0llingTheme.accentLavender)
                                    Text("Σαν Σήμερα")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(R0llingTheme.accentLavender)
                                    Spacer()
                                }
                                ForEach(appState.timeCapsuleMemories) { mem in
                                    Text("⏳ \(mem.displayText): «\(mem.entry.content)»")
                                        .font(.system(size: 13))
                                        .foregroundColor(R0llingTheme.textPrimary)
                                }
                            }
                            .padding(12)
                            .background(R0llingTheme.accentPurple.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(R0llingTheme.accentPurple.opacity(0.4), lineWidth: 1)
                            )
                        }

                        if appState.todayEntries.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(appState.todayEntries) { entry in
                                TimelineEntryCard(entry: entry)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, appState.isStreaming ? 140 : 80)
                }

                // Bottom Composer
                composerBar
            }

            // Floating Clip Bar (Εμφανίζεται μόνο όταν η ροή είναι ενεργή)
            if appState.isStreaming {
                FloatingClipBar(
                    bufferDuration: appState.bufferDuration,
                    isStreaming: appState.isStreaming,
                    onClipTapped: {
                        Task {
                            await appState.triggerClip(seconds: 10.0)
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 75)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("R0lling")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(R0llingTheme.textPrimary)

                Text(Date().formattedGreekHeader())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(R0llingTheme.textSecondary)
            }

            Spacer()

            // Glasses Connection & Streaming Badge
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
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 14, weight: .semibold))
                    Text(appState.isStreaming ? "STREAMING" : (appState.glassesState.statusDescription))
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(appState.isStreaming ? .white : R0llingTheme.accentLavender)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(appState.isStreaming ? R0llingTheme.statusLive : R0llingTheme.bgElevated)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(R0llingTheme.bgSurface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(R0llingTheme.borderSubtle),
            alignment: .bottom
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(R0llingTheme.textMuted)
                .padding(.top, 40)

            Text("Καμία καταγραφή σήμερα ακόμη")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(R0llingTheme.textPrimary)

            Text("Γράψε μια σκέψη, πάτησε το μικρόφωνο ή συνέδεσε τα Meta Glasses για αυτόματο clipping.")
                .font(.system(size: 14))
                .foregroundColor(R0llingTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            // Dictation button
            Button(action: {
                R0llingTheme.triggerHapticFeedback()
                appState.toggleSpeechDictation()
            }) {
                Image(systemName: appState.isListeningSpeech ? "mic.fill" : "mic")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(appState.isListeningSpeech ? .white : R0llingTheme.accentLavender)
                    .frame(width: 44, height: 44)
                    .background(appState.isListeningSpeech ? R0llingTheme.statusLive : R0llingTheme.bgElevated)
                    .clipShape(Circle())
            }

            // Input field
            TextField("Σημείωση για σήμερα...", text: $composerText)
                .font(.system(size: 15))
                .foregroundColor(R0llingTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(R0llingTheme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Send button
            Button(action: {
                let text = composerText
                composerText = ""
                Task {
                    await appState.addNote(text: text)
                }
            }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? R0llingTheme.bgElevated : R0llingTheme.accentPurple)
                    .clipShape(Circle())
            }
            .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(R0llingTheme.bgSurface)
    }
}
