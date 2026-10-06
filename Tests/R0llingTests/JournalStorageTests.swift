import XCTest
@testable import R0lling

final class JournalStorageTests: XCTestCase {
    var tempDirectory: URL!
    var storage: JSONFileStorageService!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("TestR0lling_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("journal.json")
        storage = JSONFileStorageService(storageURL: fileURL)
    }

    override func tearDown() async throws {
        if let dir = tempDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func testSaveAndRetrieveEntry() async throws {
        let entry = JournalEntry(
            title: "Δοκιμαστική Σημείωση",
            content: "Σήμερα ξεκίνησε η ανάπτυξη του R0lling.",
            source: .manual,
            tags: ["test", "dev"]
        )

        try await storage.saveEntry(entry)
        let retrieved = await storage.getEntry(id: entry.id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "Δοκιμαστική Σημείωση")
        XCTAssertEqual(retrieved?.tags, ["test", "dev"])
    }

    func testSearchEntries() async throws {
        let entry1 = JournalEntry(content: "Συνάντηση με Μαρία για το ταξίδι", tags: ["ταξίδι"])
        let entry2 = JournalEntry(content: "Αγορά εισιτηρίων για το συνέδριο", tags: ["εργασία"])

        try await storage.saveEntry(entry1)
        try await storage.saveEntry(entry2)

        let results = await storage.searchEntries(query: "Μαρία", tag: nil, source: nil)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, entry1.id)

        let tagResults = await storage.searchEntries(query: "", tag: "εργασία", source: nil)
        XCTAssertEqual(tagResults.count, 1)
        XCTAssertEqual(tagResults.first?.id, entry2.id)
    }

    func testDeleteEntry() async throws {
        let entry = JournalEntry(content: "Προσωρινή σημείωση")
        try await storage.saveEntry(entry)

        try await storage.deleteEntry(id: entry.id)
        let retrieved = await storage.getEntry(id: entry.id)
        XCTAssertNil(retrieved)
    }

    /// R3-009: day filter χρησιμοποιεί entry.dateKey (TZ εγγραφής) vs ρητό display TZ.
    func testGetEntriesForDateRespectsEntryTimeZoneDateKey() async throws {
        // 2026-10-06 01:30 στο Tokyo = ακόμα 2026-10-05 βράδυ στην Αθήνα.
        var tokyoComponents = DateComponents()
        tokyoComponents.calendar = Calendar(identifier: .gregorian)
        tokyoComponents.timeZone = TimeZone(identifier: "Asia/Tokyo")
        tokyoComponents.year = 2026
        tokyoComponents.month = 10
        tokyoComponents.day = 6
        tokyoComponents.hour = 1
        tokyoComponents.minute = 30
        let tokyoMorning = tokyoComponents.date!

        let entry = JournalEntry(
            timestamp: tokyoMorning,
            timeZoneIdentifier: "Asia/Tokyo",
            content: "Πρωινό στο Τόκιο",
            source: .manual
        )
        XCTAssertEqual(entry.dateKey, "2026-10-06")
        try await storage.saveEntry(entry)

        // Προβολή με Tokyo: η 6η Οκτ εμφανίζει την εγγραφή.
        var queryTokyo = DateComponents()
        queryTokyo.calendar = Calendar(identifier: .gregorian)
        queryTokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")
        queryTokyo.year = 2026
        queryTokyo.month = 10
        queryTokyo.day = 6
        queryTokyo.hour = 12
        let tokyoNoon = queryTokyo.date!

        let onTokyoDay = await storage.getEntriesForDate(
            tokyoNoon,
            displayTimeZone: TimeZone(identifier: "Asia/Tokyo")!
        )
        XCTAssertEqual(onTokyoDay.count, 1)
        XCTAssertEqual(onTokyoDay.first?.id, entry.id)

        // Προβολή Athens 5/10: η εγγραφή με dateKey Tokyo 6/10 δεν εμφανίζεται.
        var athensOct5 = DateComponents()
        athensOct5.calendar = Calendar(identifier: .gregorian)
        athensOct5.timeZone = TimeZone(identifier: "Europe/Athens")
        athensOct5.year = 2026
        athensOct5.month = 10
        athensOct5.day = 5
        athensOct5.hour = 12
        let athensDay = athensOct5.date!

        let onAthensOct5 = await storage.getEntriesForDate(
            athensDay,
            displayTimeZone: TimeZone(identifier: "Europe/Athens")!
        )
        XCTAssertTrue(onAthensOct5.isEmpty, "Εγγραφή Tokyo 6/10 δεν ανήκει στην Athens 5/10 bucket")
    }

