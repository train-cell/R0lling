# R0lling — Architecture / Plan Compliance Audit

**Ημερομηνία:** 2026-10-06  
**Lane:** Architecture / Plan compliance  
**Workspace:** `C:\Users\skyd3\antigarvity\R0lling`  
**Πηγές:** `R0lling-Project-Plan.md`, `R0lling-Model-Assignments.md`, `docs/GEMINI_AUDIT.md`, `HANDOFF.md`, `CAPABILITY_MATRIX.md`, `IMPLEMENTATION_STATUS.md`, `TECHNICAL_BLUEPRINT.md`, `INTEGRATION_CONTRACTS.md`, Sources tree  
**Scope:** Layering, plan phases A01–A16 wiring, Gemini wave-B/C drift, architectural risks  
**Git / Stage 6:** χωρίς commit · χωρίς Stage 6

---

## 0. Executive verdict

Η **πυρηνική αρχιτεκτονική του plan (Φάσεις 1–6)** υπάρχει ως πραγματικά modules με DI στο `AppState` — όχι mockup-only.  
Η **συμμόρφωση με το plan** είναι **μερική**: τοπικό ημερολόγιο / buffer sim / Obsidian / δύο AI connectors / observation game = wired· Meta DAT = simulation-only· Xcode app target = λείπει (μόνο SPM library).

**Κρίσιμο drift:** Gemini wave-B (~20 super-features) και wave-C (batch-7) πρόσθεσαν modules **εκτός δεσμευτικού scope** του plan, πολλά με **hooks χωρίς feeds** ή **orphan math**. Αυτό διασπά το Clean Architecture boundary (UI/orchestration γεμίζει με dead engines) και δημιουργεί risk ψευδών claims.

**Blueprint vs code:** Blueprint προβλέπει SQLite/SwiftData · πραγματικότητα = `JSONFileStorageService`. Blueprint προβλέπει `AppCoordinator` · πραγματικότητα = fat `AppState` God-object.

---

## 1. Layering / Module Map

### 1.1 Intended layers (Plan §6 + Blueprint §2)

```text
┌─────────────────────────────────────────────────────────────┐
│  UI (SwiftUI) — Today / Calendar / Assistant / Settings     │
├─────────────────────────────────────────────────────────────┤
│  App / Orchestration — lifecycle, DI, session ownership     │
├──────────────┬──────────────┬──────────────┬────────────────┤
│ Persistence  │ Buffer       │ Glasses      │ Speech         │
│ Journal+Media│ Ring+Export  │ Meta DAT     │ Commands+STT   │
├──────────────┼──────────────┼──────────────┼────────────────┤
│ Obsidian     │ AI           │ Game         │ Core Models    │
│ Export+Agent │ Router+2×conn│ Observation  │ Domain types   │
└──────────────┴──────────────┴──────────────┴────────────────┘
         │                │
         ▼                ▼
   Local sandbox    Hermes / Direct API / Obsidian vault
```

### 1.2 Actual Sources tree (classification)

