> Snapshot banner from 2026-10-10 (P0, Wave-B/C, and pointer sections were refreshed 2026-10-13): this matrix preserves historical assertions and design targets; the rows below are not a verified report of the current checkout. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md), [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md), and [FINDINGS_REMEDIATION.md](FINDINGS_REMEDIATION.md) for current evidence. Earlier “100%”, module counts, CI/head references and security/readiness claims are superseded.

# R0lling — GOAL 100% Feature Matrix (DoD)

```yaml
Last_Modified: 2026-10-13
role: integrator-orchestrator
current_authority: [docs/IMPLEMENTATION_STATUS.md, docs/CAPABILITY_MATRIX.md, docs/FINDINGS_REMEDIATION.md, docs/AUDIT_VERIFICATION.md]
historical_audit_snapshot: docs/AUDIT_FINAL.md
plan: R0lling-Project-Plan.md §12 A01–A16 (external plan document; not in this repository)
policy: source presence ≠ feature verification · no completion percentage without runtime evidence
base_HEAD: b29429b6d24051ee2d4f4b52e793f9c5b0748932 (pushed origin/main)
remediation_commit: b29429b contains the 93f6833 checkpoint; the 2026-10-13 cloud continuation (CI/guard fixes, cross-platform design docs) is uncommitted
cross_platform_gates: docs/MULTIPLATFORM_ROADMAP.md · docs/ADR_0001_ANDROID_WINDOWS_CLIENT_STACK.md (Proposed) · Android/Windows clients are design-only
```

**Σκοπός:** Acceptance checklist και source inventory. A listed implementation path is not a claim that its feature passed tests or works on a device.

**UI follow-up (2026-10-10, historical):** Today share is wired to a Bevel-inspired image composer (`TodayShareComposerView`) with ring-based cards, rotating coverage of all available HealthKit readings, customization, and PNG save/copy/share actions. The square preview respects available height; the second default Overview card uses the monochrome treatment in `IMG_0480`, and custom monochrome palette selection remains available. The source contract covers these rules; Apple build, export/share interaction, and rendered `IMG_0479`/`IMG_0480` comparison are still pending. This does not change any A-ID or readiness count.

**Legend readiness**

| Tag | Σημασία |
|---|---|
| `SW` | Source work not requiring Gen2 hardware; still needs executable test evidence before calling it complete |
| `MAC` | Απαιτεί `swift test` / Xcode / `AVAsset` runtime |
| `DEV` | Απαιτεί iPhone / Gen2 / live credentials / Files picker / Watch |
| `ORPHAN` | Wave-B/C χωρίς caller — DoD = wire **ή** Experimental/`#if` + honest docs |
| `FREEZE` | Out-of-plan μέχρι A05/A10 device proof (wave D+) |

`FeatureReadinessRegistry.ready` means the source path is wired and may be exposed. It does not mean the feature passed an Apple build, runtime, device, or release acceptance gate. A feature with pending `MAC` or `DEV` evidence remains incomplete for this 100% matrix even when its source flag is `true`.

**Status snapshot** (integrator @ matrix create · re-scan ενημερώνει):

| Bucket | Count |
|---|---|
| Plan A01–A16 | 16 |
| Wave-B super | 20 |
| Wave-C batch-7 | 7 |
| Platform gates (P0) | 4 |
| **Device-proven A-IDs** | **0 / 16** (AUDIT_FINAL) |

---

## 0. Platform gates (μπλοκάρουν «app 100%»)

