#!/usr/bin/env python3
"""
TDD Quality Gate & Contract Verification probe gia to Telemetry kai OLES TIS 10 Stratigikes Kainotomies.
Elegxei:
1. R0llingTelemetry.swift (10 Katigories, StathmiLog, NSLock, Ring Buffer 250, JSON Export, Zero-PII).
2. TelemetryDashboardView.swift (Filtra, Badges, WCAG 44pt targets, Bevel theme tokens, Export JSON).
3. SettingsView.swift (Enswmatwsi tou Telemetry Dashboard).
4. Subsystems Telemetry Wiring (AIHTTPClient, ObsidianVaultBridge, Speech, Storage, Glasses).
5. OLES TIS 10 KAINOTOMIES (All 10 Strategic Innovations):
   - Idea 1: SemanticSearchIndex.swift (On-Device Semantic Search CoreML)
   - Idea 2: HardwareVaultStore.swift (SQLCipher / Secure Enclave Hardware Vault)
   - Idea 3: VectorClockConflictResolver.swift (CRDT-lite Vector Clock sync)
   - Idea 4: LiveActivityStreamingCoordinator.swift (Dynamic Island ActivityKit Coordinator)
   - Idea 5: SmartActionMacroParser.swift (Voice-to-Action Smart Macros)
   - Idea 6: LifeHeatmapAnalyticsEngine.swift (Visual Life Heatmap & Streak Matrix)
   - Idea 7: LocalVisionTagger.swift (On-Device Scene & OCR Tagger)
   - Idea 8: CognitiveHealthCorrelationEngine.swift (HealthKit Cognitive Correlation)
   - Idea 9: MultipeerLocalSyncEngine.swift (Multipeer P2P Local Encrypted Sync)
   - Idea 10: R0llingTelemetry & TelemetryDashboardView (Self-Healing Diagnostics Dashboard)
"""

from __future__ import annotations

import sys
import os
import re
from pathlib import Path

# Windows console encoding fix
if sys.platform == "win32":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

ROOT_DIR = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT_DIR / "Sources" / "R0lling"

def verify_telemetry_core() -> None:
    path = SOURCE_ROOT / "Telemetry" / "R0llingTelemetry.swift"
    if not path.exists():
        raise SystemExit(f"❌ To {path} den vrethike!")
    
    periexomeno = path.read_text(encoding="utf-8")
    
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

    if "megistoOrioBuffer = 250" not in periexomeno:
        raise SystemExit("❌ To megistoOrioBuffer prepei na einai akrivws 250!")
    if "private let kleidaria = NSLock()" not in periexomeno:
        raise SystemExit("❌ H kleidaria NSLock prepei na prosthikeuei to ring buffer!")

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
    ai_client = (SOURCE_ROOT / "AI" / "AIHTTPClient.swift").read_text(encoding="utf-8")
    if "R0llingTelemetry.shared.log(.ai" not in ai_client:
        raise SystemExit("❌ To AIHTTPClient den exei telemetry wiring!")
    for line in ai_client.splitlines():
        if "R0llingTelemetry.shared.log" in line and ("bearerToken" in line or "Authorization" in line):
            raise SystemExit("❌ SECURITY VIOLATION: To AIHTTPClient kanei log credential token!")

    obsidian = (SOURCE_ROOT / "Obsidian" / "ObsidianVaultBridge.swift").read_text(encoding="utf-8")
    if "R0llingTelemetry.shared.log(.obsidian" not in obsidian:
        raise SystemExit("❌ To ObsidianVaultBridge den exei telemetry wiring!")

    speech = (SOURCE_ROOT / "Speech" / "SpeechTranscriptionService.swift").read_text(encoding="utf-8")
    if "R0llingTelemetry.shared.log(" not in speech:
        raise SystemExit("❌ To SpeechTranscriptionService den exei telemetry wiring!")

    storage = (SOURCE_ROOT / "Persistence" / "JSONFileStorageService.swift").read_text(encoding="utf-8")
    glasses = (SOURCE_ROOT / "Glasses" / "MetaGlassesAdapter.swift").read_text(encoding="utf-8")
    if "R0llingTelemetry.shared.log(.storage" not in storage:
        raise SystemExit("❌ To JSONFileStorageService den exei telemetry wiring!")
    if "R0llingTelemetry.shared.log(.glasses" not in glasses:
        raise SystemExit("❌ To MetaGlassesAdapter den exei telemetry wiring!")

    print("✅ Subsystem telemetry wiring verified.")


