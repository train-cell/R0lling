#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-obsidian-bridge-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/Sources/R0lling" "$scratch_dir/Tests/R0llingTests"
for source in \
  Sources/R0lling/Core/Models.swift \
  Sources/R0lling/Core/BoundedRegularFileReader.swift \
  Sources/R0lling/Core/AppErrorTaxonomy.swift \
  Sources/R0lling/AI/AIErrorTaxonomy.swift \
  Sources/R0lling/Persistence/StorageProtocols.swift \
  Sources/R0lling/Persistence/R0llingFileProtection.swift \
  Sources/R0lling/Persistence/MediaStorageService.swift \
  Sources/R0lling/Obsidian/AgentFolderManager.swift \
  Sources/R0lling/Obsidian/ObsidianCanvasGenerator.swift \
  Sources/R0lling/Obsidian/ObsidianVaultBridge.swift \
  Sources/R0lling/Obsidian/VaultDirectoryFileAccess.swift; do
  cp "$repo_root/$source" "$scratch_dir/Sources/R0lling/"
done

python3 - "$repo_root" "$scratch_dir/Sources/R0lling" <<'PY'
from pathlib import Path
import sys

repo = Path(sys.argv[1])
destination = Path(sys.argv[2])

def declaration(source: Path, marker: str) -> str:
    text = source.read_text(encoding="utf-8")
    start = text.index(marker)
    opening = text.index("{", start)
    depth = 0
    for index in range(opening, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[start:index + 1]
    raise RuntimeError(f"Unclosed production declaration: {marker}")

extension_source = repo / "Sources/R0lling/Core/Extensions.swift"
date_extensions = declaration(extension_source, "extension Date {")
path_guard = declaration(extension_source, "public enum PathAsfaleia {")
if sys.platform == "linux":
    # Linux Foundation rejects a canonical URL when only its leaf/parent is
    # missing; Apple Foundation accepts it. Resolve the longest existing prefix
    # to preserve the production helper's intended nonexistent-target behavior.
    path_guard = path_guard.replace(
        ".resolvingSymlinksInPath()",
        ".r0llingResolvingSymlinksInPath()",
    )
(destination / "ProductionPathGuard.swift").write_text(
    "import Foundation\n\n" + date_extensions + "\n\n" + path_guard + "\n", encoding="utf-8"
)

media_importer = (repo / "Sources/R0lling/Persistence/JournalMediaImporter.swift").read_text(encoding="utf-8")
start = media_importer.index("/// Ελάχιστος ελεύθερος χώρος")
end = media_importer.index("/// Καθαρή ταξινόμηση αρχείων", start)
(destination / "ProductionMediaErrors.swift").write_text(
    "import Foundation\n\n" + media_importer[start:end], encoding="utf-8"
)
PY

cat > "$scratch_dir/Sources/R0lling/LinuxPlatformShims.swift" <<'SWIFT'
import Foundation

extension URL {
    func startAccessingSecurityScopedResource() -> Bool { false }
    func stopAccessingSecurityScopedResource() {}

    func r0llingResolvingSymlinksInPath() -> URL {
        var missingComponents: [String] = []
        var existingPrefix = standardizedFileURL
        while !FileManager.default.fileExists(atPath: existingPrefix.path) {
            let component = existingPrefix.lastPathComponent
            guard !component.isEmpty, component != "/" else { return standardizedFileURL }
            missingComponents.append(component)
            existingPrefix.deleteLastPathComponent()
        }
        var resolved = existingPrefix.resolvingSymlinksInPath().standardizedFileURL
        for component in missingComponents.reversed() {
            resolved.appendPathComponent(component)
        }
        return resolved.standardizedFileURL
    }
}

extension URLResourceKey {
    static let volumeAvailableCapacityForImportantUsageKey = URLResourceKey("volumeAvailableCapacityForImportantUsage")
}

extension URLResourceValues {
    var volumeAvailableCapacityForImportantUsage: Int64? { 1_000_000_000 }
}

extension Data {
    // The bridge suite checks stable hash persistence/conflict flows; cryptographic
    // SHA-256 correctness is outside this filesystem harness.
    var sha256Hash: String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in self {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return String(format: "%016llx%016llx%016llx%016llx", hash, hash ^ 0x9E3779B97F4A7C15, hash &* 0x100000001B3, hash ^ (hash >> 17))
    }
}

extension String {
    var sha256Hash: String { Data(utf8).sha256Hash }
}

final class NSFileCoordinator {
    struct WritingOptions: OptionSet {
        let rawValue: Int
        static let forReplacing = WritingOptions(rawValue: 1)
    }

    init(filePresenter: AnyObject?) {}

    func coordinate(
        writingItemAt url: URL,
        options: WritingOptions,
        error: inout NSError?,
        byAccessor accessor: (URL) -> Void
    ) {
        accessor(url)
    }
}

enum VaultBookmarkStore {
    static func epanekkinisi_proepilegmenou() {}
    static func display_path_i_default() -> String { "Documents/R0lling/ObsidianVault" }
    static func fortosi_vault_url() throws -> (url: URL, requiresScopedAccess: Bool)? { nil }
}
SWIFT

cp "$repo_root/Tests/R0llingTests/ObsidianBridgeTests.swift" "$scratch_dir/Tests/R0llingTests/"
cp "$repo_root/Tests/R0llingTests/VaultDirectoryFileAccessTests.swift" "$scratch_dir/Tests/R0llingTests/"

cat > "$scratch_dir/Package.swift" <<'MANIFEST'
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "R0llingObsidianBridgeTests",
    products: [.library(name: "R0lling", targets: ["R0lling"])],
    targets: [
        .target(name: "R0lling"),
        .testTarget(name: "R0llingTests", dependencies: ["R0lling"])
    ]
)
MANIFEST

swift test --package-path "$scratch_dir"
