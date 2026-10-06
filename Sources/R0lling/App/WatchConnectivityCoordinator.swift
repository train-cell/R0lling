import Foundation
#if os(iOS) || os(watchOS)
import WatchConnectivity
#endif

/// WCSession coordinator — **ready=false** χωρίς watchOS target (`FeatureReadinessRegistry.watchCompanion`).
/// Latent handlers παραμένουν· UI/product claims απενεργοποιημένα.
public final class WatchConnectivityCoordinator: NSObject, @unchecked Sendable {
    public static let shared = WatchConnectivityCoordinator()

    /// SEC-003: μέγιστο μήκος note από Watch (2KB).
    public static let maxMikosNoteApoWatch = 2048
    /// SEC-003: επιτρεπόμενο schema version στα εισερχόμενα μηνύματα.
    public static let schemaVersionApaitoumenos = 1
    /// SEC-003 harden: ρητή allowlist ενεργειών (όχι ανοιχτό switch).
    public static let epitrepomenesEnergies: Set<String> = ["triggerClip", "saveNote"]

    public var onRemoteClipTriggerRequested: (@Sendable () -> Void)?
    public var onRemoteNoteReceived: (@Sendable (String) -> Void)?

    public override init() {
        super.init()
        #if os(iOS) || os(watchOS)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif
    }

    /// Αποστολή ενημέρωσης κατάστασης buffer στο Apple Watch
    public func updateWatchBufferState(isStreaming: Bool, bufferSeconds: Double) {
        #if os(iOS) || os(watchOS)
        guard WCSession.default.activationState == .activated, WCSession.default.isWatchAppInstalled else { return }
        let payload: [String: Any] = [
            "schemaVersion": Self.schemaVersionApaitoumenos,
            "isStreaming": isStreaming,
            "bufferSeconds": bufferSeconds,
            "timestamp": Date().timeIntervalSince1970
        ]
        try? WCSession.default.updateApplicationContext(payload)
        #endif
    }
}

#if os(iOS) || os(watchOS)
extension WatchConnectivityCoordinator: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Activation handler
    }

#if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
#endif

    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // SEC-003: schema version + allowlist actions + max note length.
        guard let version = message["schemaVersion"] as? Int,
              version == Self.schemaVersionApaitoumenos else {
            replyHandler(["status": "error", "message": "unsupported or missing schemaVersion"])
            return
        }
        guard let action = message["action"] as? String,
              Self.epitrepomenesEnergies.contains(action) else {
            replyHandler(["status": "error", "message": "missing or disallowed action"])
            return
        }

        switch action {
        case "triggerClip":
            onRemoteClipTriggerRequested?()
            replyHandler(["status": "success", "message": "Clip triggered"])
        case "saveNote":
            guard let noteText = message["text"] as? String else {
                replyHandler(["status": "error", "message": "missing text"])
                return
            }
            let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                replyHandler(["status": "error", "message": "empty note"])
                return
            }
            guard !trimmed.contains("\0") else {
                replyHandler(["status": "error", "message": "invalid note characters"])
                return
            }
            guard trimmed.count <= Self.maxMikosNoteApoWatch else {
                replyHandler(["status": "error", "message": "note exceeds max length"])
                return
            }
            onRemoteNoteReceived?(trimmed)
            replyHandler(["status": "success", "message": "Note queued"])
        default:
            replyHandler(["status": "error", "message": "unknown action"])
        }
    }
}
#endif
