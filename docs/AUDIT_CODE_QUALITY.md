> Current status (2026-10-09): This document contains historical assertions or design targets. It is not evidence for the current checkout. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) and [FINDINGS_REMEDIATION.md](FINDINGS_REMEDIATION.md). Earlier “100%”, module counts, CI/head references and security/readiness claims are superseded.

# R0lling — Historical Code Quality / Debt Audit (2026-10-06)

> Archived snapshot: counts, source findings, and statuses below describe an earlier checkout and are not current. Use `IMPLEMENTATION_STATUS.md`, `CAPABILITY_MATRIX.md`, and `FINDINGS_REMEDIATION.md` for current evidence.

**Lane:** Code quality · honesty bugs · dead code · AppState · tests · Gemini scaffolding  
**Ημερομηνία:** 2026-10-06 ~17:50 EEST  
**Auditor:** Cursor (code_reviewer + ponytail-audit + mp smell baseline)  
**Workspace:** `.`  
**Git:** χωρίς commit (όπως ζητήθηκε)  
**Gemini parallel:** IDLE μετά wave-C (~17:40) · mtimes re-checked πριν P0 edits  

**Skills:** `code_reviewer` · `ponytail-audit` · `mp_code-review` (smell baseline) · `code-simplifier` (recommendations only)

---

## 1. Executive verdict

**REQUEST CHANGES** — ο πυρήνας (journal / buffer / Obsidian conflict / Keychain / voice dedup) είναι σχετικά καθαρός μετά Stage 4–5· το χρέος συγκεντρώνεται στο **AppState god-object** + **Gemini wave-B/C scaffolding** (orphan engines, dead feeds, overclaim docstrings) + **test vacuum** εκτός persistence/buffer.

Χωρίς Mac `swift test` αυτό το host → κάλυψη επαληθεύεται μόνο με Python mirrors + static review.

---

## 2. Debt heat map

Θερμοκρασία = επίπτωση × πιθανότητα ψεύδους / συντήρησης.

| Ζώνη | Heat | LOC / σήμα | Γιατί |
|---|---|---|---|
| `AppState.swift` | 🔴 HIGH | ~430 LOC · 15+ engines · 20 `@Published` | God-object · Feature Envy · Divergent Change · κάθε wave προσθέτει held refs |
| Gemini wave-B orphans | 🔴 HIGH | ~250 LOC orphan/partial | Spatial / Metal / Watermark / FileWatcher / Proximity / Vision / Entity — **μηδενικοί callers** εκτός hold στο AppState |
| Gemini wave-C held | 🟠 MED-HIGH | ~700 LOC | Pseudo-CLIP · Whisper stub · TurnTaking χωρίς VAD · Hyperlapse χωρίς mux · Mirror χωρίς `broadcastFrame` |
| Dead sensor feeds | 🟠 MED-HIGH | Acoustic + IMU hooks | Toast υπονοεί hardware· `processAudioLevel` / `feedIMUSample` **ποτέ** από adapter |
| AI connectors DRY | 🟡 MED | Hermes ≈ Direct | ~80 γραμμές copy-paste message/HTTP body |
| Agent memory defaults | 🟡 MED → ✅ fixed | `AgentFolderManager` | Fake persona πριν CQ-P0-001 |
| Test surface | 🟠 MED-HIGH | 6 XCTest files · ~370 LOC | Καλύπτουν storage/buffer/voice/obsidian/backup· **όχι** AI/game/AppState/super-features |
| UI silent failure | 🟡 MED → ✅ fixed | Settings / Agent save | CQ-P0-002 / CQ-P0-005 |
| Core Stage4 paths | 🟢 LOW | JSON · clip moov · DAT gate · Keychain | Steward-hardened · μην αγγίξεις χωρίς test |

```
Heat bars (relative debt mass):
AppState god          ████████████████
Gemini orphans B/C    ███████████████
Dead acoustic/IMU     ████████
Test gaps             █████████
AI connector DRY      █████
Force unwrap / try?   ████
```

---

## 3. Findings (ranked)

### 3.1 Honesty bugs

