import SwiftUI

/// A02: επεξεργασία κειμένου/tags + διόρθωση ημερομηνίας με σταθερό entry ID.
public struct EntryEditorSheet: View {
    public let entry: JournalEntry
    public var onSave: (JournalEntry) -> Void
    public var onCancel: () -> Void

    @State private var contentText: String
    @State private var tagsText: String
    @State private var editedTimestamp: Date
    @State private var timeZoneIdentifier: String

    public init(
        entry: JournalEntry,
        onSave: @escaping (JournalEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.entry = entry
        self.onSave = onSave
        self.onCancel = onCancel
        _contentText = State(initialValue: entry.content)
        _tagsText = State(initialValue: entry.tags.joined(separator: ", "))
        _editedTimestamp = State(initialValue: entry.timestamp)
        _timeZoneIdentifier = State(initialValue: entry.timeZoneIdentifier)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Κείμενο") {
                    TextEditor(text: $contentText)
                        .frame(minHeight: 120)
                }

                Section("Tags (χωρισμένα με κόμμα)") {
                    TextField("π.χ. ταξίδι, εργασία", text: $tagsText)
                }

                Section("Ημερομηνία & ζώνη (A02)") {
                    DatePicker(
                        "Ημερομηνία καταγραφής",
                        selection: $editedTimestamp,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField("Time Zone identifier", text: $timeZoneIdentifier)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                    Text("Ημερολογιακή ημέρα: \(provoliDateKey)")
                        .font(.footnote)
                        .foregroundColor(R0llingTheme.textSecondary)
                    Text("Το ID παραμένει σταθερό — χωρίς διπλότυπα.")
                        .font(.caption2)
                        .foregroundColor(R0llingTheme.textMuted)
                }
            }
            .navigationTitle("Επεξεργασία")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") {
                        guard !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            return
                        }
                        let tags = tagsText
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        var updated = entry
                        updated.content = contentText
                        updated.tags = tags
                        updated.timestamp = editedTimestamp
                        let tz = timeZoneIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.timeZoneIdentifier = tz.isEmpty ? TimeZone.current.identifier : tz
                        updated.lastModified = Date()
                        onSave(updated)
                    }
                    .disabled(contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var provoliDateKey: String {
        let zone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return JournalEntry.makeDateKey(for: editedTimestamp, timeZone: zone)
    }
}
