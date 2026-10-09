import Foundation
import CryptoKit

/// Local diary storage. The complete serialized document is authenticated and encrypted at rest.
public actor EncryptedDiaryStore {
    /// Capability minted only after a successful biometric check and revoked on lock.
    public struct Authorization: Sendable {
        fileprivate let id: UUID

        fileprivate init(id: UUID) {
            self.id = id
        }
    }

    public struct Entry: Codable, Identifiable, Sendable, Equatable {
        public let id: UUID
        public let createdAt: Date
        public var content: String

        public init(id: UUID = UUID(), createdAt: Date = Date(), content: String) {
            self.id = id
            self.createdAt = createdAt
            self.content = content
        }
    }

    public struct FutureLetter: Codable, Identifiable, Sendable, Equatable {
        public let id: UUID
        public let titleHint: String
        public let unlockDate: Date
        public let payloadText: String
        public let createdAt: Date

        public init(
            id: UUID = UUID(),
            titleHint: String,
            unlockDate: Date,
            payloadText: String,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.titleHint = titleHint
            self.unlockDate = unlockDate
            self.payloadText = payloadText
            self.createdAt = createdAt
        }
    }

    /// A listing response that never carries a future letter's plaintext before its unlock date.
    public struct FutureLetterPreview: Identifiable, Sendable, Equatable {
        public let id: UUID
        public let titleHint: String
        public let unlockDate: Date
        public let payloadText: String?
        public let createdAt: Date

        fileprivate init(_ letter: FutureLetter, now: Date) {
            id = letter.id
            titleHint = letter.titleHint
            unlockDate = letter.unlockDate
            payloadText = letter.unlockDate <= now ? letter.payloadText : nil
            createdAt = letter.createdAt
        }
    }

    private struct Document: Codable {
        let schemaVersion: Int
        var entries: [Entry]
        var futureLetters: [FutureLetter]
        var decisionRecords: [DecisionRecord]

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
            case entries
            case futureLetters
            case decisionRecords
        }

        init(
            schemaVersion: Int,
            entries: [Entry],
            futureLetters: [FutureLetter] = [],
            decisionRecords: [DecisionRecord] = []
        ) {
            self.schemaVersion = schemaVersion
            self.entries = entries
            self.futureLetters = futureLetters
            self.decisionRecords = decisionRecords
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            entries = try container.decodeIfPresent([Entry].self, forKey: .entries) ?? []
            futureLetters = try container.decodeIfPresent([FutureLetter].self, forKey: .futureLetters) ?? []
            decisionRecords = try container.decodeIfPresent([DecisionRecord].self, forKey: .decisionRecords) ?? []
        }
    }

    public static let shared = EncryptedDiaryStore()

    private let storageURL: URL
    private let keyTag: String
    private let shouldRestoreSharedDirectoryBackupInclusion: Bool
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var activeAuthorizations = Set<UUID>()

    public init(storageURL: URL? = nil, keyTag: String = "private-diary-v1") {
        if let storageURL {
            self.storageURL = storageURL
            self.shouldRestoreSharedDirectoryBackupInclusion = false
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.storageURL = appSupport
                .appendingPathComponent("R0lling", isDirectory: true)
                .appendingPathComponent("private_diary_v1.bin")
            self.shouldRestoreSharedDirectoryBackupInclusion = true
        }
        self.keyTag = keyTag

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    #if DEBUG
    init(testingStorageURL storageURL: URL, keyTag: String, restoreParentBackupExclusion: Bool) {
        self.storageURL = storageURL
        self.keyTag = keyTag
        self.shouldRestoreSharedDirectoryBackupInclusion = restoreParentBackupExclusion

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }
    #endif

    public func authorize(reason: String = "Ξεκλείδωμα ιδιωτικού vault") async throws -> Authorization {
        let security = BiometricSecurityManager()
        guard await security.canAuthenticate() else {
            throw diaryError(code: 16, message: "Δεν είναι διαθέσιμος βιομετρικός έλεγχος σε αυτή τη συσκευή.")
        }
        guard await security.authenticateBiometrics(reason: reason) else {
            throw diaryError(code: 17, message: "Ο βιομετρικός έλεγχος δεν ολοκληρώθηκε.")
        }
        let authorization = Authorization(id: UUID())
        activeAuthorizations.insert(authorization.id)
        return authorization
    }

    /// Test-only capability factory; omitted from release builds.
    #if DEBUG
    func testingAuthorization() -> Authorization {
        let authorization = Authorization(id: UUID())
        activeAuthorizations.insert(authorization.id)
        return authorization
    }
    #endif

    public func lock(_ authorization: Authorization) {
        activeAuthorizations.remove(authorization.id)
    }

    public func entries(using authorization: Authorization) throws -> [Entry] {
        try requireAuthorization(authorization)
        try readDocument().entries.sorted { $0.createdAt > $1.createdAt }
    }

    public func futureLetters(using authorization: Authorization) throws -> [FutureLetterPreview] {
        try requireAuthorization(authorization)
        let now = Date()
        return try readDocument().futureLetters
            .sorted { $0.unlockDate < $1.unlockDate }
            .map { FutureLetterPreview($0, now: now) }
    }

    @discardableResult
    public func sealFutureLetter(
        titleHint: String,
        unlockDate: Date,
        payloadText: String,
        using authorization: Authorization
    ) throws -> FutureLetter {
        try requireAuthorization(authorization)
        let cleanTitle = titleHint.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPayload = payloadText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, cleanTitle.count <= 100 else {
            throw diaryError(code: 7, message: "Ο τίτλος πρέπει να έχει από 1 έως 100 χαρακτήρες.")
        }
        guard !cleanPayload.isEmpty else {
            throw diaryError(code: 8, message: "Γράψε το μήνυμα πριν το σφραγίσεις.")
        }
        guard unlockDate > Date() else {
            throw diaryError(code: 9, message: "Επίλεξε ημερομηνία ξεκλειδώματος στο μέλλον.")
        }

        var document = try readDocument()
        let letter = FutureLetter(titleHint: cleanTitle, unlockDate: unlockDate, payloadText: cleanPayload)
        document.futureLetters.append(letter)
        try Task.checkCancellation()
        try writeDocument(document)
        return letter
    }

    public func deleteFutureLetter(id: UUID, using authorization: Authorization) throws {
        try requireAuthorization(authorization)
        var document = try readDocument()
        guard document.futureLetters.contains(where: { $0.id == id }) else { return }
        document.futureLetters.removeAll { $0.id == id }
        try Task.checkCancellation()
        try writeDocument(document)
    }

    public func decisionRecords(using authorization: Authorization) throws -> [DecisionRecord] {
        try requireAuthorization(authorization)
        try readDocument().decisionRecords.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    public func saveDecision(_ record: DecisionRecord, using authorization: Authorization) throws -> DecisionRecord {
        try requireAuthorization(authorization)
        let title = record.decisionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let assumptions = record.coreAssumptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !title.isEmpty, !assumptions.isEmpty else {
            throw diaryError(code: 10, message: "Η απόφαση και τουλάχιστον μία παραδοχή είναι απαραίτητες.")
        }
        guard (0...100).contains(record.confidencePercent), record.reviewDate >= record.createdAt else {
            throw diaryError(code: 11, message: "Η βεβαιότητα πρέπει να είναι 0–100% και η αναθεώρηση να μην προηγείται της απόφασης.")
        }

        let saved = DecisionRecord(
            id: record.id,
            decisionText: title,
            coreAssumptions: assumptions,
            confidencePercent: record.confidencePercent,
            createdAt: record.createdAt,
            reviewDate: record.reviewDate,
            outcomeReview: record.outcomeReview,
            isReviewed: record.isReviewed
        )
        var document = try readDocument()
        if let index = document.decisionRecords.firstIndex(where: { $0.id == saved.id }) {
            document.decisionRecords[index] = saved
        } else {
            document.decisionRecords.append(saved)
        }
        try Task.checkCancellation()
        try writeDocument(document)
        return saved
    }

    @discardableResult
    public func reviewDecision(
        id: UUID,
        outcome: String,
        using authorization: Authorization
    ) throws -> DecisionRecord {
        try reviewDecision(id: id, outcome: outcome, at: Date(), using: authorization)
    }

    /// Clock-injected implementation stays module-internal for deterministic tests.
    func reviewDecision(
        id: UUID,
        outcome: String,
        at now: Date,
        using authorization: Authorization
    ) throws -> DecisionRecord {
        try requireAuthorization(authorization)
        let cleanOutcome = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanOutcome.isEmpty else {
            throw diaryError(code: 12, message: "Καταχώρισε το αποτέλεσμα πριν ολοκληρώσεις την ανασκόπηση.")
        }
        var document = try readDocument()
        guard let index = document.decisionRecords.firstIndex(where: { $0.id == id }) else {
            throw diaryError(code: 13, message: "Η απόφαση δεν υπάρχει πλέον στο ημερολόγιο.")
        }
        let existing = document.decisionRecords[index]
        guard !existing.isReviewed, existing.reviewDate <= now else {
            throw diaryError(code: 14, message: "Η ανασκόπηση γίνεται διαθέσιμη στην προγραμματισμένη ημερομηνία.")
        }
        let reviewed = DecisionRecord(
            id: existing.id,
            decisionText: existing.decisionText,
            coreAssumptions: existing.coreAssumptions,
            confidencePercent: existing.confidencePercent,
            createdAt: existing.createdAt,
            reviewDate: existing.reviewDate,
            outcomeReview: cleanOutcome,
            isReviewed: true
        )
        document.decisionRecords[index] = reviewed
        try Task.checkCancellation()
        try writeDocument(document)
        return reviewed
    }

    public func deleteDecision(id: UUID, using authorization: Authorization) throws {
        try requireAuthorization(authorization)
        var document = try readDocument()
        guard document.decisionRecords.contains(where: { $0.id == id }) else { return }
        document.decisionRecords.removeAll { $0.id == id }
        try Task.checkCancellation()
        try writeDocument(document)
    }

    @discardableResult
    public func save(
        content: String,
        editing id: UUID? = nil,
        using authorization: Authorization
    ) throws -> Entry {
        try requireAuthorization(authorization)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanContent.isEmpty else {
            throw diaryError(code: 1, message: "Γράψε το περιεχόμενο πριν από την αποθήκευση.")
        }

        var document = try readDocument()
        let entry: Entry
        if let id {
            guard let index = document.entries.firstIndex(where: { $0.id == id }) else {
                throw diaryError(code: 2, message: "Η εγγραφή δεν υπάρχει πλέον στο ιδιωτικό ημερολόγιο.")
            }
            entry = Entry(id: id, createdAt: document.entries[index].createdAt, content: cleanContent)
            document.entries[index] = entry
        } else {
            entry = Entry(content: cleanContent)
            document.entries.append(entry)
        }

        try Task.checkCancellation()
        try writeDocument(document)
        return entry
    }

    public func delete(id: UUID, using authorization: Authorization) throws {
        try requireAuthorization(authorization)
        var document = try readDocument()
        guard document.entries.contains(where: { $0.id == id }) else { return }
        document.entries.removeAll { $0.id == id }
        try Task.checkCancellation()
        try writeDocument(document)
    }

    private func readDocument() throws -> Document {
        if FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                try ensureStorageDirectoryIncludedInBackup()
                try excludeStorageFileFromBackup(at: storageURL)
            } catch {
                throw diaryError(
                    code: 15,
                    message: "Δεν ήταν δυνατό να εφαρμοστεί η πολιτική backup του ιδιωτικού vault.",
                    underlying: error
                )
            }
        }

        let encryptedData: Data
        do {
            encryptedData = try Data(contentsOf: storageURL)
        } catch {
            let fileError = error as NSError
            if fileError.domain == NSCocoaErrorDomain,
               fileError.code == NSFileReadNoSuchFileError {
                return Document(schemaVersion: 1, entries: [])
            }
            throw diaryError(
                code: 4,
                message: "Δεν ήταν δυνατό να διαβαστεί το κρυπτογραφημένο ημερολόγιο. Τα αρχικά δεδομένα διατηρήθηκαν.",
                underlying: error
            )
        }

        do {
            let key = try VaultCryptography.key(tag: keyTag, create: false)
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let plaintext = try AES.GCM.open(sealedBox, using: key)
            let document = try decoder.decode(Document.self, from: plaintext)
            guard document.schemaVersion == 1,
                  Set(document.entries.map(\.id)).count == document.entries.count,
                  Set(document.futureLetters.map(\.id)).count == document.futureLetters.count,
                  Set(document.decisionRecords.map(\.id)).count == document.decisionRecords.count else {
                throw diaryError(code: 3, message: "Το ιδιωτικό ημερολόγιο έχει μη υποστηριζόμενη έκδοση ή διπλότυπες εγγραφές.")
            }
            return document
        } catch {
            throw diaryError(
                code: 4,
                message: "Δεν ήταν δυνατό να ανοίξει το κρυπτογραφημένο ημερολόγιο. Τα αρχικά δεδομένα διατηρήθηκαν.",
                underlying: error
            )
        }
    }

    private func writeDocument(_ document: Document) throws {
        do {
            let key = try VaultCryptography.key(tag: keyTag, create: true)
            let plaintext = try encoder.encode(document)
            let sealedBox = try AES.GCM.seal(plaintext, using: key)
            guard let encryptedData = sealedBox.combined else {
                throw diaryError(code: 5, message: "Η κρυπτογράφηση AES-GCM απέτυχε.")
            }
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try ensureStorageDirectoryIncludedInBackup()
            try Task.checkCancellation()
            let stagingURL = storageURL.deletingLastPathComponent()
                .appendingPathComponent(".\(storageURL.lastPathComponent).\(UUID().uuidString).tmp")
            do {
                try encryptedData.write(to: stagingURL, options: .atomic)
                try excludeStorageFileFromBackup(at: stagingURL)
                try Task.checkCancellation()
                if FileManager.default.fileExists(atPath: storageURL.path) {
                    _ = try FileManager.default.replaceItemAt(
                        storageURL,
                        withItemAt: stagingURL,
                        backupItemName: nil,
                        options: .usingNewMetadataOnly
                    )
                } else {
                    try FileManager.default.moveItem(at: stagingURL, to: storageURL)
                }
            } catch {
                try? FileManager.default.removeItem(at: stagingURL)
                throw error
            }
        } catch {
            throw diaryError(
                code: 6,
                message: "Δεν ήταν δυνατό να αποθηκευτεί το ιδιωτικό ημερολόγιο.",
                underlying: error
            )
        }
    }

    private func excludeStorageFileFromBackup(at fileURL: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var file = fileURL
        try file.setResourceValues(values)
    }

    /// Earlier builds excluded the default shared parent, which also contains the journal.
    /// Restore its backup inclusion; custom storage URLs retain their caller's directory policy.
    private func ensureStorageDirectoryIncludedInBackup() throws {
        guard shouldRestoreSharedDirectoryBackupInclusion else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        var directory = storageURL.deletingLastPathComponent()
        try directory.setResourceValues(values)
    }

    private func diaryError(code: Int, message: String, underlying: Error? = nil) -> NSError {
        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
        if let underlying {
            userInfo[NSUnderlyingErrorKey] = underlying
        }
        return NSError(domain: "R0lling.EncryptedDiary", code: code, userInfo: userInfo)
    }

    private func requireAuthorization(_ authorization: Authorization) throws {
        guard activeAuthorizations.contains(authorization.id) else {
            throw diaryError(code: 18, message: "Το vault είναι κλειδωμένο. Κάνε ξανά βιομετρικό έλεγχο.")
        }
    }
}
