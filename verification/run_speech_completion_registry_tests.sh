#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-speech-completion-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/Sources/R0lling" "$scratch_dir/Tests/R0llingTests"
cp "$repo_root/Sources/R0lling/AI/SpeechCompletionRegistry.swift" "$scratch_dir/Sources/R0lling/"
cp "$repo_root/Tests/R0llingTests/SpeechCompletionRegistryTests.swift" "$scratch_dir/Tests/R0llingTests/"

cat > "$scratch_dir/Package.swift" <<'MANIFEST'
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "R0lling",
    platforms: [.macOS(.v14)],
    products: [.library(name: "R0lling", targets: ["R0lling"])],
    targets: [
        .target(
            name: "R0lling",
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "R0llingTests",
            dependencies: ["R0lling"],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        )
    ]
)
MANIFEST

swift test --package-path "$scratch_dir"