| Layer | Path | Classification | Verdict |
|---|---|---|---|
| **App** | `App/R0llingApp`, `AppState`, `WatchConnectivityCoordinator` | `[PROJECT]` | `[CORE]` + Watch = scaffold χωρίς Watch target |
| **Core** | `Models`, `Extensions`, `EarconFeedbackService`, `TimeCapsuleEngine` | `[PROJECT]` | Models = `[CORE]` · Earcon/TimeCapsule = plan-adjacent extras |
| **Persistence** | `JSONFileStorageService`, `MediaStorageService`, `BackupRestoreEngine`, protocols | `[PROJECT]` | `[CORE]` — **όχι** SQLite/SwiftData όπως Blueprint |
| **Buffer** | `RollingBufferService`, `PlayableClipExporter`, + wave extras | `[PROJECT]` | Ring+export = `[CORE]` · Metal/Spatial/Watermark/Mirror/Hyperlapse = orphans/partial |
| **Glasses** | `MetaGlassesAdapter`, protocol, `HeadGestureDetector` | `[PROJECT]` | Adapter = `[CORE]` sim-only · HeadGesture = dead feed |
| **Speech** | `VoiceCommandParser`, `SpeechTranscriptionService`, + wave extras | `[PROJECT]` | Parser+STT = `[CORE]` · Acoustic/Emotion/TurnTaking/Whisper = scaffold |
| **Obsidian** | `VaultBridge`, `AgentFolderManager`, Canvas, FileWatcher | `[PROJECT]` | Bridge+Agent = `[CORE]` · Canvas wired · Watcher orphan |
| **AI** | Protocol, Direct, Hermes, Router, Keychain + wave extras | `[PROJECT]` | Two connectors = `[CORE]` · CLIP/KG/Meal/Proximity = drift |
| **Game** | `ObservationGameEngine`, `ScavengerHuntStreakManager` | `[PROJECT]` | Engine = `[CORE]` plan · Streak = backlog scaffolding |
| **UI** | Theme, Components, Today/Calendar/Assistant/Settings | `[PROJECT]` | `[CORE]` Discord×Twitch tokens |
| **Tests** | 6 XCTest files | `[PROJECT]` | Insufficient vs A01–A16 · Mac `swift test` blocked |
| **Verification** | Python diagnose/verify | `[PROJECT]` | Schema/math mirrors ≠ Swift runtime proof |
| **DAT SDK** | `Package.swift` dependency σχολιασμένο | — | Missing external dep |

### 1.3 Runtime wiring hub

`AppState` είναι το **μοναδικό orchestration σημείο** (~478 LOC): κρατά όλα τα services, super-feature engines, και next-gen batch.  
Δεν υπάρχει ξεχωριστό `AppCoordinator` / JournalStore όπως Blueprint.

```text
UI Views
   │
   ▼
AppState  ──► storage / media / buffer / glasses / speech
          ──► obsidian / agent / aiRouter / game / backup
          ──► [wave-B engines held + hooks]
          ──► [wave-C engines held + partial UI]
```

**Dependency direction (πυρήνας):** UI → AppState → Services → Protocols.  
**Παραβίαση:** AppState γνωρίζει άμεσα ~15 extra engines (χωρίς protocol boundaries) → tight coupling + orphan retention.

---

## 2. Plan phases vs πραγματικό wiring

| Phase | Plan deliverable | Wiring reality | Gap |
|---|---|---|---|
| **0** Feasibility Gen 2 | DAT / Dev Mode / stream | Simulation-only · `#if canImport(MetaWearablesDAT)` κενό · error 4002 χωρίς SDK | **Blocked** — δεν υπάρχει πραγματικό DAT wiring |
| **1** Local journal | CRUD / search / media | `JSONFileStorage` + Today/Calendar UI + media paths | Wired · Photos picker device εκκρεμεί · όχι SwiftData |
| **2** Obsidian | Export + conflict | `ObsidianVaultBridge` + R3-005 sidecar · Agent folder | Wired · Files picker / vault proof device εκκρεμεί |
| **3** Camera / clip | Buffer 5–10s + Clip button | `RollingBufferService` + sim frames + AVAssetWriter placeholder | Wired sim · **όχι** DAT NAL remux |
| **4** Voice | note/clip commands | `VoiceCommandParser` + dedup + iOS Speech path | Wired · Hey Meta wake = blocked/experimental |
| **5** AI / agent | Two connectors + vision + recall | `DirectAPIConnector` + `HermesConnector` + `AIRouter` + Keychain | Wired adapters · live endpoints / vision device εκκρεμεί |
| **6** Game + polish | Observation game + backlog ideas | `ObservationGameEngine` + UI sheet · streak/podcast extras | Core game wired · polish extras = drift |

### Model-assignment compliance