def verify_all_ten_innovations() -> None:
    # Idea 1: SemanticSearchIndex
    p1 = SOURCE_ROOT / "AI" / "SemanticSearchIndex.swift"
    assert p1.exists(), "Idea 1: SemanticSearchIndex.swift leipei!"
    c1 = p1.read_text(encoding="utf-8")
    assert "public final class SemanticSearchIndex" in c1 and "cosineSimilarity" in c1, "Idea 1 invalid"

    # Idea 2: HardwareVaultStore
    p2 = SOURCE_ROOT / "Core" / "HardwareVaultStore.swift"
    assert p2.exists(), "Idea 2: HardwareVaultStore.swift leipei!"
    c2 = p2.read_text(encoding="utf-8")
    assert "public final class HardwareVaultStore" in c2 and "KryptografimenoStoixeio" in c2, "Idea 2 invalid"

    # Idea 3: VectorClockConflictResolver
    p3 = SOURCE_ROOT / "Obsidian" / "VectorClockConflictResolver.swift"
    assert p3.exists(), "Idea 3: VectorClockConflictResolver.swift leipei!"
    c3 = p3.read_text(encoding="utf-8")
    assert "VectorClockConflictResolver" in c3 and "DianysmatikoRoloϊ" in c3, "Idea 3 invalid"

    # Idea 4: LiveActivityStreamingCoordinator
    p4 = SOURCE_ROOT / "App" / "LiveActivityStreamingCoordinator.swift"
    assert p4.exists(), "Idea 4: LiveActivityStreamingCoordinator.swift leipei!"
    c4 = p4.read_text(encoding="utf-8")
    assert "LiveActivityStreamingCoordinator" in c4 and "DedomenaLiveActivity" in c4, "Idea 4 invalid"

    # Idea 5: SmartActionMacroParser
    p5 = SOURCE_ROOT / "Speech" / "SmartActionMacroParser.swift"
    assert p5.exists(), "Idea 5: SmartActionMacroParser.swift leipei!"
    c5 = p5.read_text(encoding="utf-8")
    assert "SmartActionMacroParser" in c5 and "DomiMacroApotelesma" in c5, "Idea 5 invalid"

    # Idea 6: LifeHeatmapAnalyticsEngine
    p6 = SOURCE_ROOT / "Core" / "LifeHeatmapAnalyticsEngine.swift"
    assert p6.exists(), "Idea 6: LifeHeatmapAnalyticsEngine.swift leipei!"
    c6 = p6.read_text(encoding="utf-8")
    assert "LifeHeatmapAnalyticsEngine" in c6 and "PinakasHeatmapApotelesma" in c6, "Idea 6 invalid"

    # Idea 7: LocalVisionTagger
    p7 = SOURCE_ROOT / "AI" / "LocalVisionTagger.swift"
    assert p7.exists(), "Idea 7: LocalVisionTagger.swift leipei!"
    c7 = p7.read_text(encoding="utf-8")
    assert "LocalVisionTagger" in c7 and "EidosSknis" in c7, "Idea 7 invalid"

    # Idea 8: CognitiveHealthCorrelationEngine
    p8 = SOURCE_ROOT / "Core" / "CognitiveHealthCorrelationEngine.swift"
    assert p8.exists(), "Idea 8: CognitiveHealthCorrelationEngine.swift leipei!"
    c8 = p8.read_text(encoding="utf-8")
    assert "CognitiveHealthCorrelationEngine" in c8 and "ypologismosPearson" in c8, "Idea 8 invalid"

    # Idea 9: MultipeerLocalSyncEngine
    p9 = SOURCE_ROOT / "Obsidian" / "MultipeerLocalSyncEngine.swift"
    assert p9.exists(), "Idea 9: MultipeerLocalSyncEngine.swift leipei!"
    c9 = p9.read_text(encoding="utf-8")
    assert "MultipeerLocalSyncEngine" in c9 and "PaketoP2PSygxronismou" in c9, "Idea 9 invalid"

    # Idea 10: R0llingTelemetry & TelemetryDashboardView
    p10 = SOURCE_ROOT / "UI" / "TelemetryDashboardView.swift"
    assert p10.exists(), "Idea 10: TelemetryDashboardView.swift leipei!"

    print("✅ All 10 Strategic Innovations (Ideas 1-10) verified in codebase.")


def main() -> None:
    print("=" * 80)
    print("🔍 R0lling Telemetry & 10 Strategic Innovations Contract Verification")
    print("=" * 80)
    
    verify_telemetry_core()
    verify_telemetry_dashboard_ui()
    verify_settings_integration()
    verify_subsystem_telemetry_wiring()
    verify_all_ten_innovations()
    
    print("\n🟢 ALL 10 INNOVATIONS & TELEMETRY CONTRACTS VERIFIED (100% SUCCESS)")


if __name__ == "__main__":
    main()
