#!/usr/bin/env python3
"""Source/config presence checks only.
This does not render UI or exercise Apple privacy grants, DAT SDK, or devices.
No compliance certification follows from substring or plist-key assertions.
"""

import os
import sys
import xml.etree.ElementTree as ET
import re
import plistlib

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def test_theme_bevel_inspired():
    print("[1] Verifying Bevel-inspired wellness theme tokens...")
    theme_swift = os.path.join(REPO_ROOT, "Sources", "R0lling", "UI", "Theme.swift")
    assert os.path.exists(theme_swift), "Theme.swift not found"
    
    with open(theme_swift, "r", encoding="utf-8") as f:
        content = f.read()

    # Charcoal/slate surfaces, periwinkle and wellness metric colors.
    for token in ("0x17181C", "0x2A2B32", "0x343640", "0x41434D",
                  "0xF3BD55", "0xB8E34A", "0x79AFFF", "0x62C99A"):
        assert token in content, f"Missing Bevel-inspired theme token {token} in Theme.swift"

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

    print("    [OK] Bevel-inspired palette tokens found; source scan does not prove visual fidelity.")

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

    # Check active Info.plist descriptions and require unavailable capabilities to stay
    # explicitly reserved, rather than treating a privacy key as implementation evidence.
    info_plist = os.path.join(REPO_ROOT, "Apps", "R0llingApp", "Info.plist")
    assert os.path.exists(info_plist), "Info.plist not found"
    with open(info_plist, "rb") as f:
        info = plistlib.load(f)

    active_usage_keys = [
        "NSMicrophoneUsageDescription",
        "NSSpeechRecognitionUsageDescription",
        "NSPhotoLibraryUsageDescription",
        "NSLocalNetworkUsageDescription",
        "NSFaceIDUsageDescription",
        "NSHealthShareUsageDescription",
    ]
    for key in active_usage_keys:
        assert isinstance(info.get(key), str) and info[key].strip(), f"Missing active usage description {key}"

    reserved_usage_keys = [
        "NSCameraUsageDescription",
        "NSPhotoLibraryAddUsageDescription",
        "NSBluetoothAlwaysUsageDescription",
        "NSBluetoothPeripheralUsageDescription",
        "NSHealthUpdateUsageDescription",
    ]
    for key in reserved_usage_keys:
        value = info.get(key)
        assert isinstance(value, str) and any(
            marker in value.lower() for marker in ("δεν είναι διαθέσιμη", "δεν είναι διαθέσιμο")
        ), f"Reserved capability {key} must be described as unavailable"

    # Verify ATS local networking
    assert "NSAllowsLocalNetworking" in info.get("NSAppTransportSecurity", {}), "Missing NSAllowsLocalNetworking in Info.plist"

    print("    [OK] Privacy manifest structure and active/reserved usage descriptions found; this does not certify Apple policy compliance.")

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

    print("    [OK] PASS: Meta Wearables Gen 2 hardware-related source markers found; runtime compliance not evaluated.")

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

def main():
    print("=" * 70)
    print("R0lling Theme/Privacy/DAT Source Presence Checks")
    print("=" * 70)
    test_theme_bevel_inspired()
    test_apple_privacy_and_permissions()
    test_meta_compliance()
    print("=" * 70)
    print("Source/config presence checks completed. No visual, Apple policy, or Meta hardware compliance certification.")
    print("=" * 70)

if __name__ == "__main__":
    main()
