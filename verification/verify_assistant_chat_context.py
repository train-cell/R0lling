#!/usr/bin/env python3
"""Guard the AppState-to-router wiring for configured all-journal chat context."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
app_state = (ROOT / "Sources/R0lling/App/AppState.swift").read_text(encoding="utf-8")
router = (ROOT / "Sources/R0lling/AI/AIRouter.swift").read_text(encoding="utf-8")

chat_start = app_state.index("public func sendMessageToAssistant(prompt: String) async {")
chat_end = app_state.index("/// A11:", chat_start)
chat_body = app_state[chat_start:chat_end]

assert "contextEntries: allEntries" in chat_body, "Assistant chat must pass the full journal snapshot"
assert "contextEntries: todayEntries" not in chat_body, "Assistant chat must not be scoped to the selected day"
assert "OpenAIChatRequestBuilder.selectedContextEntries(from: contextEntries, limit: limit)" in router, (
    "AIRouter must apply the configured newest-entry cap to the supplied journal context"
)

print("PASS: chat context is selected-date independent and capped by the configured newest-entry limit")