| ID | DoD «100% ready» | Layer | Owner lane hint | Blocker |
|---|---|---|---|---|
| **P0-01** | GHA `swift-ci` green **ή** local `swift test` PASS + log στο HANDOFF | `MAC` | mac-ci | Hosted runs on `b614db9`/`b29429b` failed before the Swift build (stale Python guards; harness manifests without `platforms` on macOS; Xcode 16 on deprecated `macos-14` vs swift-tools 6.3). The last run that reached `swift build` (37957186872 on `46fe025`) failed to compile, and those errors were still present; no commit from `82c4c0e` onward has compiled. Uncommitted, unexecuted fixes exist for the workflow/guards/manifests and for all 13 compile-error sites found by a file-by-file static review (manifest `.v17_2`, missing returns, undeclared `typeScale`, non-existent/unavailable SwiftUI API, an invalid `frame` overload, a missing CoreMedia argument label, DAT reader/encoder, two test errors). Apple build and test proof pending |
| **P0-02** | `DECISIONS.md` ρητό **v1 simulation-only** **ή** DAT SPM wired + non-sim connect χωρίς fake | `SW`/`DEV` | decisions-dat | DAT 1.0.1 setup, registration/session, explicit camera permission, publisher bridge, and H.264 conversion have source but remain unbuilt/unverified; photo/audio/IMU remain stubs and the usable path stays simulation-only |
| **P0-05** | Installable app shell: Info.plist permissions + Xcode app target docs/scaffold (SPM library ≠ app) | `SW`/`MAC` | app-scaffold | ✅ `project.yml`, host entry point, Info.plist, privacy manifest, entitlements, and AppIcon asset are present; Apple build remains unverified |
| **P0-06** | Stage 6 **μόνο** με πραγματικό device failure report | `DEV` | stage6 | no device report |

---

## 1. Plan acceptance — A01–A16

### A01 — Offline note + restart
| | |
|---|---|
| **Plan scenario** | Σημείωση χωρίς AI/γυαλιά · ανάκτηση μετά restart |
| **Wired σήμερα** | `JSONFileStorageService` · R3-001 ISO8601 |
| **DoD 100% ready** | (1) XCTest `testJournalSurvivesRestartViaNewInstance` PASS σε Mac/GHA (2) DEVICE_TESTS DEV-02 PASS σε iPhone (3) Airplane Mode → note → kill → relaunch → ίδια `id`/`dateKey` |
| **Layers** | `SW` code ✅ · `MAC` XCTest · `DEV` iPhone |
| **Proof artifacts** | XCTest log · screenshot TodayView · HANDOFF line |

### A02 — Edit / search / date TZ
| | |
|---|---|
| **Plan scenario** | Επεξεργασία, αναζήτηση, διόρθωση ημερομηνίας χωρίς διπλότυπα |
| **Wired σήμερα** | R3-009 `makeDateKey` + `getEntriesForDate(_:displayTimeZone:)` |
| **DoD 100% ready** | (1) XCTest TZ day filter PASS (2) UI edit+search smoke (3) DEV-05b: αλλαγή TZ συσκευής · entry στη σωστή ημέρα |
| **Layers** | `SW` ✅ · `MAC` · `DEV` |

### A03 — Media attach
| | |
|---|---|
| **Plan scenario** | Φωτο/βίντεο/ήχος · thumbnails · playback · σωστές πηγές |
| **Source path** | `PhotosMediaPickerButton` in `TodayView` passes Photos file representations or scoped Files URLs to file-backed `MediaStorageService` sandbox copies |
| **DoD 100% ready** | (1) Photos/Files picker UI wired (2) πραγματικό αρχείο στο sandbox + thumbnail (3) playback από timeline (4) PathAsfaleia δεν σπάει attach |
| **Layers** | `SW` picker/import path wired · `MAC` XCTest and `DEV` picker/preview smoke test pending |

### A04 — Voice note dedup
| | |
|---|---|
| **Plan scenario** | Μία τελική σημείωση · όχι per-partial |
| **Wired σήμερα** | `VoiceCommandParser` dedup R3-006 |
| **DoD 100% ready** | (1) XCTest dedup PASS (2) device mic: μία note από «σημείωσε …» (3) optional `.m4a` setting documented — implemented 2026-10-13 as an opt-in Settings toggle that attaches the AAC dictation audio to the note (`SoftwareCompletionTests` covers the writer; device recording unverified) |
| **Layers** | `SW` ✅ · `DEV` mic · Hey Meta = separate backlog |

### A05 — Clip playable
| | |
|---|---|
| **Plan scenario** | Buffer 5/10s → playable clip στο timeline |
| **Wired σήμερα** | Sim placeholder MP4 + `isSimulationPlaceholder`; H.264 Annex-B remux and raw-to-H.264 conversion have source, but the live DAT path remains gated and unverified |
| **DoD 100% ready** | **Sim path:** `AVAsset.isPlayable == true` σε Mac + honest label. **Live path:** DAT NAL → remux playable, per-sample durations derived from strictly increasing PTS (last sample uses last observed interval), duration ≈ buffer · DEV-05 PASS |
| **Layers** | `SW` sim · `MAC` AVAsset · `DEV` Gen2 |
| **Honesty** | Sim-only v1 μπορεί να είναι «SW 100%» **μόνο** αν DECISIONS δηλώνει sim-only και UI δεν ισχυρίζεται LIVE hardware |