    /// R3-001 regression: ISO8601 encode/decode parity across process-like reload (νέο service instance).
    func testJournalSurvivesRestartViaNewInstance() async throws {
        let fileURL = tempDirectory.appendingPathComponent("journal_restart.json")
        let writer = JSONFileStorageService(storageURL: fileURL)

        let entry = JournalEntry(
            title: "Restart Probe",
            content: "Να πω στη Μαρία για το ταξίδι",
            source: .voice,
            tags: ["ταξίδι"]
        )
        try await writer.saveEntry(entry)

        let reader = JSONFileStorageService(storageURL: fileURL)
        let retrieved = await reader.getEntry(id: entry.id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.content, entry.content)
        XCTAssertEqual(retrieved?.title, "Restart Probe")
        XCTAssertEqual(retrieved?.tags, ["ταξίδι"])
        XCTAssertEqual(retrieved?.source, .voice)
    }

    /// A02: edit content keeps stable ID — overwrite, όχι νέο UUID.
    func testEditKeepsStableIDNoDuplicates() async throws {
        let entry = JournalEntry(
            title: "Πριν",
            content: "Παλιό κείμενο",
            source: .manual,
            tags: ["draft"]
        )
        try await storage.saveEntry(entry)

        var updated = entry
        updated.title = "Μετά"
        updated.content = "Νέο κείμενο"
        updated.tags = ["final"]
        updated.lastModified = Date()
        try await storage.saveEntry(updated)

        let all = await storage.getAllEntries()
        XCTAssertEqual(all.filter { $0.id == entry.id }.count, 1)
        let retrieved = await storage.getEntry(id: entry.id)
        XCTAssertEqual(retrieved?.title, "Μετά")
        XCTAssertEqual(retrieved?.content, "Νέο κείμενο")
        XCTAssertEqual(retrieved?.tags, ["final"])
    }

    /// A02: διόρθωση ημερομηνίας αλλάζει dateKey χωρίς διπλότυπο ID.
    func testCorrectDateChangesDateKeySameID() async throws {
        var athensComponents = DateComponents()
        athensComponents.calendar = Calendar(identifier: .gregorian)
        athensComponents.timeZone = TimeZone(identifier: "Europe/Athens")
        athensComponents.year = 2026
        athensComponents.month = 10
        athensComponents.day = 5
        athensComponents.hour = 15
        let oct5 = athensComponents.date!

        let entry = JournalEntry(
            timestamp: oct5,
            timeZoneIdentifier: "Europe/Athens",
            content: "Λάθος ημέρα",
            source: .manual
        )
        XCTAssertEqual(entry.dateKey, "2026-10-05")
        try await storage.saveEntry(entry)

        athensComponents.day = 6
        let oct6 = athensComponents.date!
        var corrected = entry
        corrected.timestamp = oct6
        corrected.lastModified = Date()
        try await storage.saveEntry(corrected)

        let retrieved = await storage.getEntry(id: entry.id)
        XCTAssertEqual(retrieved?.dateKey, "2026-10-06")
        XCTAssertEqual(await storage.getAllEntries().filter { $0.id == entry.id }.count, 1)

        let onOct6 = await storage.getEntriesForDate(
            oct6,
            displayTimeZone: TimeZone(identifier: "Europe/Athens")!
        )
        XCTAssertEqual(onOct6.map(\.id), [entry.id])

        let onOct5 = await storage.getEntriesForDate(
            oct5,
            displayTimeZone: TimeZone(identifier: "Europe/Athens")!
        )
        XCTAssertTrue(onOct5.isEmpty)
    }

    /// A03: media attachment επιβιώνει ISO8601 restart μαζί με journal.
    func testMediaAttachmentSurvivesRestart() async throws {
        let fileURL = tempDirectory.appendingPathComponent("journal_media.json")
        let writer = JSONFileStorageService(storageURL: fileURL)

        let attachment = MediaAttachment(
            relativePath: "Photos/\(UUID().uuidString).jpg",
            mediaType: .photo,
            byteSize: 2048,
            captureTimestamp: Date(),
            hasAudio: false
        )
        let entry = JournalEntry(
            content: "Φωτο από ταξίδι",
            source: .importFile,
            tags: ["photo"],
            attachments: [attachment]
        )
        try await writer.saveEntry(entry)

        let reader = JSONFileStorageService(storageURL: fileURL)
        let retrieved = await reader.getEntry(id: entry.id)
        XCTAssertEqual(retrieved?.attachments.count, 1)
        XCTAssertEqual(retrieved?.attachments.first?.relativePath, attachment.relativePath)
        XCTAssertEqual(retrieved?.attachments.first?.mediaType, .photo)
        XCTAssertEqual(retrieved?.attachments.first?.byteSize, 2048)
    }

    /// A02: search βρίσκει title (όχι μόνο content).
    func testSearchMatchesTitle() async throws {
        let entry = JournalEntry(
            title: "Συνέδριο Ρώμης",
            content: "Λεπτομέρειες αργότερα",
            source: .manual
        )
        try await storage.saveEntry(entry)
        let results = await storage.searchEntries(query: "Ρώμης", tag: nil, source: nil)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, entry.id)
    }
}
