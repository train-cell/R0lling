# R0lling — GOAL 100% Feature Matrix (DoD)

```yaml
Last_Modified: 2026-10-06T19:35:00+03:00
role: integrator-orchestrator
canonical_audit: docs/AUDIT_FINAL.md
plan: R0lling-Project-Plan.md §12 A01–A16
policy: «100% ready» ≠ «wired» · wired = code path υπάρχει · ready = DoD checklist PASS
git_commit: NONE (docs + SW residuals · no commit)
sibling_rescan: 2026-10-06T19:35+03:00
```

**Σκοπός:** Ενιαίο contract για parallel feature lanes. Κάθε agent κλείνει **ένα** feature μέχρι το DoD του — όχι «wired αρκετά».

**Legend readiness**

| Tag | Σημασία |
|---|---|
| `SW` | Software-complete χωρίς Gen2/Mac runtime (μπορεί να κλείσει σε Windows + docs + static/Python) |
| `MAC` | Απαιτεί `swift test` / Xcode / `AVAsset` runtime |
| `DEV` | Απαιτεί iPhone / Gen2 / live credentials / Files picker / Watch |
| `ORPHAN` | Wave-B/C χωρίς caller — DoD = wire **ή** Experimental/`#if` + honest docs |
| `FREEZE` | Out-of-plan μέχρι A05/A10 device proof (wave D+) |

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
| **P0-01** | GHA `swift-ci` green **ή** local `swift test` PASS + log στο HANDOFF | `MAC` | mac-ci | Windows host · workflow ready |
| **P0-02** | `DECISIONS.md` ρητό **v1 simulation-only** **ή** DAT SPM wired + non-sim connect χωρίς fake | `SW`/`DEV` | decisions-dat | ✅ sim-only |
| **P0-05** | Installable app shell: Info.plist permissions + Xcode app target docs/scaffold (SPM library ≠ app) | `SW`/`MAC` | app-scaffold | ✅ `Apps/R0llingApp/` |
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
| **Wired σήμερα** | Media paths/`MediaStorageService` · Photos picker 🚫 |
| **DoD 100% ready** | (1) Photos/Files picker UI wired (2) πραγματικό αρχείο στο sandbox + thumbnail (3) playback από timeline (4) PathAsfaleia δεν σπάει attach |
| **Layers** | `SW` partial · `DEV` picker |

### A04 — Voice note dedup
| | |
|---|---|
| **Plan scenario** | Μία τελική σημείωση · όχι per-partial |
| **Wired σήμερα** | `VoiceCommandParser` dedup R3-006 |
| **DoD 100% ready** | (1) XCTest dedup PASS (2) device mic: μία note από «σημείωσε …» (3) optional `.m4a` setting documented |
| **Layers** | `SW` ✅ · `DEV` mic · Hey Meta = separate backlog |

### A05 — Clip playable
| | |
|---|---|
| **Plan scenario** | Buffer 5/10s → playable clip στο timeline |
| **Wired σήμερα** | Sim placeholder MP4 + `isSimulationPlaceholder` · DAT remux 🚫 |
| **DoD 100% ready** | **Sim path:** `AVAsset.isPlayable == true` σε Mac + honest label. **Live path:** DAT NAL → remux playable + duration ≈ buffer · DEV-05 PASS |
| **Layers** | `SW` sim · `MAC` AVAsset · `DEV` Gen2 |
| **Honesty** | Sim-only v1 μπορεί να είναι «SW 100%» **μόνο** αν DECISIONS δηλώνει sim-only και UI δεν ισχυρίζεται LIVE hardware |

