/// Prevents an older asynchronous journal search from replacing newer results.
public struct JournalSearchRequestGate: Sendable, Equatable {
    public private(set) var generation: UInt64 = 0

    public init() {}

    /// Starts a request and returns the token that must accompany its result.
    @discardableResult
    public mutating func beginRequest() -> UInt64 {
        generation &+= 1
        return generation
    }

    /// A result is current only while no later search request has started.
    public func canApplyResult(for request: UInt64) -> Bool {
        generation == request
    }
}
