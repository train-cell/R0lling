import XCTest
@testable import R0lling

final class OpenAIChatRequestBuilderTests: XCTestCase {
    func testOutboundPIIRedactorScrubsCommonIdentifiersAndPreservesOrdinaryText() {
        let source = "Email alex@example.com, card 4111 1111 1111 1111, invalid card 4111 1111 1111 1112, SSN 123-45-6789, ΑΦΜ: 123456789, phone +30 210 123 4567, IBANs GR12 0110 1250 0000 0001 2345 678 and GB82 WEST 1234 5698 7654 32, invalid IBAN GB83 WEST 1234 5698 7654 32. Delivery 12345 on 2026-10-10."
        let redacted = OutboundPIIRedactor.redact(source)

        for identifier in [
            "alex@example.com",
            "4111 1111 1111 1111",
            "123-45-6789",
            "123456789",
            "+30 210 123 4567",
            "GR12 0110 1250 0000 0001 2345 678",
            "GB82 WEST 1234 5698 7654 32"
        ] {
            XCTAssertFalse(redacted.contains(identifier), "Expected identifier to be removed: \(identifier)")
        }
        XCTAssertTrue(redacted.contains("2026-10-10"))
        XCTAssertTrue(redacted.contains("Delivery 12345"))
        XCTAssertTrue(redacted.contains("4111 1111 1111 1112"))
        XCTAssertTrue(redacted.contains("GB83 WEST 1234 5698 7654 32"))
    }

    func testProviderBoundTextIsRedactedAcrossPromptMemoryJournalAndLocation() throws {
        let journal = JournalEntry(
            content: "Use card 4111 1111 1111 1111, AFM: 123456789, and IBAN GR12 0110 1250 0000 0001 2345 678",
            locationName: "Call +30 210 123 4567"
        )
        let payload = AIRequestPayload(
            prompt: "Contact alex@example.com; SSN 123-45-6789",
            systemPrompt: "Private contact alex@example.com",
            contextEntries: [journal],
            agentMemoryContext: "SSN 123-45-6789"
        )

        let body = try OpenAIChatRequestBuilder.buildBoundedRequestBody(
            payload: payload,
            defaultSystemPrompt: "default system",
            memoryHeader: "Memory",
            model: "test-model",
            temperature: 0.2
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let providerText = messages.compactMap { message -> String? in
            guard let content = message["content"] else { return nil }
            if let text = content as? String { return text }
            guard let parts = content as? [[String: Any]] else { return nil }
            return parts.compactMap { $0["text"] as? String }.joined(separator: " ")
        }.joined(separator: "\n")

        for identifier in [
            "alex@example.com",
            "4111 1111 1111 1111",
            "123-45-6789",
            "123456789",
            "+30 210 123 4567",
            "GR12 0110 1250 0000 0001 2345 678"
        ] {
            XCTAssertFalse(providerText.contains(identifier), "Provider text leaked: \(identifier)")
        }
        XCTAssertTrue(providerText.contains("[REDACTED]"))
        XCTAssertEqual(payload.contextEntries.first?.content, journal.content)
        XCTAssertEqual(payload.contextEntries.first?.locationName, journal.locationName)
    }

    func testVisionPromptIsRedactedAndImagePayloadIsKept() throws {
        let payload = AIRequestPayload(
            prompt: "Describe this for alex@example.com",
            imageBase64: "YWJj"
        )
        let body = try OpenAIChatRequestBuilder.buildBoundedRequestBody(
            payload: payload,
            defaultSystemPrompt: "system",
            memoryHeader: "memory",
            model: "test-model",
            temperature: 0.2
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let visionParts = try XCTUnwrap(messages.last?["content"] as? [[String: Any]])

        XCTAssertEqual(visionParts.first?["text"] as? String, "Describe this for [REDACTED]")
        let imageURL = try XCTUnwrap(visionParts.last?["image_url"] as? [String: String])
        XCTAssertEqual(imageURL["url"], "data:image/jpeg;base64,YWJj")
    }

    func testBoundedBodyAcceptsNormalPromptAndContext() throws {
        let payload = AIRequestPayload(
            prompt: "Σύνοψε τις τελευταίες σημειώσεις μου.",
            contextEntries: [JournalEntry(content: "Σήμερα περπάτησα στο κέντρο της Αθήνας.")]
        )

        let body = try OpenAIChatRequestBuilder.buildBoundedRequestBody(
            payload: payload,
            defaultSystemPrompt: "Απάντησε στα Ελληνικά.",
            memoryHeader: "Μνήμη:",
            model: "test-model",
            temperature: 0.2
        )

        XCTAssertLessThanOrEqual(body.count, OpenAIChatRequestBuilder.maximumRequestBodyBytes)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: body))
    }

    func testBoundedBodyRejectsLargeJournalContextBeforeBuildingMessages() {
        let payload = AIRequestPayload(
            prompt: "Σύνοψη",
            contextEntries: [JournalEntry(content: String(repeating: "x", count: 32_000))]
        )

        XCTAssertThrowsError(try OpenAIChatRequestBuilder.buildBoundedRequestBody(
            payload: payload,
            defaultSystemPrompt: "system",
            memoryHeader: "memory",
            model: "test-model",
            temperature: 0.2,
            maximumBytes: 16 * 1024
        )) { error in
            XCTAssertEqual(error as? AIRequestBodyTooLarge, AIRequestBodyTooLarge(maximumBytes: 16 * 1024))
        }
    }

    func testLowLevelBodyBuilderRejectsOversizedMessagesBeforeSerialization() {
        let messages: [[String: Any]] = [[
            "role": "user",
            "content": String(repeating: "x", count: 4_096)
        ]]

        XCTAssertThrowsError(try OpenAIChatRequestBuilder.buildRequestBody(
            model: "test-model",
            messages: messages,
            temperature: 0.2,
            maximumBytes: 1_024
        )) { error in
            XCTAssertEqual(error as? AIRequestBodyTooLarge, AIRequestBodyTooLarge(maximumBytes: 1_024))
        }
    }

    func testVisionFramesAreCappedBeforeBase64Expansion() throws {
        let acceptedTotal = try OpenAIChatRequestBuilder.addingVisionFrameBytes(2 * 1024 * 1024)
        let updatedTotal = try OpenAIChatRequestBuilder.addingVisionFrameBytes(1024, to: acceptedTotal)
        XCTAssertEqual(updatedTotal, 2 * 1024 * 1024 + 1024)

        XCTAssertThrowsError(try OpenAIChatRequestBuilder.addingVisionFrameBytes(
            OpenAIChatRequestBuilder.maximumAggregateVisionImageBytes + 1
        )) { error in
            XCTAssertEqual(
                error as? AIRequestBodyTooLarge,
                AIRequestBodyTooLarge(maximumBytes: OpenAIChatRequestBuilder.maximumRequestBodyBytes)
            )
        }
    }

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

    func testRecallSourceSummaryContainsStableJournalIDs() {
        let entry = JournalEntry(title: "Ταξίδι", content: "Αναχώρηση από Αθήνα")
        let summary = AIRouter.localRecallSourceSummary([entry])

        XCTAssertTrue(summary.contains(entry.id.uuidString))
        XCTAssertTrue(summary.contains(entry.dateKey))
        XCTAssertTrue(summary.contains("Ταξίδι"))
    }
}