| ID | Sev | Finding | Evidence | Status |
|---|---|---|---|---|
| **CQ-P0-001** | P0 | Agent memory defaults εφεύραν persona («Μαρία», ταξίδια) → AI poisoning | `AgentFolderManager.loadAgentMemory` | **FIXED** — άδεια templates |
| **CQ-P0-002** | P0 | Obsidian batch export: `try?` χωρίς toast αποτυχίας | `SettingsView` | **FIXED** — `do/catch` |
| **CQ-P0-003** | P0 | Hermes `catch` τύλιγε typed 7102 ως «αδυναμία σύνδεσης» | `HermesConnector` | **FIXED** — rethrow domain + underlying |
| **CQ-P0-004** | P0 | Knowledge Graph export: άδειο Mermaid + toast επιτυχίας· `extractTriples` ποτέ | `AppState.exportKnowledgeGraphToObsidian` | **FIXED** — extract από `todayEntries` + empty guard |
| **CQ-P0-005** | P0 | Agent memory save: `try?` + `dismiss()` ακόμα και σε fail | `AssistantView` | **FIXED** |
| **CQ-P0-006** | P0 | `currentBatteryLevel()` επέστρεφε `94` όταν disconnected | `MetaGlassesAdapter` | **FIXED** → `nil` |
| **CQ-P1-010** | P1 | Acoustic/IMU hooks: toast «Ηχητική έκρηξη» / «Νεύμα» χωρίς feed | `AppState.setupSuperFeatureHooks` · κανένα κάλεσμα `processAudioLevel`/`feedIMUSample` | **FIXED** (CQ-P0-007) — flip flags όταν wire feed |
| **CQ-P1-011** | P1 | Mirror docstring «&lt;40ms / Wi-Fi Direct»· runtime μόνο TCP Bonjour χωρίς frames | `RemoteMirrorStreamServer` | OPEN — docstring + no broadcast caller |
| **CQ-P1-012** | P1 | Obsidian auto-export μετά note/clip: `_ = try?` — journal OK, vault fail αόρατο | `AppState.triggerClip` / `addNote` | **FIXED** — `exportEntryToObsidianIfConfigured` |
| **CQ-P1-013** | P1 | Meal/Podcast/Graph docstrings overclaim (HealthKit, glasses TTS, «3D RDF») | MealNutrition · DailyPodcast · AssociativeKG | OPEN — shrink comments |
| **CQ-P1-014** | P1 | MobileCLIP = FNV pseudo vectors· όνομα παραπλανεί | `MobileCLIPVectorSearchEngine` | OPEN — rename ή `#if DEBUG` banner |
| **CQ-P2-020** | P2 | `DailyPodcastGenerator.completion?()` καλείται αμέσως (όχι στο end of speech) | `playDailyPodcast` | OPEN |

### 3.2 Dead / orphan code (ponytail)