### A06 — Warm-up / disconnect / double trigger
| | |
|---|---|
| **Plan scenario** | Clip πριν γεμίσει buffer · reconnect · καμία ψεύτικη επιτυχία |
| **Wired σήμερα** | Warm-up math (Python) · concurrency device 🚫 |
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
| **Wired σήμερα** | Idempotent markers · Files picker 🚫 |
| **DoD 100% ready** | (1) UIDocumentPicker / security-scoped bookmark (2) 2× export = ίδια IDs (3) Markdown αναγνώσιμο χωρίς app |
| **Layers** | `SW` export logic ✅ · `DEV` picker |

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
| **Wired σήμερα** | Path + `capturePhoto` · live vision 🚫 |
| **DoD 100% ready** | (1) Photo από glasses **ή** Photos picker fallback (2) real vision reply (3) optional save + TTS (4) όχι continuous stream to AI |
| **Layers** | `SW` path · `DEV` vision |

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
| B01 | Acoustic auto-clip | `AcousticTriggerService` | gated OFF · no mic feed | Mic RMS → `processAudioLevel` · flag `true` · no false toast · **ή** remove hooks + doc FREEZE | `DEV`/`ORPHAN` |
| B02 | Head double-nod | `HeadGestureDetector` | gated OFF · no IMU | IMU feed από adapter · flag `true` · **ή** Experimental | `DEV`/`ORPHAN` |
| B03 | Spatial audio | `Experimental/SpatialAudioProcessor` | Experimental orphan · P1-04 ✅ | Keep Experimental **ή** wire σε mux | `ORPHAN` ✅ |
| B04 | Adaptive battery stream | `MetaGlassesAdapter` | sim battery path | Real battery telemetry → FPS/bitrate · Gen2 proof | `DEV` |
| B05 | Earcons | `EarconFeedbackService` | iOS system sounds | Earcon on clip/error paths · optional glasses audio route proof | `SW`/`DEV` |
| B06 | On-device Vision OCR | `OnDeviceVisionService` | held | Call από WhatAmISeeing prefilter · VN request PASS σε device | `DEV` |
| B07 | Multi-frame vision | `AIRouter.askWhatAmISeeingMultiFrames` | method exists · UI path thin | Sample 3–4 keyframes από buffer · live vision | `DEV` |
| B08 | Proximity alerts | `ProximityAlertManager` | held · no feed | Vision loop feed + cooldown · **ή** Experimental | `ORPHAN`/`DEV` |
| B09 | Voice emotion tags | `VoiceEmotionAnalyzer` | text heuristic in `addNote` | Prosody from audio **ή** rename to text-tag honesty + tests | `SW` |
| B10 | PII scrubber | `LocalEntityRecognizer` | held | Call before AI send · redaction unit tests | `SW` |
| B11 | Obsidian Canvas | `ObsidianCanvasGenerator` | wired fail-closed G5-003 | Export opens in Obsidian · nodes match entries | `SW`/`DEV` |
| B12 | File watcher | `Experimental/ObsidianFileWatcher` | Experimental orphan · P1-04 ✅ | Keep Experimental **ή** wire σε bridge | `ORPHAN` ✅ |
| B13 | Dataview YAML | `ObsidianVaultBridge` frontmatter | export path | Dataview query sample in docs + export sample file | `SW` |
| B14 | Daily podcast | `DailyPodcastGenerator` | wired · G5-005/P2-020 | Summarize→speech completion-at-end · device hear | `SW`/`DEV` |
| B15 | Scavenger streaks | `ScavengerHuntStreakManager` | wired G5-002/P2-024 | Persist survives restart · badge unlock proof | `SW`/`MAC` |
| B16 | Time Capsule | `TimeCapsuleEngine` | wired TodayView | TZ-aware anniversary entries on device | `SW`/`DEV` |
| B17 | Highlight reel | `HighlightReelMuxer` | AVComposition G5-001 | `AVAsset.isPlayable` reel σε Mac · ≥2 clips | `MAC`/`DEV` |
| B18 | Watermark export | `Experimental/ClipWatermarkExporter` | Experimental orphan · P1-04 ✅ | Keep Experimental **ή** wire σε share | `ORPHAN` ✅ |
| B19 | Metal frame pool | `Experimental/MetalFrameBufferPool` | Experimental orphan · P1-04 ✅ | Keep Experimental **ή** real Metal | `ORPHAN` ✅ |
| B20 | Watch companion | `WatchConnectivityCoordinator` | schema SEC-003 · no Watch target | watchOS target + clip/note E2E **ή** document latent + hide UI | `DEV` |

---

## 3. Wave-C — Batch 7 (FREEZE)

