import XCTest
@testable import R0lling

final class OpenAIChatRequestBuilderTests: XCTestCase {
    func testContextUsesNewestFiveEntriesInChronologicalOrder() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let entries = (0..<8).map { index in
            JournalEntry(
                timestamp: start.addingTimeInterval(TimeInterval(index * 60)),
                content: "entry-\(index)"
            )
        }
        let payload = AIRequestPayload(prompt: "summarize", contextEntries: entries)

        let messages = OpenAIChatRequestBuilder.buildMessages(
            payload: payload,
            defaultSystemPrompt: "system",
            memoryHeader: "memory"
        )
        let userMessages = messages.compactMap { message -> String? in
            guard message["role"] as? String == "user" else { return nil }
            return message["content"] as? String
        }

        XCTAssertEqual(userMessages.count, 6) // Five context notes plus the prompt
        for index in 0..<3 {
            XCTAssertFalse(userMessages.joined(separator: "\n").contains("entry-\(index)"))
        }
        for index in 3..<8 {
            XCTAssertTrue(userMessages.joined(separator: "\n").contains("entry-\(index)"))
        }
        XCTAssertTrue(userMessages[0].contains("entry-3"))
        XCTAssertTrue(userMessages[4].contains("entry-7"))

        let selectedIDs = OpenAIChatRequestBuilder.selectedContextEntries(from: entries).map(\.id)
        XCTAssertEqual(selectedIDs, Array(entries.suffix(5)).map(\.id))
    }

    func testSelectionHandlesNewestFirstStorageOrderAndSmallerLimit() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let newestFirst = (0..<8).reversed().map { index in
            JournalEntry(
                timestamp: start.addingTimeInterval(TimeInterval(index * 60)),
                content: "entry-\(index)"
            )
        }

        let selected = OpenAIChatRequestBuilder.selectedContextEntries(from: newestFirst, limit: 3)

        XCTAssertEqual(selected.map(\.content), ["entry-5", "entry-6", "entry-7"])
    }

    func testNoteLocationRequiresSeparateContextOptIn() {
        let entry = JournalEntry(content: "Coffee", locationName: "Athens")

        let excluded = AIRouter.sanitizedContextEntries([entry], includeLocation: false)
        XCTAssertNil(excluded.first?.locationName)

        let included = AIRouter.sanitizedContextEntries([entry], includeLocation: true)
        XCTAssertEqual(included.first?.locationName, "Athens")
        let messages = OpenAIChatRequestBuilder.buildMessages(
            payload: AIRequestPayload(prompt: "Where?", contextEntries: included),
            defaultSystemPrompt: "system",
            memoryHeader: "memory"
        )
        XCTAssertTrue(messages.contains { ($0["content"] as? String)?.contains("Athens") == true })
    }

    func testMalformedProviderBodyUsesInvalidResponseError() {
        XCTAssertThrowsError(try OpenAIChatRequestBuilder.parseChatCompletionResponse(
            data: Data("not-json".utf8),
            fallbackReply: "fallback",
            referencedEntryIDs: [],
            invalidResponseDomain: AIErrorTaxonomy.directDomain,
            invalidResponseCode: AIErrorTaxonomy.directInvalidResponse
        )) { error in
            let typed = error as NSError
            XCTAssertEqual(typed.domain, AIErrorTaxonomy.directDomain)
            XCTAssertEqual(typed.code, AIErrorTaxonomy.directInvalidResponse)
        }
    }
}
