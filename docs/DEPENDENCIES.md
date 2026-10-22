# R0lling — Declared Dependencies and Toolchain

Updated: 2026-10-13. This page describes the current package and app scaffold (base `b29429b` plus the uncommitted 2026-10-13 workflow update), not the superseded design proposal from 2026-10-06.

## Declared platform and language settings

| Setting | Current declaration | What it does not prove |
|---|---|---|
| Swift tools version | 6.3 (`Package.swift`), the toolchain listed by Meta for DAT 1.0.1; requires Xcode 26.4 or newer | No Apple build of the current source has been recorded. |
| Swift language mode | 5.0 in the XcodeGen app target; the package declares `swiftLanguageModes: [.v5]` with the `StrictConcurrency` upcoming feature | The package does not declare Swift 6 language mode. |
| Swift package platforms | iOS 17.2 (`.iOS("17.2")`; PackageDescription 6.3 has no `.v17_2` case), macOS 14 | A successful Apple build has not been recorded for the current source. |
| iOS host deployment target | iOS 17.2 (`Apps/R0llingApp/project.yml`) | The minimum does not establish device or simulator validation. |
| CI runners | Apple jobs: `macos-26` with fail-closed selection of Xcode 26.6, 26.5, 26.4.1 or 26.4. Portable harnesses: `ubuntu-latest` in the official `swift:6.1` container. Python checks: `ubuntu-latest`. This layout is the uncommitted 2026-10-13 update. | Earlier hosted runs on `b614db9`/`b29429b` used `macos-14`/Xcode 16 and failed before `swift build`. The new layout has not run yet. |

## Package dependencies

`Package.swift` declares one external package: `https://github.com/facebook/meta-wearables-dat-ios` at exact version `1.0.1`. Its `MWDATCore` and `MWDATCamera` products are linked only for iOS (`condition: .when(platforms: [.iOS])`), so macOS builds and tests compile without them. The live DAT bridge stays gated (`MetaDATStreamBridge.einaiLiveYlopoiimeno == false`) and simulation is the only usable glasses mode. See [SETUP_META.md](SETUP_META.md). `MWDATMotion` is not linked.

The app uses Apple frameworks conditionally where available, including SwiftUI, AVFoundation/AVKit, VideoToolbox, Speech, Vision, HealthKit, LocalAuthentication, Security/Keychain, CryptoKit, and ImageIO. The journal and backup format use JSON and files ([CROSS_PLATFORM_DATA_CONTRACT.md](CROSS_PLATFORM_DATA_CONTRACT.md)); SwiftData, Core Data, and SQLite are not current persistence dependencies.

## Host app and permissions

`Apps/R0llingApp/project.yml` defines an XcodeGen iOS app target, and `Info.plist` contains its usage descriptions plus the Developer Mode DAT configuration shell. CI generates and builds the target on macOS. Permission strings and build configuration do not establish that each prompt or denial path has been exercised on a device. See [the host target README](../Apps/R0llingApp/README.md) and [device test checklist](DEVICE_TESTS.md).

## Verification

A Windows/WSL or Linux environment can parse Swift source and run the portable harnesses, but cannot run the Apple build or the full XCTest suite because Apple's SDK frameworks are absent. See [AUDIT_VERIFICATION.md](AUDIT_VERIFICATION.md) for the current verification boundary and [the CI workflow](../.github/workflows/swift-ci.yml) for the jobs.
