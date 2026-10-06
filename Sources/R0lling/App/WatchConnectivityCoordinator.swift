import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Συντονιστής επικοινωνίας με το Apple Watch Companion App (WatchConnectivity WCSession)
public final class WatchConnectivityCoordinator: NSObject, @unchecked Sendable {
    public static let shared = WatchConnectivityCoordinator()

    public var onRemoteClipTriggerRequested: (@Sendable () -> Void)?
    public var onRemoteNoteReceived: (@Sendable (String) -> Void)?

    public override init() {
        super.init()
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif
    }

    /// Αποστολή ενημέρωσης κατάστασης buffer στο Apple Watch
    public func updateWatchBufferState(isStreaming: Bool, bufferSeconds: Double) {
        #if canImport(WatchConnectivity)
        guard WCSession.default.activationState == .activated, WCSession.default.isWatchAppInstalled else { return }
        let payload: [String: Any] = [
            "isStreaming": isStreaming,
            "bufferSeconds": bufferSeconds,
            "timestamp": Date().timeIntervalSince1970
        ]
        try? WCSession.default.updateApplicationContext(payload)
        #endif
    }
}

#if canImport(WatchConnectivity)
extension WatchConnectivityCoordinator: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Activation handler
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let action = message["action"] as? String {
            if action == "triggerClip" {
                onRemoteClipTriggerRequested?()
                replyHandler(["status": "success", "message": "Clip triggered"])
            } else if action == "saveNote", let noteText = message["text"] as? String {
                onRemoteNoteReceived?(noteText)
                replyHandler(["status": "success", "message": "Note queued"])
            }
        }
    }
}
#endif
