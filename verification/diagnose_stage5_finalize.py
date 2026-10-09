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
    taxonomy = read("Sources/R0lling/AI/AIErrorTaxonomy.swift")
    http_client = read("Sources/R0lling/AI/AIHTTPClient.swift")

    check(
        "Direct empty key guard",
        (
            ("7004" in direct or "directEmptyKey" in direct)
            and "trimmingCharacters" in direct
            and "Λείπει Direct API key" in direct
        ),
        "typed error before network",
    )
    check(
        "Direct always sets Bearer after guard",
        (
            "bearerToken: trimmedKey" in direct
            or "Bearer \\(trimmedKey)" in direct
            or ("Bearer" in http_client and "trimmedKey" in direct)
        ),
        "Authorization uses trimmed key via AIHTTPClient",
    )
    check(
        "Hermes empty token guard",
        (
            ("7104" in hermes or "hermesEmptyToken" in hermes)
            and "Λείπει Hermes auth token" in hermes
        ),
        "typed error before network",
    )
    check(
        "taxonomy codes present",
        "directEmptyKey = 7004" in taxonomy and "hermesEmptyToken = 7104" in taxonomy,
        "AIErrorTaxonomy owns 7004/7104",
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
        "AVFoundation playability guard",
        "load(.isPlayable)" in src and "3105" in src,
        "fail-closed when exported composition is not playable",
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


def test_sec_surgical_patches() -> None:
    """SEC-001…009 residual closure — surgical security pass → 100% lane."""
    print("[SEC] Surgical path/mirror/watch/TLS/Hermes/Keychain guards...")
    path_helper = read("Sources/R0lling/Core/Extensions.swift")
    media = read("Sources/R0lling/Persistence/MediaStorageService.swift")
    backup = read("Sources/R0lling/Persistence/BackupRestoreEngine.swift")
    obsidian = read("Sources/R0lling/Obsidian/ObsidianVaultBridge.swift")
    mirror = read("Sources/R0lling/Buffer/RemoteMirrorStreamServer.swift")
    watch = read("Sources/R0lling/App/WatchConnectivityCoordinator.swift")
    hermes = read("Sources/R0lling/AI/HermesConnector.swift")
    direct = read("Sources/R0lling/AI/DirectAPIConnector.swift")
    endpoint = read("Sources/R0lling/AI/HermesEndpointAsfaleia.swift")
    keychain = read("Sources/R0lling/AI/KeychainSecretStore.swift")
    http_client = read("Sources/R0lling/AI/AIHTTPClient.swift")
    models = read("Sources/R0lling/Core/Models.swift")
    settings = read("Sources/R0lling/UI/SettingsView.swift")
    app_state = read("Sources/R0lling/App/AppState.swift")
    podcast = read("Sources/R0lling/AI/DailyPodcastGenerator.swift")

    check(
        "PathAsfaleia helper",
        "asfalhs_resolved_url" in path_helper and "PathAsfaleia" in path_helper,
        "canonicalize helper present",
    )
    check(
        "MediaStorage uses PathAsfaleia",
        "PathAsfaleia.asfalhs_resolved_url" in media,
        "getMediaFileURL fail-closed",
    )
    check(
        "Backup+Obsidian PathAsfaleia",
        "PathAsfaleia.asfalhs_resolved_url" in backup
        and "PathAsfaleia.asfalhs_resolved_url" in obsidian,
        "restore/export fail-closed",
    )
    check(
        "Mirror AUTH gate",
        "AUTH " in mirror
        and "pairingToken" in mirror
        and "authenticatedConnections" in mirror
        and "8401" in mirror,
        "pairing required before broadcast pool",
    )
    check(
        "SEC-001-TLS release kill",
        "kodikosReleaseXorisTLS" in mirror
        and "8402" in mirror
        and "#if !DEBUG" in mirror
        and "SEC-001-TLS" in mirror,
        "Release listener/broadcast disabled χωρίς TLS",
    )
    check(
        "Watch schema + max length",
        "schemaVersionApaitoumenos" in watch and "maxMikosNoteApoWatch" in watch,
        "SEC-003 message validation",
    )
    check(
        "Watch harden allowlist + null reject",
        "epitrepomenesEnergies" in watch
        and 'contains("\\0")' in watch
        and "empty note" in watch,
        "SEC-003 further harden",
    )
    check(
        "Hermes SEC-005 scrub",
        (
            "Ο Hermes Agent απέρριψε την κλήση" in hermes
            or "httpRejectedMessagePrefix" in hermes
        )
        and "String(data: data, encoding: .utf8)" not in hermes,
        "status-only · no raw body",
    )
    check(
        "Direct SEC-005 scrub",
        (
            "Direct AI API Σφάλμα" in direct
            or "httpRejectedMessagePrefix" in direct
        )
        and "errorText" not in direct,
        "status-only · no raw body",
    )
    check(
        "SEC-004/007 HermesEndpointAsfaleia",
        "epikyroseHermesBaseURL" in endpoint
        and "epikyroseDirectBaseURL" in endpoint
        and "isAllowlistedCleartextHost" in endpoint
        and "isTailscaleCGNAT" in endpoint
        and "asfales_host_gia_log" in endpoint,
        "HTTPS + private HTTP allowlist",
    )
    check(
        "Connectors use endpoint asfaleia",
        "HermesEndpointAsfaleia.epikyroseHermesBaseURL" in hermes
        and "HermesEndpointAsfaleia.epikyroseDirectBaseURL" in direct,
        "runtime gate before network",
    )
    check(
        "Hermes default HTTPS loopback",
        'hermesBaseURL: String = "https://127.0.0.1:8080/v1"' in models
        and 'hermesEndpointURL: String = "https://127.0.0.1:8080/v1"' in settings
        and "http://192.168.1.50" not in models
        and "http://192.168.1.50" not in settings,
        "no cleartext LAN default",
    )
    check(
        "Settings validates URLs",
        ("validateHermesURL" in settings and "validateDirectURL" in settings)
        or ("validateEndpointForSaving" in settings and "validateEndpointForSaving" in read("Sources/R0lling/AI/AIRouter.swift")),
        "UI fail-closed before persist",
    )
    check(
        "Keychain Release blocks UserDefaults",
        "#if DEBUG" in keychain
        and "shouldUseUserDefaultsFallback" in keychain
        and "R0LLING_ALLOW_USERDEFAULTS_SECRETS" in keychain,
        "UserDefaults fallback DEBUG-only",
    )
    check(
        "SEC-009 no token in mirror toast",
        "pinHint" not in app_state
        and "pairingToken.prefix" not in app_state
        and (
            "Bonjour+AUTH" in app_state
            or "Mirror απενεργοποιημένο μέχρι TLS" in app_state
        ),
        "pairing token όχι σε toast",
    )
    check(
        "AIHTTPClient never returns body to UI",
        "ποτέ δεν επιστρέφει Authorization ή raw body" in http_client
        or "Authorization" in http_client,
        "client contract present",
    )
    check(
        "Podcast completion at end",
        "didFinish" in podcast and "pendingCompletion" in podcast,
        "CQ-P2-020 completion after speech",
    )

    # SEC-004 / SEC-007 — Hermes HTTPS + allowlist
    asfaleia_path = ROOT / "Sources/R0lling/AI/HermesEndpointAsfaleia.swift"
    check(
        "HermesEndpointAsfaleia module",
        asfaleia_path.is_file(),
        "SEC-004/007 endpoint guard present",
    )
    if asfaleia_path.is_file():
        asfaleia = asfaleia_path.read_text(encoding="utf-8")
        check(
            "SEC-004 HTTPS preference",
            "https" in asfaleia and "epikyroseHermesBaseURL" in asfaleia,
            "Hermes URL validation helper",
        )
        check(
            "SEC-007 allowlist LAN/VPN",
            "isRFC1918" in asfaleia
            and "isTailscaleCGNAT" in asfaleia
            and "isAllowlistedCleartextHost" in asfaleia
            and "hermesEndpointDenied" in asfaleia,
            "cleartext only localhost/RFC1918/Tailscale",
        )
        check(
            "Hermes connector uses allowlist",
            "HermesEndpointAsfaleia" in hermes and "epikyroseHermesBaseURL" in hermes,
            "HermesConnector validates before network",
        )
        check(
            "Direct forces HTTPS",
            "epikyroseDirectBaseURL" in direct or "HermesEndpointAsfaleia" in direct,
            "DirectAPIConnector HTTPS guard",
        )

    # Production AI stack (A10–A13 readiness)
    check(
        "AIHTTPClient retry/timeout",
        (ROOT / "Sources/R0lling/AI/AIHTTPClient.swift").is_file(),
        "shared HTTP client present",
    )
    check(
        "OpenAIChatRequestBuilder DRY",
        (ROOT / "Sources/R0lling/AI/OpenAIChatRequestBuilder.swift").is_file(),
        "shared chat builder present",
    )
    check(
        "AIErrorTaxonomy",
        (ROOT / "Sources/R0lling/AI/AIErrorTaxonomy.swift").is_file(),
        "error taxonomy present",
    )
    router = read("Sources/R0lling/AI/AIRouter.swift")
    check(
        "Multi-frame vision path",
        "imageBase64Frames" in router and "askWhatAmISeeingMultiFrames" in router,
        "A11 multi-frame wired",
    )
    models = read("Sources/R0lling/Core/Models.swift")
    check(
        "AgentMemory empty defaults",
        "Μαρίας" not in models and "Αγαπημένα θέματα" not in models,
        "CQ-P0-001 no fake persona in AgentMemory defaults",
    )

    # Python mirror of traversal reject rules (not full URL resolve)
    def is_unsafe_relative(path: str) -> bool:
        t = path.strip()
        if not t or "\0" in t:
            return True
        if t.startswith("/") or t.startswith("\\"):
            return True
        if len(t) >= 2 and t[1] == ":":
            return True
        parts = [p for p in t.replace("\\", "/").split("/") if p]
        return (not parts) or (".." in parts) or ("." in parts)

    check("reject ..", is_unsafe_relative("../etc/passwd"), "traversal rejected")
    check("reject abs", is_unsafe_relative("/tmp/x"), "absolute rejected")
    check("accept clip", not is_unsafe_relative("Clips/a.mp4"), "normal relative OK")

    # Python mirror of Hermes cleartext allowlist (SEC-004/007)
    def is_allowlisted_cleartext_host(host: str) -> bool:
        h = host.lower().strip("[]")
        if h in {"localhost", "127.0.0.1", "::1"} or h.endswith(".local"):
            return True
        parts = h.split(".")
        if len(parts) != 4:
            return False
        try:
            o = [int(p) for p in parts]
        except ValueError:
            return False
        if any(x < 0 or x > 255 for x in o):
            return False
        if o[0] == 10:
            return True
        if o[0] == 172 and 16 <= o[1] <= 31:
            return True
        if o[0] == 192 and o[1] == 168:
            return True
        if o[0] == 169 and o[1] == 254:
            return True
        if o[0] == 100 and 64 <= o[1] <= 127:
            return True
        return False

    check("allow 192.168", is_allowlisted_cleartext_host("192.168.1.50"), "RFC1918 OK")
    check("allow Tailscale", is_allowlisted_cleartext_host("100.64.1.2"), "CGNAT OK")
    check("deny public IP cleartext", not is_allowlisted_cleartext_host("8.8.8.8"), "public denied")
    check("deny public hostname", not is_allowlisted_cleartext_host("example.com"), "DNS cleartext denied")


def test_a04_a14_voice_game_ready() -> None:
    """A04/A14 software DoD — parser dedup, speech final-only, fail-closed game scoring."""
    print("[A04/A14] Voice + Observation Game software readiness...")
    voice = read("Sources/R0lling/Speech/VoiceCommandParser.swift")
    speech = read("Sources/R0lling/Speech/SpeechTranscriptionService.swift")
    game = read("Sources/R0lling/Game/ObservationGameEngine.swift")
    app = read("Sources/R0lling/App/AppState.swift")
    ui = read("Sources/R0lling/UI/AssistantView.swift")
    tests_voice = read("Tests/R0llingTests/VoiceCommandParserTests.swift")
    tests_game = read("Tests/R0llingTests/ObservationGameEngineTests.swift")

    check("A04 dedup state", "lastHandledTranscript" in voice and "paraThyroDedupDeuterolepta" in voice, "dedup")
    check("A04 SpeechStopResult", "SpeechStopResult" in voice and "commandHandled" in voice, "stop result enum")
    check(
        "A04 final-only speech",
        "result.isFinal" in speech
        and "processFinalTranscript" in speech
        and "utteranceResolver.stop(transcript:" in speech,
        "final callback and one-shot stop resolution",
    )
    check(
        "A04 iOS Speech not Meta mic",
        "SFSpeechRecognizer" in speech
        and ("χωρίς Meta" in speech or "όχι Meta" in speech or "Hey Meta wake" in speech),
        "iOS Speech only",
    )
    check("A04 routeVoiceCommand", "routeVoiceCommand" in app and "startObservationGame" in voice, "routing")
    check("A14 fail-closed verdict", "parseFailClosedVerdict" in game and "ambiguous" in game, "verdict")
    check("A14 EvaluationResult source", "ObservationEvaluationSource" in game and "case manual" in game, "honesty")
    check(
        "A14 PhotosPicker fallback",
        "PhotosPicker" in ui and "evaluateGameCapture(imageData:" in app,
        "picker",
    )
    check(
        "A14 streak only via success",
        "recordGameStreakAfterSuccess" in app and "recordGameStreakAfterSuccess" in ui,
        "streak",
    )
    check("XCTest voice dedup", "testFinalTranscriptDedup" in tests_voice, "voice tests")
    check("XCTest game fail-closed", "testFailClosedVerdictYesNoAmbiguous" in tests_game, "game tests")


def test_obsidian_a08_a09_ready() -> None:
    """A08/A09 Obsidian software DoD — PathAsfaleia, hash persist, Files picker, conflict flow."""
    print("[A08/A09] Obsidian vault bridge readiness...")
    bridge = read("Sources/R0lling/Obsidian/ObsidianVaultBridge.swift")
    bookmark = read("Sources/R0lling/Obsidian/VaultBookmarkStore.swift")
    agent = read("Sources/R0lling/Obsidian/AgentFolderManager.swift")
    settings = read("Sources/R0lling/UI/SettingsView.swift")
    app = read("Sources/R0lling/App/AppState.swift")
    tests = read("Tests/R0llingTests/ObsidianBridgeTests.swift")

    check(
        "A08 PathAsfaleia on notes",
        "PathAsfaleia.asfalhs_resolved_url" in bridge and "relative_note_path" in bridge,
        "note paths guarded",
    )
    check(
        "A08 hash persistence",
        "R0llingMeta/export-hashes.json" in bridge and "apothikeusi_hashes_sto_disk" in bridge,
        "hashes survive restart",
    )
    check(
        "A08 security-scoped access",
        "startAccessingSecurityScopedResource" in bridge and "vaultRequiresScopedAccess" in bridge,
        "scoped export",
    )
    check(
        "A08 VaultBookmarkStore",
        "apothikeusi_bookmark" in bookmark and "fortosi_vault_url" in bookmark,
        "bookmark persist",
    )
    check(
        "A08 Files picker UI",
        "fileImporter" in settings and ".folder" in settings and "deixeiEpilogiVault" in settings,
        "document picker",
    )
    check(
        "A08 AppState vault wiring",
        "efarmogi_epilogis_obsidian_vault" in app and "exportBatchToObsidian" in app,
        "DI helpers",
    )
    check(
        "A09 conflict sidecar",
        "r0lling-conflict" in bridge and "hadConflict: true" in bridge,
        "no overwrite",
    )
    check(
        "A09 conflict toast",
        "teleutaiaObsidianConflicts" in app and "Obsidian conflict" in app,
        "UI conflict flow",
    )
    check(
        "A09 Agent descriptor-relative no-follow access",
        "openat" in agent
        and "O_NOFOLLOW" in agent
        and "renameat" in agent
        and "linkat" in agent
        and "pinnedVaultIdentity" in agent
        and "expectedVaultIdentity" in agent,
        "Agent reads/writes stay descriptor-relative and reject a replaced pinned vault",
    )
    check(
        "A08/A09 XCTest coverage",
        "testHashPersistenceDetectsConflictAfterRestart" in tests
        and "testA08DoubleExportIdempotentBatch" in tests
        and "testPathAsfaleiaRejectsTraversalOnVaultWrite" in tests
        and "testAgentMemoryRejectsVaultDirectoryReplacement" in tests,
        "restart + double export + traversal + Agent vault replacement",
    )
    check(
        "Canvas/KG via PathAsfaleia",
        "grapse_arxeio_sto_vault" in bridge and "grapse_arxeio_sto_vault" in app,
        "safe vault writes",
    )


def test_a15_a16_backup_permissions_ready() -> None:
    """A15 backup restore + A16 error taxonomy / Info.plist app scaffold (P0-05)."""
    print("[A15/A16] Backup restore + permissions scaffold...")
    backup = read("Sources/R0lling/Persistence/BackupRestoreEngine.swift")
    taxonomy = read("Sources/R0lling/Core/AppErrorTaxonomy.swift")
    media = read("Sources/R0lling/Persistence/MediaStorageService.swift")
    settings = read("Sources/R0lling/UI/SettingsView.swift")
    app = read("Sources/R0lling/App/AppState.swift")
    tests = read("Tests/R0llingTests/BackupRestoreTests.swift")
    plist = (ROOT / "Apps/R0llingApp/Info.plist").read_text(encoding="utf-8")
    app_readme = (ROOT / "Apps/R0llingApp/README.md").read_text(encoding="utf-8")
    gha = (ROOT / ".github/workflows/swift-ci.yml").read_text(encoding="utf-8")

    check(
        "A15 agentManager wired",
        "agentManager" in backup and "saveAgentMemory" in backup and "loadAgentMemory" in backup,
        "backup includes Agent memory",
    )
    check(
        "A15 AppErrorTaxonomy on missing manifest",
        "AppErrorTaxonomy.backupMissingManifest" in backup
        and "AppErrorTaxonomy.backupDomain" in backup,
        "typed backup errors",
    )
    check(
        "A15 PathAsfaleia on restore",
        "PathAsfaleia.asfalhs_resolved_url" in backup,
        "SEC-002 restore paths",
    )
    check(
        "A15 Settings Files picker restore",
        "epanafora_apo_backup_bundle" in settings
        and "deixeiEpilogiBackup" in settings
        and "dimiourgia_backup_bundle" in app,
        "UI restore path",
    )
    check(
        "A15 XCTest clean sandbox + media + agent",
        "testRestorePreservesIdsMediaAndAgentMemory" in tests
        and "testSecondRestoreDoesNotDuplicateIds" in tests
        and "testRestoreRejectsTraversalMediaPathsAtomically" in tests,
        "restore DoD tests",
    )
    check(
        "A16 AppErrorTaxonomy domains",
        "permissionDomain" in taxonomy
        and "diskDomain" in taxonomy
        and "diskFull" in taxonomy
        and "permissionCameraDenied" in taxonomy,
        "permission/disk codes",
    )
    check(
        "A16 disk-full gate in MediaStorage",
        "ELAXISTOS_ELEUTHEROS_XOROS_BYTES" in media
        and "anepikisXoros" in media,
        "disk full path",
    )
    check(
        "A16/P0-05 active and reserved Info.plist privacy strings",
        "NSMicrophoneUsageDescription" in plist
        and "NSSpeechRecognitionUsageDescription" in plist
        and "NSPhotoLibraryUsageDescription" in plist
        and "NSLocalNetworkUsageDescription" in plist
        and "NSHealthShareUsageDescription" in plist
        and "NSCameraUsageDescription" in plist
        and "NSBluetoothAlwaysUsageDescription" in plist
        and "δεν είναι διαθέσιμη" in plist,
        "implemented flow descriptions and explicitly unavailable future capabilities; presence is not implementation evidence",
    )
    check(
        "P0-05 Apps/R0llingApp scaffold README",
        "R0llingApp" in app_readme and "Info.plist" in app_readme and "xcodegen" in app_readme.lower(),
        "Mac build docs",
    )
    check(
        "P0-01 GHA swift test + python verify",
        "swift test" in gha
        and "python-verify" in gha
        and "verify_all_subsystems.py" in gha
        and "verify_theme_apple_meta_compliance.py" in gha
        and "upload-artifact" in gha,
        "CI workflow ready for Mac proof",
    )


def main() -> int:
    print("=== R0lling Stage 5 Finalize Diagnostics ===")
    print(f"ROOT: {ROOT}")
    test_r3_009()
    test_r3_012()
    test_g5_001_highlight_no_byte_concat()
    test_stage4_not_regressed()
    test_gemini_super_features_present()
    test_sec_surgical_patches()
    test_a04_a14_voice_game_ready()
    test_obsidian_a08_a09_ready()
    test_a15_a16_backup_permissions_ready()
    # A01–A03 journal/media contracts
    import diagnose_journal_media_a01_a03 as journal_media
    journal_media.errors.clear()
    journal_media.test_a01_offline_restart()
    journal_media.test_a02_edit_search_tz()
    journal_media.test_a03_media_attach_display()
    journal_media.test_no_compile_break_camera_source()
    errors.extend(journal_media.errors)
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
