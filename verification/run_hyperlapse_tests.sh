#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-hyperlapse-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/Sources/CoreLocation" "$scratch_dir/Sources/R0lling" "$scratch_dir/Tests/R0llingTests"
cp "$repo_root/verification/CoreLocationShim.swift" "$scratch_dir/Sources/CoreLocation/"
cp "$repo_root/Sources/R0lling/Experimental/HyperlapseTripCompressor.swift" "$scratch_dir/Sources/R0lling/"
cp "$repo_root/Tests/R0llingTests/HyperlapseTripCompressorTests.swift" "$scratch_dir/Tests/R0llingTests/"

cat > "$scratch_dir/Package.swift" <<'MANIFEST'
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "R0llingHyperlapseTests",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CoreLocation"),
        .target(name: "R0lling", dependencies: ["CoreLocation"]),
        .testTarget(name: "R0llingTests", dependencies: ["CoreLocation", "R0lling"])
    ]
)
MANIFEST

swift test --package-path "$scratch_dir"