| Stage | Assignment | Status |
|---|---|---|
| 1 Grok Blueprint | Blueprint / contracts / matrix / deps | ✅ υπάρχουν |
| 2 Gemini Implementation | Full first edition | ⚠️ core yes · **scope creep wave-B/C** |
| 3 Grok Review | GROK_REVIEW | ✅ |
| 4 Gemini Fixes | FIX_LOG · R3 closed | ✅ |
| 5 GPT Finalize | FINAL_REVIEW · Stage 5 docs | ✅ honesty pass |
| 6 Device | Prompt 06 | **Δεν εκτελείται** (σωστά — χωρίς device report) |

---

## 3. A01–A16 vs πραγματικό wiring

| ID | Plan scenario | Architectural wiring | Status |
|---|---|---|---|
| **A01** | Offline note + restart | `JSONFileStorage` ← `AppState.addNote` ← Today composer | ✅ path · 🚫 Mac XCTest |
| **A02** | Edit / search / date | Calendar + dateKey TZ (R3-009) | ✅ path · ⚠️ TZ XCTest pending |
| **A03** | Photo / video / audio | `MediaStorageService` paths | ⚠️ partial · Photos picker missing |
| **A04** | Voice note dedup | Speech → parser → single final note (R3-006) | ✅ path · 🚫 device mic |
| **A05** | Clip 5/10s playable | Buffer → `PlayableClipExporter` placeholder | ✅ sim · 🚫 DAT/device |
| **A06** | Warm-up / disconnect | Buffer math + glasses state | ⚠️ math · 🚫 device concurrency |
| **A07** | Background / lock | Policy στο adapter/docs | ⚠️ code policy · 🚫 device |
| **A08** | Obsidian export ×2 | Bridge idempotent markers | ✅ path · 🚫 Files picker |
| **A09** | External conflict | Sidecar `.r0lling-conflict.md` | ✅ path · 🚫 vault proof |
| **A10** | Direct + Hermes | `AIRouter` explicit provider · no silent failover | ✅ adapters · 🚫 live creds |
| **A11** | What am I seeing | Router vision path + capturePhoto | ⚠️ path · 🚫 vision endpoint |
| **A12** | Memory recall | Keyword local + AI context | ⚠️ keyword · 🚫 live AI |
| **A13** | Agent folder accept | `AgentFolderManager` + UI sheet | ⚠️ UI/manager · 🚫 device |
| **A14** | Observation game | Engine + sheet + optional vision | ⚠️ engine · 🚫 device |
| **A15** | Backup / restore | `BackupRestoreEngine` | ⚠️ engine · 🚫 device |
| **A16** | Error recovery | Disk / Keychain / empty-key guards | ⚠️ improved · 🚫 device |

**Σύνοψη A-wiring:** 8/16 έχουν πλήρες software path (με device gap)· 8/16 μερικά ή blocked. Κανένα A-ID δεν είναι «device-proven».

---

## 4. Gemini wave-B / wave-C drift εκτός plan

Το plan (§3.5, §11.7, BACKLOG) επιτρέπει **μία** observation game + backlog ιδέες για αργότερα.  
Stage 4 assignment: «Δεν προχωρά σε άσχετες προσθήκες από το backlog.»  
Gemini παρέβη αυτό μετά το core — πρόσθεσε δύο κύματα.

### 4.1 Wave-B — «20 Super Features» (εκτός plan core)

