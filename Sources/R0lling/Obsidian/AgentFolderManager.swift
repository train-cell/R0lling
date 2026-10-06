import Foundation

/// Διαχείριση των αρχείων μνήμης του προσωπικού AI Agent (`Agent/` υποφάκελος)
public actor AgentFolderManager {
    private static let agentFolderName = "Agent"
    private static let memoryFileName = "Memory.md"
    private static let preferencesFileName = "Preferences.md"
    private static let openLoopsFileName = "Open-loops.md"

    private var baseVaultURL: URL?

    public init(vaultURL: URL? = nil) {
        if let url = vaultURL {
            self.baseVaultURL = url
        } else if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.baseVaultURL = docs.appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
        } else {
            self.baseVaultURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("R0lling/ObsidianVault", isDirectory: true)
        }
    }

    public func setVaultURL(_ url: URL) {
        self.baseVaultURL = url
    }

    public var currentVaultURL: URL? {
        baseVaultURL
    }

    /// SEC-002: ασφαλή URL για Agent/*.md μέσω PathAsfaleia.
    private func asfales_agent_file_url(_ fileName: String) throws -> URL {
        guard let vault = baseVaultURL else {
            throw NSError(
                domain: "R0lling.Agent",
                code: 6101,
                userInfo: [NSLocalizedDescriptionKey: "Δεν έχει οριστεί Obsidian vault για Agent."]
            )
        }
        let relative = "\(Self.agentFolderName)/\(fileName)"
        return try PathAsfaleia.asfalhs_resolved_url(relativePath: relative, baseDirectory: vault)
    }

    private func asfales_agent_directory_url() throws -> URL {
        guard let vault = baseVaultURL else {
            throw NSError(
                domain: "R0lling.Agent",
                code: 6101,
                userInfo: [NSLocalizedDescriptionKey: "Δεν έχει οριστεί Obsidian vault για Agent."]
            )
        }
        return try PathAsfaleia.asfalhs_resolved_url(
            relativePath: Self.agentFolderName,
            baseDirectory: vault
        )
    }

    /// Φόρτωση του AgentMemory από τα Markdown αρχεία
    public func loadAgentMemory() throws -> AgentMemory {
        guard baseVaultURL != nil else {
            return AgentMemory()
        }

        let agentDir = try asfales_agent_directory_url()
        try FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)

        let memURL = try asfales_agent_file_url(Self.memoryFileName)
        let prefURL = try asfales_agent_file_url(Self.preferencesFileName)
        let loopsURL = try asfales_agent_file_url(Self.openLoopsFileName)

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

    /// Αποθήκευση του AgentMemory στα Markdown αρχεία (fail-closed — CQ-P0-005).
    public func saveAgentMemory(_ memory: AgentMemory) throws {
        guard baseVaultURL != nil else {
            throw NSError(
                domain: "R0lling.Agent",
                code: 6101,
                userInfo: [NSLocalizedDescriptionKey: "Δεν έχει οριστεί Obsidian vault για Agent."]
            )
        }

        let agentDir = try asfales_agent_directory_url()
        try FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)

        let memURL = try asfales_agent_file_url(Self.memoryFileName)
        let prefURL = try asfales_agent_file_url(Self.preferencesFileName)
        let loopsURL = try asfales_agent_file_url(Self.openLoopsFileName)

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
