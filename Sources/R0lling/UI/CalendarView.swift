import SwiftUI

/// Οθόνη ιστορικού και αναζήτησης ημερολογίου (Calendar View)
public struct CalendarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchQuery: String = ""
    @State private var selectedSourceFilter: EntrySource? = nil
    @State private var displayedEntries: [JournalEntry] = []

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Ημερολόγιο & Αρχείο")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(R0llingTheme.bgSurface)

            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(R0llingTheme.textSecondary)

                TextField("Αναζήτηση σημειώσεων, tags...", text: $searchQuery)
                    .font(.system(size: 15))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .onChange(of: searchQuery) { _ in
                        filterEntries()
                    }

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        filterEntries()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(R0llingTheme.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Source Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "Όλα",
                        isSelected: selectedSourceFilter == nil,
                        onTap: {
                            selectedSourceFilter = nil
                            filterEntries()
                        }
                    )

                    ForEach(EntrySource.allCases, id: \.self) { source in
                        FilterChip(
                            title: source.displayName,
                            isSelected: selectedSourceFilter == source,
                            onTap: {
                                selectedSourceFilter = (selectedSourceFilter == source) ? nil : source
                                filterEntries()
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            // Entries List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if displayedEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(R0llingTheme.textMuted)
                                .padding(.top, 40)
                            Text("Δεν βρέθηκαν καταγραφές")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(R0llingTheme.textSecondary)
                        }
                    } else {
                        ForEach(displayedEntries) { entry in
                            TimelineEntryCard(entry: entry)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
        .onAppear {
            filterEntries()
        }
    }

    private func filterEntries() {
        let all = appState.allEntries
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        displayedEntries = all.filter { entry in
            var matches = true
            if !q.isEmpty {
                let inContent = entry.content.lowercased().contains(q)
                let inTags = entry.tags.contains { $0.lowercased().contains(q) }
                matches = matches && (inContent || inTags)
            }
            if let src = selectedSourceFilter {
                matches = matches && (entry.source == src)
            }
            return matches
        }
    }
}

public struct FilterChip: View {
    public let title: String
    public let isSelected: Bool
    public let onTap: () -> Void

    public var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : R0llingTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? R0llingTheme.accentPurple : R0llingTheme.bgElevated)
                .clipShape(Capsule())
        }
    }
}