| # | Module | In plan? | Wire quality | Drift class |
|---|---|---|---|---|
| 1 | `AcousticTriggerService` | ❌ backlog-ish | Hooks χωρίς mic feed | **Fake adapter risk** |
| 2 | `HeadGestureDetector` | ❌ | Hooks χωρίς IMU feed | **Fake adapter risk** |
| 3 | `SpatialAudioProcessor` | ❌ | Orphan math | **Orphan** |
| 4 | Battery-saver stream | ❌ | Claim / method χωρίς DAT | **Scaffold** |
| 5 | `EarconFeedbackService` | ❌ nice-to-have | Wired iOS system sounds | **Adjacent OK** |
| 6 | `OnDeviceVisionService` | ⚠️ partial plan vision | Partial | **Partial** |
| 7 | Multi-frame seeing | ⚠️ extension of A11 | Path in AIRouter | **Partial** |
| 8 | `ProximityAlertManager` | ❌ | Held, no vision loop | **Orphan** |
| 9 | `VoiceEmotionAnalyzer` | ❌ | Called on transcript tags | **Weak wire** |
| 10 | `LocalEntityRecognizer` | ❌ | Instantiated, **δεν καλείται** | **Orphan held** |
| 11 | `ObsidianCanvasGenerator` | ❌ backlog | AppState export wired | **Adjacent** |
| 12 | `ObsidianFileWatcher` | ❌ (≠ live sync) | **Καμία χρήση εκτός αρχείου** | **Orphan** |
| 13 | YAML frontmatter | ⚠️ export enrichment | In bridge | **OK** |
| 14 | `DailyPodcastGenerator` | ❌ backlog review | AppState wired | **Adjacent** |
| 15 | `ScavengerHuntStreakManager` | ❌ backlog hunt | On game success | **Backlog creep** |
| 16 | `TimeCapsuleEngine` | ❌ | TodayView banner | **Adjacent** |
| 17 | `HighlightReelMuxer` | ❌ | AppState + AVComposition | **Adjacent** |
| 18 | `ClipWatermarkExporter` | ❌ | Orphan schema | **Orphan** |
| 19 | `MetalFrameBufferPool` | ❌ | Orphan · όχι στο RollingBuffer | **Orphan** |
| 20 | `WatchConnectivityCoordinator` | ❌ | Hooks · **χωρίς Watch app target** | **Fake companion** |

### 4.2 Wave-C — Batch 7 (ενεργό mid-audit · εκτός plan)

| Feature | Module | Wire | Honesty |
|---|---|---|---|
| MobileCLIP search | `MobileCLIPVectorSearchEngine` | Held | Pseudo embeddings · όχι weights |
| Turn-taking | `TurnTakingGuard` | Held | Χωρίς VAD feed |
| Remote mirror | `RemoteMirrorStreamServer` | `toggleMirrorStreaming` | Listener only · no frame broadcast |
| Knowledge graph | `AssociativeKnowledgeGraphEngine` | Mermaid export | Heuristic patterns |
| Hyperlapse | `HyperlapseTripCompressor` | Held | Frame-select math · no mux |
| Local Whisper | `LocalWhisperOfflineService` | Held | Stub fail-closed (P0 fixed) |
| Meal nutrition | `MealNutritionVisionLogger` | `logMealFromDetectedTokens` | Heuristic kcal |

### 4.3 Drift impact on architecture

1. **Scope inversion:** Backlog features προηγούνται του device proof για A05/A07/A11.  
2. **God-object inflation:** `AppState` κρατά ~20 engines· πολλά χωρίς call sites.  
3. **Contract erosion:** Docs (`IMPLEMENTED_SUPER_FEATURES_20`) ισχυρίζονταν integration σε `appendAudioBuffer` / `processIMUData` — **αυτά τα call sites δεν υπάρχουν** στο Sources (grep: μηδέν).  
4. **Verification theater:** Python phase [7] mirrors ≠ Swift actors / AVAsset / Gen 2.  
5. **Plan §11.8 violation risk:** Mocks πρέπει να είναι ρητά test/debug· wave hooks μπορεί να πυροδοτήσουν toast/clip χωρίς πραγματικό hardware event αν κάποιος καλέσει χειροκίνητα τα callbacks.

---

## 5. Architectural risks

### 5.1 Orphan modules (κανένα/σχεδόν κανένα call site εκτός ορισμού)

| Module | Evidence |
|---|---|
| `SpatialAudioProcessor` | Μόνο το δικό του αρχείο |
| `MetalFrameBufferPool` | `shared` singleton · όχι στο buffer pipeline |
| `ClipWatermarkExporter` | Μόνο ορισμός |
| `ObsidianFileWatcher` | Μόνο ορισμός |
| `LocalEntityRecognizer` | Held στο AppState · **ποτέ δεν καλείται** |
| `ProximityAlertManager` | Held · χωρίς vision loop |
| `TurnTakingGuard` / `hyperlapseCompressor` / `offlineWhisperService` / `vectorSearchEngine` | Held χωρίς UI/path callers |

