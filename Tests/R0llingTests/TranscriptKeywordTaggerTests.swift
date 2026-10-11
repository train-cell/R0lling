import XCTest
@testable import R0lling

final class TranscriptKeywordTaggerTests: XCTestCase {
    private let tagger = TranscriptKeywordTagger()

    func testGreekTranscriptProducesExplicitTextCuesInStableOrder() {
        let cues = tagger.detectCues(in: "Τέλειο! Μην ξεχάσεις, ίσως αυτή την ιδέα για το project?")

        XCTAssertEqual(cues, [
            "κείμενο: ενθουσιασμός",
            "κείμενο: επείγον",
            "κείμενο: σκέψη",
            "κείμενο: ιδέα"
        ])
    }

    func testEnglishKeywordCueIsLabeledAsTextRatherThanVoiceEmotion() {
        XCTAssertEqual(tagger.detectCues(in: "This is an amazing project!"), [
            "κείμενο: ενθουσιασμός",
            "κείμενο: ιδέα"
        ])
    }

    func testKeywordMatchingUsesWordBoundaries() {
        XCTAssertEqual(tagger.detectCues(in: "The projector is on the table."), [])
        XCTAssertEqual(tagger.detectCues(in: "This is not amazingish."), [])
    }

    func testPunctuationBetweenWordsDoesNotBreakPhraseMatching() {
        XCTAssertEqual(tagger.detectCues(in: "Μην, ξεχάσεις το σχέδιο."), [
            "κείμενο: επείγον",
            "κείμενο: ιδέα"
        ])
    }

    func testLegacyVoiceEmotionAPIRemainsSourceCompatible() {
        let legacy = VoiceEmotionAnalyzer()
        XCTAssertEqual(
            legacy.analyzeTranscript(text: "urgent", durationSeconds: 2),
            ["κείμενο: επείγον"]
        )
    }
}
