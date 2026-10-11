import Foundation

/// Κοινός OpenAI-compatible chat request builder (DRY Direct ↔ Hermes).
public enum OpenAIChatRequestBuilder {
    public static let maxContextEntries: Int = 5
    public static let maxVisionFrames: Int = 4
    public static let maximumRequestBodyBytes: Int = AIHTTPClient.defaultMaximumRequestBytes
    public static let maximumAggregateVisionImageBytes: Int = 7 * 1024 * 1024
    private static let requestBodyStructuralReserveBytes = 4 * 1024

    /// Caps JPEG bytes before Base64 expansion; returns the updated aggregate count.
    @discardableResult
    public static func addingVisionFrameBytes(_ frameBytes: Int, to aggregateBytes: Int = 0) throws -> Int {
        guard frameBytes >= 0, aggregateBytes >= 0 else {
            throw AIRequestBodyTooLarge(maximumBytes: maximumRequestBodyBytes)
        }
        let (total, overflow) = aggregateBytes.addingReportingOverflow(frameBytes)
        guard !overflow, total <= maximumAggregateVisionImageBytes else {
            throw AIRequestBodyTooLarge(maximumBytes: maximumRequestBodyBytes)
        }
        return total
    }

    /// Selects the exact context entries used by both the prompt and response provenance.
    /// The newest entries are chosen, then returned in chronological order for readability.
    public static func selectedContextEntries(
        from entries: [JournalEntry],
        limit: Int = maxContextEntries
    ) -> [JournalEntry] {
        let boundedLimit = max(0, min(limit, maxContextEntries))
        guard boundedLimit > 0 else { return [] }
        return entries
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(boundedLimit)
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Χτίζει το `messages` array για chat/completions (text + optional multi-frame vision).
    public static func buildMessages(
        payload: AIRequestPayload,
        defaultSystemPrompt: String,
        memoryHeader: String
    ) -> [[String: Any]] {
        var messages: [[String: Any]] = []

        var sysContent = OutboundPIIRedactor.redact(payload.systemPrompt ?? defaultSystemPrompt)
        if let memory = payload.agentMemoryContext, !memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sysContent += "\n\n\(OutboundPIIRedactor.redact(memoryHeader))\n\(OutboundPIIRedactor.redact(memory))"
        }
        messages.append(["role": "system", "content": sysContent])

        for entry in selectedContextEntries(from: payload.contextEntries) {
            messages.append([
                "role": "user",
                "content": "[Καταγραφή \(OutboundPIIRedactor.redact(entry.formattedTime))] \(OutboundPIIRedactor.redact(entry.content))"
                    + (entry.locationName.map { "\n[Τοποθεσία] \(OutboundPIIRedactor.redact($0))" } ?? "")
            ])
        }

        let frames = collectVisionFrames(from: payload)
        if frames.isEmpty {
            messages.append(["role": "user", "content": OutboundPIIRedactor.redact(payload.prompt)])
        } else {
            var visionContent: [[String: Any]] = [
                ["type": "text", "text": OutboundPIIRedactor.redact(payload.prompt)]
            ]
            for b64 in frames {
                visionContent.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(b64)"]
                ])
            }
            messages.append(["role": "user", "content": visionContent])
        }

        return messages
    }

    /// JSON body για OpenAI-compatible `/chat/completions`.
    public static func buildRequestBody(
        model: String,
        messages: [[String: Any]],
        temperature: Double,
        maximumBytes: Int = maximumRequestBodyBytes
    ) throws -> Data {
        let maximumBytes = max(1, maximumBytes)
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature
        ]
        guard let estimatedBytes = jsonUpperBound(for: requestBody, maximumBytes: maximumBytes),
              estimatedBytes <= maximumBytes else {
            throw AIRequestBodyTooLarge(maximumBytes: maximumBytes)
        }
        let data = try JSONSerialization.data(withJSONObject: requestBody)
        guard data.count <= maximumBytes else {
            throw AIRequestBodyTooLarge(maximumBytes: maximumBytes)
        }
        return data
    }

    /// Preflights user content before message interpolation and JSON serialization.
    /// The estimate assumes the worst valid JSON escaping for each Unicode scalar,
    /// then the final serialized body is checked against the exact byte limit.
    public static func buildBoundedRequestBody(
        payload: AIRequestPayload,
        defaultSystemPrompt: String,
        memoryHeader: String,
        model: String,
        temperature: Double,
        maximumBytes: Int = maximumRequestBodyBytes
    ) throws -> Data {
        let maximumBytes = max(1, maximumBytes)
        guard maximumBytes > requestBodyStructuralReserveBytes else {
            throw AIRequestBodyTooLarge(maximumBytes: maximumBytes)
        }

        var estimatedRawInputBytes = 0
        var estimatedInputBytes = 0
        func includeRaw(_ value: String) -> Bool {
            let rawInputBudget = maximumBytes - requestBodyStructuralReserveBytes
            guard let valueBytes = jsonStringUpperBound(value, maximumBytes: rawInputBudget),
                  valueBytes <= rawInputBudget - estimatedRawInputBytes else {
                return false
            }
            estimatedRawInputBytes += valueBytes
            return true
        }
        func include(_ value: String) -> Bool {
            guard let valueBytes = jsonStringUpperBound(value, maximumBytes: maximumBytes),
                  valueBytes <= maximumBytes - estimatedInputBytes else {
                return false
            }
            estimatedInputBytes += valueBytes
            return true
        }

        let systemPrompt = payload.systemPrompt ?? defaultSystemPrompt
        guard includeRaw(model), include(model),
              includeRaw(systemPrompt), include(OutboundPIIRedactor.redact(systemPrompt)) else {
            throw AIRequestBodyTooLarge(maximumBytes: maximumBytes)
        }
        if let memory = payload.agentMemoryContext, !memory.isEmpty {
            guard includeRaw(memoryHeader), include(OutboundPIIRedactor.redact(memoryHeader)),
                  includeRaw(memory), include(OutboundPIIRedactor.redact(memory)) else {
                throw AIRequestBodyTooLarge(maximumBytes: maximumBytes)
            }
        }

        for entry in selectedContextEntries(from: payload.contextEntries) {
            let formattedTime = entry.formattedTime
            guard includeRaw(formattedTime), include(OutboundPIIRedactor.redact(formattedTime)),
                  includeRaw(entry.content),
                  include(OutboundPIIRedactor.redact(entry.content)) else {
                throw AIRequestBodyTooLarge(maximumBytes: maximumBytes)
            }
            if let locationName = entry.locationName {
                guard includeRaw(locationName), include(OutboundPIIRedactor.redact(locationName)) else {
                    throw AIRequestBodyTooLarge(maximumBytes: maximumBytes)
                }
            }
        }

        guard includeRaw(payload.prompt), include(OutboundPIIRedactor.redact(payload.prompt)) else {
            throw AIRequestBodyTooLarge(maximumBytes: maximumBytes)
        }
        for frame in collectVisionFrames(from: payload) {
            guard includeRaw(frame), include(frame) else {
                throw AIRequestBodyTooLarge(maximumBytes: maximumBytes)
            }
        }

        guard estimatedInputBytes <= maximumBytes - requestBodyStructuralReserveBytes else {
            throw AIRequestBodyTooLarge(maximumBytes: maximumBytes)
        }

        let messages = buildMessages(
            payload: payload,
            defaultSystemPrompt: defaultSystemPrompt,
            memoryHeader: memoryHeader
        )
        return try buildRequestBody(
            model: model,
            messages: messages,
            temperature: temperature,
            maximumBytes: maximumBytes
        )
    }

    /// Εξάγει reply + tokens από επιτυχές JSON response (χωρίς raw body leak στο caller).
    public static func parseChatCompletionResponse(
        data: Data,
        fallbackReply: String,
        referencedEntryIDs: [UUID],
        invalidResponseDomain: String,
        invalidResponseCode: Int
    ) throws -> AIResponseResult {
        let json: [String: Any]?
        do {
            json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            throw NSError(domain: invalidResponseDomain, code: invalidResponseCode, userInfo: [
                NSLocalizedDescriptionKey: "Ο πάροχος AI επέστρεψε μη έγκυρη απάντηση.",
                NSUnderlyingErrorKey: error
            ])
        }
        let choices = json?["choices"] as? [[String: Any]]
        let firstChoice = choices?.first?["message"] as? [String: Any]
        guard let replyText = firstChoice?["content"] as? String,
              !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: invalidResponseDomain, code: invalidResponseCode, userInfo: [
                NSLocalizedDescriptionKey: "Ο πάροχος AI επέστρεψε κενή ή μη έγκυρη απάντηση."
            ])
        }
        let usage = json?["usage"] as? [String: Any]
        let totalTokens = usage?["total_tokens"] as? Int
        return AIResponseResult(
            reply: replyText,
            tokensUsed: totalTokens,
            referencedEntryIDs: referencedEntryIDs
        )
    }

    // MARK: - Private

    private static func collectVisionFrames(from payload: AIRequestPayload) -> [String] {
        var frames: [String] = []
        if let multi = payload.imageBase64Frames {
            for item in multi where !item.isEmpty {
                frames.append(item)
                if frames.count >= maxVisionFrames { break }
            }
        }
        if frames.isEmpty, let single = payload.imageBase64, !single.isEmpty {
            frames.append(single)
        }
        return frames
    }

    /// Upper bound for JSON-escaped string bytes, calculated without making a copy.
    private static func jsonStringUpperBound(_ value: String, maximumBytes: Int) -> Int? {
        guard maximumBytes >= 2 else { return nil }
        var byteCount = 2 // JSON quotes
        for scalar in value.unicodeScalars {
            let scalarBytes: Int
            switch scalar.value {
            case 0...0x1F, 0x22, 0x2F, 0x5C:
                scalarBytes = scalar.value <= 0x1F ? 6 : 2
            case 0x20...0x7E:
                scalarBytes = 1
            case 0x7F...0xFFFF:
                scalarBytes = 6
            default:
                scalarBytes = 12
            }
            guard scalarBytes <= maximumBytes - byteCount else { return nil }
            byteCount += scalarBytes
        }
        return byteCount
    }

    /// Bounds only JSON types accepted by JSONSerialization; unknown values fail closed.
    private static func jsonUpperBound(for value: Any, maximumBytes: Int) -> Int? {
        if let string = value as? String {
            return jsonStringUpperBound(string, maximumBytes: maximumBytes)
        }
        if value is NSNull { return 4 }
        if value is NSNumber { return 256 }
        if let array = value as? [Any] {
            var total = 2 // brackets
            for (index, element) in array.enumerated() {
                guard let elementBytes = jsonUpperBound(
                    for: element,
                    maximumBytes: maximumBytes - total
                ) else { return nil }
                let separatorBytes = index == 0 ? 0 : 1
                guard separatorBytes <= maximumBytes - total,
                      elementBytes <= maximumBytes - total - separatorBytes else { return nil }
                total += separatorBytes + elementBytes
            }
            return total
        }
        if let dictionary = value as? [String: Any] {
            var total = 2 // braces
            for (index, (key, element)) in dictionary.enumerated() {
                guard let keyBytes = jsonStringUpperBound(key, maximumBytes: maximumBytes - total),
                      let valueBytes = jsonUpperBound(
                        for: element,
                        maximumBytes: maximumBytes - total
                      ) else { return nil }
                let separatorBytes = index == 0 ? 0 : 1
                guard keyBytes < maximumBytes - total,
                      valueBytes <= maximumBytes - total - keyBytes - 1 else { return nil }
                let memberBytes = keyBytes + 1 + valueBytes // colon
                guard separatorBytes <= maximumBytes - total,
                      memberBytes <= maximumBytes - total - separatorBytes else { return nil }
                total += separatorBytes + memberBytes
            }
            return total
        }
        return nil
    }
}