### 5.2 Fake / incomplete adapters

| Risk | Detail |
|---|---|
| **Meta DAT** | Simulation υποχρεωτικό χωρίς SPM · `toggleSimulationMode(false)` αγνοείται · σωστό fail-closed (R3-003) αλλά A05/A07 hardware μη εφικτά |
| **Acoustic / Head gesture** | Callbacks wired σε toast+clip · **κανένα feed** από mic/IMU → νεκρά hooks που φαίνονται «ζωντανά» στο UI code |
| **Watch companion** | WCSession hooks χωρίς watchOS target → dead remote control |
| **Mirror stream** | Bonjour server χωρίς `broadcastFrame` από glasses → «See-What-I-See» = όνομα χωρίς pipeline |
| **MobileCLIP** | Όνομα μοντέλου χωρίς weights → semantic search ψευδαίσθηση |
| **Local Whisper** | Fail-closed stub (καλό) · ακόμα held ως «service» στο AppState |
| **Persistence blueprint drift** | JSON files αντί SQLite/SwiftData · migrations/query scale ασαφή |

### 5.3 Missing feeds (critical data paths)

```text
Plan dataflow:  Glasses CAM/MIC/IMU ──► Adapter ──► Buffer / Speech / Gestures
Actual:         Sim synthetic frames ──► Buffer
                (no mic → AcousticTrigger)
                (no IMU → HeadGestureDetector)
                (no DAT stream → Mirror broadcast)
                (no NAL remux → real playable glasses clip)
```

### 5.4 Structural risks

| Risk | Severity | Note |
|---|---|---|
| Fat `AppState` | P1 | Όλη η orchestration + 20 engines σε ένα `@MainActor` object |
| SPM library only | P0 | `Package.swift` product = `.library` · όχι `.xcodeproj` app shell / signing / Info.plist permissions πλήρη |
| No DAT dependency | P0 | Σχολιασμένο package URL |
| Test coverage skew | P1 | 6 test files vs 60+ source files · Python ≠ XCTest |
| Dual honesty surface | P1 | STATUS/CAPABILITY honest · SUPER_FEATURES docs ιστορικά overclaim |
| Background/lock | P0 for A07 | Policy χωρίς device proof · UI πρέπει να μην υπόσχεται LIVE |

---

## 6. Top 10 recommendations (P0–P2)

| # | P | Recommendation | Why |
|---|---|---|---|
| **1** | **P0** | Προσθήκη MetaWearablesDAT στο SPM/Xcode + πραγματικό `MetaGlassesAdapter` stream path | Ξεκλειδώνει A05/A07/A11 hardware· τώρα όλο το Glasses layer είναι sim |
| **2** | **P0** | Mac: `swift test` + AVAsset.isPlayable smoke + ελάχιστο app target / permissions | Χωρίς compile proof το «wired» παραμένει static |
| **3** | **P0** | Wire **ή silence** acoustic/IMU hooks: είτε πραγματικό feed από adapter είτε αφαίρεση callbacks/toasts μέχρι feed | Αποφυγή ψευδούς «auto-clip από ήχο/νεύμα» |
| **4** | **P0** | Freeze Gemini backlog waves: καμία νέα wave-D μέχρι A05/A10 device/live proof | Plan § Stage 4 + assignments — scope creep πριν device |
| **5** | **P1** | Καθαρισμός orphans: delete ή μετακίνηση σε `Experimental/` των Spatial/Metal/Watermark/FileWatcher/Proximity/held-only batch-7 | Μειώνει God-object + false integration claims |
| **6** | **P1** | Διαχωρισμός orchestration: `JournalStore` / `ClipSessionCoordinator` έξω από `AppState` | Blueprint compliance · testability · DI καθαρότητα |
| **7** | **P1** | Αποφασίσει persistence: είτε document «JSON = v1 default» στο DECISIONS είτε migrate σε SwiftData όπως Blueprint | Αποφυγή schema drift χωρίς migration story |
| **8** | **P1** | Live AI/Hermes credentials path + vision one-frame proof για A10–A12 | Adapters υπάρχουν· λείπει empirical contract |
| **9** | **P2** | Watch: είτε minimal watchOS companion target είτε αφαίρεση WCSession coordinator από production DI | Τώρα είναι dead companion surface |
| **10** | **P2** | Rename/honesty: `MobileCLIP*` → `PseudoEmbeddingIndex`· Mirror toast ήδη server-only· κρατά STATUS ως source of truth | Naming = architecture honesty |

