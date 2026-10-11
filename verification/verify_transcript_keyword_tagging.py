#!/usr/bin/env python3
"""Guard that journal tags are wired as disclosed transcript cues, not audio emotion."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
app_state = (ROOT / "Sources/R0lling/App/AppState.swift").read_text(encoding="utf-8")
tagger = (ROOT / "Sources/R0lling/Speech/TranscriptKeywordTagger.swift").read_text(encoding="utf-8")
registry = (ROOT / "Sources/R0lling/Core/FeatureReadinessRegistry.swift").read_text(encoding="utf-8")
matrix = (ROOT / "docs/GOAL_100_FEATURE_MATRIX.md").read_text(encoding="utf-8")

notes_start = app_state.index("public func addNote(text: String")
notes_end = app_state.index("// MARK: - Speech", notes_start)
add_note = app_state[notes_start:notes_end]

assert "transcriptKeywordTagger.detectCues(in: text)" in add_note
assert "tags + detectedTextCues + detectedEntityTags" in add_note
assert 'case excitement = "κείμενο: ενθουσιασμός"' in tagger
assert "does not infer emotion from voice acoustics" in tagger
assert "ρητά text-based, όχι acoustic emotion/prosody" in registry
assert "Transcript keyword cues" in matrix

print("PASS: addNote wires explicitly disclosed transcript keyword cues; no voice-prosody claim")
