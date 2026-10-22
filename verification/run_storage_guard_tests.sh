#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-storage-guard-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/Sources/R0lling" "$scratch_dir/Tests/R0llingTests"
for source in \
  Sources/R0lling/Core/BoundedRegularFileReader.swift \
  Sources/R0lling/Core/FeatureReadinessRegistry.swift \
  Sources/R0lling/Core/JournalSearchRequestGate.swift \
  Sources/R0lling/Persistence/MediaReferenceMutationGate.swift; do
  cp "$repo_root/$source" "$scratch_dir/Sources/R0lling/"
done

for test in \
  BoundedRegularFileReaderTests.swift \
  FeatureReadinessTests.swift \
  JournalSearchRequestGateTests.swift \
  MediaReferenceMutationGateTests.swift; do
  cp "$repo_root/Tests/R0llingTests/$test" "$scratch_dir/Tests/R0llingTests/"
done

cat > "$scratch_dir/Package.swift" <<'MANIFEST'
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "R0llingStorageGuardTests",
    platforms: [.macOS(.v14)],
    products: [.library(name: "R0lling", targets: ["R0lling"])],
    targets: [
        .target(name: "R0lling"),
        .testTarget(name: "R0llingTests", dependencies: ["R0lling"])
    ]
)
MANIFEST

swift test --package-path "$scratch_dir"
