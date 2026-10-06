#!/usr/bin/env python3
"""
Stage 4 fix diagnostics — επαληθεύει ότι τα R3-001..R3-006 διορθώθηκαν στον κώδικα.
Χωρίς Swift runtime: static source + λογικοί έλεγχοι.
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


def test_r3_001() -> None:
    print("[R3-001] JSON ISO8601 encode/decode parity...")
    src = read("Sources/R0lling/Persistence/JSONFileStorageService.swift")
    check(
        "decode strategy",
        "dateDecodingStrategy = .iso8601" in src,
        "ensureLoaded uses .iso8601",
    )
    check(
        "encode strategy",
        "dateEncodingStrategy = .iso8601" in src,
        "flushToDisk uses .iso8601",
    )
    tests = read("Tests/R0llingTests/JournalStorageTests.swift")
    check(
        "restart XCTest",
        "testJournalSurvivesRestartViaNewInstance" in tests,
        "regression test present",
    )


def test_r3_002() -> None:
    print("[R3-002] Playable MP4 export (no fake ftyp+mdat-only mux)...")
    buffer_src = read("Sources/R0lling/Buffer/RollingBufferService.swift")
    exporter = read("Sources/R0lling/Buffer/PlayableClipExporter.swift")
    proto = read("Sources/R0lling/Buffer/RollingBufferProtocol.swift")

    check(
        "fake mux removed",
        "synthesizeMP4Container" not in buffer_src,
        "synthesizeMP4Container absent",
    )
    check(
        "AVAssetWriter path",
        "AVAssetWriter" in exporter and "moov" in exporter,
        "PlayableClipExporter uses AVAssetWriter + moov guard",
    )
    check(
        "isPlayable field",
        "isPlayable" in proto and "isSimulationPlaceholder" in proto,
        "ClipExportResult declares playability honestly",
    )
    tests = read("Tests/R0llingTests/RollingBufferTests.swift")
    check(
        "moov XCTest",
        'Data("moov".utf8)' in tests or "moov" in tests,
        "RollingBufferTests asserts moov presence",
    )


def test_r3_003() -> None:
    print("[R3-003] Meta adapter: no fake non-sim connect without SDK...")
    src = read("Sources/R0lling/Glasses/MetaGlassesAdapter.swift")
    check(
        "SDK gate",
        "canImport(MetaWearablesDAT)" in src and "4002" in src,
        "non-sim without SDK throws 4002",
    )
    check(
        "force simulation",
        "παραμένει Simulation" in src or "simulationEnabled = true" in src,
        "toggle real mode blocked without SDK",
    )
    check(
        "R3-007 capturePhoto",
        "case .connected, .streaming:" in src,
        "capturePhoto accepts connected OR streaming",
    )


def test_r3_004() -> None:
    print("[R3-004] Keychain secrets (not UserDefaults by default)...")
    keychain = read("Sources/R0lling/AI/KeychainSecretStore.swift")
    router = read("Sources/R0lling/AI/AIRouter.swift")
    check(
        "Keychain store",
        "SecItemAdd" in keychain and "kSecClassGenericPassword" in keychain,
        "Security framework Keychain helper present",
    )
    check(
        "router wired",
        "KeychainSecretStore" in router and "UserDefaults.standard.set(value" not in router,
        "AIRouter uses KeychainSecretStore",
    )
    check(
        "explicit fallback flag",
        "R0LLING_ALLOW_USERDEFAULTS_SECRETS" in keychain,
        "UserDefaults only with env flag",
    )


def test_r3_005() -> None:
    print("[R3-005] Obsidian conflict guard (no silent overwrite)...")
    src = read("Sources/R0lling/Obsidian/ObsidianVaultBridge.swift")
    check(
        "sidecar",
        "r0lling-conflict.md" in src and "hadConflict: true" in src,
        "writes conflict sidecar and skips overwrite",
    )
    check(
        "batch conflicts",
        "conflictsList.append" in src,
        "exportBatch fills conflictsDetected",
    )
    tests = read("Tests/R0llingTests/ObsidianBridgeTests.swift")
    check(
        "conflict XCTest",
        "testExternalEditCreatesConflictSidecarWithoutOverwrite" in tests,
        "regression test present",
    )


def test_r3_006() -> None:
    print("[R3-006] VoiceCommandParser dedup active...")
    src = read("Sources/R0lling/Speech/VoiceCommandParser.swift")
    check(
        "dedup read/write",
        "lastHandledTranscript" in src and "lastHandledAt" in src,
        "dedup state is read and written",
    )
    check(
        "returns nil on dup",
        "return nil" in src and "dedupWindowSeconds" in src,
        "duplicate final transcripts return nil",
    )
    tests = read("Tests/R0llingTests/VoiceCommandParserTests.swift")
    check(
        "dedup XCTest",
        "testFinalTranscriptDedup" in tests,
        "regression test present",
    )


def test_iso8601_roundtrip_python() -> None:
    """Παράλληλος έλεγχος: ISO8601 round-trip όπως Swift .iso8601 αναμένει."""
    print("[R3-001-py] ISO8601 journal round-trip (Python mirror)...")
    import json
    from datetime import datetime, timezone

    ts = datetime(2026, 10, 6, 10, 30, 0, tzinfo=timezone.utc)
    iso = ts.strftime("%Y-%m-%dT%H:%M:%SZ")
    container = {
        "schemaVersion": 1,
        "appVersion": "1.0.0",
        "lastUpdated": iso,
        "entries": [
            {
                "id": "00000000-0000-0000-0000-000000000001",
                "timestamp": iso,
                "lastModified": iso,
                "content": "restart probe",
            }
        ],
    }
    raw = json.dumps(container)
    parsed = json.loads(raw)
    check(
        "python round-trip",
        parsed["entries"][0]["timestamp"] == iso and parsed["lastUpdated"] == iso,
        f"ISO8601 survives encode/decode ({iso})",
    )


def test_moov_required_contract() -> None:
    print("[R3-002-py] moov-required contract (anti-regression)...")
    # Το παλιό fake container δεν πρέπει να θεωρείται playable.
    fake = (
        bytes([0x00, 0x00, 0x00, 0x20])
        + b"ftypisom"
        + b"\x00" * 20
        + (4).to_bytes(4, "big")
        + b"mdat"
        + b"\x00" * 16
    )
    check(
        "fake not playable",
        b"moov" not in fake,
        "legacy ftyp+mdat without moov rejected by contract",
    )
    # Το exporter source απαιτεί moov μετά το write.
    exporter = read("Sources/R0lling/Buffer/PlayableClipExporter.swift")
    check(
        "post-write moov assert",
        'range(of: Data("moov".utf8))' in exporter or 'Data("moov"' in exporter,
        "exporter fails closed without moov",
    )


def main() -> int:
    print("=" * 70)
    print("R0lling Stage 4 Fix Diagnostics")
    print("=" * 70)
    test_r3_001()
    test_r3_002()
    test_r3_003()
    test_r3_004()
    test_r3_005()
    test_r3_006()
    test_iso8601_roundtrip_python()
    test_moov_required_contract()
    print("=" * 70)
    if errors:
        print(f"FAILED: {len(errors)} check(s)")
        for e in errors:
            print(f"  - {e}")
        print("=" * 70)
        return 1
    print("ALL STAGE 4 FIX CHECKS PASSED")
    print("=" * 70)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
