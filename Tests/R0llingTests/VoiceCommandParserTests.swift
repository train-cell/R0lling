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

        let result5s = parser.parse(transcript: "clip 5 seconds please")
        XCTAssertEqual(result5s, .clip(seconds: 5.0))
    }

    func testClipCommandGreek() {
        let result = parser.parse(transcript: "κράτα κλιπ γρήγορα")
        XCTAssertEqual(result, .clip(seconds: 10.0))

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

        let resultEl = parser.parse(transcript: "Τι βλέπω μπροστά μου;")
        XCTAssertEqual(resultEl, .whatAmISeeing)
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
}
