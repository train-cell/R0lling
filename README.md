# R0lling

Clip the moment. Keep the day.

R0lling is a personal journal implemented as a Swift package with an iOS app host. Notes and media are stored locally. Linking an Obsidian vault is an explicit setup action; while linked, journal saves and edits export automatically. AI requests remain user-triggered.

On iOS, journal writes, media imports, and restored media use Apple's file protection until the first unlock after a device restart; existing journal/media files are migrated when loaded or accessed. This is OS-managed encryption at rest, not app-level encryption; backup bundles remain plaintext.

The package uses Swift tools 5.10 and Swift 5 language mode with StrictConcurrency checking. The iOS host targets iOS 17.2. These settings do not establish Swift 6 concurrency compliance.

## Current implementation

The table describes source paths in this checkout. It does not mean the Apple runtime, network providers, hardware, or visual layout have passed end-to-end validation; see [implementation status](docs/IMPLEMENTATION_STATUS.md).

| Feature | Current status |
|---|---|
| Journal CRUD, search, date correction, media viewer | Implemented; corrupted/unsupported JSON fails closed without overwriting it |
| Obsidian export | Files picker, bookmarks, Markdown, attachment copies, conflict sidecars; export errors propagate |
| Backup/restore | Plain JSON + media + optional Agent memory; copy errors propagate; no backup encryption |
| AI chat | Direct HTTPS or Hermes gateway; selected endpoint is validated on save; Keychain credentials can be removed from Settings; settings persisted |
| Chat context | Journal and Agent memory OFF by default; up to five recent entries; optional manually entered note location is sent only with its separate opt-in |
| Explicit AI summary/recall | Sends the selected entries to the configured provider; summary context is limited to five |
| Imported image AI | Decodes and converts images to JPEG without original metadata before transmission |
| Glasses | Simulation only; importing the DAT SDK does not complete session/camera integration |
| Rolling clips | Simulation placeholder MP4 export; H264 remux helper exists, real DAT feed missing |
| HealthKit | Five optional quantities (HRV, resting heart rate, respiratory rate, blood oxygen, and body temperature) plus the longest merged sleep episode in the prior-evening-to-noon window; overlapping stages count once and a separate nap is not added; request completion is not proof of read permission; no fabricated readings or clinical recovery score |
| Fitness | 30-day workout-count calendar with selectable days; cumulative workout-duration chart, total, and period comparison from HealthKit samples; empty and unavailable reads stay distinct |
| Executive utilities | Tasks and focus history persist in UserDefaults; daily focus totals aggregate session/day overlap and the active focus ring updates live; scratchpad writes journal; stopwatch uses monotonic time; active deadline resumes after relaunch using wall-clock time |
| Studio and strategy cards | Explicit UI previews; most actor helpers are prototypes, not integrated product features |
| Biohacking / Health | Live HealthKit readings and local breathing/binaural-audio tools; disconnected sample metrics remain collapsed previews; binaural output needs stereo headphones and device playback is not validated |
| Vault helper | AES-GCM + device-bound Keychain key; not Secure Enclave AES; does not encrypt the journal or backups |
| Private diary | AES-GCM encrypted local entries; store APIs require a per-store authorization capability issued only after successful LocalAuthentication and revoked on lock. Device-bound Keychain key; explicitly excluded from OS backups, with no recovery on device loss. The Keychain item is not itself biometry-bound or Secure Enclave-backed |
| Future letterbox | Encrypted local messages; store API requires a post-biometric authorization capability and redacts future payloads using the device's current wall clock. A changed clock can move the unlock date. Excluded from OS backups |
| Decision journal | Encrypted decisions and assumptions with confidence tracking and a due-date-gated 90-day review. Store APIs require the same post-biometric authorization capability; the Keychain item is not itself biometry-bound or Secure Enclave-backed. Excluded from OS backups |
| Shamir / secure zeroization | Core 2-of-3 split/recovery API with authenticated shares; no share-delivery UI or independent security audit. Secure zeroization remains unavailable |

AI actions send data to a provider. Hermes is a configurable gateway, not an enforced air gap. There is no outbound byte counter or firewall enforcement. The app does not automatically redact journal text for PII.

## Evidence and limitations

See [implementation status](docs/IMPLEMENTATION_STATUS.md), [capability map](docs/CAPABILITY_MATRIX.md), and [findings remediation](docs/FINDINGS_REMEDIATION.md).

The Python scripts contain independent model examples and source/config checks. Passing them does not prove Swift behavior, visual fidelity, platform compliance, or hardware support. The GitHub Actions workflow contains separate macOS Swift build/tests and iOS host builds. No claim is made that the current uncommitted changes have passed those jobs.

The UI direction follows the Bevel screens in the external `ui understanding` folder: charcoal/slate cards with a subtle raised bevel edge, inset metric rings, and floating capsule navigation. The primary destinations are Today, Journal, Fitness, and Health. Fitness has a 30-day HealthKit workout calendar and duration comparison; Today keeps the summary prominent and collapses secondary tools by default. Static code was updated across these screens, but rendered iPhone/Simulator comparison remains pending.

## Build

On a Mac with Xcode:

```sh
swift build
cd Apps/R0llingApp
xcodegen generate
open R0llingApp.xcodeproj
```

`Package.swift` produces a library. `Apps/R0llingApp/Host` provides the app entry point. Enable a valid signing team with HealthKit capability for a device build. Windows cannot build this Apple-framework application.

## License

[MIT](LICENSE)
