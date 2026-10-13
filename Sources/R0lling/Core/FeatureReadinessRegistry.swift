import Foundation

/// Κεντρικό μητρώο ετοιμότητας wave-B/C super-features.
/// `ready` controls whether the source-wired product path may be exposed; it is not a build,
/// runtime, device, or release-verification certificate. `ready == false` permits only an
/// explicit diagnostic/status surface until the missing implementation and its acceptance gates pass.
public enum FeatureReadinessRegistry {

    /// Σημαία ετοιμότητας ενός super-feature.
    public struct Flag: Sendable, Identifiable {
        public let id: String
        public let ready: Bool
        public let reason: String

        public init(id: String, ready: Bool, reason: String) {
            self.id = id
            self.ready = ready
            self.reason = reason
        }
    }

    // MARK: - Source-wired product paths (Apple runtime/device validation is tracked separately)

    public static let earcon = Flag(
        id: "earcon",
        ready: true,
        reason: "AudioServices system sounds σε clip save/error · OS-controlled route · χωρίς direct glasses routing"
    )
    public static let timeCapsule = Flag(
        id: "timeCapsule",
        ready: true,
        reason: "Anniversary lookup + TodayView banner"
    )
    public static let highlightReel = Flag(
        id: "highlightReel",
        ready: true,
        reason: "AVMutableComposition mux + Assistant UI"
    )
    public static let podcast = Flag(
        id: "podcast",
        ready: true,
        reason: "AVSpeechSynthesizer digest + Assistant UI"
    )
    public static let canvas = Flag(
        id: "canvas",
        ready: true,
        reason: "Obsidian .canvas JSON export + UI"
    )
    public static let knowledgeGraph = Flag(
        id: "knowledgeGraph",
        ready: true,
        reason: "Heuristic triples → Mermaid Obsidian export"
    )
    public static let emotionTags = Flag(
        id: "emotionTags",
        ready: true,
        reason: "Transcript keyword cues στο addNote· ρητά text-based, όχι acoustic emotion/prosody"
    )
    public static let scavengerStreak = Flag(
        id: "scavengerStreak",
        ready: true,
        reason: "UserDefaults streak/badges στο ObservationGame"
    )
    public static let appleSpeech = Flag(
        id: "appleSpeech",
        ready: true,
        reason: "SpeechTranscriptionService (SFSpeechRecognizer) — όχι Whisper"
    )
    public static let onDeviceVisionOCR = Flag(
        id: "onDeviceVisionOCR",
        ready: true,
        reason: "VNRecognizeTextRequest στο What-am-I-seeing path"
    )
    public static let entityTags = Flag(
        id: "entityTags",
        ready: true,
        reason: "Keyword entity tags στο addNote"
    )
    public static let nutritionHeuristic = Flag(
        id: "nutritionHeuristic",
        ready: true,
        reason: "OCR food tokens → reviewable, user-confirmed heuristic meal estimate (όχι HealthKit)"
    )
    public static let dataviewFrontmatter = Flag(
        id: "dataviewFrontmatter",
        ready: true,
        reason: "YAML frontmatter στο ObsidianVaultBridge export"
    )

    // MARK: - REMOVED / disabled (ready=false · αρχεία κρατιούνται)

    public static let acoustic = Flag(
        id: "acoustic",
        ready: false,
        reason: "Sink API accepts samples; current adapter is simulation-only · no live DAT microphone proof"
    )
    public static let headGesture = Flag(
        id: "headGesture",
        ready: false,
        reason: "Sink API accepts samples; current adapter is simulation-only · no live DAT IMU proof"
    )
    public static let spatialAudio = Flag(
        id: "spatialAudio",
        ready: false,
        reason: "Experimental/ orphan · 0 callers · DECISIONS §5"
    )
    public static let metalPool = Flag(
        id: "metalPool",
        ready: false,
        reason: "Experimental/ orphan · όχι RollingBuffer wire · DECISIONS §5"
    )
    public static let watermark = Flag(
        id: "watermark",
        ready: false,
        reason: "AVFoundation/Core Animation export and MediaViewer path implemented; Apple build and rendered-frame verification pending"
    )
    public static let fileWatcher = Flag(
        id: "fileWatcher",
        ready: false,
        reason: "Monitors directory-entry changes by path and identity; reconciliation failures stop the watcher. File-content detection/import/sync and Apple Files-scope/runtime validation remain unavailable"
    )
    public static let proximity = Flag(
        id: "proximity",
        ready: false,
        reason: "Experimental orphan · χωρίς location/vision feed"
    )
    public static let watchCompanion = Flag(
        id: "watchCompanion",
        ready: false,
        reason: "Χωρίς watchOS target · WCSession latent μόνο"
    )
    public static let pseudoVectorSearch = Flag(
        id: "pseudoVectorSearch",
        ready: false,
        reason: "Experimental orphan · FNV pseudo embeddings, όχι CLIP weights"
    )
    public static let turnTaking = Flag(
        id: "turnTaking",
        ready: false,
        reason: "Experimental orphan · χωρίς VAD/mic feed"
    )
    public static let mirror = Flag(
        id: "mirror",
        ready: false,
        reason: "TLS + glasses broadcastFrame εκκρεμούν · UI κρυφό"
    )
    public static let hyperlapse = Flag(
        id: "hyperlapse",
        ready: false,
        reason: "Experimental · GPS frame-select only · όχι capture/video mux"
    )
    public static let whisperStub = Flag(
        id: "whisperStub",
        ready: false,
        reason: "Experimental fail-closed stub · χωρίς weights · χωρίς product caller"
    )
    public static let multiFrameVision = Flag(
        id: "multiFrameVision",
        ready: false,
        reason: "Request builder δέχεται έως 4 εικόνες · λείπει DAT H264-to-image capture pipeline"
    )
    public static let adaptiveBattery = Flag(
        id: "adaptiveBattery",
        ready: false,
        reason: "Throttle helper υπάρχει · χωρίς πραγματική τηλεμετρία μπαταρίας ή DAT feed"
    )

    /// Όλες οι σημαίες (READY + REMOVED) για diagnostics.
    public static let allFlags: [Flag] = [
        earcon, timeCapsule, highlightReel, podcast, canvas, knowledgeGraph,
        emotionTags, scavengerStreak, appleSpeech, onDeviceVisionOCR, entityTags,
        nutritionHeuristic, dataviewFrontmatter,
        acoustic, headGesture, spatialAudio, metalPool, watermark, fileWatcher,
        proximity, watchCompanion, pseudoVectorSearch, turnTaking, mirror,
        hyperlapse, whisperStub, multiFrameVision, adaptiveBattery
    ]

    /// Μόνο features που επιτρέπεται να εμφανίζονται στο UI.
    public static var uiReadyFlags: [Flag] {
        allFlags.filter(\.ready)
    }

    /// Επιστρέφει `true` αν το feature είναι ready για UI/product surface.
    public static func isReady(_ flag: Flag) -> Bool {
        flag.ready
    }
}
