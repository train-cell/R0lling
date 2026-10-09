> Current status (2026-10-09): This document contains historical assertions or design targets. It is not evidence for the current checkout. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) and [FINDINGS_REMEDIATION.md](FINDINGS_REMEDIATION.md). Earlier “100%”, module counts, CI/head references and security/readiness claims are superseded.

# R0lling — Rectification Report (Plan · Docs · Code)

**Ημερομηνία:** 2026-10-06 ~18:00 EEST  
**Workspace:** `.`  
**Git:** χωρίς commit (όπως ζητήθηκε)  
**Inputs:** `R0lling-Project-Plan.md` (Codex) · `docs/*` · `Sources/` · `verification/*.py` · `AUDIT_CODE_QUALITY.md` · `GEMINI_AUDIT.md`

---

## 1. Executive summary

Ο πυρήνας **Phases 0–6 / A01–A16** (journal, buffer, Obsidian conflict, voice dedup, AI connectors, game) **ευθυγραμμίζεται** με το πλάνο ως *wired software* με **εκκρεμή device/DAT/Mac proof**. Το drift είναι κυρίως **Gemini wave-B/C**: held engines, overclaim docs, dead sensor feeds.

**Rectification pass (σήμερα):**
- Ενσωμάτωση **6 code-quality P0** (CQ-P0-001…006) στον λογαριασμό παραδοτέων.
- **CQ-P0-007:** fail-closed acoustic/IMU — gated hooks, όχι hardware toasts χωρίς feed.
- **CQ-P1-012:** Obsidian export μετά clip/note — warning toast αντί silent `try?`.
- Doc honesty: `IMPLEMENTED_SUPER_FEATURES_20` (acoustic/IMU), `RemoteMirrorStreamServer` header.
- **Δεν** Stage 6 device · **δεν** αφαίρεση Gemini scaffold · **δεν** inflate STATUS.

---

## 2. Plan phases vs code (core)

| Phase / A-block | Plan claim | Code evidence | Gap |
|---|---|---|---|
| 0 DAT / Gen 2 | Pairing + stream | `MetaGlassesAdapter`, sim mode, `Package.swift` DAT commented | **missing SDK** · simulation OK |
| 1 Journal | CRUD + media | `JSONFileStorageService`, SwiftUI | **wired** · Mac XCTest pending |
| 2 Obsidian | export + conflict | `ObsidianVaultBridge`, R3-005 sidecar | **wired** · Files picker proof pending |
| 3 Buffer/clip | 5–10s + playable export | `RollingBufferService`, `PlayableClipExporter` | **wired sim** · DAT NAL remux **missing** |
| 4 Voice | note/clip commands | `VoiceCommandParser`, `SpeechTranscriptionService` | **wired** · Hey Meta **missing** |
| 5 AI | Direct + Hermes + vision | `AIRouter`, Keychain, connectors | **wired** · live endpoints **missing** |
| 6 Game | observation game | `ObservationGameEngine`, G5-002 streak | **wired** · device vision **missing** |

---

## 3. Top gaps (plan/doc vs reality)

| Item | Doc / plan | Reality | Type |
|---|---|---|---|
| Acoustic auto-clip | Super-features MD (παλιό) | Service exists · **no mic feed** · hooks gated | **overclaim → fixed docs** |
| Head double-nod | Super-features MD | Detector exists · **no IMU feed** · hooks gated | **overclaim → fixed docs** |
| Remote mirror | Batch-7 / marketing docstrings | NWListener OK · **no `broadcastFrame` from stream** | **scaffold** |
| MobileCLIP | Name implies model | FNV pseudo embeddings | **wrong impl / naming** |
| Spatial/Metal/Watermark/FileWatcher | Super-features list | Orphan · AppState hold only | **scaffold** |
| DAT remux | Plan §3.2 real stream | Placeable MP4 placeholder | **missing** (expected without SDK) |
| `swift test` | Plan §12 | Windows host | **external blocker** |

