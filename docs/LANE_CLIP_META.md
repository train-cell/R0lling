> Current status (2026-10-09): This document contains historical assertions or design targets. It is not evidence for the current checkout. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) and [FINDINGS_REMEDIATION.md](FINDINGS_REMEDIATION.md). Earlier “100%”, module counts, CI/head references and security/readiness claims are superseded.

# R0lling — Clip Buffer + Meta Glasses Lane (`LANE_CLIP_META`)

**Έργο:** `R0lling`  
**Lane:** A05 playable clip · A06 warm-up/disconnect · A07 background/lock · RollingBuffer · PlayableClipExporter · MetaGlassesAdapter  
**Host αυτού του pass:** Windows (Swift UNAVAILABLE · DAT **δεν** vendored)  
**Ημερομηνία:** 6 Οκτωβρίου 2026  

---

## 1. Software implementation present (χωρίς Gen 2 — validation pending)

| Κομμάτι | Κατάσταση | Αρχεία |
|---|---|---|
| Rolling buffer 5–10s + keyframe align | Implemented; XCTest/runtime validation pending | `RollingBufferService.swift` |
| Warm-up clip (πραγματική μικρότερη διάρκεια) | Implemented; XCTest/runtime validation pending | `triggerClip` + XCTest source |
| Disconnect / gap safety (stream generation) | Implemented; runtime validation pending | `markStreamInterrupted` · `streamGeneration` |
| Concurrent export guard | Implemented; runtime validation pending | error `3012` |
| Pause / resume (A07 software) | Implemented; runtime validation pending | `pauseBuffering` / `resumeBuffering` |
| ScenePhase → PAUSED + honest toast | Implemented; runtime validation pending | `R0llingApp` · `AppState.handleScenePhaseChange` |
| Reconnect policy (auto-resume foreground) | Implemented; runtime validation pending | `GlassesReconnectPolicy` · adapter |
| Stage-4 placeholder MP4 | Source path present; AVFoundation validation pending | `PlayableClipExporter.grapsePlayablePlaceholderMP4` uses `AVURLAsset.load(.isPlayable)` |
| H.264 Annex-B remux pipeline | Structure present; codec/runtime validation pending | `H264AnnexBRemuxer` — πετάει **3010** χωρίς SPS/PPS |
| Meta protocol + simulation **ρητά labeled** | Implemented; runtime validation pending | `MetaGlassesAdapter` · `(SIMULATION — όχι φυσική συσκευή)` |
| Non-sim χωρίς SDK → error **4002** | Implemented; runtime validation pending | R3-003 |
| DAT bridge stubs `#if canImport` | Stub only | `MetaDATStreamBridge` — **4010** χωρίς SDK · **4011** μέχρι wire |
| Acoustic / IMU feed API | ⚠️ synthetic adapter plumbing only; live DAT samples are not wired | `MetaGlassesAdapter` simulation · readiness false |
| Auto-clip toasts | ⏸ gated | `FeatureReadinessRegistry.acoustic/headGesture.ready = false` |

**Do not flip readiness flags from this historical example.** Current acoustic and head-gesture flags remain false. Enable them only after the corresponding real sensor capture, app flow, and device tests have been implemented and reviewed.

---

## 2. Τι χρειάζεται ακόμα Gen 2 + Mac (όχι 100% device)

| Κενό | Γιατί | Error / gate |
|---|---|---|
| MetaWearablesDAT SPM dependency | Δεν vendor-άρεται αξιόπιστα σε Windows | `Package.swift` σχολιασμένο |
| Real BT pairing / battery | Χωρίς DAT session | Simulation ή 4002 |
| Real camera elementary stream | Χωρίς DAT frames | Sim synthetic bytes (όχι NAL) |
| Successful H.264 remux από γυαλιά | Χρειάζεται SPS/PPS από DAT | Remux 3010 → fallback placeholder |
| `AVAsset.isPlayable` smoke | Χρειάζεται Mac/iOS runtime | XCTest σε GHA/Mac |
| Continuous background capture | Meta sample συχνά κλείνει session | `promisesContinuousBackgroundCapture = false` μέχρι proof |
| Hey Meta wake | Experimental SDK | Εκτός αυτού του lane |
| Live acoustic/IMU από hardware | DAT mic/IMU hooks | Μόνο synthetic samples· το live bridge επιστρέφει nil και τα readiness flags μένουν false |

---

## 3. Future implementation outline (not an enablement checklist)

The steps below describe engineering work that still needs to happen. They do not enable a live device path. Merely adding the DAT package does not make this bridge operational: the current `canImport` branch still throws `4011` for sessions/frames, `kleiseLiveSession` is empty, and audio/IMU pulls return `nil`. Do not switch the app to real mode until those hooks have a reviewed implementation and device evidence.

### Βήμα 0 — Προαπαιτούμενα
1. macOS 14+ · Xcode 16+ · iPhone iOS 17.2+ · Meta Ray-Ban Gen 2  
2. Meta Wearables Developer Center app + Client Token  
3. Meta View → Developer Mode (7 taps) → Wireless Camera Streaming  

### Βήμα 1 — Uncomment DAT στο SPM
Στο `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/facebook/meta-wearables-dat-ios.git", from: "1.0.0")
],
targets: [
    .target(
        name: "R0lling",
        dependencies: [
            .product(name: "MetaWearablesDAT", package: "meta-wearables-dat-ios")
        ],
        ...
    )
]
```

> Αν το product name διαφέρει, δες το README του DAT repo και διόρθωσε το `.product(name:)`.

### Βήμα 2 — Wire `MetaDATStreamBridge`
Άνοιξε `Sources/R0lling/Glasses/MetaDATStreamBridge.swift` μέσα στα `#if canImport(MetaWearablesDAT)` blocks:

