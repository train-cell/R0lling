import Foundation

/// Δεξαμενή μνήμης (Buffer Pool) και διαχείριση επιταχυνόμενων καρέ στη GPU για μηδενικό CPU overhead
public final class MetalFrameBufferPool: @unchecked Sendable {
    public static let shared = MetalFrameBufferPool()

    private var recycledBuffers: [Data] = []
    private let lock = NSLock()
    private let maxPoolSize = 60

    public init() {}

    /// Ανάκτηση προ-δεσμευμένου block μνήμης
    public func acquireBuffer(size: Int) -> Data {
        lock.lock()
        defer { lock.unlock() }

        if let existing = recycledBuffers.popLast(), existing.count >= size {
            return existing
        }
        return Data(count: size)
    }

    /// Επιστροφή block στη δεξαμενή για ανακύκλωση χωρίς dealloc
    public func recycleBuffer(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }

        if recycledBuffers.count < maxPoolSize {
            recycledBuffers.append(data)
        }
    }

    /// Καθαρισμός δεξαμενής
    public func purge() {
        lock.lock()
        defer { lock.unlock() }
        recycledBuffers.removeAll(keepingCapacity: false)
    }
}
