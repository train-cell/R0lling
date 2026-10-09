# R0llingApp — iOS host target

`Package.swift` defines the reusable `R0lling` Swift package. `project.yml` defines the iOS app target through XcodeGen, `Host/` contains the app entry point, and `Info.plist` contains app metadata and privacy usage descriptions. The generated `.xcodeproj` is not checked in.

## Build the app on macOS

Requirements are an Apple toolchain compatible with the declared iOS 17.2 deployment target, XcodeGen, and an iOS Simulator or device. The repo's CI generates the project and builds both generic iOS and Simulator targets; inspect the CI run to learn which Xcode version actually ran.

```bash
cd Apps/R0llingApp
xcodegen generate
xcodebuild build -project R0llingApp.xcodeproj -scheme R0llingApp \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

To run on a physical device, select a signing team and device in Xcode. This build setup does not imply that the current uncommitted remediation has been built or exercised on an Apple device.

## Privacy usage descriptions

The current `Info.plist` declares:

| Key | Purpose |
|---|---|
| `NSCameraUsageDescription` | Reserved for future camera capture; this version has no camera capture flow |
| `NSMicrophoneUsageDescription` | Speech notes; this version does not capture or synchronize clip audio |
| `NSSpeechRecognitionUsageDescription` | Speech-to-text |
| `NSPhotoLibraryUsageDescription` | Importing media |
| `NSPhotoLibraryAddUsageDescription` | Reserved for future Photos-library export; current media import uses pickers and does not write to Photos |
| `NSBluetoothAlwaysUsageDescription`, `NSBluetoothPeripheralUsageDescription` | Reserved for future glasses pairing; this version has no CoreBluetooth transport and live Meta DAT remains unavailable |
| `NSLocalNetworkUsageDescription` | Outgoing connection to a manually configured local Hermes endpoint; Bonjour discovery is not implemented |
| `NSFaceIDUsageDescription` | Private diary unlock |
| `NSHealthShareUsageDescription` | Reading five optional HealthKit measurements, sleep intervals, and recorded workouts for the Health and Fitness screens |
| `NSHealthUpdateUsageDescription` | Reserved for future HealthKit writes; current HealthKit service requests read-only access |

Several usage keys are retained for planned capabilities and do not represent working product flows. This version has no camera capture, Photos-library write, CoreBluetooth glasses transport, clip-audio capture/synchronization, or HealthKit write path. Photos and Files picker imports are implemented; speech notes and HealthKit measurement, sleep, and workout reads are separate implemented paths. Live Meta DAT is unavailable. No permission prompt or denial flow has been verified on-device.

## Disk space

`MediaStorageService` checks `ELAXISTOS_ELEUTHEROS_XOROS_BYTES` (50 MB) before a media write and reports `MediaApothikeusiError.anepikisXoros` through `AppErrorTaxonomy.diskFull`.

## Verification boundaries

The Python scripts are independent examples or source/config checks. They do not execute the Swift app, test OS permission prompts, or render the UI. Current Apple build/XCTest status is in [`docs/IMPLEMENTATION_STATUS.md`](../../docs/IMPLEMENTATION_STATUS.md); the manual device checklist is in [`docs/DEVICE_TESTS.md`](../../docs/DEVICE_TESTS.md).
