# R0lling — Lane Voice + Observation Game (A04 / A14)

```yaml
Last_Modified: 2026-10-06T18:45:00+03:00
lane: voice-observation-game
scope: [A04, A14, Phase4, Phase6]
git_commit: NONE
host: Windows · Swift UNAVAILABLE · Python diagnostics OK
```

## Definition of Done — «100% ready» (software)

| # | DoD | Status |
|---|---|---|
| 1 | Voice parser EL/EN: clip / note / whatAmISeeing / game start / next mission | ✅ |
| 2 | R3-006 dedup 2s — μία εντολή ανά final utterance | ✅ |
| 3 | Speech: μόνο final (όχι partial) → command; `SpeechStopResult` αποφεύγει διπλό addNote | ✅ |
| 4 | iOS `SFSpeechRecognizer` + mic (χωρίς Meta / Hey Meta wake) · auth errors honest | ✅ |
| 5 | `AppState.routeVoiceCommand` κεντρική δρομολόγηση | ✅ |
| 6 | Game session lifecycle: idle → active → evaluating → completed/failed | ✅ |
| 7 | Fail-closed scoring: ασαφές/σφάλμα AI → 0 πόντοι · `ObservationVerdict.ambiguous` | ✅ |
| 8 | Evaluation honesty: `.aiVision` / `.manual` / `.unavailable` · UI labels | ✅ |
| 9 | Score + streak persistence · streak μόνο σε success (G5-002) · `didPersist` toast | ✅ |
| 10 | UI: glasses capture + PhotosPicker fallback + manual (όχι AI) + session badge | ✅ |
| 11 | XCTest: VoiceCommandParser + ObservationGameEngine fail-closed | ✅ (Mac/`swift test`) |
| 12 | Python stage5 A04/A14 suite | ✅ |

### Εκτός DoD (ρητά)

| Residual | Why |
|---|---|
| Meta «Hey Meta» wake | Experimental / DAT — όχι iOS API |
| Live Vision AI απόδειξη σε device | Απαιτεί API key + κάμερα/γυαλιά |
| Mic permission Info.plist στο `.app` | SPM library μόνο — host app target εκκρεμεί |
| `swift test` σε αυτό το host | Windows · UNAVAILABLE |

## Files

### Changed / authored
- `Sources/R0lling/Speech/VoiceCommandParser.swift`
- `Sources/R0lling/Speech/SpeechTranscriptionService.swift`
- `Sources/R0lling/Game/ObservationGameEngine.swift`
- `Sources/R0lling/App/AppState.swift` (speech + game sections)
- `Sources/R0lling/UI/AssistantView.swift` (`ObservationGameSheet`)
- `Tests/R0llingTests/VoiceCommandParserTests.swift`
- `Tests/R0llingTests/ObservationGameEngineTests.swift`
- `verification/diagnose_stage5_finalize.py` (`test_a04_a14_voice_game_ready`)
- `docs/LANE_VOICE_GAME.md` (αυτό)

### Unchanged (used)
- `Sources/R0lling/Game/ScavengerHuntStreakManager.swift` (ήδη G5-004 / CQ-P2-024)
- `Sources/R0lling/UI/TodayView.swift` (mic → `toggleSpeechDictation`)

## Verify

```text
python verification/diagnose_stage5_finalize.py
python verification/diagnose_stage4_fixes.py   # R3-006 regression
# σε Mac:
swift test --filter VoiceCommandParserTests
swift test --filter ObservationGameEngineTests
```