### A06 — Warm-up / disconnect / double trigger
| | |
|---|---|
| **Plan scenario** | Clip πριν γεμίσει buffer · reconnect · καμία ψεύτικη επιτυχία |
| **Wired σήμερα** | Swift rolling-buffer warm-up exports the captured interval and resets generation on disconnect; XCTest covers short warm-up · device concurrency proof pending |
| **DoD 100% ready** | (1) XCTest shorter duration when buffer < target (2) disconnect mid-stream → clear state · νέο buffer μετά reconnect (3) no «Αποθηκεύτηκε» χωρίς file |
| **Layers** | `SW`/`MAC` · `DEV` concurrency |

### A07 — Background / lock
| | |
|---|---|
| **Plan scenario** | Επαληθευμένη συμπεριφορά ή ρητή «σταμάτησε» |
| **Wired σήμερα** | Policy in code · device proof 🚫 |
| **DoD 100% ready** | (1) Foreground/background/lock matrix στο DEVICE_TESTS filled (2) UI shows PAUSED όχι LIVE όταν session κλείνει (3) καμία υπόσχεση continuous capture χωρίς proof |
| **Layers** | `DEV` (απαραίτητο) |

### A08 — Obsidian export ×2
| | |
|---|---|
| **Plan scenario** | Files picker · export δύο φορές · χωρίς διπλότυπα |
| **Wired σήμερα** | `SettingsView.fileImporter` folder picker → Obsidian vault selection/bookmark; idempotent export markers |
| **DoD 100% ready** | (1) UIDocumentPicker / security-scoped bookmark (2) 2× export = ίδια IDs (3) Markdown αναγνώσιμο χωρίς app |
| **Layers** | `SW` picker/export path wired · `MAC` tests and `DEV` repeat-export on a real vault pending |

### A09 — External conflict
| | |
|---|---|
| **Plan scenario** | Εξωτερική αλλαγή Obsidian → conflict sidecar · όχι silent overwrite |
| **Wired σήμερα** | R3-005 sidecar |
| **DoD 100% ready** | (1) XCTest conflict PASS (2) πραγματικό vault: edit σε Obsidian → sidecar εμφανίζεται (3) local journal άθικτο |
| **Layers** | `SW`/`MAC` · `DEV` vault |

### A10 — Direct + Hermes
| | |
|---|---|
| **Plan scenario** | Και οι δύο διαδρομές με πραγματικό context · χωρίς silent failover |
| **Wired σήμερα** | Adapters + Keychain · live 🚫 · SEC-004/007 ✅ CLOSED |
| **DoD 100% ready** | (1) Live Direct HTTPS reply με real key (2) Live Hermes LAN/VPN reply (3) empty key → 7004/7104 (4) HTTPS/allowlist enforced (SEC-004/007 CLOSED) (5) provider switch manual only |
| **Layers** | `SW` guards · `DEV` credentials |

### A11 — What am I seeing + day summary
| | |
|---|---|
| **Plan scenario** | Ένα καρέ → vision reply · ημερήσια σύνοψη |
| **Wired σήμερα** | Photos picker and `capturePhoto` paths; result can be saved on request or spoken with TTS. Live provider credentials and DAT multi-frame decoding remain unverified/unavailable |
| **DoD 100% ready** | (1) Photo από glasses **ή** Photos picker fallback (2) real vision reply (3) optional save + TTS (4) όχι continuous stream to AI |
| **Layers** | `SW` photo picker/vision path · `DEV` configured endpoint credentials and live glasses/DAT |

### A12 — Memory recall
| | |
|---|---|
| **Plan scenario** | «τι ήθελα να πω…» → απάντηση από υπαρκτές καταγραφές + links |
| **Wired σήμερα** | Keyword recall + AI path |
| **DoD 100% ready** | (1) Seed entries με γνωστό κείμενο (2) query επιστρέφει source IDs (3) empty → «δεν βρέθηκαν» όχι hallucination (4) live AI optional αλλά honesty OK |
| **Layers** | `SW` keyword · `DEV` live AI polish |

