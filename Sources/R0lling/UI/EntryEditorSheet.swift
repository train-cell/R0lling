import SwiftUI

/// A02: επεξεργασία κειμένου/tags + διόρθωση ημερομηνίας με σταθερό entry ID.
public struct EntryEditorSheet: View {
    public let entry: JournalEntry
    public var onSave: (JournalEntry) -> Void
    public var onCancel: () -> Void

    @State private var contentText: String
    @State private var tagsText: String
    @State private var locationNameText: String
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
        _locationNameText = State(initialValue: entry.locationName ?? "")
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

                Section("Τοποθεσία (προαιρετικά)") {
                    TextField("π.χ. Αθήνα", text: $locationNameText)
                    Text("Το όνομα τοποθεσίας προστίθεται χειροκίνητα. Αποστέλλεται σε AI μόνο αν ενεργοποιήσεις την αντίστοιχη ρύθμιση.")
                        .font(.caption)
                        .foregroundColor(R0llingTheme.textSecondary)
                }

                Section("Ημερομηνία & ζώνη (A02)") {
                    DatePicker(
                        "Ημερομηνία καταγραφής",
                        selection: $editedTimestamp,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField("π.χ. Europe/Athens", text: $timeZoneIdentifier)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                        .accessibilityHint("Άφησε το πεδίο κενό για την τρέχουσα ζώνη ώρας.")
                    if !timeZoneIsValid {
                        Label("Μη έγκυρη ζώνη ώρας. Χρησιμοποίησε αναγνωριστικό IANA, όπως Europe/Athens, ή άφησε το πεδίο κενό.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(R0llingTheme.statusError)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Ημερολογιακή ημέρα: \(provoliDateKey)")
                        .font(.footnote)
                        .foregroundColor(R0llingTheme.textSecondary)
                    Text("Το ID παραμένει σταθερό — χωρίς διπλότυπα.")
                        .font(.caption2)
                        .foregroundColor(R0llingTheme.textMuted)
                }
            }
            .r0llingFormSurface()
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
                        let locationName = locationNameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.locationName = locationName.isEmpty ? nil : locationName
                        updated.timestamp = editedTimestamp
                        guard let normalizedTimeZone = JournalTimeZoneIdentifier.normalized(timeZoneIdentifier) else {
                            return
                        }
                        updated.timeZoneIdentifier = normalizedTimeZone
                        updated.lastModified = Date()
                        onSave(updated)
                    }
                    .disabled(contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !timeZoneIsValid)
                }
            }
        }
        .tint(R0llingTheme.accentPurple)
    }

    private var provoliDateKey: String {
        guard let normalized = JournalTimeZoneIdentifier.normalized(timeZoneIdentifier),
              let zone = TimeZone(identifier: normalized) else {
            return "—"
        }
        return JournalEntry.makeDateKey(for: editedTimestamp, timeZone: zone)
    }

    private var timeZoneIsValid: Bool {
        JournalTimeZoneIdentifier.normalized(timeZoneIdentifier) != nil
    }
}