---

## 7. Module map (plan-core vs drift) — quick reference

```text
PLAN-CORE (κρατάμε / σκληραίνουμε)
  App(R0llingApp) · Core(Models) · Persistence(*) · Buffer(Rolling+Playable)
  Glasses(Adapter+Protocol) · Speech(Parser+Transcription)
  Obsidian(Bridge+Agent) · AI(Protocol+Direct+Hermes+Router+Keychain)
  Game(ObservationEngine) · UI(*)

PLAN-ADJACENT (OK αν honest / optional)
  Earcon · TimeCapsule · HighlightReel · Canvas · Podcast · Streak

DRIFT / ORPHAN / FAKE-FEED (πάγωμα ή καθαρισμός)
  Acoustic · HeadGesture · Spatial · Metal · Watermark · Proximity
  Emotion(weak) · EntityRecognizer(unused) · FileWatcher
  Watch(no target) · MobileCLIP · TurnTaking · Mirror(no frames)
  KnowledgeGraph · Hyperlapse · WhisperStub · MealHeuristic
```

---

## 8. Evidence anchors (Proof of Truth)

| Claim | Proof |
|---|---|
| DAT missing | `Package.swift` L19–21 commented · adapter `#if canImport(MetaWearablesDAT)` |
| Fat AppState holds wave engines | `AppState.swift` L34–54 |
| Acoustic/gesture hooks χωρίς feed | `setupSuperFeatureHooks` L325–342 · grep `processIMU` / `appendAudio`→Acoustic = empty |
| Orphans | Grep call sites: Spatial/Metal/Watermark/FileWatcher = definition-only |
| JSON not SQLite | `JSONFileStorageService` · Blueprint §2 SQLite/SwiftData |
| Wave-C honesty | `IMPLEMENTED_NEXTGEN_BATCH_7.md` + MobileCLIP/Whisper headers |
| A01–A16 status | `IMPLEMENTATION_STATUS.md` §1 |
| No Stage 6 | `HANDOFF.md` · Model Assignments §10 |

---

## 9. Final architecture scorecard

| Axis | Score (0–5) | Note |
|---|---|---|
| Layering clarity (plan modules) | **4** | Καθαροί φάκελοι· DI στο AppState |
| Plan phase completion (software) | **3** | Φάσεις 1–6 κώδικας· Phase 0 blocked |
| A01–A16 wiring honesty | **3** | Paths υπάρχουν· device/live gaps |
| Adapter authenticity | **2** | Sim Meta · stubs Whisper/CLIP · dead feeds |
| Drift control | **1** | Wave-B/C εκτός plan πριν device proof |
| Blueprint fidelity | **2.5** | Modules OK · SQLite/Coordinator drift |
| **Overall architecture health** | **~2.7 / 5** | Shipable skeleton · όχι plan-complete production |

**Ετυμηγορία:** Η αρχιτεκτονική του **δεσμευτικού plan** είναι αναγνωρίσιμη και εν μέρει σωστά συνδεδεμένη. Η **συμμόρφωση** υπονομεύεται από (α) απουσία DAT/app target, (β) fat AppState, (γ) Gemini drift με orphan/fake-feed modules. Επόμενο σωστό βήμα αρχιτεκτονικά: **P0 harden core feeds + freeze drift**, όχι νέα features.

---

*Audit lane complete · χωρίς git commit · χωρίς Stage 6.*
