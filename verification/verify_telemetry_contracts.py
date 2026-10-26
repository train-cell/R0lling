#!/usr/bin/env python3
"""
TDD Quality Gate & Contract Verification probe gia to Telemetry kai tis 10 Stratigikes Kaintomies.
Elegxei:
1. R0llingTelemetry.swift (10 Katigories, StathmiLog, NSLock, Ring Buffer 250, JSON Export, Zero-PII).
2. TelemetryDashboardView.swift (Filtra, Badges, WCAG 44pt targets, Bevel theme tokens, Export JSON).
3. SettingsView.swift (Enswmatwsi tou Telemetry Dashboard).
4. Subsystems Telemetry Wiring (AIHTTPClient, ObsidianVaultBridge, Speech, Storage, Glasses).
5. Cognitive Engines:
   - SmartActionMacroParser.swift (Idea 5: Voice-to-Action smart macros, tags, priorities, mentions).
   - LocalVisionTagger.swift (Idea 7: On-device scene & OCR tagging).
   - VectorClockConflictResolver.swift (Idea 3: CRDT-lite vector clock sync).
"""

from __future__ import annotations

import sys
import os
import re
from pathlib import Path

# Windows console encoding fix
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

ROOT_DIR = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT_DIR / "Sources" / "R0lling"

def verify_telemetry_core() -> None:
    path = SOURCE_ROOT / "Telemetry" / "R0llingTelemetry.swift"
    if not path.exists():
        raise SystemExit(f"❌ To {path} den vrethike!")
    
    periexomeno = path.read_text(encoding="utf-8")
    
    # 1. Elegxos Katigoriwn (10 katigories)
    apaitoumenes_katigories = [
        "case ui = \"UI\"",
        "case journal = \"Journal\"",
        "case storage = \"Storage\"",
        "case glasses = \"Glasses\"",
        "case media = \"Media\"",
        "case ai = \"AI\"",
        "case obsidian = \"Obsidian\"",
        "case health = \"Health\"",
        "case backup = \"Backup\"",
        "case security = \"Security\""
    ]
    for kat in apaitoumenes_katigories:
        if kat not in periexomeno:
            raise SystemExit(f"❌ Leipei i katigoria telemetry: {kat}")
            
    # 2. Elegxos Stathmwn Log
    apaitoumenes_stathmes = [
        "case debug = \"DEBUG\"",
        "case info = \"INFO\"",
        "case notice = \"NOTICE\"",
        "case warning = \"WARNING\"",
        "case error = \"ERROR\"",
        "case fault = \"FAULT\""
    ]
    for stathmi in apaitoumenes_stathmes:
        if stathmi not in periexomeno:
            raise SystemExit(f"❌ Leipei i stathmi log: {stathmi}")

    # 3. Elegxos Ring Buffer & Thread-Safety
    if "megistoOrioBuffer = 250" not in periexomeno:
        raise SystemExit("❌ To megistoOrioBuffer prepei na einai akrivws 250!")
    if "private let kleidaria = NSLock()" not in periexomeno:
        raise SystemExit("❌ H kleidaria NSLock prepei na prosthikeuei to ring buffer!")

    # 4. Elegxos Methodwn
    apaitoumenes_methodoi = [
        "public func log(",
        "public func xronometrisi<T>(",
        "public func xronometrisiAsync<T>(",
        "public func eksagwgiDiagnwstikwn() -> [TelemetrySimvan]",
        "public func laveFiltraSimvanta(katigoria: Katigoria? = nil, stathmi: StathmiLog? = nil) -> [TelemetrySimvan]",
        "public func paragogiDiagnwstikouJSON() -> Data?",
        "public func katharismosBuffer()"
    ]
    for m in apaitoumenes_methodoi:
        if m not in periexomeno:
            raise SystemExit(f"❌ Leipei i methodos: {m}")
            
    print("✅ R0llingTelemetry core contract verified.")


def verify_telemetry_dashboard_ui() -> None:
    path = SOURCE_ROOT / "UI" / "TelemetryDashboardView.swift"
    if not path.exists():
        raise SystemExit(f"❌ To {path} den yparxei akoma!")
        
    periexomeno = path.read_text(encoding="utf-8")
    
    apaitoumena = [
        "public struct TelemetryDashboardView: View",
        "R0llingTelemetry.shared",
        "paragogiDiagnwstikouJSON",
        "katharismosBuffer",
        "ShareLink",
        ".r0llingFormSurface()",
        ".frame(minHeight: 44",
        "Picker("
    ]
    for item in apaitoumena:
        if item not in periexomeno:
            raise SystemExit(f"❌ Sto TelemetryDashboardView leipei: {item}")
            
    print("✅ TelemetryDashboardView contract verified.")


def verify_settings_integration() -> None:
    path = SOURCE_ROOT / "UI" / "SettingsView.swift"
    periexomeno = path.read_text(encoding="utf-8")
    
    if "TelemetryDashboardView" not in periexomeno:
        raise SystemExit("❌ To TelemetryDashboardView den syndethike sto SettingsView!")
    if "Διαγνωστικά & Τηλεμετρία" not in periexomeno:
        raise SystemExit("❌ Leipei to section 'Διαγνωστικά & Τηλεμετρία' sto SettingsView!")
        
    print("✅ SettingsView integration verified.")


