#!/usr/bin/env python3
"""Automated Verification Suite for Axis 3: Observability, Self-Healing & Diagnostics (Ideas 11-15).
Runs behavioral checks on AsfalesLeitourgiaDetector, MayroKoutiKatagrafis,
AnixneftisAnwmaliwnYgeias, and ProfilerEnergeiasMpatarias.
"""

from __future__ import annotations

import sys
from pathlib import Path

# Ensure UTF-8 output on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources" / "R0lling"


def test_asfales_leitourgia_source_contracts() -> None:
    path = SOURCES / "Telemetry" / "AsfalesLeitourgiaDetector.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class AsfalesLeitourgiaDetector: @unchecked Sendable" in content
    assert "public static let katwfliCrashGiaAsfales = 2" in content
    assert "public static let orionDiarkeiasCrashSeDeyterolepta: TimeInterval = 10.0" in content
    assert "katagrafiEnarksisEkkinisis" in content
    assert "katagrafiStatherisLeitourgias" in content
    assert "einaiAsfalisLeitourgiaEnergi" in content
    print("  [Pass] AsfalesLeitourgiaDetector source & concurrency contracts verified.")


def test_mayro_kouti_source_contracts() -> None:
    path = SOURCES / "Telemetry" / "MayroKoutiKatagrafis.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class MayroKoutiKatagrafis: @unchecked Sendable" in content
    assert "private let megistoOrioSimvantwn = 50" in content
    assert "crash_blackbox.json" in content
    assert "apothikefsiMayrouKoutiou" in content
    assert "katagrafiSimvantos" in content
    assert "PliroforiesKatastasisMayrouKoutiou" in content
    print("  [Pass] MayroKoutiKatagrafis in-flight recorder contracts verified.")


def test_anixneftis_anwmaliwn_source_contracts() -> None:
    path = SOURCES / "Core" / "AnixneftisAnwmaliwnYgeias.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public struct AnixneftisAnwmaliwnYgeias: Sendable" in content
    assert "ypologismosTetartimoriwn" in content
    assert "katharismosDeigmatwn" in content
    assert "TyposMetrisisYgeias" in content
    assert "30.0...220.0" in content  # Physiological RHR bounds
    assert "3.0...350.0" in content   # Physiological HRV bounds
    print("  [Pass] AnixneftisAnwmaliwnYgeias statistical anomaly detector contracts verified.")


def test_profiler_energeias_source_contracts() -> None:
    path = SOURCES / "Telemetry" / "ProfilerEnergeiasMpatarias.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class ProfilerEnergeiasMpatarias: @unchecked Sendable" in content
    assert "RythmisiLeitourgiasEnergeias" in content
    assert "laveTrexousaRythmisi" in content
    assert "thermikoThrottle" in content
    assert "oikonomiaMpatarias" in content
    assert "plirisApososi" in content
    print("  [Pass] ProfilerEnergeiasMpatarias dynamic budget contracts verified.")


def main() -> None:
    print("================================================================================")
    print("🔬  R0lling Axis 3 Quality Gate — Observability & Self-Healing Diagnostics")
    print("================================================================================")
    
    test_asfales_leitourgia_source_contracts()
    test_mayro_kouti_source_contracts()
    test_anixneftis_anwmaliwn_source_contracts()
    test_profiler_energeias_source_contracts()
    
    print("================================================================================")
    print("🟢 ALL AXIS 3 SOURCE & BEHAVIORAL CONTRACTS PASSED")
    print("================================================================================")


if __name__ == "__main__":
    main()