| # | Feature | File | Current honesty | DoD 100% ready | Layer |
|---|---|---|---|---|---|
| C01 | Vector search | `PseudoLexicalVectorSearchEngine` | FNV pseudo · ready=false | Rename ✅ · UI search **ή** real CoreML (DEV) | `SW` rename ✅ |
| C02 | Turn-taking | `TurnTakingGuard` | no VAD | VAD/mic gate στο speech · **ή** Experimental | `ORPHAN`/`DEV` |
| C03 | Remote mirror | `RemoteMirrorStreamServer` | AUTH + Release kill · ready=false | TLS identity πριν ready=true · frames από buffer | `SW` harden ✅ · `DEV` frames |
| C04 | Knowledge graph | `AssociativeKnowledgeGraphEngine` | heuristic Mermaid | Export non-empty · Obsidian opens · no fake success | `SW` (partial ready) |
| C05 | Hyperlapse | `HyperlapseTripCompressor` | GPS math · no mux | AV mux output playable **ή** Experimental | `ORPHAN`/`DEV` |
| C06 | Whisper offline | `LocalWhisperOfflineService` | stub fail-closed | Real model **ή** keep stub + UI never claims offline STT | `SW` honesty / `DEV` model |
| C07 | Meal nutrition | `MealNutritionVisionLogger` | heuristic tokens | Label always «estimate» · optional HealthKit later backlog | `SW` honesty OK if labeled |

---

## 4. Security residuals (cross-cutting DoD)

| ID | DoD CLOSED | Touches |
|---|---|---|
| **SEC-001 AUTH** | ✅ CLOSED stub (pairing + AUTH before pool) | Mirror |
| **SEC-001-TLS** | ✅ kill-in-Release · TLS identity πριν `mirror.ready=true` | Mirror · AppState |
| **SEC-002** | ✅ PathAsfaleia | Media/Backup/Obsidian |
| **SEC-003** | ✅ schema (latent χωρίς Watch) | WatchConnectivity |
| **SEC-004** | ✅ Hermes rejects non-HTTPS except LAN allowlist | HermesConnector · Settings |
| **SEC-005** | ✅ status-only errors | Hermes/Direct |
| **SEC-007** | ✅ URL allowlist localhost + RFC1918 (+ optional VPN CIDR) | HermesConnector · Settings |

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
| **Software 100% (no Gen2/Mac)** | Όλα τα `SW` DoD items CLOSED · orphans resolved (wire ή Experimental) · SEC-004/007 + TLS-gate CLOSED · DECISIONS sim-only · docs honest · Python verify 4/4 PASS · **χωρίς** fake device claims |
| **Engineering soft-GO** | Software 100% + P0-01 Mac/`swift test` green + app target scaffold |
| **Product / Gen2 100%** | Όλα A01–A16 `DEV` PASS · DAT live · Stage 6 device report closed · 0 CRITICAL/HIGH SEC open |

**Integrator rule:** Μην δηλώσεις CreateGoal complete αν μένει οποιοδήποτε `SW` gap ανοιχτό.

---

## 7. Verification contract (όλα τα lanes)

Μετά κάθε lane merge (όχι mid-edit):

```text
python verification/diagnose_stage3_defects.py
python verification/diagnose_stage4_fixes.py
python verification/diagnose_stage5_finalize.py
python verification/verify_all_subsystems.py
```

Πρέπει: EXIT 0 · stage5 includes SEC suite · verify_all 7/7 phases.  
Νέα DoD checks → πρόσθεσε στο `diagnose_stage5` **μόνο** αν δεν σπάει sibling WIP (integrator owns harness).

---

## 8. Pointer map

```text
THIS MATRIX     docs/GOAL_100_FEATURE_MATRIX.md
CTO audit       docs/AUDIT_FINAL.md
Status A-IDs    docs/IMPLEMENTATION_STATUS.md
Device protocol docs/DEVICE_TESTS.md
Handoff         docs/HANDOFF.md
Progress rollup docs/GOAL_100_PROGRESS.md   (integrator updates after re-scan)
```

---

---

## 9. Sibling integration snapshot (post SW residuals ~19:35)

> Status από lane notes + FeatureReadinessRegistry + A15/A16/P0 scaffold + verify.

### Plan A-IDs — software DoD (όχι device)

