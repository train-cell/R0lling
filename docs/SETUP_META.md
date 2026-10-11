> Current status (2026-10-10): This document describes the current Meta source gate, not a working pairing walkthrough. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) and [FINDINGS_REMEDIATION.md](FINDINGS_REMEDIATION.md).

# R0lling — Meta glasses integration status

**Updated:** 2026-10-10 · This page reports current source behavior; it is not a pairing walkthrough.

## Current status: simulation only

The live Meta DAT bridge is not implemented. `MetaGlassesAdapter` keeps simulation enabled, and disabling simulation fails because `MetaDATStreamBridge.einaiLiveYlopoiimeno` is `false`. The current SDK's camera sample uses the `MWDATCore` and `MWDATCamera` products; the source checks for those modules but does not link them. If both modules are added, session/video/audio/IMU hooks still fail with the typed unwired error. As of 2026-10-10, the official iOS repository lists DAT 1.0.1 as the latest stable release ([changelog](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md)). The official sample currently lists Xcode 26.4+, Swift 6.3+, and iOS 17.2+, while this package uses Swift tools 5.10 and targets iOS 17.0; those settings require a reviewed update before attempting integration. This app therefore cannot currently pair with Gen 2, report real battery telemetry, stream a camera, capture a photo, or expose DAT audio/IMU samples.

The Settings and Today controls can exercise the explicitly labeled simulation path. Synthetic data and placeholder clips are not evidence of Meta glasses connectivity or live media.

## Work required before a real-device setup guide is valid

1. Select and link the supported Meta DAT SDK in the app/package target.
2. Implement DAT authorization/session open and close, camera stream start/stop, frame mapping and timestamps, photo capture, and any supported audio/IMU feeds in `MetaDATStreamBridge`.
3. Keep simulation and live-device state visibly distinct. Do not enable feature readiness flags just to expose controls.
4. Build with the Apple SDK, run the Swift tests, then test pairing, reconnect, live frames, audio/IMU, background transitions, and clip playability on a supported iPhone and Gen 2 glasses.

Until those steps are complete, do not use the old pairing/30 FPS/1080p/background claims in historical audit documents as operating instructions. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md), [DEVICE_TESTS.md](DEVICE_TESTS.md), and [LANE_CLIP_META.md](LANE_CLIP_META.md) for the current limits and proof checklist.
