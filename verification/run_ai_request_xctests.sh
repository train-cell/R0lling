#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-ai-request-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/Sources/R0lling" "$scratch_dir/Tests/R0llingTests"
cp "$repo_root/Sources/R0lling/AI/AIHTTPClient.swift" "$scratch_dir/Sources/R0lling/"
cp "$repo_root/Sources/R0lling/AI/AIErrorTaxonomy.swift" "$scratch_dir/Sources/R0lling/"
cp "$repo_root/Sources/R0lling/AI/AIConnectorProtocol.swift" "$scratch_dir/Sources/R0lling/"
cp "$repo_root/Sources/R0lling/AI/OutboundPIIRedactor.swift" "$scratch_dir/Sources/R0lling/"
cp "$repo_root/Sources/R0lling/AI/OpenAIChatRequestBuilder.swift" "$scratch_dir/Sources/R0lling/"
cp "$repo_root/Sources/R0lling/AI/DirectAPIConnector.swift" "$scratch_dir/Sources/R0lling/"
cp "$repo_root/Sources/R0lling/AI/HermesConnector.swift" "$scratch_dir/Sources/R0lling/"
cp "$repo_root/Tests/R0llingTests/AIHTTPClientTests.swift" "$scratch_dir/Tests/R0llingTests/"
cp "$repo_root/Tests/R0llingTests/OpenAIChatRequestBuilderTests.swift" "$scratch_dir/Tests/R0llingTests/"

cat > "$scratch_dir/Package.swift" <<'MANIFEST'
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "R0lling",
    products: [.library(name: "R0lling", targets: ["R0lling"])],
    targets: [
        .target(name: "R0lling"),
        .testTarget(name: "R0llingTests", dependencies: ["R0lling"])
    ]
)
MANIFEST

cat > "$scratch_dir/Sources/R0lling/TestModelsShim.swift" <<'SWIFT'
import Foundation

public enum AIProviderType: Sendable {
    case directAPI
    case hermes
}

public struct JournalEntry: Sendable {
    public let id: UUID
    public var timestamp: Date
    public var content: String
    public var locationName: String?
    public var title: String?
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        title: String? = nil,
        content: String,
        locationName: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
        self.title = title
        self.locationName = locationName
        self.tags = tags
    }

    public var formattedTime: String { ISO8601DateFormatter().string(from: timestamp) }
    public var dateKey: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: timestamp)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

enum HermesEndpointAsfaleia {
    static func epikyroseDirectBaseURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else { throw URLError(.badURL) }
        return url
    }

    static func epikyroseHermesBaseURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else { throw URLError(.badURL) }
        return url
    }

    static func chatCompletionsURL(
        fromBaseURL url: URL,
        errorDomain: String,
        errorCode: Int
    ) throws -> URL {
        url.appendingPathComponent("chat/completions")
    }

    static func chatCompletionsURL(fromBaseURL url: URL) throws -> URL {
        url.appendingPathComponent("chat/completions")
    }

    static func asfales_host_gia_log(_ url: URL) -> String { url.host ?? "unknown" }
}

public enum AIRouter {
    public static func sanitizedContextEntries(
        _ entries: [JournalEntry],
        includeLocation: Bool
    ) -> [JournalEntry] {
        entries.map { entry in
            var result = entry
            if !includeLocation { result.locationName = nil }
            return result
        }
    }

    public static func localRecallSourceSummary(_ entries: [JournalEntry]) -> String {
        entries.prefix(5).map { "\($0.id.uuidString) \($0.dateKey) \($0.title ?? "")" }
            .joined(separator: "\n")
    }
}
SWIFT

swift test --package-path "$scratch_dir"
