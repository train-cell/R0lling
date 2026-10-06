import XCTest
@testable import R0lling

final class VoiceCommandParserTests: XCTestCase {
    var parser: VoiceCommandParser!

    override func setUp() {
        parser = VoiceCommandParser()
    }

    func testClipCommandEnglish() {
        let result = parser.parse(transcript: "Hey Meta, clip this right now")
        XCTAssertEqual(result, .clip(seconds: 10.0))

        parser.resetDedup()
        let result5s = parser.parse(transcript: "clip 5 seconds please")
        XCTAssertEqual(result5s, .clip(seconds: 5.0))
    }

    func testClipCommandGreek() {
        let result = parser.parse(transcript: "κράτα κλιπ γρήγορα")
        XCTAssertEqual(result, .clip(seconds: 10.0))

        parser.resetDedup()
        let result5s = parser.parse(transcript: "κράτα κλιπ πέντε δευτερόλεπτα")
        XCTAssertEqual(result5s, .clip(seconds: 5.0))
    }

    func testNoteCommandEnglish() {
        let result = parser.parse(transcript: "note this: buy flight tickets")
        XCTAssertEqual(result, .note(text: "Buy flight tickets"))
    }

    func testNoteCommandGreek() {
        let result = parser.parse(transcript: "σημείωσε να πω στη Μαρία για το ταξίδι")
        XCTAssertEqual(result, .note(text: "Να πω στη Μαρία για το ταξίδι"))
    }

    func testWhatAmISeeingCommand() {
        let resultEn = parser.parse(transcript: "What am I seeing?")
        XCTAssertEqual(resultEn, .whatAmISeeing)

        parser.resetDedup()
        let resultEl = parser.parse(transcript: "Τι βλέπω μπροστά μου;")
        XCTAssertEqual(resultEl, .whatAmISeeing)
    }

    func testObservationGameCommands() {
        XCTAssertEqual(parser.parse(transcript: "start observation game"), .startObservationGame)
        parser.resetDedup()
        XCTAssertEqual(parser.parse(transcript: "ξεκίνα το παιχνίδι"), .startObservationGame)
        parser.resetDedup()
        XCTAssertEqual(parser.parse(transcript: "next mission please"), .nextMission)
        parser.resetDedup()
        XCTAssertEqual(parser.parse(transcript: "επόμενη αποστολή"), .nextMission)
    }

    func testUnknownDictation() {
        let result = parser.parse(transcript: "Καλημέρα πώς είσαι;")
        XCTAssertEqual(result, .unknown(raw: "Καλημέρα πώς είσαι;"))
    }

    /// R3-006: Δύο ίδια final transcripts → μία εντολή μέσα στο dedup window.
    func testFinalTranscriptDedup() {
        parser.resetDedup()
        let first = parser.parse(transcript: "σημείωσε να πω στη Μαρία για το ταξίδι")
        XCTAssertEqual(first, .note(text: "Να πω στη Μαρία για το ταξίδι"))

        let duplicate = parser.parse(transcript: "σημείωσε να πω στη Μαρία για το ταξίδι")
        XCTAssertNil(duplicate, "Διπλότυπο final transcript πρέπει να αγνοείται")

        let different = parser.parse(transcript: "σημείωσε αγόρασε γάλα")
        XCTAssertEqual(different, .note(text: "Αγόρασε γάλα"))
    }

    func testScrubGreekAndEnglish() {
        XCTAssertEqual(parser.scrubGreekAndEnglish(raw: "να πάρω γάλα"), "Να πάρω γάλα")
    }
}
