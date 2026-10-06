import Foundation

/// Διαχείριση των αρχείων μνήμης του προσωπικού AI Agent (`Agent/` υποφάκελος)
public actor AgentFolderManager {
    private var baseVaultURL: URL?

    public init(vaultURL: URL? = nil) {
        if let url = vaultURL {
            self.baseVaultURL = url
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.baseVaultURL = docs.appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
        }
    }

    public func setVaultURL(_ url: URL) {
        self.baseVaultURL = url
    }

    private var agentDirectoryURL: URL? {
        return baseVaultURL?.appendingPathComponent("Agent", isDirectory: true)
    }

    /// Φόρτωση του AgentMemory από τα Markdown αρχεία
    public func loadAgentMemory() throws -> AgentMemory {
        guard let agentDir = agentDirectoryURL else {
            return AgentMemory()
        }

        try FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)

        let memURL = agentDir.appendingPathComponent("Memory.md")
        let prefURL = agentDir.appendingPathComponent("Preferences.md")
        let loopsURL = agentDir.appendingPathComponent("Open-loops.md")

        // CQ-P0-001: άδεια templates — όχι εφευρεμένα persona facts (fake memory poisoning).
        let memoryText = (try? String(contentsOf: memURL, encoding: .utf8))
            ?? "# Σημειώσεις Μνήμης Βοηθού\n\n"
        let prefText = (try? String(contentsOf: prefURL, encoding: .utf8))
            ?? "# Προτιμήσεις Χρήστη\n\n"
        let loopsText = (try? String(contentsOf: loopsURL, encoding: .utf8))
            ?? "# Εκκρεμότητες & Ανοιχτά Θέματα\n\n"

        return AgentMemory(
            memoryNotes: memoryText,
            userPreferences: prefText,
            openLoops: loopsText,
            lastUpdated: Date()
        )
    }

    /// Αποθήκευση του AgentMemory στα Markdown αρχεία
    public func saveAgentMemory(_ memory: AgentMemory) throws {
        guard let agentDir = agentDirectoryURL else { return }

        try FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)

        let memURL = agentDir.appendingPathComponent("Memory.md")
        let prefURL = agentDir.appendingPathComponent("Preferences.md")
        let loopsURL = agentDir.appendingPathComponent("Open-loops.md")

        try memory.memoryNotes.write(to: memURL, atomically: true, encoding: .utf8)
        try memory.userPreferences.write(to: prefURL, atomically: true, encoding: .utf8)
        try memory.openLoops.write(to: loopsURL, atomically: true, encoding: .utf8)
    }

    /// Προσαρμογή μνήμης κατόπιν επιβεβαίωσης από τον χρήστη
    public func appendNoteToMemory(note: String) throws {
        var current = try loadAgentMemory()
        current.memoryNotes += "\n- [\(Date().iso8601String)] \(note)\n"
        current.lastUpdated = Date()
        try saveAgentMemory(current)
    }
}
