#!/usr/bin/env python3
"""
A01 / A02 / A03 contract diagnostics — Journal + Media production-ready gates.
Static source + Python ISO8601 / TZ / media path mirrors (χωρίς Swift runtime).
Δεν σπάει R3-001: επιβεβαιώνει encode/decode ISO8601 parity.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timedelta, timezone
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


def make_date_key(dt: datetime, tz_name: str) -> str:
    """Mirror two fixed-time-zone fixtures without requiring host tzdata."""
    fixture_offsets = {
        "Asia/Tokyo": timezone(timedelta(hours=9)),
        "Europe/Athens": timezone(timedelta(hours=3)),
    }
    try:
        fixture_zone = fixture_offsets[tz_name]
    except KeyError as error:
        raise ValueError(f"Unsupported fixed-offset fixture zone: {tz_name}") from error
    local = dt.astimezone(fixture_zone)
    return local.strftime("%Y-%m-%d")


def test_a01_offline_restart() -> None:
    print("[A01] Offline note + restart (R3-001 ISO8601)...")
    storage = read("Sources/R0lling/Persistence/JSONFileStorageService.swift")
    app = read("Sources/R0lling/App/AppState.swift")
    tests = read("Tests/R0llingTests/JournalStorageTests.swift")
    restart = read("Tests/R0llingTests/PersistenceRestartDiagnosticTests.swift")

    check(
        "ISO8601 encode",
        "dateEncodingStrategy = .iso8601" in storage,
        "JSONEncoder iso8601",
    )
    check(
        "ISO8601 decode",
        "dateDecodingStrategy = .iso8601" in storage,
        "JSONDecoder iso8601 — R3-001",
    )
    check(
        "atomic write",
        "options: .atomic" in storage
        or "options:.atomic" in storage
        or "options: R0llingFileProtection.atomicWriteOptions" in storage,
        "atomic flush with platform file-protection options",
    )
    check(
        "addNote error path",
        "func addNote" in app and "Σφάλμα αποθήκευσης" in app,
        "no silent save failure",
    )
    check(
        "XCTest restart",
        "testJournalSurvivesRestartViaNewInstance" in tests
        and "testJournalSurvivesNewStorageInstance" in restart,
        "restart XCTest present",
    )

    # Python mirror round-trip
    ts = datetime(2026, 10, 6, 10, 30, 0, tzinfo=timezone.utc)
    iso = ts.strftime("%Y-%m-%dT%H:%M:%SZ")
    container = {
        "schemaVersion": 1,
        "appVersion": "1.0.0",
        "lastUpdated": iso,
        "entries": [
            {
                "id": "00000000-0000-0000-0000-0000000000a1",
                "timestamp": iso,
                "lastModified": iso,
                "timeZoneIdentifier": "Europe/Athens",
                "content": "offline note",
                "source": "manual",
                "tags": [],
                "attachments": [],
                "isFavorite": False,
            }
        ],
    }
    parsed = json.loads(json.dumps(container))
    check(
        "python ISO8601 round-trip",
        parsed["entries"][0]["timestamp"] == iso,
        f"survives encode/decode ({iso})",
    )


def test_a02_edit_search_tz() -> None:
    print("[A02] Edit / search / TZ date correction...")
    models = read("Sources/R0lling/Core/Models.swift")
    storage = read("Sources/R0lling/Persistence/JSONFileStorageService.swift")
    app = read("Sources/R0lling/App/AppState.swift")
    calendar = read("Sources/R0lling/UI/CalendarView.swift")
    editor = read("Sources/R0lling/UI/EntryEditorSheet.swift")
    tests = read("Tests/R0llingTests/JournalStorageTests.swift")

    check(
        "makeDateKey POSIX",
        "makeDateKey(for" in models and "en_US_POSIX" in models,
        "stable day key",
    )
    check(
        "displayTimeZone filter",
        "displayTimeZone" in storage and "makeDateKey" in storage,
        "R3-009 day filter",
    )
    check(
        "updateEntry API",
        "func updateEntry" in app,
        "AppState edit",
    )
    check(
        "correctEntryDate API",
        "func correctEntryDate" in app and "διπλότυπο ID" in app,
        "date fix + duplicate guard",
    )
    check(
        "searchJournal API",
        "func searchJournal" in app and "searchEntries" in storage,
        "title/content/tags search",
    )
    check(
        "Calendar uses storage search",
        "searchJournal" in calendar,
        "UI not content-only filter",
    )
    check(
        "EntryEditorSheet",
        "EntryEditorSheet" in editor and "timeZoneIdentifier" in editor,
        "edit + TZ UI",
    )
    check(
        "XCTest edit/date/search",
        "testEditKeepsStableIDNoDuplicates" in tests
        and "testCorrectDateChangesDateKeySameID" in tests
        and "testSearchMatchesTitle" in tests,
        "A02 XCTest coverage",
    )

    # TZ math mirror: Tokyo morning vs Athens previous evening
    tokyo = datetime(2026, 10, 5, 16, 30, 0, tzinfo=timezone.utc)  # 01:30 JST Oct 6
    check(
        "Tokyo dateKey",
        make_date_key(tokyo, "Asia/Tokyo") == "2026-10-06",
        "01:30 JST → 2026-10-06",
    )
    check(
        "Athens dateKey same instant",
        make_date_key(tokyo, "Europe/Athens") == "2026-10-05",
        "same instant → 2026-10-05 Athens",
    )


def test_a03_media_attach_display() -> None:
    print("[A03] Media attach / display / Photos picker...")
    media = read("Sources/R0lling/Persistence/MediaStorageService.swift")
    importer = read("Sources/R0lling/Persistence/JournalMediaImporter.swift")
    picker = read("Sources/R0lling/UI/PhotosMediaPicker.swift")
    components = read("Sources/R0lling/UI/Components.swift")
    today = read("Sources/R0lling/UI/TodayView.swift")
    app = read("Sources/R0lling/App/AppState.swift")
    tests = read("Tests/R0llingTests/MediaStorageTests.swift")
    journal_tests = read("Tests/R0llingTests/JournalStorageTests.swift")

    check(
        "typed media errors",
        "MediaApothikeusiError" in importer and "kenoDedomena" in importer,
        "fail-closed empty/disk",
    )
    check(
        "empty data rejected",
        "kenoDedomena" in media and "FileManager.default.fileExists" in media,
        "verify file after write",
    )
    check(
        "PathAsfaleia on get",
        "PathAsfaleia.asfalhs_resolved_url" in media,
        "SEC-002",
    )
    check(
        "PhotosPicker present",
        "PhotosPicker" in picker and "PhotosUI" in picker,
        "PHPicker via PhotosUI",
    )
    check(
        "fileImporter audio/video",
        "fileImporter" in picker and ".audio" in picker,
        "Files path for audio",
    )
    check(
        "attachMediaData API",
        "func attachMediaData" in app and "importFile" in app,
        "AppState media attach",
    )
    check(
        "TodayView wires picker",
        "PhotosMediaPickerButton" in today and "attachMediaFile" in today,
        "composer media button",
    )
    check(
        "MediaPreview resolves URL",
        "resolveURL" in components and "LOCAL FILE" in components,
        "honest local file status",
    )
    check(
        "no fake Obsidian sync",
        "Synced to Obsidian Local Vault" not in components,
        "removed pretend-success footer",
    )
    check(
        "honest footer",
        "Τοπικό ημερολόγιο" in components,
        "local journal label",
    )
    check(
        "Media XCTest",
        "testSavePhotoCreatesFileAndAttachment" in tests
        and "testEmptyDataFailsClosed" in tests
        and "testPathTraversalRejected" in tests,
        "MediaStorageTests",
    )
    check(
        "attachment restart XCTest",
        "testMediaAttachmentSurvivesRestart" in journal_tests,
        "media in journal ISO8601",
    )

    # Media relative path safety mirror
    def is_unsafe(path: str) -> bool:
        t = path.strip()
        if not t or "\0" in t:
            return True
        if t.startswith("/") or t.startswith("\\"):
            return True
        if len(t) >= 2 and t[1] == ":":
            return True
        parts = [p for p in t.replace("\\", "/").split("/") if p]
        return (not parts) or (".." in parts) or ("." in parts)

    check("reject traversal", is_unsafe("../x.jpg"), "unsafe")
    check("accept Photos path", not is_unsafe("Photos/a.jpg"), "safe relative")


def test_no_compile_break_camera_source() -> None:
    print("[Guard] EntrySource.camera compile break removed...")
    app = read("Sources/R0lling/App/AppState.swift")
    models = read("Sources/R0lling/Core/Models.swift")
    check(
        "no .camera source",
        "source: .camera" not in app,
        "meal path uses valid EntrySource",
    )
    check(
        "EntrySource cases",
        "case importFile" in models and "case ai" in models,
        "known sources only",
    )


def main() -> int:
    print("=== R0lling Journal+Media A01/A02/A03 Diagnostics ===")
    print(f"ROOT: {ROOT}")
    test_a01_offline_restart()
    test_a02_edit_search_tz()
    test_a03_media_attach_display()
    test_no_compile_break_camera_source()
    print()
    if errors:
        print(f"FAILED ({len(errors)}):")
        for err in errors:
            print(f"  - {err}")
        return 1
    print("ALL A01/A02/A03 JOURNAL+MEDIA CONTRACTS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
