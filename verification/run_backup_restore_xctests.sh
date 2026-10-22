#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-backup-restore-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/Sources/R0lling" "$scratch_dir/Tests/R0llingTests"
for source in \
  Sources/R0lling/Core/Models.swift \
  Sources/R0lling/Core/BoundedRegularFileReader.swift \
  Sources/R0lling/Core/AppErrorTaxonomy.swift \
  Sources/R0lling/AI/AIErrorTaxonomy.swift \
  Sources/R0lling/Persistence/StorageProtocols.swift \
  Sources/R0lling/Persistence/R0llingFileProtection.swift \
  Sources/R0lling/Persistence/JSONFileStorageService.swift \
  Sources/R0lling/Persistence/MediaStorageService.swift \
  Sources/R0lling/Persistence/MediaReferenceMutationGate.swift \
  Sources/R0lling/Persistence/BackupRestoreEngine.swift \
  Sources/R0lling/Obsidian/AgentFolderManager.swift; do
  cp "$repo_root/$source" "$scratch_dir/Sources/R0lling/"
done

# Extract the production path guard and error declarations without importing their
# unrelated CryptoKit / UniformTypeIdentifiers dependencies into the Linux harness.
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
path_guard = declaration(extension_source, "public enum PathAsfaleia {")
date_extensions = declaration(extension_source, "extension Date {")
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
}

extension URLResourceKey {
    static let volumeAvailableCapacityForImportantUsageKey = URLResourceKey("volumeAvailableCapacityForImportantUsage")
}

extension URLResourceValues {
    var volumeAvailableCapacityForImportantUsage: Int64? { 1_000_000_000 }
}
SWIFT

cp "$repo_root/Tests/R0llingTests/BackupRestoreTests.swift" "$scratch_dir/Tests/R0llingTests/"

cat > "$scratch_dir/Package.swift" <<'MANIFEST'
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "R0llingBackupRestoreTests",
    platforms: [.macOS(.v14)],
    products: [.library(name: "R0lling", targets: ["R0lling"])],
    targets: [
        .target(name: "R0lling"),
        .testTarget(name: "R0llingTests", dependencies: ["R0lling"])
    ]
)
MANIFEST

swift test --package-path "$scratch_dir"
