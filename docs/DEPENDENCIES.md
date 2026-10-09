# R0lling — Declared Dependencies and Toolchain

Updated: 2026-10-09. This page describes the current package and app scaffold, not the superseded design proposal from 2026-10-06.

## Declared platform and language settings

| Setting | Current declaration | What it does not prove |
|---|---|---|
| Swift tools version | 5.10 (`Package.swift`) | It is not a promise that every Swift 5.10/Xcode combination builds the project. |
| Swift language mode | 5.0 in the XcodeGen app target; the package uses Swift 5 mode with the `StrictConcurrency` upcoming feature | The package does not declare Swift 6 language mode. |
| Swift package platforms | iOS 17, macOS 14 | A successful Apple build has not been recorded for the current remediation. |
| iOS host deployment target | iOS 17.2 (`Apps/R0llingApp/project.yml`) | The minimum does not establish device or simulator validation. |
| CI runner | `macos-14`; workflow selects an available Xcode, preferring Xcode 16.x and falling back to 15.4 | The fallback is an availability path, not a certified minimum. Check the run logs for the exact Xcode and results. |

## Package dependencies

`Package.swift` currently declares no external Swift package dependencies. The Meta Wearables DAT package and product entries are commented out. The real DAT bridge remains unavailable; the app identifies glasses mode as simulation.

The app uses Apple frameworks conditionally where available, including SwiftUI, AVFoundation/AVKit, Speech, HealthKit, LocalAuthentication, Security/Keychain, and ImageIO. The journal and backup format use JSON and files; SwiftData, Core Data, and SQLite are not current persistence dependencies.

## Host app and permissions

`Apps/R0llingApp/project.yml` defines an XcodeGen iOS app target and `Info.plist` contains its usage descriptions. CI generates and builds the target on macOS. Permission strings and build configuration do not establish that each prompt or denial path has been exercised on a device. See [the host target README](../Apps/R0llingApp/README.md) and [device test checklist](DEVICE_TESTS.md).

## Verification

The current Windows/WSL environment can parse Swift source but cannot run the Apple build or XCTest suite because Apple's SDK frameworks are absent. See [implementation status](IMPLEMENTATION_STATUS.md) for the current verification boundary and [CI workflow](../.github/workflows/swift-ci.yml) for the Apple jobs.
