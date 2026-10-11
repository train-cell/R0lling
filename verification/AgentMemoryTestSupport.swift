import Foundation

public struct AgentMemory: Codable, Sendable, Equatable {
    public var memoryNotes: String
    public var userPreferences: String
    public var openLoops: String
    public var lastUpdated: Date

    public init(
        memoryNotes: String = "# Σημειώσεις Μνήμης Βοηθού\n\n",
        userPreferences: String = "# Προτιμήσεις Χρήστη\n\n",
        openLoops: String = "# Εκκρεμότητες & Ανοιχτά Θέματα\n\n",
        lastUpdated: Date = Date()
    ) {
        self.memoryNotes = memoryNotes
        self.userPreferences = userPreferences
        self.openLoops = openLoops
        self.lastUpdated = lastUpdated
    }
}

extension Date {
    var iso8601String: String { ISO8601DateFormatter().string(from: self) }
}

#if os(Linux)
extension URL {
    func startAccessingSecurityScopedResource() -> Bool { false }
    func stopAccessingSecurityScopedResource() {}
}
#endif
