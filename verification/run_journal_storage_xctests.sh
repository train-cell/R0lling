#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-journal-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/Sources/R0lling" "$scratch_dir/Tests/R0llingTests"
for source in \
  Core/Models.swift \
  Core/BoundedRegularFileReader.swift \
  Persistence/R0llingFileProtection.swift \
  Persistence/StorageProtocols.swift \
  Persistence/JSONFileStorageService.swift; do
  cp "$repo_root/Sources/R0lling/$source" "$scratch_dir/Sources/R0lling/"
done
cp "$repo_root/Tests/R0llingTests/JournalStorageTests.swift" "$scratch_dir/Tests/R0llingTests/"
cp "$repo_root/Tests/R0llingTests/JournalStorageProtocolCompatibilityTests.swift" "$scratch_dir/Tests/R0llingTests/"

cat > "$scratch_dir/Package.swift" <<'MANIFEST'
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "R0lling",
    platforms: [.macOS(.v14)],
    products: [.library(name: "R0lling", targets: ["R0lling"])],
    targets: [
        .target(name: "R0lling"),
        .testTarget(name: "R0llingTests", dependencies: ["R0lling"])
    ]
)
MANIFEST

cd "$scratch_dir"
swift test
