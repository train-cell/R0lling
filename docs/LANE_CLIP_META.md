# R0lling — Clip Buffer + Meta Glasses Lane (`LANE_CLIP_META`)

**Έργο:** `R0lling`  
**Lane:** A05 playable clip · A06 warm-up/disconnect · A07 background/lock · RollingBuffer · PlayableClipExporter · MetaGlassesAdapter  
**Host αυτού του pass:** Windows (Swift UNAVAILABLE · DAT **δεν** vendored)  
**Ημερομηνία:** 6 Οκτωβρίου 2026  

---

## 1. Τι είναι 100% software (χωρίς Gen 2)

| Κομμάτι | Κατάσταση | Αρχεία |
|---|---|---|
| Rolling buffer 5–10s + keyframe align | ✅ | `RollingBufferService.swift` |
| Warm-up clip (πραγματική μικρότερη διάρκεια) | ✅ | `triggerClip` + XCTest |
| Disconnect / gap safety (stream generation) | ✅ | `markStreamInterrupted` · `streamGeneration` |
| Concurrent export guard | ✅ | error `3012` |
| Pause / resume (A07 software) | ✅ | `pauseBuffering` / `resumeBuffering` |
| ScenePhase → PAUSED + honest toast | ✅ | `R0llingApp` · `AppState.handleScenePhaseChange` |
| Reconnect policy (auto-resume foreground) | ✅ | `GlassesReconnectPolicy` · adapter |
| Stage-4 playable placeholder MP4 + moov | ✅ **ΜΗΝ ΣΠΑΣΕΙΣ** | `PlayableClipExporter.grapsePlayablePlaceholderMP4` |
| H.264 Annex-B remux pipeline | ✅ structure | `H264AnnexBRemuxer` — πετάει **3010** χωρίς SPS/PPS |
| Meta protocol + simulation **ρητά labeled** | ✅ | `MetaGlassesAdapter` · `(SIMULATION — όχι φυσική συσκευή)` |
| Non-sim χωρίς SDK → error **4002** | ✅ | R3-003 |
| DAT bridge stubs `#if canImport` | ✅ | `MetaDATStreamBridge` — **4010** χωρίς SDK · **4011** μέχρι wire |
| Acoustic / IMU feed API end-to-end | ✅ wired · triggers gated | adapter → `GlassesSensorFeedSink` → AppState |
| Auto-clip toasts | ⏸ gated | `FeatureReadinessRegistry.acoustic/headGesture.ready = false` |

**Flip για auto-clip (χωρίς νέο wiring):**

```swift
// FeatureReadinessRegistry.swift
public static let acoustic = Flag(..., ready: true, ...)
public static let headGesture = Flag(..., ready: true, ...)
```

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
| Live acoustic/IMU από hardware | DAT mic/IMU hooks | Feed API έτοιμο · ready flags false |

---

## 3. Mac steps → flip σε 100% device path

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

1. `anoixeLiveSession()` — αντικατέστησε το `throw 4011` με πραγματικό connect + `camera.startStreaming` από το **CameraAccess** sample.  
2. `diavaseEpomenoVideoFrame()` — map DAT compressed frame → `BufferedSample` με Annex-B bytes + `isKeyframe` + timestamps.  
3. `diavaseEpomenoAudioSample()` — αν το SDK δίνει sync audio.  
4. `diavaseEpomenoIMU()` — αν εκτίθεται head tracking / IMU.  
5. `kleiseLiveSession()` — stop + disconnect.

### Βήμα 3 — Άνοιγμα real mode στο adapter
```swift
await glassesAdapter.toggleSimulationMode(enabled: false)
try await glassesAdapter.connectDevice()
try await glassesAdapter.startStreaming()
```
Με DAT linked, το `canImport` path ενεργοποιείται· χωρίς επιτυχή session παραμένει error (όχι fake connected).

### Βήμα 4 — Επαλήθευση A05 remux
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
| Αν DAT επιτρέπει background HEVC | Θέσε `promisesContinuousBackgroundCapture = true` **μόνο μετά** εμπειρική επιβεβαίωση |

### Βήμα 6 — Acoustic / IMU product surface
Μετά από πραγματικό mic/IMU από DAT:
1. `FeatureReadinessRegistry.acoustic.ready = true`  
2. `FeatureReadinessRegistry.headGesture.ready = true`  
3. Χωρίς άλλο wiring — το sink είναι ήδη registered στο `AppState`.

### Βήμα 7 — CI / P0-01 (checklist)

**GHA (προτιμητέο):**
1. GitHub → Actions → `R0lling CI (Cloud macOS)` → Run workflow (ή push `main`).
2. Πράσινο: `python-verify` + `build-and-test`.
3. Artifact `swift-test-log` → HANDOFF line.
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

*Lane complete on software side · Gen 2 remains external proof gate · no git commit in this pass.*
