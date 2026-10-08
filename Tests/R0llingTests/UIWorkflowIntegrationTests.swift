import XCTest
import SwiftUI
@testable import R0lling

/// Επαλήθευση UI workflows, HUD overlay, και MediaViewer integration
final class UIWorkflowIntegrationTests: XCTestCase {

    @MainActor
    func testLiveViewfinderCardAndHUDOverlay() {
        let hud = ViewfinderHUDOverlay()
        XCTAssertNotNil(hud)

        var clipTapped = false
        let card = LiveViewfinderCard(
            isStreaming: true,
            bufferDuration: 8.5,
            onClipTap: { clipTapped = true }
        )
        XCTAssertNotNil(card)
        XCTAssertTrue(card.isStreaming)
        XCTAssertEqual(card.bufferDuration, 8.5)

        card.onClipTap()
        XCTAssertTrue(clipTapped)
    }

    @MainActor
    func testMediaViewerSheetInitialization() {
        let testURL = URL(fileURLWithPath: "/tmp/sample.mp4")
        let att = MediaAttachment(
            id: UUID(),
            relativePath: "clips/sample.mp4",
            originalFilename: "sample.mp4",
            mediaType: .clip,
            byteSize: 1024,
            durationSeconds: 10.0
        )

        let sheet = MediaViewerSheet(url: testURL, attachment: att)
        XCTAssertNotNil(sheet)
        XCTAssertEqual(sheet.url, testURL)
        XCTAssertEqual(sheet.attachment.mediaType, .clip)
    }

    @MainActor
    func testEntryEditorSheetDateKeyCalculation() {
        let baseDate = Date(timeIntervalSince1970: 1728211200) // 2024-10-06 10:40:00 UTC
        let entry = JournalEntry(
            content: "Αρχική σημείωση",
            tags: ["τεστ"],
            timestamp: baseDate,
            timeZoneIdentifier: "Europe/Athens"
        )

        var savedEntry: JournalEntry?
        let editor = EntryEditorSheet(
            entry: entry,
            onSave: { updated in savedEntry = updated },
            onCancel: {}
        )
        XCTAssertNotNil(editor)
        XCTAssertEqual(entry.timeZoneIdentifier, "Europe/Athens")
    }

    @MainActor
    func testStrategicVaultCardViews() {
        let diaryCard = EncryptedDiaryCardView(secretContent: "Απόρρητο μήνυμα")
        XCTAssertNotNil(diaryCard)
        XCTAssertEqual(diaryCard.secretContent, "Απόρρητο μήνυμα")

        let decision = DecisionRecord(
            decisionText: "Αρχιτεκτονική απόφαση On-Device",
            coreAssumptions: ["Μηδενικό latency"],
            confidencePercent: 98
        )
        let decisionCard = DecisionRecordCardView(decision: decision)
        XCTAssertNotNil(decisionCard)
        XCTAssertEqual(decisionCard.decision.confidencePercent, 98)

        let inversionCard = PreMortemInversionCardView()
        XCTAssertNotNil(inversionCard)

        let airGappedBanner = AirGappedStatusBanner()
        XCTAssertNotNil(airGappedBanner)
    }

    func testMediaAttachmentFilenameHandling() throws {
        let attWithDefault = MediaAttachment(
            relativePath: "photos/vacation.jpg",
            mediaType: .photo,
            byteSize: 2048
        )
        XCTAssertEqual(attWithDefault.originalFilename, "vacation.jpg")

        let attWithExplicit = MediaAttachment(
            relativePath: "photos/123.jpg",
            originalFilename: "custom_name.jpg",
            mediaType: .photo,
            byteSize: 1024
        )
        XCTAssertEqual(attWithExplicit.originalFilename, "custom_name.jpg")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(attWithExplicit)
        let decoded = try decoder.decode(MediaAttachment.self, from: data)
        XCTAssertEqual(decoded.originalFilename, "custom_name.jpg")
        XCTAssertEqual(decoded.relativePath, "photos/123.jpg")
    }
}

