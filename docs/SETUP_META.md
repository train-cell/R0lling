---
tags: [r0lling, meta, dat, hardware]
last_modified: 2026-10-13
---

# R0lling — Meta glasses integration status

**Updated:** 2026-10-13 · This page reports source configuration and remaining work; it is not a pairing walkthrough or proof of a working connection.

See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md), [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md), and [AUDIT_VERIFICATION.md](AUDIT_VERIFICATION.md) for the repository-wide status.

## DAT SDK and app configuration shell

The package now declares the official `meta-wearables-dat-ios` release `1.0.1`, with `MWDATCore` and `MWDATCamera` as iOS-only target products. `Package.swift` uses Swift tools 6.3, iOS 17.2, and Swift 5 language mode to match the published SDK requirements while preserving the existing source language mode. These declarations have not been resolved or built on an Apple toolchain.

`R0llingApp` calls `Wearables.configure()` at app initialization and forwards app-link callbacks only when the URL uses `com.personal.r0lling` and contains the `metaWearablesAction` query item. `Info.plist` declares that callback scheme, the `MWDAT` dictionary, supported accessory protocol, DAT background modes, and Bonjour service. The current `MetaAppID=0`, blank client token, and `$(DEVELOPMENT_TEAM)` substitution are Developer Mode scaffolding, not production credentials. The user must supply and validate any real Meta Developer Center app values and signing team before a production setup.

Meta's [Getting Started guide](https://github.com/facebook/meta-wearables-dat-ios/blob/main/plugins/mwdat-ios/skills/getting-started/SKILL.md) lists Xcode 26.4+, Swift 6.3+, and iOS 17.2+ and requires SDK initialization plus app-link callback handling. The official [CameraAccess sample](https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples/CameraAccess) documents session and camera-stream setup. These sources guide the declarations above; source inspection does not prove XcodeGen generation, package resolution, initialization, callback handling, or permission behavior on a device.

## Current runtime status: simulation only; DAT session source is wired

The app's usable glasses path remains the explicitly labeled simulation. `MetaGlassesAdapter` defaults to simulation, and attempts to disable it remain rejected because `MetaDATStreamBridge.einaiLiveYlopoiimeno` is `false`. The bridge now has source code for user-triggered registration, `AutoDeviceSelector` session startup, waiting for `.started` with a 30-second timeout, and session teardown. If registration is missing, the first connect action opens Meta AI and reports that the user must finish approval and tap Connect again. A started session maps its SDK device name and optional battery field into the existing connection handle. This code has not been compiled or exercised with the pinned Apple SDK, registered credentials, or hardware.

The existing Today start control now has an explicit confirmation before a camera-permission request can switch to Meta AI. After permission is granted, source code attaches a medium `.raw` DAT camera only to a started session, retains/cancels publisher tokens, adapts frames through a two-frame loss-reporting queue, and encodes 504×896 YUV frames into H.264 Annex-B with VideoToolbox. A 15-second stream-start timeout, callback errors, encoder overload, and unexpected resolution changes fail closed. This source has not been Apple-built or exercised with credentials/device; the live gate remains false. Photo capture, audio, and IMU remain unwired. Device name and battery mapping are also unverified.

## Sensor APIs exposed by the SDK

DAT 1.0.0/1.0.1 also exposes `MWDATMotion` for device motion and an experimental PCM audio extension to `MWDATCamera.Stream`. Motion is experimental, requires capability enablement in Wearables Developer Center, has no runtime permission, and cannot currently be published to production release channels. Camera audio is experimental, requires camera and microphone permission, and arrives alongside the camera stream. R0lling does not link `MWDATMotion` or wire either capability; the existing adapter samples remain simulation-only. The current `NSMicrophoneUsageDescription` only describes voice notes and says audio is not recorded for clips; revise that disclosure to describe glasses camera-audio processing before requesting microphone permission for DAT audio. Keep the current string while no DAT audio flow is wired. See Meta's [Motion guide](https://github.com/facebook/meta-wearables-dat-ios/blob/main/plugins/mwdat-ios/skills/motion/SKILL.md), [Audio Streaming guide](https://github.com/facebook/meta-wearables-dat-ios/blob/main/plugins/mwdat-ios/skills/audio-streaming/SKILL.md), and [SDK changelog](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md).