### A13 — Agent folder
| | |
|---|---|
| **Plan scenario** | Memory/Preferences/Open-loops επεξεργάσιμα · accept → persist |
| **Wired σήμερα** | `AgentFolderManager` + UI · device sync 🚫 |
| **DoD 100% ready** | (1) Empty templates OK (CQ-P0-001) (2) edit+accept survives restart (3) export στο Obsidian Agent/ (4) conflict rules documented |
| **Layers** | `SW` · `DEV` Files |

### A14 — Observation game
| | |
|---|---|
| **Plan scenario** | Αποστολή → capture → honest eval → next |
| **Wired σήμερα** | `ObservationGameEngine` · G5-002 streak · device vision 🚫 |
| **DoD 100% ready** | (1) Manual confirm path labeled non-AI (2) AI eval μόνο με real vision (3) streak μόνο σε success (4) DEV-10 PASS |
| **Layers** | `SW` engine · `DEV` vision |

### A15 — Backup / restore
| | |
|---|---|
| **Plan scenario** | Backup → clean storage → restore IDs/links |
| **Wired σήμερα** | `BackupRestoreEngine` · device restore 🚫 |
| **DoD 100% ready** | (1) XCTest no-dupe IDs (2) restore σε καθαρό sandbox (3) media + Agent memory intact (4) PathAsfaleia on restore paths |
| **Layers** | `SW`/`MAC` · `DEV` |

### A16 — Permissions / secrets / disk
| | |
|---|---|
| **Plan scenario** | API fail / permission deny / disk full → clear error · data safe |
| **Wired σήμερα** | Keychain + guards · device permissions 🚫 |
| **DoD 100% ready** | (1) Info.plist permission strings (2) deny camera/mic/speech → UI error (3) disk-full path tested or documented (4) secrets never in logs/exports |
| **Layers** | `SW` Keychain · `MAC` plist · `DEV` prompts |

---

## 2. Wave-B — 20 Super Features (FREEZE policy · DoD still required)

> Policy AUDIT_FINAL: **FREEZE** για νέο scope. «100% ready» για κάθε item = **wire+proof** **ή** **Experimental/`#if` + honest STATUS** (όχι orphan hold).

