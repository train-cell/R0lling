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

    func testNoteBodyContainingClipRemainsDictationInEnglishAndGreek() {
        XCTAssertEqual(
            parser.parse(transcript: "note this: clip the paragraph about my trip"),
            .note(text: "Clip the paragraph about my trip")
        )

        parser.resetDedup()
        XCTAssertEqual(
            parser.parse(transcript: "σημείωσε: το clip για το ταξίδι"),
            .note(text: "Το clip για το ταξίδι")
        )
    }

    func testMentioningClipDoesNotTriggerClipCommand() {
        XCTAssertEqual(
            parser.parse(transcript: "I found a clip about the trip"),
            .unknown(raw: "I found a clip about the trip")
        )
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

    func testFinalUnknownTranscriptIsReturnedAsDictationDespiteParserDedup() {
        let resolver = VoiceCommandUtteranceResolver(parser: parser)
        resolver.beginUtterance()
        let transcript = "Καλημέρα πώς είσαι;"

        XCTAssertNil(resolver.processFinalTranscript(transcript), "Dictation must not dispatch as a command")
        let stopped = resolver.stop(transcript: transcript)

        XCTAssertEqual(stopped.result, .dictation(transcript))
        XCTAssertNil(stopped.commandToDispatch)
    }

    func testFinalCommandIsReturnedAndDispatchedOnlyOnce() {
        let resolver = VoiceCommandUtteranceResolver(parser: parser)
        resolver.beginUtterance()
        let transcript = "note this: buy flight tickets"

        XCTAssertEqual(resolver.processFinalTranscript(transcript), .note(text: "Buy flight tickets"))
        let stopped = resolver.stop(transcript: transcript)

        XCTAssertEqual(stopped.result, .commandHandled(.note(text: "Buy flight tickets")))
        XCTAssertNil(stopped.commandToDispatch, "The final callback already dispatched the command")
    }

    func testStopWithoutFinalCallbackDispatchesCommandOnce() {
        let resolver = VoiceCommandUtteranceResolver(parser: parser)
        resolver.beginUtterance()
        let stopped = resolver.stop(transcript: "note this: buy flight tickets")

        XCTAssertEqual(stopped.result, .commandHandled(.note(text: "Buy flight tickets")))
        XCTAssertEqual(stopped.commandToDispatch, .note(text: "Buy flight tickets"))
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