The official camera guide uses a lifecycle and publisher API, not synchronous frame pulls: confirm before a camera permission request that switches to Meta AI, start `DeviceSession`, wait for `.started`, then add the camera and listen to `videoFramePublisher`. R0lling now adapts that publisher to its pull-style buffer through a bounded queue and cancels retained listeners after stopping the child camera. It requests `.raw` medium frames at 24 FPS and uses VideoToolbox to produce the existing H.264 Annex-B sample contract; the encoder expects 504×896 frames and terminates on a resolution change because the current clip track cannot represent a format switch. These paths remain unbuilt and unverified. See Meta's [Camera Streaming guide](https://github.com/facebook/meta-wearables-dat-ios/blob/main/plugins/mwdat-ios/skills/camera-streaming/SKILL.md) and [Getting Started guide](https://github.com/facebook/meta-wearables-dat-ios/blob/main/plugins/mwdat-ios/skills/getting-started/SKILL.md).

Before using Motion for B02, the app needs Developer Center approval, a session lifecycle, an explicit mapping from the SDK's optional orientation samples to the existing pitch detector, and device evidence that the signal and thresholds identify a double nod. Before using camera audio for B01, the app needs the camera session, explicit permission flow, route/source honesty, and PCM-to-RMS handling. Neither capability should turn its readiness flag on from module presence alone.

Synthetic adapter samples and placeholder clips are not evidence of Meta glasses connectivity or live media. No pairing, permission prompt, callback round trip, capture, or reconnect behavior has been verified on an iPhone or Gen 2 glasses.

## Work still required for live capture

The official [CameraAccess sample](https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples/CameraAccess) ends its active camera session when the app backgrounds and returns to an idle state; the user starts a new session after returning. When adapting this to R0lling's existing A07 paused/auto-resume UI, background/lock handling must stop the DAT stream and session, and foreground resume must create a fresh session before attaching a camera. Do not preserve a stale session handle or claim continuous background capture.

1. Resolve Developer Mode and production-credential configuration with the user's Meta app, signing team, and target Apple setup.
2. Source now implements the existing-app permission confirmation, registration handoff, `DeviceSession` and camera start/stop lifecycles, publisher-token retention, bounded startup wait, and fresh-session auto-resume after background/lock. On Apple, verify the registration callback/return flow, camera permission/denial, both startup timeouts, teardown, and supported-device behavior.
3. Source now selects documented `.raw` medium frames and converts them to H.264 Annex-B with VideoToolbox, preserving presentation timestamps and keyframe parameter sets. The remuxer derives positive sample durations from adjacent PTS at its presentation timescale and uses the last observed interval for the final sample. The queue and encoder stop on overflow, encoding failure, or resolution change. Validate conversion, timing, and playable-clip output on Apple hardware; the source is not evidence of a successful remux.
4. Implement photo capture only through the existing capture contract. The SDK exposes experimental Motion and camera-audio surfaces; integrate them only after their Developer Center approval, required permission/user flow, source semantics, and sample mapping are reviewed. Keep readiness false until device validation.
5. On supported macOS/Xcode, resolve and build the package/app, run the full XCTest target, then validate pairing, callback return, permission denial, live capture, clip playability, interruption, reconnect, and background behavior on supported iPhone/Gen 2 hardware.

Until the Apple build and device evidence exist, do not describe pairing, real battery telemetry, camera capture, live audio/IMU, or background capture as working. See [DEVICE_TESTS.md](DEVICE_TESTS.md), [LANE_CLIP_META.md](LANE_CLIP_META.md), and the [official SDK changelog](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md) for related requirements and API history.
