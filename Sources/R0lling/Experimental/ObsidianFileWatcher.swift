import Foundation

/// Παρατηρητής αλλαγών αρχείων Obsidian Vault (File Watcher) για άμεσο συγχρονισμό εξωτερικών αλλαγών
/// Vault file watcher — **Experimental orphan** · `FeatureReadinessRegistry.fileWatcher.ready=false`.
public final class ObsidianFileWatcher: @unchecked Sendable {
    private var fileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?
    public var onFileChanged: (@Sendable (URL) -> Void)?

    public init() {}

    /// Εκκίνηση παρακολούθησης φακέλου
    public func startWatching(directoryURL: URL) {
        stopWatching()

        fileDescriptor = open(directoryURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .link, .rename],
            queue: DispatchQueue.global(qos: .utility)
        )

        dispatchSource.setEventHandler { [weak self] in
            self?.onFileChanged?(directoryURL)
        }

        dispatchSource.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        self.source = dispatchSource
        dispatchSource.resume()
    }

    /// Τερματισμός παρακολούθησης
    public func stopWatching() {
        source?.cancel()
        source = nil
    }

    deinit {
        stopWatching()
    }
}
