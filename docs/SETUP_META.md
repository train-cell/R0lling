> Current status (2026-10-09): This document contains historical assertions or design targets. It is not evidence for the current checkout. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) and [FINDINGS_REMEDIATION.md](FINDINGS_REMEDIATION.md). Earlier “100%”, module counts, CI/head references and security/readiness claims are superseded.

# R0lling — Meta glasses integration status

**Updated:** 2026-10-09 · This page reports current source behavior; it is not a pairing walkthrough.

## Current status: simulation only

The live Meta DAT bridge is not implemented. `MetaGlassesAdapter` keeps simulation enabled, and disabling simulation fails because `MetaDATStreamBridge.einaiLiveYlopoiimeno` is `false`. If the DAT module is linked, session startup and frame reads still fail with the typed unavailable error. This app therefore cannot currently pair with Gen 2, report real battery telemetry, stream a camera, capture a photo, or expose DAT audio/IMU samples.

The Settings and Today controls can exercise the explicitly labeled simulation path. Synthetic data and placeholder clips are not evidence of Meta glasses connectivity or live media.

## Work required before a real-device setup guide is valid

1. Select and link the supported Meta DAT SDK in the app/package target.
2. Implement DAT authorization/session open and close, camera stream start/stop, frame mapping and timestamps, photo capture, and any supported audio/IMU feeds in `MetaDATStreamBridge`.
3. Keep simulation and live-device state visibly distinct. Do not enable feature readiness flags just to expose controls.
4. Build with the Apple SDK, run the Swift tests, then test pairing, reconnect, live frames, audio/IMU, background transitions, and clip playability on a supported iPhone and Gen 2 glasses.

Until those steps are complete, do not use the old pairing/30 FPS/1080p/background claims in historical audit documents as operating instructions. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md), [DEVICE_TESTS.md](DEVICE_TESTS.md), and [LANE_CLIP_META.md](LANE_CLIP_META.md) for the current limits and proof checklist.