| ID | SW DoD | Evidence lane / harness |
|---|---|---|
| A01 | ✅ SW | stage5 A01 + Journal XCTest · `diagnose_journal_media_a01_a03` |
| A02 | ✅ SW | EntryEditorSheet · search/TZ APIs · stage5 A02 |
| A03 | ✅ SW | PhotosMediaPicker · MediaStorageTests · stage5 A03 |
| A04 | ✅ SW | `LANE_VOICE_GAME` · SpeechStopResult · stage5 A04 |
| A05 | ✅ SW sim | `LANE_CLIP_META` · placeholder playable · remux 3010 χωρίς NAL |
| A06 | ✅ SW | warm-up + disconnect generation · concurrent 3012 |
| A07 | ✅ SW policy | ScenePhase PAUSED · `promisesContinuousBackgroundCapture=false` |
| A08 | ✅ SW | `LANE_OBSIDIAN` · Files picker + VaultBookmarkStore |
| A09 | ✅ SW | conflict sidecar + hash persist · stage5 A08/A09 |
| A10 | ✅ SW adapters | HermesEndpointAsfaleia SEC-004/007 · DECISIONS §3 · live creds = DEV |
| A11 | ✅ SW path | OCR wired · live vision reply = DEV |
| A12 | ✅ SW keyword | recall path · live AI polish = DEV |
| A13 | ✅ SW | AgentFolder + PathAsfaleia · device accept/export = DEV |
| A14 | ✅ SW | `LANE_VOICE_GAME` · fail-closed verdicts · Photos fallback |
| A15 | ✅ SW | Backup+agent+media · clean restore XCTest · Files picker · PathAsfaleia |
| A16 | ✅ SW | `AppErrorTaxonomy` · disk-full · `Apps/R0llingApp/Info.plist` privacy |

**Device-proven:** ακόμα **0 / 16**.

### Wave-B/C via `FeatureReadinessRegistry`

| ready=true (UI OK) | ready=false (hidden / orphan honesty) |
|---|---|
| earcon · timeCapsule · highlightReel · podcast · canvas · KG · emotionTags · scavengerStreak · appleSpeech · onDeviceVisionOCR · entityTags · nutritionHeuristic · dataviewFrontmatter · adaptiveBattery | acoustic · headGesture · spatial · metal · watermark · fileWatcher · proximity · watch · pseudoVector · turnTaking · **mirror** · hyperlapse · whisperStub · multiFrameVision |

C01 rename: `MobileCLIP*` → `PseudoLexicalVectorSearchEngine` ✅  
Orphans P1-04: `Sources/R0lling/Experimental/` (Spatial · Metal · Watermark · FileWatcher) ✅  
AppState P1-05: DEFERRED split · orphans off AppState · DECISIONS §6 ✅  
Mirror: AUTH + Release kill · `ready=false` μέχρι TLS+frames ✅ honesty

### P0 gates

| ID | Status |
|---|---|
| P0-01 Mac/`swift test` | 🚫 BLOCKED — checklist `DEVICE_TESTS.md` §3 · workflow ready · **green log 🚫** |
| P0-02 DAT vs sim | ✅ `DECISIONS.md` §2 simulation-only |
| P0-05 App target / Info.plist | ✅ `Apps/R0llingApp/` scaffold + privacy plist + Mac README |
| P0-06 Stage 6 | 🚫 no device failure report |

### Software % (honest post CreateGoal SW close)

| Scope | % |
|---|---|
| Plan SW DoD (A01–A16 software rows) | **100%** (16/16 SW ✅ · DEV proofs ξεχωριστά) |
| Wave-B/C honesty (Experimental + ready flags) | **100%** SW honesty (orphans Experimental · rename done) |
| **Software objective (P0/P1 SW · χωρίς device/Mac runtime)** | **SATISFIED** — βλ. `GOAL_100_PROGRESS.md` |
| Engineering soft-GO (needs P0-01 green) | **όχι** μέχρι GHA/`swift test` proof |
| Product / Gen2 | **~5%** (0 device A-IDs) |

*CreateGoal SW close · Experimental orphans · no git commit · parent κρίνει UpdateGoal.*