| # | Feature | Primary file | Current honesty | DoD 100% ready | Layer |
|---|---|---|---|---|---|
| B01 | Acoustic auto-clip | `AcousticTriggerService` | disabled · simulation-only sample plumbing · no live DAT microphone feed · ready=false; DAT camera PCM extension is experimental and unwired; current microphone usage text covers voice notes only | Before DAT audio permission, revise microphone disclosure; implement and validate the permission/route flow, PCM-to-RMS mapping, app flow, and device behavior before enabling; otherwise keep frozen | `DEV`/`ORPHAN` |
| B02 | Head double-nod | `HeadGestureDetector` | disabled · simulation-only sample plumbing · no live DAT IMU feed · ready=false; detector now counts completed pitch troughs above 0.40 rad with inclusive 0.25–1.0s spacing; experimental `MWDATMotion` is not linked and requires Developer Center approval | Map optional orientation samples into the existing pitch contract, then validate real callbacks, detector thresholds, app flow, and device behavior before enabling; otherwise keep Experimental/frozen | `DEV`/`ORPHAN` |
| B03 | Spatial audio | `Experimental/SpatialAudioProcessor` | Experimental orphan · P1-04 ✅ | Keep Experimental **ή** wire σε mux | `ORPHAN` ✅ |
| B04 | Adaptive battery stream | `MetaGlassesAdapter` | sim battery path | Real battery telemetry → FPS/bitrate · Gen2 proof | `DEV` |
| B05 | Earcons | `EarconFeedbackService` | AudioServices system sounds on clip-save/error paths; OS controls output routing, with no direct glasses route | Keep current app events; verify audio behavior on Apple device before claiming a glasses route | `SW`/`DEV` |
| B06 | On-device Vision OCR | `OnDeviceVisionService` + `OnDeviceVisionAnalysisPipeline` + `AppState.executeWhatAmISeeing` | Local OCR now runs before optional cloud description; isolated pipeline tests pass, but native Vision OCR and image recognition still need Apple-device verification | VN request PASS σε device | `SW source-tested` / `DEV` pending |
| B07 | Multi-frame vision | `AIRouter.askWhatAmISeeingMultiFrames` + `AppState.executeWhatAmISeeing` | AppState submits available buffer keyframes when at least two exist; the live DAT H264→image feed is still unavailable and keyframe capture remains unverified | Produce 3–4 real keyframes from DAT buffer · live vision | `SW caller-wired` / `DEV` pending |
| B08 | Proximity alerts | `Experimental/ProximityAlertManager` | Experimental orphan · no location/vision feed or product caller · readiness false | Keep Experimental · **ή** wire a real feed + cooldown | `ORPHAN` ✅ / `DEV` if wired |
| B09 | Transcript keyword cues | `TranscriptKeywordTagger` via `AppState.addNote` | Greek/English keyword cues use word/phrase boundaries, are visibly labeled `κείμενο: …`, and pass 5/5 isolated regression tests; no acoustic emotion inference is claimed | Keep wording text-based; audio prosody analysis is outside current implementation | `SW source-tested` |
| B10 | PII scrubber | `OutboundPIIRedactor` in shared chat request builder | Common email, mod-97-checksum-valid IBAN, Luhn-valid payment-card, US SSN, contextual Greek AFM, and phone patterns are scrubbed from outbound text; tests cover provider-bound requests | Best-effort only: image pixels, names, and free-form addresses are not inferred; Apple provider/device path validation remains pending | `SW` |
| B11 | Obsidian Canvas | `ObsidianCanvasGenerator` | wired fail-closed G5-003 | Export opens in Obsidian · nodes match entries | `SW`/`DEV` |
| B12 | File watcher | `Experimental/ObsidianFileWatcher` + AppState + Settings | Debounced directory-entry hints for root and nested directories; reconciles new/removed directories and skips symlink subtrees; no content reads/sync or reliable file-content edit detection | Apple Files-provider/security-scope/device validation; keep readiness false meanwhile | `SW source-tested` / `DEV pending` |
| B13 | Dataview YAML | ObsidianVaultBridge frontmatter | Exported daily-note metadata plus a Dataview query and schema-template example are documented; no synthetic journal entry is included | Query/template docs are source-backed; actual Obsidian plugin rendering remains unverified | SW source/docs · vault review pending |
| B14 | Daily podcast | `DailyPodcastGenerator` | wired · G5-005/P2-020 | Summarize→speech completion-at-end · device hear | `SW`/`DEV` |
| B15 | Scavenger streaks | `ScavengerHuntStreakManager` | wired G5-002/P2-024 | Persist survives restart · badge unlock proof | `SW`/`MAC` |
| B16 | Time Capsule | `TimeCapsuleEngine` | wired TodayView | TZ-aware anniversary entries on device | `SW`/`DEV` |
| B17 | Highlight reel | `HighlightReelMuxer` + `HighlightReelJournalCommitter` | AVComposition G5-001; verified video is attached to a journal entry for in-app playback | `AVAsset.isPlayable` reel σε Mac · ≥2 clips · journal reference + attachment playback | `MAC`/`DEV` |
| B18 | Watermark export | `Experimental/ClipWatermarkExporter` + `MediaViewerSheet` | AVFoundation/Core Animation overlay exporter and gated share action implemented; `ready=false` pending Apple validation | Run Apple build and fixture render/playability test, compare result in Simulator/device, then reassess readiness | `SW pending` / `MAC` / `DEV` |
| B19 | Metal frame pool | `Experimental/MetalFrameBufferPool` | Experimental orphan · P1-04 ✅ | Keep Experimental **ή** real Metal | `ORPHAN` ✅ |
| B20 | Watch companion | `WatchConnectivityCoordinator` | schema-only latent coordinator · ready=false · no watchOS target or Watch UI; AppState callbacks and state updates are gated | Keep latent + UI hidden **ή** add watchOS target and clip/note E2E | `SW gate/docs ✅` / `DEV` if integrated |

---

## 3. Wave-C — Batch 7 (FREEZE)

