import Foundation
import XCTest
import AVFAudio
@testable import R0lling

/// Executable evidence for documented `SW` DoD items (docs/GOAL_100_FEATURE_MATRIX.md) and for the
/// 2026-10-13 source fixes that had no test.
final class SoftwareCompletionTests: XCTestCase {
    // A10 (3): an empty key fails with the typed Direct error before any request is built.
    func testDirectConnectorRejectsEmptyKeyBeforeNetwork() async {
        let connector = DirectAPIConnector(
            baseURLString: "https://api.example.invalid/v1",
            modelName: "test-model",
            apiKey: "   "
        )
        do {
            _ = try await connector.generateReply(payload: AIRequestPayload(prompt: "γεια"))
            XCTFail("An empty Direct API key must be rejected")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, AIErrorTaxonomy.directDomain)
            XCTAssertEqual(error.code, AIErrorTaxonomy.directEmptyKey)
        } catch {
            XCTFail("Expected the typed missing-key error, received \(error)")
        }
    }

    // A12 (3): no local match → an explicit «not found» reply, no provider call, no sources.
    func testRecallWithoutLocalMatchesSaysSoWithoutCallingTheProvider() async throws {
        let router = AIRouter(settings: AISettings(), connectorOverrideForTesting: ProviderMustNotBeCalledConnector())
        let entry = JournalEntry(content: "Αναχώρηση από Αθήνα")

        let result = try await router.recallMemories(query: "ανύπαρκτο θέμα", allEntries: [entry])

        XCTAssertTrue(result.matchingEntries.isEmpty)
        XCTAssertTrue(result.reply.hasPrefix("Δεν βρήκα"), result.reply)
    }

    // The documented readiness split: 13 wired flags and 15 gated ones (IMPLEMENTATION_STATUS).
    func testReadinessRegistryMatchesTheDocumentedReadyAndGatedFlags() {
        let ready = Set(FeatureReadinessRegistry.allFlags.filter(\.ready).map(\.id))
        let gated = Set(FeatureReadinessRegistry.allFlags.filter { !$0.ready }.map(\.id))

        XCTAssertEqual(ready, [
            "earcon", "timeCapsule", "highlightReel", "podcast", "canvas", "knowledgeGraph",
            "emotionTags", "scavengerStreak", "appleSpeech", "onDeviceVisionOCR", "entityTags",
            "nutritionHeuristic", "dataviewFrontmatter"
        ])
        XCTAssertEqual(gated, [
            "acoustic", "headGesture", "spatialAudio", "metalPool", "watermark", "fileWatcher",
            "proximity", "watchCompanion", "pseudoVectorSearch", "turnTaking", "mirror",
            "hyperlapse", "whisperStub", "multiFrameVision", "adaptiveBattery"
        ])
        XCTAssertEqual(FeatureReadinessRegistry.allFlags.count, 28)
    }

    func testEntityTagsMatchEnglishCuesAsWholeWordsAndKeepCategoryOrder() {
        let recognizer = LocalEntityRecognizer()

        XCTAssertEqual(recognizer.detectEntities(textClues: ["Left my card at the location desk"]), [])
        XCTAssertEqual(
            recognizer.detectEntities(textClues: ["Two cars and a dog in the park"]),
            ["κατοικίδιο", "αυτοκίνητο", "φύση"]
        )
        XCTAssertEqual(recognizer.detectEntities(textClues: ["Ήπια καφές με τη γάτα"]), ["κατοικίδιο", "καφές"])
    }

    func testBufferTargetNormalizationUsesTheTwoDocumentedWindows() {
        XCTAssertEqual(MetaGlassesAdapter.normalizedBufferTarget(5), 5)
        XCTAssertEqual(MetaGlassesAdapter.normalizedBufferTarget(7.4), 5)
        XCTAssertEqual(MetaGlassesAdapter.normalizedBufferTarget(7.5), 10)
        XCTAssertEqual(MetaGlassesAdapter.normalizedBufferTarget(30), 10)
        XCTAssertEqual(MetaGlassesAdapter.normalizedBufferTarget(.nan), 10)
    }

    @MainActor
    func testDurationBadgeShowsMinutesAndSeconds() {
        XCTAssertEqual(MediaPreviewCard.durationBadgeText(9.6), "00:09")
        XCTAssertEqual(MediaPreviewCard.durationBadgeText(75), "01:15")
        XCTAssertEqual(MediaPreviewCard.durationBadgeText(-3), "00:00")
        XCTAssertEqual(MediaPreviewCard.durationBadgeText(.infinity), "00:00")
    }

    // DECISIONS §1 / A04: the optional original audio of a dictated note is an AAC `.m4a`.
    func testVoiceNoteAudioWriterProducesM4AWithMeasuredDuration() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let writer = try VoiceNoteAudioWriter(format: format)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410))
        buffer.frameLength = 4_410
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for index in 0..<Int(buffer.frameLength) {
            samples[index] = Float(sin(Double(index) * 2 * Double.pi * 440 / 44_100)) * 0.2
        }

        writer.append(buffer)
        let recording = try XCTUnwrap(writer.finish())
        defer { try? FileManager.default.removeItem(at: recording.fileURL) }

        XCTAssertEqual(recording.fileURL.pathExtension, "m4a")
        XCTAssertEqual(recording.durationSeconds, 0.1, accuracy: 0.001)
        let attributes = try FileManager.default.attributesOfItem(atPath: recording.fileURL.path)
        let size = try XCTUnwrap(attributes[.size] as? NSNumber)
        XCTAssertGreaterThan(size.intValue, 0)
    }

    func testVoiceNoteAudioWriterWithoutAudioLeavesNoFile() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let writer = try VoiceNoteAudioWriter(format: format)

        XCTAssertNil(writer.finish())
        XCTAssertFalse(FileManager.default.fileExists(atPath: writer.fileURL.path))
    }
}

private struct ProviderMustNotBeCalledConnector: AIConnectorProtocol {
    let providerType: AIProviderType = .directAPI

    func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult {
        XCTFail("A recall without local matches must not call the provider")
        return AIResponseResult(reply: "")
    }

    func describeImage(imageData: Data, question: String?) async throws -> String {
        XCTFail("Recall must not call image description")
        return ""
    }

    func summarizeDay(entries: [JournalEntry]) async throws -> String {
        XCTFail("Recall must not call day summaries")
        return ""
    }
}
