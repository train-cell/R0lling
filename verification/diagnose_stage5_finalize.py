#!/usr/bin/env python3
"""
Stage 5 finalize diagnostics — R3-009 timezone day filter + R3-012 empty API key guard.
Επίσης smoke-checks ότι Stage-4 fixes δεν ξεγράφηκαν και ότι Gemini super-features υπάρχουν.
Χωρίς Swift runtime: static source checks.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
PASS = "[OK] PASS"
FAIL = "[ERR] FAIL"
errors: list[str] = []


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def check(name: str, condition: bool, detail: str) -> None:
    if condition:
        print(f"    {PASS}: {name} — {detail}")
    else:
        print(f"    {FAIL}: {name} — {detail}")
        errors.append(f"{name}: {detail}")


def test_r3_009() -> None:
    print("[R3-009] Timezone-aware day filter...")
    models = read("Sources/R0lling/Core/Models.swift")
    storage = read("Sources/R0lling/Persistence/JSONFileStorageService.swift")
    tests = read("Tests/R0llingTests/JournalStorageTests.swift")

    check(
        "makeDateKey helper",
        "makeDateKey(for" in models and 'en_US_POSIX' in models,
        "JournalEntry.makeDateKey + POSIX locale",
    )
    check(
        "getEntriesForDate displayTimeZone",
        "displayTimeZone" in storage and "makeDateKey" in storage,
        "storage day filter uses makeDateKey + displayTimeZone",
    )
    check(
        "no bare DateFormatter day key",
        not re.search(
            r'func getEntriesForDate[\s\S]*?formatter\.dateFormat = "yyyy-MM-dd"\s*\n\s*let targetKey',
            storage,
        ),
        "removed silent device-local formatter path",
    )
    check(
        "XCTest coverage",
        "testGetEntriesForDateRespectsEntryTimeZoneDateKey" in tests,
        "timezone day filter test present",
    )


def test_r3_012() -> None:
    print("[R3-012] Empty API key / Hermes token guard...")
    direct = read("Sources/R0lling/AI/DirectAPIConnector.swift")
    hermes = read("Sources/R0lling/AI/HermesConnector.swift")

    check(
        "Direct empty key guard",
        "7004" in direct and "trimmingCharacters" in direct and "Λείπει Direct API key" in direct,
        "typed error before network",
    )
    check(
        "Direct always sets Bearer after guard",
        'Bearer \\(trimmedKey)' in direct or "Bearer \\(trimmedKey)" in direct,
        "Authorization uses trimmed key",
    )
    check(
        "Hermes empty token guard",
        "7104" in hermes and "Λείπει Hermes auth token" in hermes,
        "typed error before network",
    )
    check(
        "cancellation checks",
        "Task.checkCancellation" in direct and "Task.checkCancellation" in hermes,
        "Task.checkCancellation before request",
    )
    check(
        "no silent skip Authorization",
        "if !apiKey.isEmpty" not in direct and "if !authToken.isEmpty" not in hermes,
        "removed optional Authorization skip",
    )


def test_stage4_not_regressed() -> None:
    print("[Stage-4] Regression guards still present...")
    storage = read("Sources/R0lling/Persistence/JSONFileStorageService.swift")
    meta = read("Sources/R0lling/Glasses/MetaGlassesAdapter.swift")
    keychain = read("Sources/R0lling/AI/KeychainSecretStore.swift")
    buffer = read("Sources/R0lling/Buffer/RollingBufferService.swift")
    voice = read("Sources/R0lling/Speech/VoiceCommandParser.swift")
    obsidian = read("Sources/R0lling/Obsidian/ObsidianVaultBridge.swift")

    check("R3-001 iso8601 decode", "dateDecodingStrategy = .iso8601" in storage, "decode parity")
    check("R3-002 no fake mux", "synthesizeMP4Container" not in buffer, "fake mux removed")
    check("R3-003 error 4002", "4002" in meta and "simulationEnabled" in meta, "sim/real gate")
    check("R3-004 Keychain store", "SecItemAdd" in keychain or "kSecClass" in keychain, "Keychain API")
    check("R3-005 conflict sidecar", "r0lling-conflict" in obsidian, "conflict sidecar")
    check("R3-006 voice dedup", "lastHandledTranscript" in voice, "dedup window")


def test_g5_001_highlight_no_byte_concat() -> None:
    print("[G5-001] HighlightReelMuxer must not byte-concat MP4...")
    src = read("Sources/R0lling/Buffer/HighlightReelMuxer.swift")
    check(
        "no Data.append concat",
        "combinedData.append" not in src and "AVMutableComposition" in src,
        "uses AVMutableComposition instead of byte concat",
    )
    check(
        "export session",
        "AVAssetExportSession" in src,
        "exports via AVAssetExportSession",
    )
    check(
        "moov guard",
        "moov" in src and "3105" in src,
        "fail-closed without moov",
    )


def test_gemini_super_features_present() -> None:
    print("[Gemini] Super-feature modules present (scaffolding OK)...")
    required = [
        "Sources/R0lling/Speech/AcousticTriggerService.swift",
        "Sources/R0lling/Core/TimeCapsuleEngine.swift",
        "Sources/R0lling/Core/EarconFeedbackService.swift",
        "Sources/R0lling/Glasses/HeadGestureDetector.swift",
        "Sources/R0lling/App/WatchConnectivityCoordinator.swift",
    ]
    for rel in required:
        path = ROOT / rel
        check(rel, path.is_file() and path.stat().st_size > 100, f"exists ({path.stat().st_size if path.is_file() else 0} bytes)")

    app = read("Sources/R0lling/App/AppState.swift")
    check(
        "AppState wires AcousticTrigger",
        "AcousticTriggerService" in app and "onSpikeDetected" in app,
        "hook wired",
    )
    check(
        "AppState wires TimeCapsule",
        "TimeCapsuleEngine" in app and "timeCapsuleMemories" in app,
        "hook wired",
    )
    check(
        "AppState keeps R3-008 byteSize",
        "isSimulationPlaceholder" in app and "byteSize" in app,
        "Stage-4 clip honesty retained",
    )

    capsule = read("Sources/R0lling/Core/TimeCapsuleEngine.swift")
    check(
        "TimeCapsule uses entry TZ",
        "timeZoneIdentifier" in capsule and "displayTimeZone" in capsule,
        "TZ-aware capsule day match",
    )


def main() -> int:
    print("=== R0lling Stage 5 Finalize Diagnostics ===")
    print(f"ROOT: {ROOT}")
    test_r3_009()
    test_r3_012()
    test_g5_001_highlight_no_byte_concat()
    test_stage4_not_regressed()
    test_gemini_super_features_present()
    print()
    if errors:
        print(f"FAILED ({len(errors)}):")
        for err in errors:
            print(f"  - {err}")
        return 1
    print("ALL STAGE 5 FINALIZE CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
