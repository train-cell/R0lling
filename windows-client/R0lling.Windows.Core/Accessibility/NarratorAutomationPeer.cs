using System;

namespace R0lling.Windows.Core.Accessibility;

/// <summary>
/// Epilysh tou Spike 1 tou ADR-0001:
/// Native UI Automation (UIA) provider contract gia ton Windows Narrator.
/// Enyparxei amesa sto WinUI 3 (Option C) parakamptontas to Java Access Bridge (JAB) barrier.
/// </summary>
public interface INarratorAccessibleElement
{
    string AutomationName { get; }
    string AutomationHelpText { get; }
    string AutomationItemStatus { get; }
    bool IsKeyboardFocusable { get; }
}

/// <summary>
/// Ylopoihsh tou UIA contract gia Tis Kartes Hmerologiou sto WinUI 3.
/// </summary>
public class JournalEntryAutomationPeer : INarratorAccessibleElement
{
    private readonly string _id;
    private readonly string _timestamp;
    private readonly string? _title;
    private readonly string _content;
    private readonly bool _hasAttachments;

    public JournalEntryAutomationPeer(string id, string timestamp, string? title, string content, bool hasAttachments)
    {
        _id = id;
        _timestamp = timestamp;
        _title = title;
        _content = content;
        _hasAttachments = hasAttachments;
    }

    public string AutomationName => string.IsNullOrWhiteSpace(_title)
        ? $"Σημείωση {_timestamp}: {_content[..Math.Min(30, _content.Length)]}..."
        : $"{_title}, καταγραφή {_timestamp}";

    public string AutomationHelpText => _hasAttachments
        ? "Περιέχει συνημμένα πολυμέσα. Πατήστε Enter για άνοιγμα προβολής."
        : "Πατήστε Enter για επεξεργασία.";

    public string AutomationItemStatus => "Αποθηκευμένο τοπικά";

    public bool IsKeyboardFocusable => true;
}
