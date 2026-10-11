#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/r0lling-watermark-probe.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT

swiftc \
  "$repo_root/Sources/R0lling/Experimental/ClipWatermarkExporter.swift" \
  "$repo_root/verification/clip_watermark_contract_probe.swift" \
  -o "$build_dir/clip-watermark-contract-probe"
"$build_dir/clip-watermark-contract-probe"
