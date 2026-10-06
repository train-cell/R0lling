import Foundation

/// Πηγή προέλευσης μιας καταγραφής στο R0lling
public enum EntrySource: String, Codable, Sendable, CaseIterable {
    case manual = "manual"
    case glasses = "glasses"
    case glassesClip = "glasses_clip"
    case voice = "voice"
    case importFile = "import"
    case ai = "ai"

    public var displayName: String {
        switch self {
        case .manual: return "Χειροκίνητη"
        case .glasses: return "Meta Glasses"
        case .glassesClip: return "Rolling Clip"
        case .voice: return "Φωνητική"
        case .importFile: return "Εισαγωγή"
        case .ai: return "AI Βοηθός"
        }
    }

    public var iconName: String {
        switch self {
        case .manual: return "square.and.pencil"
        case .glasses: return "eyeglasses"
        case .glassesClip: return "scissors"
        case .voice: return "mic.fill"
        case .importFile: return "arrow.down.doc"
        case .ai: return "sparkles"
        }
    }
}

/// Τύπος πολυμέσου που επισυνάπτεται σε καταγραφή
public enum MediaType: String, Codable, Sendable, CaseIterable {
    case photo = "photo"
    case video = "video"
    case clip = "clip"
    case audio = "audio"

    public var folderName: String {
        switch self {
        case .photo: return "Photos"
        case .video: return "Videos"
        case .clip: return "Clips"
        case .audio: return "Audio"
        }
    }
}

/// Συνημμένο αρχείο πολυμέσων (φωτογραφία, βίντεο, clip ή ηχητικό)
public struct MediaAttachment: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var relativePath: String
    public var mediaType: MediaType
    public var byteSize: Int64
    public var durationSeconds: Double?
    public var captureTimestamp: Date
    public var width: Int?
    public var height: Int?
    public var hasAudio: Bool

    public init(
        id: UUID = UUID(),
        relativePath: String,
        mediaType: MediaType,
        byteSize: Int64,
        durationSeconds: Double? = nil,
        captureTimestamp: Date = Date(),
        width: Int? = nil,
        height: Int? = nil,
        hasAudio: Bool = false
    ) {
        self.id = id
        self.relativePath = relativePath
        self.mediaType = mediaType
        self.byteSize = byteSize
        self.durationSeconds = durationSeconds
        self.captureTimestamp = captureTimestamp
        self.width = width
        self.height = height
        self.hasAudio = hasAudio
    }
}

/// Βασική καταχώριση ημερολογίου στο R0lling
public struct JournalEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var timestamp: Date
    public var timeZoneIdentifier: String
    public var title: String?
    public var content: String
    public var source: EntrySource
    public var tags: [String]
    public var locationName: String?
    public var attachments: [MediaAttachment]
    public var isFavorite: Bool
    public var lastModified: Date

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        timeZoneIdentifier: String = TimeZone.current.identifier,
        title: String? = nil,
        content: String,
        source: EntrySource = .manual,
        tags: [String] = [],
        locationName: String? = nil,
        attachments: [MediaAttachment] = [],
        isFavorite: Bool = false,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.timeZoneIdentifier = timeZoneIdentifier
        self.title = title
        self.content = content
        self.source = source
        self.tags = tags
        self.locationName = locationName
        self.attachments = attachments
        self.isFavorite = isFavorite
        self.lastModified = lastModified
    }

    /// Κλειδί ημερομηνίας σε μορφή YYYY-MM-DD σύμφωνα με την τοπική ζώνη ώρας της εγγραφής
    public var dateKey: String {
        let zone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        return Self.makeDateKey(for: timestamp, timeZone: zone)
    }

    /// R3-009: σταθερό YYYY-MM-dd με POSIX locale + ρητό timeZone (όχι σιωπηλό device default).
    public static func makeDateKey(for date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Ώρα μορφοποιημένη σε HH:mm
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        if let tz = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = tz
        }
        return formatter.string(from: timestamp)
    }
}

