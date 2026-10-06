import Foundation

/// Κοινός OpenAI-compatible chat request builder (DRY Direct ↔ Hermes).
public enum OpenAIChatRequestBuilder {
    public static let maxContextEntries: Int = 5
    public static let maxVisionFrames: Int = 4

    /// Χτίζει το `messages` array για chat/completions (text + optional multi-frame vision).
    public static func buildMessages(
        payload: AIRequestPayload,
        defaultSystemPrompt: String,
        memoryHeader: String
    ) -> [[String: Any]] {
        var messages: [[String: Any]] = []

        var sysContent = payload.systemPrompt ?? defaultSystemPrompt
        if let memory = payload.agentMemoryContext, !memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sysContent += "\n\n\(memoryHeader)\n\(memory)"
        }
        messages.append(["role": "system", "content": sysContent])

        for entry in payload.contextEntries.prefix(maxContextEntries) {
            messages.append([
                "role": "user",
                "content": "[Καταγραφή \(entry.formattedTime)] \(entry.content)"
            ])
        }

        let frames = collectVisionFrames(from: payload)
        if frames.isEmpty {
            messages.append(["role": "user", "content": payload.prompt])
        } else {
            var visionContent: [[String: Any]] = [
                ["type": "text", "text": payload.prompt]
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
        temperature: Double
    ) throws -> Data {
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature
        ]
        return try JSONSerialization.data(withJSONObject: requestBody)
    }

    /// Εξάγει reply + tokens από επιτυχές JSON response (χωρίς raw body leak στο caller).
    public static func parseChatCompletionResponse(
        data: Data,
        fallbackReply: String,
        referencedEntryIDs: [UUID]
    ) throws -> AIResponseResult {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let firstChoice = choices?.first?["message"] as? [String: Any]
        let replyText = firstChoice?["content"] as? String ?? fallbackReply
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
}
