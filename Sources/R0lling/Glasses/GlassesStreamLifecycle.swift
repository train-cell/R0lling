import Foundation

/// Γεγονός lifecycle εφαρμογής που επηρεάζει Meta stream / rolling buffer (A07).
public enum GlassesAppLifecycleEvent: Sendable, Equatable {
    /// Εφαρμογή πάει στο background (Home / app switcher).
    case willEnterBackground
    /// Οθόνη κλειδώνει / resign active πριν το lock.
    case willResignActiveForLock
    /// Επιστροφή στο foreground (ενεργή).
    case didBecomeActive
}

/// Πολιτική επανασύνδεσης / pause μετά από disconnect ή background (A06 + A07).
public struct GlassesReconnectPolicy: Sendable, Equatable {
    /// Αυτόματη επανεκκίνηση ροής όταν επιστρέφει foreground (αν ήταν streaming πριν).
    public var autoResumeStreamOnForeground: Bool
    /// Καθαρισμός buffer σε disconnect — ποτέ ένωση χρονικών κενών.
    public var clearBufferOnDisconnect: Bool
    /// Καθαρισμός buffer όταν μπαίνει background/lock (νέο session μετά resume).
    public var clearBufferOnBackgroundPause: Bool
    /// Μέγιστες προσπάθειες auto-reconnect μετά από απώλεια σύνδεσης.
    public var maxReconnectAttempts: Int
    /// Καθυστέρηση μεταξύ προσπαθειών (nanoseconds).
    public var reconnectDelayNanoseconds: UInt64
    /// Ρητή δήλωση: χωρίς device proof, ΔΕΝ υποσχόμαστε continuous background capture.
    public var promisesContinuousBackgroundCapture: Bool

    public init(
        autoResumeStreamOnForeground: Bool = true,
        clearBufferOnDisconnect: Bool = true,
        clearBufferOnBackgroundPause: Bool = true,
        maxReconnectAttempts: Int = 3,
        reconnectDelayNanoseconds: UInt64 = 1_000_000_000,
        promisesContinuousBackgroundCapture: Bool = false
    ) {
        self.autoResumeStreamOnForeground = autoResumeStreamOnForeground
        self.clearBufferOnDisconnect = clearBufferOnDisconnect
        self.clearBufferOnBackgroundPause = clearBufferOnBackgroundPause
        self.maxReconnectAttempts = maxReconnectAttempts
        self.reconnectDelayNanoseconds = reconnectDelayNanoseconds
        self.promisesContinuousBackgroundCapture = promisesContinuousBackgroundCapture
    }

    /// Προεπιλογή R0lling: honest — χωρίς DAT device proof, όχι continuous background.
    public static let proepilogiR0lling = GlassesReconnectPolicy()
}

/// Αποτέλεσμα χειρισμού lifecycle — για UI honesty labels.
public struct GlassesLifecycleOutcome: Sendable, Equatable {
    public let didPauseStream: Bool
    public let didClearBuffer: Bool
    public let bufferStateLabel: String
    public let userMessage: String?

    public init(
        didPauseStream: Bool,
        didClearBuffer: Bool,
        bufferStateLabel: String,
        userMessage: String? = nil
    ) {
        self.didPauseStream = didPauseStream
        self.didClearBuffer = didClearBuffer
        self.bufferStateLabel = bufferStateLabel
        self.userMessage = userMessage
    }
}

/// Καθαρή μηχανή αποφάσεων A07 — testable χωρίς UIKit scene.
public enum GlassesLifecyclePolicy {
    /// Υπολογίζει ενέργεια για background/lock χωρίς side-effects.
    public static func apofasiGia(
        event: GlassesAppLifecycleEvent,
        isCurrentlyStreaming: Bool,
        policy: GlassesReconnectPolicy
    ) -> GlassesLifecycleOutcome {
        switch event {
        case .willEnterBackground, .willResignActiveForLock:
            guard isCurrentlyStreaming else {
                return GlassesLifecycleOutcome(
                    didPauseStream: false,
                    didClearBuffer: false,
                    bufferStateLabel: "idle",
                    userMessage: nil
                )
            }
            let msg: String
            if policy.promisesContinuousBackgroundCapture {
                msg = "Ροή συνεχίζεται στο background (DAT-verified mode)."
            } else {
                msg = event == .willEnterBackground
                    ? "Ροή ανεστάλη στο background — το buffer δεν γεμίζει εκτός συσκευής."
                    : "Ροή ανεστάλη (κλειδωμένη οθόνη) — το buffer σταμάτησε."
            }
            return GlassesLifecycleOutcome(
                didPauseStream: true,
                didClearBuffer: policy.clearBufferOnBackgroundPause,
                bufferStateLabel: "PAUSED",
                userMessage: msg
            )

        case .didBecomeActive:
            return GlassesLifecycleOutcome(
                didPauseStream: false,
                didClearBuffer: false,
                bufferStateLabel: isCurrentlyStreaming ? "active" : "idle",
                userMessage: policy.autoResumeStreamOnForeground && !isCurrentlyStreaming
                    ? "Επιστροφή foreground — έτοιμο για auto-resume ροής."
                    : nil
            )
        }
    }
}
