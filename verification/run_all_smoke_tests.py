#!/usr/bin/env python3
"""
Enoποιημένος Master Smoke Test Runner gia to R0lling.
Ektelesi olwn twn apaitoumenwn production quality gates:
1. verify_exchange_schema.py (Exchange Schema v1 & Invariants)
2. verify_ui_source_contracts.py (Swift UI Contracts, Bevel Tokens & Touch Targets)
3. diagnose_journal_media_a01_a03.py (Journal & Media Storage Contracts)
4. diagnose_stage5_finalize.py (Stage-5 Finalize, Hardware DAT & Security Gates)

Paragei analytical scoreboard me xronous ektelesis kai exit codes.
Fail-closed: Ean opoiodipote test apotyxei, o runner termatizei me Exit Code 1.
"""

from __future__ import annotations

import sys
import os
import time
import subprocess
from pathlib import Path
from typing import List, Dict, Any, Tuple

# Windows console encoding fix
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

ROOT_DIR = Path(__file__).resolve().parents[1]
VERIFICATION_DIR = ROOT_DIR / "verification"


class ApotelesmaDokimis:
    """Metathesi apotelesmatos mias dokimis smoke test."""
    def __init__(self, onoma: str, perigrafi: str, arxeio: str, diarkeia_sec: float, exit_code: int, eksodos: str) -> None:
        self.onoma = onoma
        self.perigrafi = perigrafi
        self.arxeio = arxeio
        self.diarkeia_sec = diarkeia_sec
        self.exit_code = exit_code
        self.eksodos = eksodos
        self.einai_epituxis = (exit_code == 0)


class MasterSmokeRunner:
    """Enoποιημενος orchestrator olwn twn smoke tests tou R0lling."""

    def __init__(self) -> None:
        self.lista_dokimon: List[Dict[str, str]] = [
            {
                "onoma": "Exchange Schema Invariants",
                "perigrafi": "Epalithefsi JSON Schema v1, ISO8601 UTC whole seconds, Uppercase UUIDs kai negative regressions",
                "arxeio": "verify_exchange_schema.py"
            },
            {
                "onoma": "Swift UI Source Contracts",
                "perigrafi": "Epalithefsi 107+ Swift files, Bevel tokens, 44pt WCAG AAA touch targets, QuickAction parity",
                "arxeio": "verify_ui_source_contracts.py"
            },
            {
                "onoma": "Journal & Media Storage (A01-A03)",
                "perigrafi": "Epalithefsi ISO8601 storage round-trip, TZ day filter, PathAsfaleia kai PhotosPicker allowlist",
                "arxeio": "diagnose_journal_media_a01_a03.py"
            },
            {
                "onoma": "Stage 5 Finalize & Hardware Security",
                "perigrafi": "Epalithefsi Meta DAT fail-closed gates (4002/4010), PTS monotonicity, MP4 container integrity",
                "arxeio": "diagnose_stage5_finalize.py"
            }
        ]

    def ektelesi_mias_dokimis(self, dokimi: Dict[str, str]) -> ApotelesmaDokimis:
        diadromi = VERIFICATION_DIR / dokimi["arxeio"]
        if not diadromi.exists():
            return ApotelesmaDokimis(
                onoma=dokimi["onoma"],
                perigrafi=dokimi["perigrafi"],
                arxeio=dokimi["arxeio"],
                diarkeia_sec=0.0,
                exit_code=1,
                eksodos=f"Το αρχείο {diadromi} δεν βρέθηκε."
            )

        ksekinima = time.perf_counter()
        process = subprocess.run(
            [sys.executable, str(diadromi)],
            cwd=str(ROOT_DIR),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace"
        )
        diarkeia = time.perf_counter() - ksekinima

        return ApotelesmaDokimis(
            onoma=dokimi["onoma"],
            perigrafi=dokimi["perigrafi"],
            arxeio=dokimi["arxeio"],
            diarkeia_sec=diarkeia,
            exit_code=process.returncode,
            eksodos=process.stdout
        )

    def ektelesi_olon(self) -> Tuple[bool, List[ApotelesmaDokimis]]:
        print("================================================================================")
        print("🏛️  R0lling Master Smoke Test Runner — Zero-Trust Quality Gate")
        print(f"Directory: {ROOT_DIR}")
        print("================================================================================\n")

        apotelesmata: List[ApotelesmaDokimis] = []
        synoliki_epituxia = True

        for index, dokimi in enumerate(self.lista_dokimon, start=1):
            print(f"[{index}/{len(self.lista_dokimon)}] Εκτέλεση: {dokimi['onoma']} ({dokimi['arxeio']})...")
            res = self.ektelesi_mias_dokimis(dokimi)
            apotelesmata.append(res)

            katastasi = "✅ PASS" if res.einai_epituxis else "❌ FAIL"
            print(f"    Status: {katastasi} | Διάρκεια: {res.diarkeia_sec:.2f}s | Exit Code: {res.exit_code}")
            if not res.einai_epituxis:
                synoliki_epituxia = False
                print("    --- Σφάλμα Εξόδου ---")
                lines = res.eksodos.strip().splitlines()
                for line in lines[-15:]:
                    print(f"    | {line}")
                print("    ---------------------")

        print("\n================================================================================")
        print("📊 ΣΥΓΚΕΝΤΡΩΤΙΚΟΣ ΠΙΝΑΚΑΣ SMOKE TESTS (SCOREBOARD)")
        print("================================================================================")
        print(f"{'Όνομα Gate':<38} | {'Αρχείο':<32} | {'Χρόνος':<8} | {'Status'}")
        print("-" * 90)

        for res in apotelesmata:
            status_str = "🟢 PASS" if res.einai_epituxis else "🔴 FAIL"
            print(f"{res.onoma:<38} | {res.arxeio:<32} | {res.diarkeia_sec:>6.2f}s | {status_str}")

        print("=" * 90)
        synolikos_xronos = sum(r.diarkeia_sec for r in apotelesmata)
        print(f"Συνολικός Χρόνος: {synolikos_xronos:.2f}s | Αποτέλεσμα: {'🟢 ALL TESTS PASSED' if synoliki_epituxia else '🔴 QUALITY GATE FAILED'}\n")

        return synoliki_epituxia, apotelesmata


def main() -> int:
    runner = MasterSmokeRunner()
    epituxia, _ = runner.ektelesi_olon()
    return 0 if epituxia else 1


if __name__ == "__main__":
    sys.exit(main())