1. Πριν το `camera.startStreaming`, επιβεβαίωσε ποιοι codecs υποστηρίζονται από το SDK και τα γυαλιά. Το παρόν `H264AnnexBRemuxer` δέχεται μόνο H.264 Annex-B (SPS/PPS NAL types 7/8). Αν το DAT δίνει μόνο HEVC, χρειάζεται ξεχωριστή HEVC remux διαδρομή ή τεκμηριωμένη ρύθμιση H.264· μην υποθέσεις ότι τα δύο formats είναι εναλλάξιμα.
2. `anoixeLiveSession()` — αντικατέστησε το `throw 4011` με πραγματικό connect και `camera.startStreaming` από το **CameraAccess** sample, χρησιμοποιώντας τον codec που επαληθεύτηκε στο προηγούμενο βήμα.
3. `diavaseEpomenoVideoFrame()` — map DAT compressed frame → `BufferedSample` με bytes στο format που υποστηρίζει ο αντίστοιχος remuxer + `isKeyframe` + timestamps.
4. `diavaseEpomenoAudioSample()` — αν το SDK δίνει sync audio.
5. `diavaseEpomenoIMU()` — αν εκτίθεται head tracking / IMU.
6. `kleiseLiveSession()` — stop + disconnect.

### Βήμα 3 — Άνοιγμα real mode στο adapter
```swift
await glassesAdapter.toggleSimulationMode(enabled: false)
try await glassesAdapter.connectDevice()
try await glassesAdapter.startStreaming()
```
Το παράδειγμα αυτό δεν συνδέεται στο παρόν checkout. Ακόμη και με DAT linked, το bridge σήμερα επιστρέφει `4011` και το app δεν μπαίνει σε real mode· το session και τα frame/sensor callbacks απαιτούν υλοποίηση πρώτα.

### Βήμα 4 — Μετά την υλοποίηση: επαλήθευση A05 remux
1. Stream ≥ 10s με πραγματικά NAL (πρέπει να υπάρχουν SPS type 7 + PPS type 8).  
2. `Clip` → `ClipExportResult.isSimulationPlaceholder == false`.  
3. `AVAsset(url:).isPlayable == true` στο XCTest / device.  
4. Αν λείπουν SPS/PPS → remux 3010 → Stage-4 placeholder (honest label).

### Βήμα 5 — A06 / A07 device matrix
| Test | Αναμενόμενο |
|---|---|
| Clip στα 3s warm-up | Διάρκεια ~3s, playable, όχι fake 10s |
| Disconnect mid-stream | Buffer clear · νέα generation · όχι ένωση κενών |
| Background κατά LIVE | UI `PAUSED` · toast honest · buffer δεν γεμίζει (default policy) |
| Lock screen | Ίδιο με background |
| Foreground resume | Auto-resume αν `autoResumeStreamOnForeground` |
| Αν DAT επιτρέπει background capture | Θέσε `promisesContinuousBackgroundCapture = true` μόνο μετά από δοκιμή της πραγματικής codec διαδρομής και εμπειρική επιβεβαίωση σε συσκευή |

### Βήμα 6 — Acoustic / IMU product surface
Το παρόν checkout δεν τεκμηριώνει πλήρη real-sensor διαδρομή. Υλοποίησε και έλεγξε capture, handoff, app behavior και device tests πριν αλλάξεις τα readiness flags. Μέχρι τότε κράτησέ τα `false`.

### Βήμα 7 — CI / P0-01 (checklist)

**GHA (προτιμητέο):**
1. GitHub → Actions → `R0lling CI (Cloud macOS)` → Run workflow (ή push `main`).
2. Πράσινο: `python-verify` + `build-and-test`.
3. Artifact `swift-build-and-test-logs` → HANDOFF line.
4. Λεπτομέρειες: `docs/DEVICE_TESTS.md` §3.

**Τοπικό Mac:**
```bash
swift test --parallel 2>&1 | tee swift-test.log
# ή GitHub Action: R0lling CI (Cloud macOS)
```

> Χωρίς πράσινο log → P0-01 παραμένει **BLOCKED** (όχι fake 100%).

---

## 4. Honesty rules (μην παραβιάσεις)

1. Simulation device name **πρέπει** να περιέχει `SIMULATION`.  
2. Χωρίς DAT → ποτέ `.connected` σε non-sim path (4002).  
3. Stage-4 `grapsePlayablePlaceholderMP4` παραμένει η σταθερή playable διαδρομή.  
4. Remux χωρίς SPS/PPS → throw, όχι silent fake moov από NAL garbage.  
5. Background continuous capture = **όχι** default promise.  
6. Auto-clip toasts μόνο με `FeatureReadinessRegistry.*.ready == true`.

---

## 5. Quick file map

```text
Buffer/
  RollingBufferProtocol.swift      state · generation · pause API
  RollingBufferService.swift       A05/A06/A07 buffer actor
  PlayableClipExporter.swift       Stage-4 placeholder (+ coordinator)
  H264AnnexBRemuxer.swift          real remux / 3010 stubs
Glasses/
  MetaGlassesProtocol.swift        protocol + paused state + feed sink
  MetaGlassesAdapter.swift         sim labeled + DAT loop + lifecycle
  MetaDATStreamBridge.swift        #if canImport DAT hooks
  GlassesStreamLifecycle.swift     A07 policy pure functions
App/
  AppState.swift                   sink + scenePhase handler
  R0llingApp.swift                 onChange(scenePhase)
```

*Software implementation is present; Apple runtime validation remains pending, and Gen 2 behavior requires device evidence. No git commit was made in this pass.*
