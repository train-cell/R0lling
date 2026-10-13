#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-obsidian-watcher-tests.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/Sources/R0lling" "$scratch_dir/Tests/R0llingTests"
cp "$repo_root/Sources/R0lling/Experimental/ObsidianFileWatcher.swift" "$scratch_dir/Sources/R0lling/"
cp "$repo_root/Sources/R0lling/Obsidian/VaultDirectoryFileAccess.swift" "$scratch_dir/Sources/R0lling/"
cp "$repo_root/Tests/R0llingTests/ObsidianFileWatcherTests.swift" "$scratch_dir/Tests/R0llingTests/"

cat > "$scratch_dir/Sources/R0lling/WatcherHarnessSupport.swift" <<'SUPPORT'
import Foundation

// The watcher harness does not exercise atomic content replacement or SHA-256 matching.
extension Data {
    var sha256Hash: String { "watcher-harness-unverified" }
}
SUPPORT

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

swift test --package-path "$scratch_dir"
