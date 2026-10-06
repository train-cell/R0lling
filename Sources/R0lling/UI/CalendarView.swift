import SwiftUI

/// Οθόνη ιστορικού και αναζήτησης ημερολογίου (Calendar & Archive) σε στυλ Strava Activity Log
public struct CalendarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchQuery: String = ""
    @State private var selectedSourceFilter: EntrySource? = nil
    @State private var displayedEntries: [JournalEntry] = []

    public var body: some View {
        VStack(spacing: 0) {
            // Header
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

                // Total entries badge
                Text("\(displayedEntries.count) LOGS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.stravaOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(R0llingTheme.stravaOrange.opacity(0.12))
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

            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(R0llingTheme.stravaOrange)
                    .font(.system(size: 14, weight: .bold))

                TextField("Αναζήτηση σημειώσεων, #tags, δραστηριοτήτων...", text: $searchQuery)
                    .font(.system(size: 14))
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
            .padding(12)
            .background(R0llingTheme.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(R0llingTheme.borderSubtle, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Source Filter Chips (Strava style athletic filters)
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
                            TimelineEntryCard(entry: entry, onFavoriteToggle: {
                                Task {
                                    await appState.toggleFavorite(entry: entry)
                                    filterEntries()
                                }
                            }, onDelete: {
                                Task {
                                    await appState.deleteEntry(id: entry.id)
                                    filterEntries()
                                }
                            })
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
        Button(action: {
            R0llingTheme.triggerHapticFeedback()
            onTap()
        }) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .heavy : .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : R0llingTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? R0llingTheme.stravaOrange : R0llingTheme.bgElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? R0llingTheme.stravaFlame : R0llingTheme.borderSubtle, lineWidth: 1)
                )
                .shadow(color: isSelected ? R0llingTheme.stravaOrange.opacity(0.35) : Color.clear, radius: 6, x: 0, y: 2)
        }
    }
}