---

## 4. Code-quality P0 integrated (prior audit lane)

| ID | File | Action |
|---|---|---|
| CQ-P0-001 | `Obsidian/AgentFolderManager.swift` | Empty agent memory templates |
| CQ-P0-002 | `UI/SettingsView.swift` | Obsidian batch export `do/catch` |
| CQ-P0-003 | `AI/HermesConnector.swift` | Hermes domain rethrow |
| CQ-P0-004 | `App/AppState.swift` | KG export empty guard + extract |
| CQ-P0-005 | `UI/AssistantView.swift` | Agent save fail → toast |
| CQ-P0-006 | `Glasses/MetaGlassesAdapter.swift` | Battery `nil` when disconnected |
| **CQ-P0-007** | `App/AppState.swift` | `SUPER_FEATURE_*_FEED_WIRED = false` · gated callbacks |
| **CQ-P1-012** | `App/AppState.swift` | `exportEntryToObsidianIfConfigured` |

---

## 5. Doc changes (this pass)

| File | Change |
|---|---|
| `docs/RECTIFICATION_REPORT.md` | **NEW** (this file) |
| `docs/IMPLEMENTATION_STATUS.md` | §4 acoustic/IMU honesty · §5 CQ table |
| `docs/HANDOFF.md` | CQ-P0-007 closed · pointer here |
| `docs/AUDIT_CODE_QUALITY.md` | CQ-P0-007 / P1-010 / P1-012 FIXED |
| `docs/IMPLEMENTED_SUPER_FEATURES_20.md` | Acoustic + IMU integration lines honest |
| `docs/CAPABILITY_MATRIX.md` | (unchanged — already honest Stage 4–5 note) |

---

## 6. Code paths touched (rectification)

- `Sources/R0lling/App/AppState.swift` — flags, gated hooks, Obsidian helper
- `Sources/R0lling/Buffer/RemoteMirrorStreamServer.swift` — docstring

**Preserved:** R3-001…012, G5-001…005, RollingBuffer/PlayableClip, DAT error 4002 path.

---

## 7. Verification

| Script | Result (2026-10-06 ~18:00 EEST) |
|---|---|
| `verification/diagnose_stage3_defects.py` | **PASS** (delegates → stage4) |
| `verification/diagnose_stage4_fixes.py` | **ALL STAGE 4 FIX CHECKS PASSED** |
| `verification/diagnose_stage5_finalize.py` | **ALL STAGE 5 FINALIZE CHECKS PASSED** (incl. `onSpikeDetected` presence) |
| `verification/verify_all_subsystems.py` | **7 phases / 27 modules PASS** |
| `swift test` / Xcode | **UNAVAILABLE** (Windows) |

**Mac checklist (εκκρεμές):** Hermes 7102 rethrow · Agent empty defaults · KG empty export · gated acoustic integration (no false toast).

---

## 8. Open blockers

1. **Mac:** compile + `swift test` + AVAsset.isPlayable on exported clips.
2. **Device:** Meta Gen 2 + DAT SPM · mic/IMU feeds → flip `SUPER_FEATURE_*` flags.
3. **Mirror:** wire `broadcastFrame` from buffer or hide UI toggle.
4. **P1 backlog:** orphan AppState holds (CQ-P1-017), MobileCLIP rename, Direct/Hermes DRY.

---

## 9. Gemini vs steward boundary

| Wave | Keep | Action |
|---|---|---|
| A (core plan) | All production modules | Maintain tests on Mac |
| B (20 super) | Earcons, TimeCapsule, Highlight, Watch hooks | Orphans: hold or `Experimental/` — no delete without decision |
| C (batch 7) | Whisper fail-closed, KG heuristic | Rename pseudo-CLIP · mirror frames TBD |

**Rule:** wire **or** fail-closed + honest docs — no fake success.