| # | Feature | File | Current honesty | DoD 100% ready | Layer |
|---|---|---|---|---|---|
| C01 | Vector search | `Experimental/PseudoLexicalVectorSearchEngine` | FNV pseudo · no product caller · ready=false | Keep Experimental · **ή** real CoreML + UI search | `ORPHAN` ✅ / `DEV` if wired |
| C02 | Turn-taking | `Experimental/TurnTakingGuard` | no VAD/mic feed or speech caller · ready=false | Keep Experimental · **ή** wire VAD/mic gate into speech | `ORPHAN` ✅ / `DEV` if wired |
| C03 | Remote mirror | `RemoteMirrorStreamServer` | AUTH + Release kill · ready=false | TLS identity πριν ready=true · frames από buffer | `SW` harden ✅ · `DEV` frames |
| C04 | Knowledge graph | `AssociativeKnowledgeGraphEngine` | Local text-pattern heuristic exported as Mermaid; entity, place, and topic candidates are trimmed and whitespace-only candidates are discarded | Export non-empty · Obsidian opens · no fake success | `SW` source path; Obsidian rendering remains pending |
| C05 | Hyperlapse | `Experimental/HyperlapseTripCompressor` | Experimental GPS-sample frame selection only; no location/camera capture, video mux, or UI; registry remains not ready | Keep Experimental **ή** mux playable video from real inputs | `ORPHAN` ✅ / `DEV` if wired |
| C06 | Whisper offline | `Experimental/LocalWhisperOfflineService` | fail-closed stub · no model weights, product caller, or UI claim · ready=false | Keep Experimental stub and do not claim offline Whisper · **ή** bundle/validate real model | `SW honesty / ORPHAN` ✅ · `DEV` if model |
| C07 | Meal nutrition | `MealNutritionVisionLogger` | heuristic tokens | Label always «estimate» · optional HealthKit later backlog | `SW` honesty OK if labeled |

---

## 4. Security residuals (cross-cutting DoD)

| ID | DoD CLOSED | Touches |
|---|---|---|
| **SEC-001 AUTH** | DEBUG-only authenticated listener; production pairing/provisioning is incomplete | Mirror |
| **SEC-001-TLS** | Release listener fails closed; TLS identity and secure frame delivery are absent; `mirror.ready=false` | Mirror · AppState |
| **SEC-002** | ✅ PathAsfaleia | Media/Backup/Obsidian |
| **SEC-003** | ✅ schema (latent χωρίς Watch) | WatchConnectivity |
| **SEC-004** | ✅ Hermes rejects non-HTTPS except LAN allowlist | HermesConnector · Settings |
| **SEC-005** | ✅ status-only errors | Hermes/Direct |
| **SEC-007** | Fixed allowlist: localhost, RFC1918, IPv4 link-local, Tailscale `100.64/10`, and `.local`; no configurable VPN CIDR | HermesConnector · Settings |

---

## 5. Lane ownership map (για parallel agents)

| Lane ID | Features | Forbidden overlap |
|---|---|---|
| `L-CORE-A01-A03` | Journal/media | AppState mega-refactor |
| `L-CLIP-A05-A07` | Buffer/clip/lifecycle | Mirror TLS |
| `L-OBS-A08-A09-A13` | Obsidian/agent | FileWatcher orphan decision only |
| `L-AI-A10-A12` | Direct/Hermes/recall + SEC-004/007 | Mirror |
| `L-VISION-A11-A14` | WhatAmISeeing + game | Buffer remux |
| `L-BACKUP-A15-A16` | Backup + permissions plist | — |
| `L-WAVEB-ORPHANS` | B03/B12/B18/B19 Experimental wrap | Don't delete without matrix update |
| `L-WAVEC-MIRROR` | C03 TLS + frame gate | Don't touch Hermes |
| `L-WAVEC-CLIP-RENAME` | C01 rename honesty | Don't touch Mirror |
| `L-PLATFORM` | P0-02 DECISIONS · P0-05 scaffold · docs sync | No Stage 6 |
| `L-INTEGRATOR` | **this matrix** · conflict merge · verify harness · HANDOFF | No large Sources edits while siblings run |

---

## 6. Definition of «software 100%» vs «product 100%»