/// Ρυθμίσεις για τον κυκλικό buffer
public struct BufferConfig: Codable, Sendable, Equatable {
    public var targetDurationSeconds: Double
    public var enableAudio: Bool
    public var maxMemoryMegabytes: Int

    public init(
        targetDurationSeconds: Double = 10.0,
        enableAudio: Bool = true,
        maxMemoryMegabytes: Int = 30
    ) {
        self.targetDurationSeconds = targetDurationSeconds
        self.enableAudio = enableAudio
        self.maxMemoryMegabytes = maxMemoryMegabytes
    }
}

/// Ρυθμίσεις παρόχου τεχνητής νοημοσύνης
public enum AIProviderType: String, Codable, Sendable, CaseIterable {
    case directAPI = "direct_api"
    case hermes = "hermes"

    public var title: String {
        switch self {
        case .directAPI: return "Άμεσο AI API (OpenAI/Cloud)"
        case .hermes: return "Hermes Agent (Home PC / VPN)"
        }
    }
}

public struct AISettings: Codable, Sendable, Equatable {
    public var activeProvider: AIProviderType
    public var directAPIBaseURL: String
    public var directAPIModel: String
    public var directAPIKeyKeychainKey: String
    public var hermesBaseURL: String
    public var hermesTokenKeychainKey: String
    public var includeLocationInContext: Bool
    public var maxContextEntries: Int

    public init(
        activeProvider: AIProviderType = .directAPI,
        directAPIBaseURL: String = "https://api.openai.com/v1",
        directAPIModel: String = "gpt-4o-mini",
        directAPIKeyKeychainKey: String = "r0lling.direct_api_key",
        hermesBaseURL: String = "http://192.168.1.50:8080/v1",
        hermesTokenKeychainKey: String = "r0lling.hermes_token",
        includeLocationInContext: Bool = false,
        maxContextEntries: Int = 10
    ) {
        self.activeProvider = activeProvider
        self.directAPIBaseURL = directAPIBaseURL
        self.directAPIModel = directAPIModel
        self.directAPIKeyKeychainKey = directAPIKeyKeychainKey
        self.hermesBaseURL = hermesBaseURL
        self.hermesTokenKeychainKey = hermesTokenKeychainKey
        self.includeLocationInContext = includeLocationInContext
        self.maxContextEntries = maxContextEntries
    }
}

/// Δομή μνήμης του προσωπικού βοηθού (Agent)
public struct AgentMemory: Codable, Sendable, Equatable {
    public var memoryNotes: String
    public var userPreferences: String
    public var openLoops: String
    public var lastUpdated: Date

    public init(
        memoryNotes: String = "# Σημειώσεις Μνήμης Βοηθού\n\n- Αγαπημένα θέματα: Ταξίδια, τεχνολογία, προγραμματισμός.\n",
        userPreferences: String = "# Προτιμήσεις Χρήστη\n\n- Γλώσσα: Ελληνικά\n- Στυλ απαντήσεων: Συνοπτικό, ουσιαστικό, φιλικό.\n",
        openLoops: String = "# Εκκρεμότητες & Ανοιχτά Θέματα\n\n- Ενημέρωση Μαρίας για το ταξίδι.\n",
        lastUpdated: Date = Date()
    ) {
        self.memoryNotes = memoryNotes
        self.userPreferences = userPreferences
        self.openLoops = openLoops
        self.lastUpdated = lastUpdated
    }
}

/// Αποστολή στο παιχνίδι παρατήρησης
public struct ObservationMission: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let prompt: String
    public let targetDescription: String
    public var isCompleted: Bool
    public var completedTimestamp: Date?
    public var capturedImageRelativePath: String?
    public var evaluationFeedback: String?

    public init(
        id: UUID = UUID(),
        prompt: String,
        targetDescription: String,
        isCompleted: Bool = false,
        completedTimestamp: Date? = nil,
        capturedImageRelativePath: String? = nil,
        evaluationFeedback: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.targetDescription = targetDescription
        self.isCompleted = isCompleted
        self.completedTimestamp = completedTimestamp
        self.capturedImageRelativePath = capturedImageRelativePath
        self.evaluationFeedback = evaluationFeedback
    }
}
