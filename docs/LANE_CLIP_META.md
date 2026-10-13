> Current status (2026-10-13): This lane retains its original 2026-10-06 inventory and now reflects DAT setup, registration/session, and permission-confirmed camera/frame-conversion source. It is not runtime evidence; see IMPLEMENTATION_STATUS.md, SETUP_META.md, and AUDIT_VERIFICATION.md for current proof limits. Earlier 100%, module counts, CI/head references and security/readiness claims are superseded.

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
| H.264 Annex-B remux pipeline | Source derives each sample duration from adjacent PTS; the last uses the last observed interval. Codec/runtime validation pending | `H264AnnexBRemuxer` — **3010** without SPS/PPS; **3011** for invalid, unrepresentable, or non-increasing timing |
| Meta protocol + simulation **ρητά labeled** | Implemented; runtime validation pending | `MetaGlassesAdapter` · `(SIMULATION — όχι φυσική συσκευή)` |
| Non-sim χωρίς SDK → error **4002** | Implemented; runtime validation pending | R3-003 |
| DAT registration / `DeviceSession` | Source wired; Apple SDK build, credentials, callback round-trip, and device validation pending | `MetaDATStreamBridge` — **4010** χωρίς SDK · **4011** session failure · **4012** registration handoff · **4013** start timeout |
| DAT camera/frame | Permission-confirmed publisher, bounded loss-reporting queue, and raw-to-H.264 Annex-B source present; unbuilt and live mode remains gated | MetaDATStreamBridge / MetaDATH264Encoder; Apple build, permissions, callback lifecycle, frame/format handling, and playable clip remain unverified |
| DAT photo/audio/IMU | Unwired; live mode remains gated | No photo capture, camera-audio, or motion-feed source |
| Acoustic / IMU feed API | ⚠️ synthetic adapter plumbing only; live DAT samples are not wired | `MetaGlassesAdapter` simulation · readiness false |
| Auto-clip toasts | ⏸ gated | `FeatureReadinessRegistry.acoustic/headGesture.ready = false` |

**Do not flip readiness flags from this historical example.** Current acoustic and head-gesture flags remain false. Enable them only after the corresponding real sensor capture, app flow, and device tests have been implemented and reviewed.

---

## 2. Τι χρειάζεται ακόμα Gen 2 + Mac (όχι 100% device)

| Κενό | Γιατί | Error / gate |
|---|---|---|
| DAT 1.0.1 SPM dependency and app setup | Declared for iOS with the 6.3 toolchain; Apple package/app build not run | `Package.swift`, app callback, and plist shell are present; setup does not create a live session |
| Real BT pairing / battery | Registration and `DeviceSession` source now exist, but credentials, callback return, SDK build, and device evidence are absent | Simulation remains the only usable path; live bridge remains gated |
| Real camera elementary stream | Camera attach, publisher consumption, and raw-frame conversion have source; no verified live frames are currently available because the bridge gate remains closed | Apple SDK build and Gen 2 permission/callback/frame checks are still required |
| Successful H.264 remux from glasses | The .raw path has VideoToolbox H.264 Annex-B conversion source; remux sample durations derive from adjacent source PTS, with the final duration using the last observed interval. HEVC hvc1 is not selected | Source conversion/remux timing is unbuilt; verify parameter sets, timestamps, duration, and playable clip on Apple hardware; otherwise Stage-4 placeholder remains |
| `AVAsset.isPlayable` smoke | Χρειάζεται Mac/iOS runtime | XCTest σε GHA/Mac |
| Continuous background capture | Meta sample συχνά κλείνει session | `promisesContinuousBackgroundCapture = false` μέχρι proof |
| Hey Meta wake | Experimental SDK | Εκτός αυτού του lane |
| Live acoustic/IMU από hardware | DAT mic/IMU hooks | Μόνο synthetic samples· τα unwired live hooks αποτυγχάνουν με 4010 χωρίς SDK ή 4011 όταν το SDK έχει γίνει import, και τα readiness flags μένουν false |

The official [CameraAccess sample](https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples/CameraAccess) ends the active session on background and returns to idle. For R0lling's A07 policy, a live implementation must stop the DAT camera and session on background/lock; any foreground auto-resume must create a fresh session and reattach the camera. Keep `promisesContinuousBackgroundCapture = false` unless actual device evidence supports changing it.

---

## 3. Remaining implementation and validation outline