| Goal | Criteria |
|---|---|
| **Software 100% (no Gen2/Mac)** | Όλα τα `SW` DoD items CLOSED · orphans resolved (wire ή Experimental) · SEC-004/007 + TLS-gate CLOSED · DECISIONS sim-only · docs honest · CI `python-verify` (five source guards) and `portable-harnesses` (Linux) PASS on the current head; this replaces the earlier "Python verify 4/4", which referred to the archived `diagnose_stage*` scripts · **χωρίς** fake device claims |
| **Engineering soft-GO** | Software 100% + P0-01 Mac/`swift test` green + app target scaffold |
| **Product / Gen2 100%** | Όλα A01–A16 `DEV` PASS · DAT live · Stage 6 device report closed · 0 CRITICAL/HIGH SEC open |

**Integrator rule:** Μην δηλώσεις CreateGoal complete αν μένει οποιοδήποτε `SW` gap ανοιχτό.

---

## 7. Verification contract (όλα τα lanes)

Τρέχον contract (2026-10-13): τα jobs του `.github/workflows/swift-ci.yml`.

```text
python-verify       verify_all_subsystems.py (10 illustrative sections), verify_theme_apple_meta_compliance.py,
                    verify_assistant_chat_context.py, verify_transcript_keyword_tagging.py, verify_ui_source_contracts.py
portable-harnesses  19 isolated production-source XCTest harnesses + focused/source probes (Linux swift:6.1)
build-and-test      swift build --build-tests + swift test (macos-26, Xcode 26.4+)
package-ios-app     XcodeGen + generic iOS / Simulator builds + unsigned IPA (needs the three jobs above)
```

Πρέπει: όλα τα jobs πράσινα στο τρέχον head. Νέοι source guards μπαίνουν στο `python-verify` και νέα harnesses στο `portable-harnesses`, μόνο αν δεν σπάνε sibling WIP (integrator owns harness).

Ιστορικό: το παλιό contract έτρεχε `diagnose_stage3_defects.py`, `diagnose_stage4_fixes.py`, `diagnose_stage5_finalize.py` και `verify_all_subsystems.py` («verify_all 7/7 phases»). Τα `diagnose_stage*` είναι πλέον αρχειοθετημένα διαγνωστικά, όχι CI gates (βλ. `verification/README.md`).

---

## 8. Pointer map

```text
THIS MATRIX     docs/GOAL_100_FEATURE_MATRIX.md
Current status  docs/IMPLEMENTATION_STATUS.md
Capability map  docs/CAPABILITY_MATRIX.md
Remediation     docs/FINDINGS_REMEDIATION.md
Historical audit snapshot  docs/AUDIT_FINAL.md
Status A-IDs    docs/IMPLEMENTATION_STATUS.md
Device protocol docs/DEVICE_TESTS.md
Handoff         docs/HANDOFF_R0lling_2026-10-12.md   (current; 2026-10-11 is styling history)
Cross-platform  docs/MULTIPLATFORM_ROADMAP.md · docs/CROSS_PLATFORM_DATA_CONTRACT.md · docs/CROSS_PLATFORM_FEATURE_PARITY.md · docs/ADR_0001_ANDROID_WINDOWS_CLIENT_STACK.md
Progress rollup docs/GOAL_100_PROGRESS.md   (integrator updates after re-scan)
```

---

---

## 9. Sibling integration snapshot (post SW residuals ~19:35)

> Status από lane notes + FeatureReadinessRegistry + A15/A16/P0 scaffold + verify.

### Plan A-IDs — source inventory (not completion status)

The rows below identify code paths and outstanding proof. Their labels are not pass marks. Selected isolated Linux SwiftPM suites have run (including 15 journal cases and, in the latest continuation, 12 Hyperlapse cases); the complete Apple XCTest target, Apple build, iPhone, and Gen 2 verification have not run.

