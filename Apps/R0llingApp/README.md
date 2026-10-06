# R0llingApp — iOS Host Target Scaffold (P0-05)

Το `Package.swift` παράγει **SPM library** (`R0lling`). Αυτός ο φάκελος είναι το **installable app shell**: Info.plist με privacy strings (A16) + οδηγίες Mac build.

> Δεν υπάρχει committed `.xcodeproj` (αποφυγή merge thrash). Δημιούργησε το app target σε Mac μία φορά με τα βήματα κάτω.

## Απαιτήσεις

- macOS 14.4+ · Xcode 16+ · iPhone iOS 17.2+ (ή Simulator)
- Apple Developer Team για device signing

## Γρήγορο build (SPM library smoke)

```bash
cd /path/to/R0lling
swift build
swift test
```

Το library target περιέχει ήδη `@main` `R0llingApp` για macOS SPM run. Για **iOS device/simulator** χρειάζεται App target (κάτω).

## Δημιουργία iOS App target σε Xcode

1. **File → New → Project → iOS → App**
   - Product Name: `R0llingApp`
   - Bundle ID: `com.personal.r0lling` (ή δικό σου)
   - Interface: SwiftUI · Language: Swift · Storage: None
2. **Κλείσε** το default `ContentView` / `@main` App αρχείο του template (θα χρησιμοποιήσεις το package).
3. **File → Add Package Dependencies… → Add Local…** → επίλεξε το root `R0lling/` (όπου είναι το `Package.swift`).
4. Στο App target → **General → Frameworks** → πρόσθεσε το product `R0lling`.
5. **Info** του App target → άνοιξε / αντικατέστησε με `Apps/R0llingApp/Info.plist`
   - ή κάνε Copy Keys από αυτό το plist στα Custom iOS Target Properties.
6. **Signing & Capabilities** → Personal Team · μοναδικό Bundle ID.
7. (Προαιρετικό) Meta DAT: βλ. `docs/LANE_CLIP_META.md` · `docs/DECISIONS.md` §2 (v1 simulation-only OK).
8. Scheme → iPhone / Simulator → **⌘R**.

### Εναλλακτικό: XcodeGen

Αν έχεις `xcodegen`:

```bash
cd Apps/R0llingApp
xcodegen generate   # διαβάζει project.yml
open R0llingApp.xcodeproj
```

## Privacy keys (A16) — ήδη στο Info.plist

| Key | Σκοπός |
|---|---|
| `NSCameraUsageDescription` | Photos / game / glasses |
| `NSMicrophoneUsageDescription` | Voice notes / clip audio |
| `NSSpeechRecognitionUsageDescription` | On-device STT |
| `NSPhotoLibraryUsageDescription` | A03 media attach |
| `NSBluetoothAlwaysUsageDescription` | Meta Gen 2 |
| `NSLocalNetworkUsageDescription` | Hermes LAN |

Deny path: UI δείχνει typed error μέσω `AppErrorTaxonomy` — χωρίς silent success.

## Disk full (A16)

`MediaStorageService` ελέγχει `ELAXISTOS_ELEUTHEROS_XOROS_BYTES` (50MB) πριν εγγραφή · ρίχνει `MediaApothikeusiError.anepikisXoros` → `AppErrorTaxonomy.diskFull`.

## Verification

```bash
# Windows / οποιοδήποτε host
python verification/diagnose_stage5_finalize.py
python verification/verify_all_subsystems.py

# Mac only
swift test
```
