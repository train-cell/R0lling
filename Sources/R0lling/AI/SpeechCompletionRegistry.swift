import Foundation

/// Keeps speech completion handlers associated with the utterance that owns them.
/// AVSpeechSynthesizer may have multiple queued utterances, and its delegate callbacks
/// can arrive independently of calls that enqueue or cancel speech.
final class SpeechCompletionRegistry: @unchecked Sendable {
    typealias Completion = @Sendable () -> Void

    private let lock = NSLock()
    private var completions: [ObjectIdentifier: Completion] = [:]

    func register(_ completion: @escaping Completion, for utterance: AnyObject) {
        lock.lock()
        completions[ObjectIdentifier(utterance)] = completion
        lock.unlock()
    }

    func take(for utterance: AnyObject) -> Completion? {
        lock.lock()
        let completion = completions.removeValue(forKey: ObjectIdentifier(utterance))
        lock.unlock()
        return completion
    }

    func discard(for utterance: AnyObject) {
        lock.lock()
        completions.removeValue(forKey: ObjectIdentifier(utterance))
        lock.unlock()
    }

    func discardAll() {
        lock.lock()
        completions.removeAll(keepingCapacity: false)
        lock.unlock()
    }
}
