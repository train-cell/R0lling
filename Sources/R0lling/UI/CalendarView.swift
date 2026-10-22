import SwiftUI

/// Οθόνη ιστορικού και αναζήτησης ημερολογίου.
public struct CalendarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchQuery: String = ""
    @State private var selectedSourceFilter: EntrySource? = nil
    @State private var displayedEntries: [JournalEntry] = []
    @State private var entryProsEpeksergasia: JournalEntry?
    @State private var isSearching: Bool = false
    @State private var searchRequestGate = JournalSearchRequestGate()

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Αρχείο & Δραστηριότητα")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("Σημειώσεις και δραστηριότητες")
                        .font(.subheadline)
                        .foregroundColor(R0llingTheme.textSecondary)
                }
                .accessibilityElement(children: .combine)
                Spacer()

                Text("\(displayedEntries.count) καταγραφές")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(R0llingTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 32)
                    .r0llingBevelCapsule()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(R0llingTheme.bgPrimary)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(R0llingTheme.accentPurple)
                    .font(.system(size: 14, weight: .bold))
                    .accessibilityHidden(true)

                TextField("Αναζήτηση σημειώσεων, #tags, δραστηριοτήτων...", text: $searchQuery)
                    .font(.subheadline)
                    .foregroundColor(R0llingTheme.textPrimary)
                    .accessibilityLabel("Αναζήτηση στο ημερολόγιο")
                    .accessibilityHint("Αναζήτησε σε κείμενο, τίτλους, tags και δραστηριότητες.")
                    .onChange(of: searchQuery) {
                        Task { await filterEntries() }
                    }
                    .onSubmit {
                        Task { await filterEntries() }
                    }

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        Task { await filterEntries() }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(R0llingTheme.textSecondary)
                            // 44pt hit area (DESIGN.md) without growing the padded search bar.
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .padding(.vertical, -12)
                    }
                    .accessibilityLabel("Καθαρισμός αναζήτησης")
                }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                        .accessibilityLabel("Αναζήτηση σε εξέλιξη")
                }
            }
            .padding(12)
            .r0llingBevelInsetSurface(cornerRadius: 14)
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
        let request = searchRequestGate.beginRequest()
        isSearching = true
        defer {
            if searchRequestGate.canApplyResult(for: request) {
                isSearching = false
            }
        }

        let results = await appState.searchJournal(
            query: searchQuery,
            tag: nil,
            source: selectedSourceFilter
        )
        guard searchRequestGate.canApplyResult(for: request) else { return }
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
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isSelected ? R0llingTheme.textPrimary : R0llingTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(minHeight: 44)
                .contentShape(Capsule())
                .background {
                    Capsule()
                        .fill(isSelected ? R0llingTheme.bgSelectedControl : R0llingTheme.bgUnselectedControl)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