def verify_subsystem_telemetry_wiring() -> None:
    # 1. AIHTTPClient
    ai_client = (SOURCE_ROOT / "AI" / "AIHTTPClient.swift").read_text(encoding="utf-8")
    if "R0llingTelemetry.shared.log(.ai" not in ai_client:
        raise SystemExit("❌ To AIHTTPClient den exei telemetry wiring!")
    if "Bearer" in ai_client and "R0llingTelemetry.shared.log" in ai_client:
        # Sigourevomaste oti den ginetai log to bearer token
        for line in ai_client.splitlines():
            if "R0llingTelemetry.shared.log" in line and ("bearerToken" in line or "Authorization" in line):
                raise SystemExit("❌ SECURITY VIOLATION: To AIHTTPClient kanei log credential token!")

    # 2. ObsidianVaultBridge
    obsidian = (SOURCE_ROOT / "Obsidian" / "ObsidianVaultBridge.swift").read_text(encoding="utf-8")
    if "R0llingTelemetry.shared.log(.obsidian" not in obsidian:
        raise SystemExit("❌ To ObsidianVaultBridge den exei telemetry wiring!")

    # 3. SpeechTranscriptionService
    speech = (SOURCE_ROOT / "Speech" / "SpeechTranscriptionService.swift").read_text(encoding="utf-8")
    if "R0llingTelemetry.shared.log(" not in speech:
        raise SystemExit("❌ To SpeechTranscriptionService den exei telemetry wiring!")

    # 4. Storage & Glasses
    storage = (SOURCE_ROOT / "Persistence" / "JSONFileStorageService.swift").read_text(encoding="utf-8")
    glasses = (SOURCE_ROOT / "Glasses" / "MetaGlassesAdapter.swift").read_text(encoding="utf-8")
    if "R0llingTelemetry.shared.log(.storage" not in storage:
        raise SystemExit("❌ To JSONFileStorageService den exei telemetry wiring!")
    if "R0llingTelemetry.shared.log(.glasses" not in glasses:
        raise SystemExit("❌ To MetaGlassesAdapter den exei telemetry wiring!")

    print("✅ Subsystem telemetry wiring verified.")


def verify_cognitive_innovations() -> None:
    # 1. SmartActionMacroParser (Idea 5)
    macro_path = SOURCE_ROOT / "Speech" / "SmartActionMacroParser.swift"
    if not macro_path.exists():
        raise SystemExit(f"❌ To {macro_path} den yparxei akoma!")
    macro_content = macro_path.read_text(encoding="utf-8")
    for expected in [
        "public struct SmartActionMacroParser",
        "public struct DomiMacroApotelesma",
        "public func epeksergasiaKeimenou(",
        "etiketes",
        "proteraiotita",
        "anafores",
        "energeies"
    ]:
        if expected not in macro_content:
            raise SystemExit(f"❌ Leipei apo to SmartActionMacroParser: {expected}")

    # 2. LocalVisionTagger (Idea 7)
    vision_path = SOURCE_ROOT / "AI" / "LocalVisionTagger.swift"
    if not vision_path.exists():
        raise SystemExit(f"❌ To {vision_path} den yparxei akoma!")
    vision_content = vision_path.read_text(encoding="utf-8")
    for expected in [
        "public struct LocalVisionTagger",
        "public enum EidosSknis: String, Sendable, CaseIterable, Codable",
        "public struct ApotelesmaTagVision: Sendable",
        "public func katigoriopoiisiEikonas(",
        "fysi",
        "eswterikosXoros",
        "apodeiksi",
        "geuma"
    ]:
        if expected not in vision_content:
            raise SystemExit(f"❌ Leipei apo to LocalVisionTagger: {expected}")

    # 3. VectorClockConflictResolver (Idea 3)
    crdt_path = SOURCE_ROOT / "Obsidian" / "VectorClockConflictResolver.swift"
    if not crdt_path.exists():
        raise SystemExit(f"❌ To {crdt_path} den yparxei akoma!")
    crdt_content = crdt_path.read_text(encoding="utf-8")
    for expected in [
        "public struct VectorClockConflictResolver",
        "public struct DianysmatikoRoloϊ: Sendable, Codable, Equatable",
        "enum SxesiXronou",
        "public func sygkrishRologiwn(",
        "proigithike",
        "akolouthise",
        "tautoxrono",
        "panomoiotypo"
    ]:
        if expected not in crdt_content:
            raise SystemExit(f"❌ Leipei apo to VectorClockConflictResolver: {expected}")

    print("✅ Cognitive Innovations (Smart Macros, Vision Tagger, Vector Clock Sync) verified.")


def main() -> None:
    print("=" * 80)
    print("🔍 R0lling Telemetry & Cognitive Innovations Contract Verification")
    print("=" * 80)
    
    verify_telemetry_core()
    verify_telemetry_dashboard_ui()
    verify_settings_integration()
    verify_subsystem_telemetry_wiring()
    verify_cognitive_innovations()
    
    print("\n🟢 ALL TELEMETRY & COGNITIVE QUALITY GATES PASSED (100% SUCCESS)")


if __name__ == "__main__":
    main()
