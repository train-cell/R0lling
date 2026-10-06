import Foundation

public struct AIRequestPayload: Sendable {
    public let prompt: String
    public let systemPrompt: String?
    public let imageBase64: String?
    public let contextEntries: [JournalEntry]
    public let agentMemoryContext: String?

    public init(
        prompt: String,
        systemPrompt: String? = nil,
        imageBase64: String? = nil,
        contextEntries: [JournalEntry] = [],
        agentMemoryContext: String? = nil
    ) {
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.imageBase64 = imageBase64
        self.contextEntries = contextEntries
        self.agentMemoryContext = agentMemoryContext
    }
}

public struct AIResponseResult: Sendable, Equatable {
    public let reply: String
    public let tokensUsed: Int?
    public let referencedEntryIDs: [UUID]

    public init(reply: String, tokensUsed: Int? = nil, referencedEntryIDs: [UUID] = []) {
        self.reply = reply
        self.tokensUsed = tokensUsed
        self.referencedEntryIDs = referencedEntryIDs
    }
}

public protocol AIConnectorProtocol: Sendable {
    var providerType: AIProviderType { get }
    func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult
    func describeImage(imageData: Data, question: String?) async throws -> String
    func summarizeDay(entries: [JournalEntry]) async throws -> String
}
