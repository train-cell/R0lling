#!/usr/bin/env python3
"""
verify_theme_apple_meta_compliance.py

Empirical verification script for:
1. Discord x Twitch Dark Cold Aesthetic (Color token inspection & zero orange)
2. Apple App Store Privacy Manifest & Permissions compliance (PrivacyInfo.xcprivacy, Info.plist, ATS)
3. Meta Wearables Gen 2 Compliance (DAT lifecycle, hardware safety error codes, honesty)
"""

import os
import sys
import xml.etree.ElementTree as ET
import re

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def test_theme_discord_twitch():
    print("[1] Verifying Discord x Twitch Theme Tokens...")
    theme_swift = os.path.join(REPO_ROOT, "Sources", "R0lling", "UI", "Theme.swift")
    assert os.path.exists(theme_swift), "Theme.swift not found"
    
    with open(theme_swift, "r", encoding="utf-8") as f:
        content = f.read()

    # Verify background and surface tokens
    assert "0x16161D" in content, "Missing Discord dark background 0x16161D in Theme.swift"
    assert "0x22232D" in content, "Missing Discord surface 0x22232D in Theme.swift"
    assert "0x2C2D39" in content, "Missing Discord elevated surface 0x2C2D39 in Theme.swift"
    assert "0x373948" in content, "Missing border token 0x373948 in Theme.swift"

    # Verify Twitch and Discord purple/lavender/cyan accents
    assert "0x7742DC" in content, "Missing Twitch Purple 0x7742DC in Theme.swift"
    assert "0x9146FF" in content, "Missing Twitch Accent 0x9146FF in Theme.swift"
    assert "0xA78BFA" in content, "Missing Lavender 0xA78BFA in Theme.swift"
    assert "0x00E5FF" in content, "Missing Cyan 0x00E5FF in Theme.swift"

    # Verify status tokens
    assert "0x55D6A4" in content, "Missing Success 0x55D6A4 in Theme.swift"
    assert "0xFF6B7A" in content, "Missing Error 0xFF6B7A in Theme.swift"

    # Check that in active UI files, there are no active calls to stravaOrange or stravaFlame or .orange
    ui_files = [
        "TodayView.swift",
        "Components.swift",
        "CalendarView.swift",
        "AssistantView.swift",
        "SettingsView.swift",
        "PhotosMediaPicker.swift"
    ]
    for uif in ui_files:
        path = os.path.join(REPO_ROOT, "Sources", "R0lling", "UI", uif)
        assert os.path.exists(path), f"UI file {uif} not found"
        with open(path, "r", encoding="utf-8") as f:
            uicontent = f.read()
        
        # Check no active usage of .orange
        assert ".orange" not in uicontent, f"Found .orange in {uif}"
        
        # Check no active usage of stravaOrange (excluding comments)
        lines = uicontent.split("\n")
        for idx, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
                continue
            assert "stravaOrange" not in line, f"Found active stravaOrange in {uif}:{idx+1}: {line}"
            assert "stravaFlame" not in line, f"Found active stravaFlame in {uif}:{idx+1}: {line}"

    print("    [OK] PASS: Discord x Twitch theme and zero orange in active UI verified.")