| ID | Source path / current scope | Verification status |
|---|---|---|
| A01 | Journal persistence and restart path | 15 isolated Linux XCTest cases passed across journal storage and protocol compatibility; full Apple target remains unrun |
| A02 | Edit/search/date filtering | Some date/search logic has isolated coverage; full Apple XCTest and UI smoke remain unrun |
| A03 | Photos/Files media import, sandbox storage and preview | XCTest/device picker smoke not run |
| A04 | Speech transcription and command parsing | XCTest/device microphone check not run |
| A05 | Simulation clip path; live DAT capture/remux remains unavailable | XCTest/AVFoundation/device checks not run |
| A06 | Buffer warm-up and disconnect handling | XCTest/device concurrency check not run |
| A07 | Background/lock pause policy | Device lifecycle check not run |
| A08 | Obsidian vault export and scoped access | Obsidian bridge/path harness passed 36/36 Linux-applicable tests at the 2026-10-11 baseline; Apple coordination, bookmarks, and Files-provider validation remain open |
| A09 | Obsidian conflict sidecars | Hash persistence and root-level sidecar reuse pass in the 36/36 isolated harness (2026-10-11 baseline); Apple coordination and Files-provider behavior remain open |
| A10 | Direct API/Hermes adapters and settings | XCTest/live endpoint check not run |
| A11 | Photos vision/OCR fallback; DAT multi-frame path unavailable | Local-first OCR orchestration passes 5/5 Linux-applicable tests; native Vision, Apple build, live provider reply, and DAT multi-frame capture remain unverified |
| A12 | Keyword recall; semantic embeddings unavailable | XCTest/live AI polish not run |
| A13 | Agent memory folder and preferences | Agent transaction, symlink, and size tests are included in the 36/36 Obsidian harness (2026-10-11 baseline); Apple Files-provider export remains unverified |
| A14 | Observation game and fail-closed evaluation | XCTest/device flow not run |
| A15 | Plain JSON backup bundle, Files export/restore | BackupRestoreTests passed 16/16 Linux-applicable cases in the isolated harness at the 2026-10-11 baseline (iOS protection case excluded); Files-provider export and full Apple target remain unrun |
| A16 | Error taxonomy and privacy declarations | XCTest/Apple build not run |

**Device-proven:** ακόμα **0 / 16**.

### Wave-B/C via `FeatureReadinessRegistry`

| ready=true (source registry flag) | ready=false (source registry flag) |
|---|---|
| earcon · timeCapsule · highlightReel · podcast · canvas · KG · emotionTags · scavengerStreak · appleSpeech · onDeviceVisionOCR · entityTags · nutritionHeuristic · dataviewFrontmatter | acoustic · headGesture · spatial · metal · watermark · fileWatcher · proximity · watch · pseudoVector · turnTaking · **mirror** · hyperlapse · whisperStub · multiFrameVision · adaptiveBattery |

B08/C01/C02/C05/C06 no-caller helpers now use the Experimental placement permitted by the freeze policy; their readiness flags remain false. Tests/build have not run for these path moves.
`adaptiveBattery` stays disabled until real battery telemetry and DAT are available.
Mirror remains disabled until its live transport path is implemented and verified.

### P0 gates

| ID | Status |
|---|---|
| **P0-01** Mac/`swift test` | Apple build/XCTest NOT RUN. WSL Swift parser passes; Linux package build stops at unavailable Apple `ImageIO`. Hosted CI on `b29429b` (run 38415047820) failed before `swift build`; run 37957186872 on `46fe025` was the last to compile and failed. The 2026-10-13 workflow and static compile fixes are uncommitted and unexecuted |
| P0-02 DAT vs sim | DAT 1.0.1, registration/DeviceSession, explicit camera-permission confirmation, bounded publisher adaptation, and raw-to-H.264 Annex-B conversion have source code but remain unbuilt/unverified with credentials/device. Photo/audio/IMU remain stubs, `einaiLiveYlopoiimeno` stays false, and simulation is the only usable path |
| P0-05 App target / Info.plist | Project scaffold and privacy plist are present; Apple build not run |
| P0-06 Stage 6 | NOT VERIFIED — no device failure report |

### Completion status

| Scope | Status |
|---|---|
| A01–A16 | Source inventory only; completion not established |
| Swift/Xcode runtime | Not run on this host |
| iPhone/Gen 2 behavior | Not verified; 0/16 device-proven A-IDs |
| Overall software objective | **NOT VERIFIED / INCOMPLETE** |

See [`IMPLEMENTATION_STATUS.md`](IMPLEMENTATION_STATUS.md), [`FINDINGS_REMEDIATION.md`](FINDINGS_REMEDIATION.md), and [`DEVICE_TESTS.md`](DEVICE_TESTS.md) for current scope and next validation steps.
