#!/usr/bin/env python3
"""Source-contract check for the AppState clip journal-commit rollback path.

This intentionally checks source shape only; it does not execute Swift actors,
the media buffer, storage, or Apple platform APIs.
"""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources/R0lling/App/AppState.swift"
text = SOURCE.read_text(encoding="utf-8")

trigger_start = text.find("public func triggerClip(seconds: Double = 10.0) async {")
helper_start = text.find(
    "private func removeUnreferencedMediaAfterFailedJournalCommit(_ attachment: MediaAttachment) async {",
    trigger_start,
)
next_marker = text.find("// MARK:", helper_start)
if trigger_start < 0 or helper_start < 0:
    sys.exit("FAIL: clip action or rollback helper is missing")
if next_marker < 0:
    next_marker = len(text)

trigger = text[trigger_start:helper_start]
helper = text[helper_start:next_marker]

checks = {
    "journal save occurs inside the shared media-reference gate": bool(
        re.search(
            r"mediaReferenceMutationGate\.withExclusiveAccess\s*\{[\s\S]{0,300}storage\.saveEntry\(entry\)",
            trigger,
        )
    ),
    "successful save is marked committed before later work": bool(
        re.search(r"storage\.saveEntry\(entry\)[\s\S]{0,120}journalCommitted\s*=\s*true", trigger)
    ),
    "pre-commit failure schedules rollback for the created attachment": bool(
        re.search(
            r"if\s*!journalCommitted,\s*let\s+attachmentForRollback\s*\{[\s\S]{0,160}removeUnreferencedMediaAfterFailedJournalCommit",
            trigger,
        )
    ),
    "rollback runs independently and rechecks references under the same gate": (
        "let cleanupTask = Task { @MainActor [self] in" in helper
        and "mediaReferenceMutationGate.withExclusiveAccess" in helper
        and "katharismosOrphanMedia(afairoumena: [attachment])" in helper
    ),
}

for label, passed in checks.items():
    print(f"{'PASS' if passed else 'FAIL'}: {label}")

if not all(checks.values()):
    sys.exit(1)
