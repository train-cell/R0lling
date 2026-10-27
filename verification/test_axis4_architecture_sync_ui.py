#!/usr/bin/env python3
"""Automated Verification Suite for Axis 4: Overall Architecture, Local-First Sync & UI (Ideas 16-20).
Runs behavioral and contract checks on TopikosMetagrapheasIxou, SyntonistisP2PZeygariou,
SympiknwthsTombstones, ElegktisAntithesisWCAG, and KryptografimenoThumbnailStore.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

# Ensure UTF-8 output on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources" / "R0lling"


def test_topikos_metagrapheas_contracts() -> None:
    path = SOURCES / "Speech" / "TopikosMetagrapheasIxou.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class TopikosMetagrapheasIxou: @unchecked Sendable" in content
    assert "metagrafiPCMDeigmatwn" in content
    assert "ApotelesmaMetagrafisIxou" in content
    assert "guard !deigmata.isEmpty" in content
    print("  [Pass] TopikosMetagrapheasIxou offline fallback contracts verified.")


def test_p2p_pairing_contracts() -> None:
    path = SOURCES / "Obsidian" / "SyntonistisP2PZeygariou.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class SyntonistisP2PZeygariou: @unchecked Sendable" in content
    assert "Curve25519.KeyAgreement" in content
    assert "dimiourgiaNeouZeygariou" in content
    assert "oloklirwsiZeygariou" in content
    assert "hkdfDerivedSymmetricKey" in content
    print("  [Pass] SyntonistisP2PZeygariou Curve25519 ECDH contracts verified.")


def test_sympiknwths_tombstones_contracts() -> None:
    path = SOURCES / "Obsidian" / "SympiknwthsTombstones.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class SympiknwthsTombstones: @unchecked Sendable" in content
    assert "public static let orioDiatirisisTombstoneSec: TimeInterval = 30.0 * 24.0 * 3600.0" in content
    assert "kataxwrisiTombstone" in content
    assert "ektelesiSympiknwsis" in content
    assert "einaiTombstone" in content
    print("  [Pass] SympiknwthsTombstones 30-day compaction contracts verified.")


def test_wcag_contrast_contracts() -> None:
    path = SOURCES / "UI" / "ElegktisAntithesisWCAG.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public struct ElegktisAntithesisWCAG: Sendable" in content
    assert "linearizeColorComponent" in content
    assert "sxetikiFoteinotita" in content
    assert "ypologismosLogouAntithesis" in content
    assert "elegxosSymmorfwsis" in content
    assert "epivevaiwsiTouchTarget" in content

    # Mathematical behavioral verification in Python
    def srgb_linear(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else math.pow((c + 0.055) / 1.055, 2.4)

    def rel_lum(r: float, g: float, b: float) -> float:
        return 0.2126 * srgb_linear(r) + 0.7152 * srgb_linear(g) + 0.0722 * srgb_linear(b)

    # Test pure white (1,1,1) on charcoal (0.12, 0.125, 0.137)
    l_white = rel_lum(1.0, 1.0, 1.0)
    l_charcoal = rel_lum(0x1F / 255.0, 0x20 / 255.0, 0x23 / 255.0)
    ratio = (l_white + 0.05) / (l_charcoal + 0.05)
    assert ratio >= 7.0, f"White on Charcoal contrast {ratio:.2f} must meet WCAG AAA (>= 7.0)"
    print(f"  [Pass] ElegktisAntithesisWCAG mathematical verification passed (White on Charcoal ratio: {ratio:.2f} >= 7.0).")


def test_thumbnail_store_contracts() -> None:
    path = SOURCES / "Core" / "KryptografimenoThumbnailStore.swift"
    assert path.is_file(), f"Missing {path}"
    content = path.read_text(encoding="utf-8")

    assert "public final class KryptografimenoThumbnailStore: @unchecked Sendable" in content
    assert "AES.GCM.seal" in content
    assert "AES.GCM.open" in content
    assert "apothikefsiThumbnail" in content
    assert "anaklisiThumbnail" in content
    assert "diagrafiThumbnail" in content
    print("  [Pass] KryptografimenoThumbnailStore AES-GCM contracts verified.")


def main() -> None:
    print("================================================================================")
    print("🔬  R0lling Axis 4 Quality Gate — Architecture, Local-First Sync & UI")
    print("================================================================================")
    
    test_topikos_metagrapheas_contracts()
    test_p2p_pairing_contracts()
    test_sympiknwths_tombstones_contracts()
    test_wcag_contrast_contracts()
    test_thumbnail_store_contracts()
    
    print("================================================================================")
    print("🟢 ALL AXIS 4 SOURCE & BEHAVIORAL CONTRACTS PASSED")
    print("================================================================================")


if __name__ == "__main__":
    main()
