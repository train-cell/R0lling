#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-ai-router-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/Sources/R0lling" "$scratch_dir/Tests/R0llingTests" "$scratch_dir/ModuleShim"
for source in \
  Sources/R0lling/Core/Models.swift \
  Sources/R0lling/AI/AIConnectorProtocol.swift \
  Sources/R0lling/AI/AIHTTPClient.swift \
  Sources/R0lling/AI/AIErrorTaxonomy.swift \
  Sources/R0lling/AI/OutboundPIIRedactor.swift \
  Sources/R0lling/AI/OpenAIChatRequestBuilder.swift \
  Sources/R0lling/AI/AIRouter.swift; do
  cp "$repo_root/$source" "$scratch_dir/Sources/R0lling/"
done
cp "$repo_root/Tests/R0llingTests/AIRouterCancellationTests.swift" "$scratch_dir/Tests/R0llingTests/"

cat > "$scratch_dir/ModuleShim/ImageIO.swift" <<'SWIFT'
public enum ImageIOHarnessModule {}
SWIFT
swiftc -emit-module -module-name ImageIO \
  "$scratch_dir/ModuleShim/ImageIO.swift" \
  -emit-module-path "$scratch_dir/ModuleShim/ImageIO.swiftmodule"

cat > "$scratch_dir/Sources/R0lling/TestRuntimeShims.swift" <<'SWIFT'
import Foundation

struct DirectAPIConnector: AIConnectorProtocol, Sendable {
    let providerType: AIProviderType = .directAPI
    init(baseURLString: String, modelName: String, apiKey: String) {}
    func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult { AIResponseResult(reply: "stub") }
    func describeImage(imageData: Data, question: String?) async throws -> String { "" }
    func summarizeDay(entries: [JournalEntry]) async throws -> String { "" }
}

struct HermesConnector: AIConnectorProtocol, Sendable {
    let providerType: AIProviderType = .hermes
    init(baseURLString: String, authToken: String) {}
    func generateReply(payload: AIRequestPayload) async throws -> AIResponseResult { AIResponseResult(reply: "stub") }
    func describeImage(imageData: Data, question: String?) async throws -> String { "" }
    func summarizeDay(entries: [JournalEntry]) async throws -> String { "" }
}

enum KeychainSecretStore {
    static func retrieve(forKey key: String) -> String? { nil }
    static func store(value: String, forKey key: String) throws {}
    static func deleteChecked(forKey key: String) throws {}
}

enum ImageMetadataSanitizer {
    static func encodeForVision(_ data: Data) throws -> Data { data }
}

enum HermesEndpointAsfaleia {
    static func epikyroseHermesBaseURL(_ raw: String) throws -> URL {
        guard let url = URL(string: raw) else { throw URLError(.badURL) }
        return url
    }

    static func epikyroseDirectBaseURL(_ raw: String) throws -> URL {
        guard let url = URL(string: raw) else { throw URLError(.badURL) }
        return url
    }
}
SWIFT

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

swift test --package-path "$scratch_dir" -Xswiftc -I -Xswiftc "$scratch_dir/ModuleShim"
