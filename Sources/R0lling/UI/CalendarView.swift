import SwiftUI

/// Οθόνη ιστορικού και αναζήτησης ημερολογίου (Calendar & Archive) σε στυλ Strava Activity Log
public struct CalendarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchQuery: String = ""
    @State private var selectedSourceFilter: EntrySource? = nil
    @State private var displayedEntries: [JournalEntry] = []
    @State private var entryProsEpeksergasia: JournalEntry?
    @State private var isSearching: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Αρχείο & Δραστηριότητα")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(R0llingTheme.textPrimary)

                    Text("ARCHIVE & TELEMETRY LOGS")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(R0llingTheme.textMuted)
                        .tracking(1.0)
                }
                Spacer()

                Text("\(displayedEntries.count) LOGS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.accentPurple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(R0llingTheme.accentPurple.opacity(0.15))
                    .clipShape(Capsule())
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

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(R0llingTheme.accentPurple)
                    .font(.system(size: 14, weight: .bold))

                TextField("Αναζήτηση σημειώσεων, #tags, δραστηριοτήτων...", text: $searchQuery)
                    .font(.system(size: 14))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .onChange(of: searchQuery) {
                        Task { await filterEntries() }
                    }

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        Task { await filterEntries() }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(12)
            .background(R0llingTheme.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(R0llingTheme.borderSubtle, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "Όλα",
                        isSelected: selectedSourceFilter == nil,
                        onTap: {
                            selectedSourceFilter = nil
                            Task { await filterEntries() }
                        }
                    )

                    ForEach(EntrySource.allCases, id: \.self) { source in
                        FilterChip(
                            title: source.displayName,
                            isSelected: selectedSourceFilter == source,
                            onTap: {
                                selectedSourceFilter = (selectedSourceFilter == source) ? nil : source
                                Task { await filterEntries() }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            ScrollView {
                LazyVStack(spacing: 14) {
                    if displayedEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 42))
                                .foregroundColor(R0llingTheme.textMuted)
                                .padding(.top, 40)
                            Text("Δεν βρέθηκαν καταγραφές")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(R0llingTheme.textSecondary)
                        }
                    } else {
                        ForEach(displayedEntries) { entry in
                            TimelineEntryCard(
                                entry: entry,
                                einaiObsidianSync: false,
                                onFavoriteToggle: {
                                    Task {
                                        await appState.toggleFavorite(entry: entry)
                                        await filterEntries()
                                    }
                                },
                                onDelete: {
                                    Task {
                                        await appState.deleteEntry(id: entry.id)
                                        await filterEntries()
                                    }
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
                .padding(16)
            }
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
        .sheet(item: $entryProsEpeksergasia) { entry in
            EntryEditorSheet(
                entry: entry,
                onSave: { updated in
                    entryProsEpeksergasia = nil
                    Task {
                        await appState.updateEntry(updated)
                        await filterEntries()
                    }
                },
                onCancel: { entryProsEpeksergasia = nil }
            )
        }
        .task {
            await filterEntries()
        }
        .onChange(of: appState.allEntries.count) {
            Task { await filterEntries() }
        }
    }

    /// A02: search μέσω `storage.searchEntries` (title + content + tags), όχι μόνο client content.
    private func filterEntries() async {
        isSearching = true
        defer { isSearching = false }

        let results = await appState.searchJournal(
            query: searchQuery,
            tag: nil,
            source: selectedSourceFilter
        )
        displayedEntries = results
    }
}

public struct FilterChip: View {
    public let title: String
    public let isSelected: Bool
    public let onTap: () -> Void

    public var body: some View {
        Button(action: {
            R0llingTheme.triggerHapticFeedback()
            onTap()
        }) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .heavy : .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : R0llingTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? R0llingTheme.accentPurple : R0llingTheme.bgElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? R0llingTheme.accentLavender : R0llingTheme.borderSubtle, lineWidth: 1)
                )
                .shadow(color: isSelected ? R0llingTheme.accentPurple.opacity(0.35) : Color.clear, radius: 6, x: 0, y: 2)
        }
    }
}
