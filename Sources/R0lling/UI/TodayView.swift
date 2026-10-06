import SwiftUI

/// Κύρια οθόνη ημερήσιας ροής (Today View) με Strava Activity Feed & Bevel 3-Ring Telemetry
public struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @State private var composerText: String = ""
    @State private var selectedTags: String = ""
    @State private var entryProsEpeksergasia: JournalEntry?

    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerView

                ScrollView {
                    LazyVStack(spacing: 16) {
                        BevelTelemetryCard(
                            bufferDuration: appState.bufferDuration,
                            todayClipsCount: appState.todayEntries.filter { !$0.attachments.isEmpty }.count,
                            isStreaming: appState.isStreaming,
                            glassesStatus: appState.glassesState.statusDescription
                        )

                        if !appState.timeCapsuleMemories.isEmpty {
                            timeCapsuleBanner
                        }

                        if appState.todayEntries.isEmpty {
                            emptyStateView
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("ACTIVITY TIMELINE")
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        .foregroundColor(R0llingTheme.textMuted)
                                        .tracking(1.2)
                                    Spacer()
                                    Text("\(appState.todayEntries.count) ENTRIES")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(R0llingTheme.accentPurple)
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
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("R0lling")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(R0llingTheme.textPrimary)

                    Text("POV LAB")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(R0llingTheme.accentPurple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(R0llingTheme.accentPurple.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                Text(Date().formattedGreekHeader().uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(R0llingTheme.textSecondary)
                    .tracking(0.6)
            }

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
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 13, weight: .bold))
                    Text(appState.isStreaming ? "REC LIVE" : appState.glassesState.statusDescription.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    appState.isStreaming ? R0llingTheme.primaryButtonGradient : LinearGradient(
                        colors: [R0llingTheme.bgElevated, R0llingTheme.bgElevated],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(appState.isStreaming ? R0llingTheme.accentPurple : R0llingTheme.borderSubtle, lineWidth: 1)
                )
                .shadow(color: appState.isStreaming ? R0llingTheme.accentPurple.opacity(0.35) : Color.clear, radius: 8, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(R0llingTheme.bgSurface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(R0llingTheme.borderSubtle),
            alignment: .bottom
        )
    }

    private var timeCapsuleBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(R0llingTheme.bevelCyan)
                    .font(.system(size: 13, weight: .bold))
                Text("ΣΑΝ ΣΗΜΕΡΑ — TIME CAPSULE")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(R0llingTheme.bevelCyan)
                    .tracking(1.0)
                Spacer()
            }
            ForEach(appState.timeCapsuleMemories) { mem in
                Text("⏳ \(mem.displayText): «\(mem.entry.content)»")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(R0llingTheme.textPrimary)
            }
        }
        .padding(14)
        .background(R0llingTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundColor(R0llingTheme.textPrimary)
                .tracking(1.2)

            Text("Ξεκίνα τη ροή από τα Meta Glasses, σημείωσε μια σκέψη, ή επισύναψε φωτογραφία/βίντεο από Photos.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(R0llingTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 20)
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            Button(action: {
                R0llingTheme.triggerHapticFeedback()
                appState.toggleSpeechDictation()
            }) {
                Image(systemName: appState.isListeningSpeech ? "waveform" : "mic.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(appState.isListeningSpeech ? .white : R0llingTheme.accentPurple)
                    .frame(width: 44, height: 44)
                    .background(appState.isListeningSpeech ? R0llingTheme.accentPurple : R0llingTheme.bgElevated)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(appState.isListeningSpeech ? R0llingTheme.accentLavender : R0llingTheme.borderSubtle, lineWidth: 1)
                    )
            }

            PhotosMediaPickerButton(
                onImport: { data, filename, mediaType in
                    let note = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
                    await appState.attachMediaData(
                        data: data,
                        originalFilename: filename,
                        mediaType: mediaType,
                        noteText: note.isEmpty ? nil : note
                    )
                    if !note.isEmpty {
                        composerText = ""
                    }
                },
                onError: { minima in
                    appState.showToast(minima)
                }
            )

            TextField("Σημείωση δραστηριότητας...", text: $composerText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(R0llingTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(R0llingTheme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(R0llingTheme.borderSubtle, lineWidth: 1)
                )

            Button(action: {
                let text = composerText
                composerText = ""
                Task {
                    await appState.addNote(text: text)
                }
            }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? LinearGradient(colors: [R0llingTheme.bgElevated, R0llingTheme.bgElevated], startPoint: .top, endPoint: .bottom)
                            : R0llingTheme.primaryButtonGradient
                    )
                    .clipShape(Circle())
                    .shadow(
                        color: composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.clear
                            : R0llingTheme.accentPurple.opacity(0.4),
                        radius: 6, x: 0, y: 2
                    )
            }
            .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(R0llingTheme.bgSurface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(R0llingTheme.borderSubtle),
            alignment: .top
        )
    }
}
