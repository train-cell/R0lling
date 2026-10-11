#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_dir="${TMPDIR:-/tmp}/r0lling-vision-probe-$$"
mkdir -p "$scratch_dir"
trap 'rm -rf "$scratch_dir"' EXIT

swiftc -emit-module -emit-library -module-name Vision \
  "$repo_root/verification/vision_shim/Vision.swift" \
  -emit-module-path "$scratch_dir/Vision.swiftmodule" \
  -o "$scratch_dir/libVision.so"

swiftc -strict-concurrency=complete -I "$scratch_dir" -L "$scratch_dir" -lVision \
  "$repo_root/Sources/R0lling/AI/OnDeviceVisionService.swift" \
  "$repo_root/verification/on_device_vision_continuation_probe.swift" \
  -o "$scratch_dir/vision-probe"

for behavior in throw-before-callback callback-then-throw normal; do
  LD_LIBRARY_PATH="$scratch_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    timeout 5 "$scratch_dir/vision-probe" "$behavior"
done
