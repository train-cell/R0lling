import Foundation

/// Κεντρικό μητρώο ετοιμότητας wave-B/C super-features.
/// `ready == false` → κρυφό από UI · όχι product surface στο AppState · αρχεία παραμένουν για άλλες lanes.
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

    // MARK: - READY (πραγματικό software pipeline + UI/hooks)

    public static let earcon = Flag(
        id: "earcon",
        ready: true,
        reason: "AudioServices earcons σε clip save/error"
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
        reason: "Keyword emotion tags στο addNote (όχι prosody/F0)"
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
        reason: "OCR food tokens → heuristic meal note (όχι HealthKit)"
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
        reason: "Feed API wired (adapter→AppState) · ready=false μέχρι Gen2/mic proof — flip = auto-clip"
    )
    public static let headGesture = Flag(
        id: "headGesture",
        ready: false,
        reason: "IMU feed API wired (adapter→AppState) · ready=false μέχρι Gen2 IMU — flip = auto-clip"
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
        reason: "Experimental/ orphan schema · όχι export path · DECISIONS §5"
    )
    public static let fileWatcher = Flag(
        id: "fileWatcher",
        ready: false,
        reason: "Experimental/ orphan · όχι bridge instantiate · DECISIONS §5"
    )
    public static let proximity = Flag(
        id: "proximity",
        ready: false,
        reason: "Χωρίς location/vision feed"
    )
    public static let watchCompanion = Flag(
        id: "watchCompanion",
        ready: false,
        reason: "Χωρίς watchOS target · WCSession latent μόνο"
    )
    public static let pseudoVectorSearch = Flag(
        id: "pseudoVectorSearch",
        ready: false,
        reason: "FNV pseudo embeddings · όχι CLIP weights"
    )
    public static let turnTaking = Flag(
        id: "turnTaking",
        ready: false,
        reason: "Χωρίς VAD/mic feed"
    )
    public static let mirror = Flag(
        id: "mirror",
        ready: false,
        reason: "TLS + glasses broadcastFrame εκκρεμούν · UI κρυφό"
    )
    public static let hyperlapse = Flag(
        id: "hyperlapse",
        ready: false,
        reason: "GPS frame-select only · όχι video mux"
    )
    public static let whisperStub = Flag(
        id: "whisperStub",
        ready: false,
        reason: "Stub χωρίς weights · χρήση Apple Speech"
    )
    public static let multiFrameVision = Flag(
        id: "multiFrameVision",
        ready: false,
        reason: "AIRouter στέλνει μόνο το 1ο frame · όχι πραγματικό multi-frame"
    )
    public static let adaptiveBattery = Flag(
        id: "adaptiveBattery",
        ready: true,
        reason: "MetaGlassesAdapter low-battery FPS throttle (15fps <20%) στο simulation/DAT loop"
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