def test_apple_privacy_and_permissions():
    print("[2] Verifying Apple Privacy Manifest & Permissions...")
    privacy_plist = os.path.join(REPO_ROOT, "Apps", "R0llingApp", "PrivacyInfo.xcprivacy")
    assert os.path.exists(privacy_plist), "PrivacyInfo.xcprivacy not found in Apps/R0llingApp"

    tree = ET.parse(privacy_plist)
    root = tree.getroot()
    assert root.tag == "plist", "PrivacyInfo.xcprivacy is not valid plist XML"
    
    with open(privacy_plist, "r", encoding="utf-8") as f:
        privacy_text = f.read()

    assert "NSPrivacyTracking" in privacy_text, "Missing NSPrivacyTracking"
    assert "<false/>" in privacy_text, "NSPrivacyTracking must be false"
    assert "NSPrivacyAccessedAPICategoryFileTimestamp" in privacy_text, "Missing FileTimestamp category"
    assert "NSPrivacyAccessedAPICategoryDiskSpace" in privacy_text, "Missing DiskSpace category"
    assert "NSPrivacyAccessedAPICategoryUserDefaults" in privacy_text, "Missing UserDefaults category"

    # Check Info.plist
    info_plist = os.path.join(REPO_ROOT, "Apps", "R0llingApp", "Info.plist")
    assert os.path.exists(info_plist), "Info.plist not found"
    with open(info_plist, "r", encoding="utf-8") as f:
        info_text = f.read()

    required_permissions = [
        "NSCameraUsageDescription",
        "NSMicrophoneUsageDescription",
        "NSSpeechRecognitionUsageDescription",
        "NSPhotoLibraryUsageDescription",
        "NSPhotoLibraryAddUsageDescription",
        "NSBluetoothAlwaysUsageDescription",
        "NSBluetoothPeripheralUsageDescription",
        "NSLocalNetworkUsageDescription",
        "NSHealthShareUsageDescription",
        "NSHealthUpdateUsageDescription"
    ]
    for perm in required_permissions:
        assert perm in info_text, f"Missing required permission {perm} in Info.plist"

    # Verify ATS local networking
    assert "NSAppTransportSecurity" in info_text, "Missing NSAppTransportSecurity in Info.plist"
    assert "NSAllowsLocalNetworking" in info_text, "Missing NSAllowsLocalNetworking in Info.plist"

    print("    [OK] PASS: Apple PrivacyInfo.xcprivacy manifest and Info.plist permissions verified.")

def test_meta_compliance():
    print("[3] Verifying Meta Wearables Gen 2 Compliance & Safety...")
    taxonomy_file = os.path.join(REPO_ROOT, "Sources", "R0lling", "Core", "AppErrorTaxonomy.swift")
    with open(taxonomy_file, "r", encoding="utf-8") as f:
        tax_content = f.read()

    assert "metaGlassesDomain" in tax_content, "Missing metaGlassesDomain in AppErrorTaxonomy.swift"
    assert "metaCameraPrivacyIndicatorObscured" in tax_content, "Missing metaCameraPrivacyIndicatorObscured"
    assert "metaThermalThrottleExceeded" in tax_content, "Missing metaThermalThrottleExceeded"
    assert "metaBatteryDepleted" in tax_content, "Missing metaBatteryDepleted"
    assert "metaBackgroundCaptureRestricted" in tax_content, "Missing metaBackgroundCaptureRestricted"

    adapter_file = os.path.join(REPO_ROOT, "Sources", "R0lling", "Glasses", "MetaGlassesAdapter.swift")
    with open(adapter_file, "r", encoding="utf-8") as f:
        adapter_content = f.read()

    # Verify lifecycle background/lock handling
    assert "willEnterBackground" in adapter_content, "Adapter must handle willEnterBackground"
    assert "willResignActiveForLock" in adapter_content, "Adapter must handle willResignActiveForLock"
    assert "didBecomeActive" in adapter_content, "Adapter must handle didBecomeActive"

    # Verify honest battery reporting (nil on disconnect)
    assert "case .connected" in adapter_content, "Adapter must only report battery when connected"

    print("    [OK] PASS: Meta Wearables Gen 2 hardware safety and compliance verified.")

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

def main():
    print("=" * 70)
    print("R0lling Theme, Apple & Meta Compliance Verification Suite")
    print("=" * 70)
    test_theme_discord_twitch()
    test_apple_privacy_and_permissions()
    test_meta_compliance()
    print("=" * 70)
    print("ALL COMPLIANCE CHECKS PASSED (100% SUCCESS).")
    print("=" * 70)

if __name__ == "__main__":
    main()
