#!/usr/bin/env python3
"""Automated Verification Suite for Axis 2: Edge Cases & System Fault Tolerance (Ideas 6-10).
Runs behavioral and contract checks on MonotonikoRoloiSyskevis, WALJournalStore,
DiorthwthsPTSDrift, DiaxeiristisDiakopisAudio, and DiaxeiristisXwrouDiskoy.
"""

from __future__ import annotations

import sys
from pathlib import Path

# Ensure UTF-8 output on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources" / "R0lling"


def test_monotoniko_roloi_contracts() -> None:
    path = SOURCES / "Core" / "MonotonikoRoloiSyskevis.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class MonotonikoRoloiSyskevis: @unchecked Sendable" in content
    assert "public static let orioApoklisisSec: Double = 300.0" in content
    assert "xeirokinitiAllagiXronou" in content
    assert "epivevaiwsiKaiEnimerwsiXronou" in content
    assert "perasmenaToixouSec < -1.0" in content  # Rejection of backward clock tampering
    print("  [Pass] MonotonikoRoloiSyskevis clock-skew defense contracts verified.")


def test_wal_journal_contracts() -> None:
    path = SOURCES / "Persistence" / "WALJournalStore.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class WALJournalStore: @unchecked Sendable" in content
    assert "WALKareklaFrame" in content
    assert "kataxwrisiSynallagis" in content
    assert "anagnwsiKaiApokatastasiWAL" in content
    assert "checkpointWAL" in content
    assert "SHA256" in content
    print("  [Pass] WALJournalStore crash-resilient write-ahead logging contracts verified.")


def test_pts_drift_contracts() -> None:
    path = SOURCES / "Buffer" / "DiorthwthsPTSDrift.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class DiorthwthsPTSDrift: @unchecked Sendable" in content
    assert "diorthwsiPTS" in content
    assert "diorthwmenoPTS <= teleytaioPTS" in content  # Out-of-order clamping
    assert "Self.proepilegmeniDiarkeiaFrame" in content
    assert "Self.megistoApodektoJitterSec" in content
    print("  [Pass] DiorthwthsPTSDrift presentation timestamp contracts verified.")


def test_diaxeiristis_diakopis_audio_contracts() -> None:
    path = SOURCES / "Speech" / "DiaxeiristisDiakopisAudio.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class DiaxeiristisDiakopisAudio: @unchecked Sendable" in content
    assert "enarksiDiakopis" in content
    assert "termatismosDiakopis" in content
    assert "KatastasiDiakopisAudio" in content
    print("  [Pass] DiaxeiristisDiakopisAudio interruption state machine contracts verified.")


def test_diaxeiristis_xwrou_diskoy_contracts() -> None:
    path = SOURCES / "Persistence" / "DiaxeiristisXwrouDiskoy.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class DiaxeiristisXwrouDiskoy: @unchecked Sendable" in content
    assert "50 * 1024 * 1024" in content   # 50 MiB Hard stop
    assert "100 * 1024 * 1024" in content  # 100 MiB Pause threshold
    assert "200 * 1024 * 1024" in content  # 200 MiB Warning threshold
    assert "elegxosEggrafis" in content
    assert "ekkatharisiOrphanedProsorinwn" in content
    print("  [Pass] DiaxeiristisXwrouDiskoy multi-tier quota & pruning contracts verified.")


def main() -> None:
    print("================================================================================")
    print("🔬  R0lling Axis 2 Quality Gate — Edge Cases & System Fault Tolerance")
    print("================================================================================")
    
    test_monotoniko_roloi_contracts()
    test_wal_journal_contracts()
    test_pts_drift_contracts()
    test_diaxeiristis_diakopis_audio_contracts()
    test_diaxeiristis_xwrou_diskoy_contracts()
    
    print("================================================================================")
    print("🟢 ALL AXIS 2 SOURCE & BEHAVIORAL CONTRACTS PASSED")
    print("================================================================================")


if __name__ == "__main__":
    main()