| Tag | Finding | Replacement | Path |
|---|---|---|---|
| `delete:` | SpatialAudioProcessor — κανένας caller | nothing μέχρι DAT multi-mic | `Buffer/SpatialAudioProcessor.swift` |
| `delete:` | MetalFrameBufferPool — όχι Metal· απλό `Data` recycle· orphan | nothing ή wire σε RollingBuffer | `Buffer/MetalFrameBufferPool.swift` |
| `delete:` | ClipWatermarkExporter — orphan schema | nothing | `Buffer/ClipWatermarkExporter.swift` |
| `delete:` | ObsidianFileWatcher — δεν instantiates πουθενά | wire από bridge ή delete | `Obsidian/ObsidianFileWatcher.swift` |
| `yagni:` | ProximityAlertManager / OnDeviceVision / LocalEntityRecognizer — held στο AppState, μηδενική χρήση | αφαιρέσε holds ή κάλεσε από vision path | `AppState` + AI/* |
| `yagni:` | vectorSearch / turnTaking / hyperlapse / offlineWhisper — held, no UI/API path | κρατά stubs με `#warning` ή μετακίνησε σε `Experimental/` | AppState + wave-C |
| `yagni:` | AcousticTrigger + HeadGesture — callback wired, **input dead** | feed από stream ή αφαίρεσε toast hooks | Speech/Glasses + AppState |
| `shrink:` | HermesConnector ≈ DirectAPIConnector message build | κοινό `OpenAIChatRequestBuilder` | AI/* |
| `shrink:` | RemoteMirror docstring marketing claims | 3-line honest header | RemoteMirrorStreamServer |
| `native:` | MetalFrameBufferPool χωρίς MetalKit | AVFoundation / IOSurface όταν υπάρξει real frames | — |

**ponytail net (εκτίμηση):** `net: ~-350 LOC orphan delete δυνατό, -0 deps` (κανένα εξωτ. package ακόμα· DAT σχολιασμένο στο `Package.swift`).

### 3.3 AppState god-object (mp smells)

| Smell | Απόδειξη |
|---|---|
| **Divergent Change** | Journal + glasses + speech + AI chat + game + podcast + mirror + nutrition + graph στο ίδιο type |
| **Feature Envy** | Orchestrates 15+ services· λίγη δική του λογική |
| **Speculative Generality** | Held engines χωρίς callers (wave-B/C) |
| **Data Clumps** | chatMessages tuple αντί typed `ChatMessage` |
| **Shotgun Surgery** | Κάθε νέο feature → νέα `public let` + hook στο init |

**Πρόταση (όχι rewrite τώρα):** εξαγωγή coordinators  
`JournalCoordinator` · `GlassesStreamCoordinator` · `AssistantCoordinator` · `GameCoordinator` · `ExperimentalFeaturesRegistry` (held scaffolds). AppState κρατάει μόνο `@Published` façade + DI.

### 3.4 Force unwrap / silent try? (υπόλοιπα)

| Site | Risk | Priority |
|---|---|---|
| `JSONFileStorageService` / `AgentFolderManager` / `MediaStorage` `.first!` για Documents | Crash αν sandbox σπάσει (σπάνιο) | P2 → `guard let` |
| `HighlightReelMuxer` `"moov".data(using:)!` | Resolved: byte sniff removed; AVFoundation validates the exported asset with `isPlayable` | Closed in current source |
| `RollingBufferService` `samples.last!` μετά `guard !isEmpty` | Τοπικά ασφαλές | OK |
| `OnDeviceVisionService` `try? handler.perform` | Silent vision fail | P1 |
| `ScavengerHuntStreakManager` encode `try?` | Χάσιμο streak χωρίς σήμα | P1 |
| `ObsidianVaultBridge` media `try? copyItem` | Attachments λείπουν σιωπηλά | P1 |

### 3.5 Gemini scaffolding quality

| Wave | Quality | Notes |
|---|---|---|
| A (core plan) | ✅ Good | Protocols, honesty flags (`isSimulationPlaceholder`), tests σε κρίσιμα |
| B (20 super) | ⚠️ Scaffold | Πολλοί τύποι με σωστό shape· **orphan**· docstrings overclaim |
| C (batch 7) | ⚠️ Mixed | Whisper fail-closed καλό· CLIP όνομα κακό· Mirror server πραγματικό NWListener αλλά μισό προϊόν· KG heuristic OK αν δεν πουλάει «RDF/3D» |

**Κανόνας για επόμενα Gemini passes:** κάθε νέο module → (1) caller από UI ή coordinator **ή** (2) φάκελος `Experimental/` χωρίς AppState hold **ή** (3) reject.

### 3.6 Duplication

1. **DirectAPIConnector ↔ HermesConnector** — σχεδόν ίδιο OpenAI chat payload (messages, vision, summarizeDay). Extract builder.
2. **exportCanvas / exportKnowledgeGraph** — ίδιο vaultURL guard + write + toast pattern → `ObsidianExportHelper`.
3. **Watch / acoustic / gesture** — τρία ίδια `[weak self] Task { @MainActor in triggerClip }` closures.

### 3.7 Test gaps

| Covered (XCTest) | Missing (high value) |
|---|---|
| Journal ISO8601 / restart / TZ day key | `AIRouter` empty-key routing |
| RollingBuffer playable placeholder | Hermes 7102 vs 7103 (CQ-P0-003) |
| VoiceCommandParser dedup | AgentFolderManager empty defaults |
| Obsidian conflict sidecar | Knowledge graph empty-guard |
| BackupRestore | ObservationGame streak only-on-success |
| | MetaGlasses 4002 without SDK |
| | Acoustic/IMU **no false toast** integration |
| | MobileCLIP cosine unit (math only — OK χωρίς weights) |

**Κάλυψη εκτίμηση:** ~15–20% κρίσιμων modules με unit tests· 0% για AppState orchestration.

---

## 4. P0 – P2 backlog

### P0 — τώρα / blocker honesty

| ID | Action | Owner hint |
|---|---|---|
| CQ-P0-001…006 | Ολοκληρώθηκαν αυτό το pass (βλ. §5) | code-quality lane |
| CQ-P0-007 | **Silence ή wire** acoustic/IMU: μέχρι mic/IMU feed, μην δείχνεις toast που υπονοεί hardware event | **FIXED** — gated hooks στο `AppState` |
| CQ-P0-008 | Mac: `swift test` + compile proof | Mac host |

### P1 — σύντομα

| ID | Action |
|---|---|
| CQ-P1-010 | Wire acoustic RMS από speech/buffer **ή** αφαίρεσε hooks από `setupSuperFeatureHooks` |
| CQ-P1-011 | Mirror: κάλεσε `broadcastFrame` από stream **ή** κρύψε UI toggle |
| CQ-P1-012 | Obsidian export μετά save: toast warning αν fail (μη σιωπηλό `try?`) | **FIXED** |
| CQ-P1-013 | Docstring honesty pass σε wave-B/C modules |
| CQ-P1-014 | Rename `MobileCLIP*` → `PseudoVectorSearchEngine` ή ξεκάθαρο `isPseudoEmbedding` API |
| CQ-P1-015 | Extract OpenAI chat request builder (DRY Direct/Hermes) |
| CQ-P1-016 | XCTest για Agent defaults · Hermes error domains · KG empty export |
| CQ-P1-017 | Αφαίρεσε AppState holds για πλήρη orphans (Spatial/Metal/Watermark/FileWatcher) **ή** μετακίνησε Experimental |

### P2 — χρέος / simplify

| ID | Action |
|---|---|
| CQ-P2-020 | Podcast completion στο speech end |
| CQ-P2-021 | Split AppState → coordinators (βήμα-βήμα, όχι big bang) |
| CQ-P2-022 | Typed `ChatMessage` αντί tuple |
| CQ-P2-023 | `guard let` αντί `.first!` σε Documents URLs |
| CQ-P2-024 | Streak persist fail → log/toast |
| CQ-P2-025 | code-simplifier: iterator/join σε cosine & KG sanitize (χαμηλή προτεραιότητα) |

---

## 5. Surgical P0 fixes applied (αυτό το pass)

| ID | File | Change |
|---|---|---|
| CQ-P0-001 | `Obsidian/AgentFolderManager.swift` | Empty markdown templates |
| CQ-P0-002 | `UI/SettingsView.swift` | Export batch `do/catch` toast |
| CQ-P0-003 | `AI/HermesConnector.swift` | Rethrow `R0lling.Hermes` / Cancellation · underlying on 7103 |
| CQ-P0-004 | `App/AppState.swift` | Extract triples πριν export · empty fail-closed |
| CQ-P0-005 | `UI/AssistantView.swift` | Save memory fail → toast, no dismiss |
| CQ-P0-006 | `Glasses/MetaGlassesAdapter.swift` | Battery `nil` when disconnected |
| (chore) | `AppState.swift` | Αφαίρεση διπλού comment `// Published State` |
| CQ-P0-007 | `AppState.swift` | Gated `onSpikeDetected` / `onDoubleNodDetected` · flags false |
| CQ-P1-012 | `AppState.swift` | `exportEntryToObsidianIfConfigured` αντί silent `try?` |
| (doc) | `RemoteMirrorStreamServer.swift` | Honest Bonjour-only header |

**Δεν αγγίχτηκαν** (αποφυγή σύγκρουσης / scope): wave-C engine internals, RollingBuffer/PlayableClip, DAT path, HighlightReel muxer.

**Mtime gate:** Gemini IDLE· επεξεργασία μόνο σε αρχεία χωρίς ενεργό parallel writer.

---

## 6. code-simplifier recommendations (όχι rewrite)

1. `MobileCLIPVectorSearchEngine.cosineSimilarity` → `zip` + `reduce` (ίδια συμπεριφορά).  
2. `AssociativeKnowledgeGraphEngine.sanitizeIdentifier` → `CharacterSet` filter once.  
3. AppState clip/note Obsidian export → ιδιωτικό `exportToObsidianOrWarn(_:)`.  
4. Μην «απλοποιήσεις» μακριά τα fail-closed guards (Whisper stub, AVFoundation playability validation, empty KG).

---

## 7. mp Standards axis (summary)

- **Hard:** silent failure / fake success paths (διορθώθηκαν 001–006)· remaining dead-feed toasts = hard honesty.  
- **Judgement:** AppState god-object, speculative Gemini modules, Direct/Hermes duplication.  
- **Spec axis:** N/A αυτού του lane (βλ. `GEMINI_AUDIT.md` για plan vs code).

---

## 8. Verification notes

```text
Host: Windows — χωρίς swift test
Static review + mtime gate: OK
Προηγούμενα: diagnose_stage4/5 + verify_all_subsystems PASS (Python mirrors)
Μετά τα P0: χρειάζεται Mac XCTest για Hermes rethrow / Agent defaults / KG empty
```

---

## 9. Closing checklist

- [x] Honesty bugs σκαναρισμένα (fake success, try?, force unwrap)  
- [x] Orphan / dead feed map  
- [x] AppState god-object smells  
- [x] Test gaps  
- [x] Gemini scaffolding quality  
- [x] Duplication  
- [x] Debt heat map + P0–P2  
- [x] Surgical P0 χωρίς git commit  

**Επόμενο βήμα lane:** CQ-P1-017 (drop orphan holds) · wire acoustic/IMU flags όταν feed · Mac `swift test`.