The steps below describe remaining engineering and validation work; they do not enable a live camera path. The canImport branch now has source for registration handoff, DeviceSession .started, user-confirmed camera permission, camera attachment, publisher-token lifecycle, a bounded frame queue, and raw-to-H.264 Annex-B conversion. Photo/audio/IMU hooks still fail closed, and einaiLiveYlopoiimeno remains false. Do not switch the app to real mode until the Apple build and device evidence validate the existing stream path.

### Βήμα 0 — Προαπαιτούμενα
1. Official CameraAccess sample currently lists iOS 17.2+, Xcode 26.4+, and Swift 6.3+; a supported iPhone and Meta glasses are required for hardware validation. See [Meta CameraAccess prerequisites](https://github.com/facebook/meta-wearables-dat-ios/blob/main/samples/CameraAccess/README.md).
2. Meta Wearables Developer Center app + Client Token  
3. Meta View → Developer Mode (7 taps) → Wireless Camera Streaming  

### Βήμα 1 — Confirm the linked SDK on the Apple toolchain

The package now pins `meta-wearables-dat-ios` 1.0.1 and conditionally links `MWDATCore` and `MWDATCamera` for iOS. `R0llingApp` initializes the SDK and forwards filtered app callbacks; `Info.plist` contains the Developer Mode shell. Resolve and build this configuration on the supported Apple toolchain before proceeding. The `MetaAppID=0`, empty client token, and build-setting Team ID are development placeholders; production values must come from the user's Meta project.

### Step 2 — Review and validate MetaDATStreamBridge
Άνοιξε `Sources/R0lling/Glasses/MetaDATStreamBridge.swift` μέσα στα `#if canImport(MWDATCore) && canImport(MWDATCamera)` blocks. The official DAT camera guide is event-driven: confirm before `requestPermission(.camera)` because it switches to Meta AI, call `DeviceSession.start()`, wait until `stateStream()` reports `.started`, then add the camera. Keep `videoFramePublisher.listen` tokens alive while callbacks are active; stop the camera before the parent session. Do not implement these publisher callbacks as a blocking/polling SDK API.

1. The source selects documented .raw frames and converts them with VideoToolbox to the existing H.264 Annex-B sample contract. The hvc1 path is not selected. Apple build/device review must verify NAL units, parameter sets, timestamps, and compatibility with the clip pipeline.
2. `anoixeLiveSession()` now starts user-triggered registration when needed, then creates an `AutoDeviceSelector` session, waits up to 30 seconds for `.started`, reports the SDK's device name/optional battery, and stops the session on cancellation or disconnect. Validate this flow on the Apple toolchain and device. Start a camera only after the user confirms the Meta AI permission handoff and the session is started.
3. diavaseEpomenoVideoFrame() retains R0lling's pull-style adapter contract over videoFramePublisher. The source uses a two-frame bounded queue, terminates on overflow, and maps encoded frames to BufferedSample with source timestamps and keyframe metadata. Verify ordering, overflow, frame drops, and cancellation on Apple hardware.
4. `diavaseEpomenoAudioSample()` — αν το SDK δίνει sync audio.
5. `diavaseEpomenoIMU()` — αν εκτίθεται head tracking / IMU.
6. kleiseLiveSession() stops the child camera, cancels listener tokens, flushes the encoder, and finishes the frame queue before stopping/releasing the owned DeviceSession; verify teardown ordering and callbacks on device.

### Βήμα 3 — Open real mode only after bridge and evidence
```swift
await glassesAdapter.toggleSimulationMode(enabled: false)
try await glassesAdapter.connectDevice()
try await glassesAdapter.startStreaming()
```
Το παράδειγμα αυτό δεν συνδέεται στο παρόν checkout. Το bridge παραμένει κλειστό και το app δεν μπαίνει σε real mode· υλοποίηση, Apple build και device validation προηγούνται κάθε αλλαγής στο live-mode gate.

### Βήμα 4 — Μετά την υλοποίηση: επαλήθευση A05 remux
1. Stream ≥ 10s through an explicit conversion/remux path that produces genuine H.264 NALs (SPS type 7 + PPS type 8) and uses positive per-sample durations derived from strictly increasing presentation timestamps. The final sample uses the last observed interval.
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
  H264AnnexBRemuxer.swift          H.264 Annex-B MP4 remux; 3010 missing SPS/PPS, 3011 invalid timing; runtime unverified
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
