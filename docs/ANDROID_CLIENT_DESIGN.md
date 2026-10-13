# R0lling Android client — design

Updated: 2026-10-13. Status: design only. There is no Android code, Gradle project, build, test, or release artifact in this repository. The stack decision is open; see [ADR_0001_ANDROID_WINDOWS_CLIENT_STACK.md](ADR_0001_ANDROID_WINDOWS_CLIENT_STACK.md). Both candidate stacks (options A and C) use Kotlin and Jetpack Compose on Android, so this design applies to either. Under option A, the shared core lives in KMP `commonMain`.

Scope and parity rules come from [CROSS_PLATFORM_FEATURE_PARITY.md](CROSS_PLATFORM_FEATURE_PARITY.md). Data shapes come from [CROSS_PLATFORM_DATA_CONTRACT.md](CROSS_PLATFORM_DATA_CONTRACT.md) and [`contracts/r0lling-exchange-v1.schema.json`](contracts/r0lling-exchange-v1.schema.json).

## Product boundary

- A separate, local-first Android app. Each installation owns its journal. The only exchange paths are the explicit backup bundle and the Obsidian vault export. There is no account, server, or automatic sync.
- Same Greek UI copy, routes, actions, and semantics as iOS. Prototype and sample cards are out of the initial scope.
- Capabilities without a validated Android source stay off and say so: Health Connect until its gate passes, DAT glasses, OCR, speech, and TTS.

## Architecture

```text
android-app (Jetpack Compose UI, navigation, Android adapters)
  ├─ ui/            screens: Today, Journal, Fitness, Health, Vault, Assistant, Settings
  ├─ adapters/      SAF vault + document trees, Photo Picker, Health Connect,
  │                 Keystore/BiometricPrompt, TTS, speech, OCR, DAT (all gated)
  └─ depends on
core (platform-neutral Kotlin; KMP commonMain under ADR option A)
  ├─ contract/      v1 JSON codec (journal file, backup manifest, export hashes)
  ├─ journal/       repository rules: day grouping, search, atomic merge, limits
  ├─ media/         path grammar, naming, size/reserve checks (I/O behind interfaces)
  ├─ backup/        bundle writer/reader with all-or-nothing restore semantics
  ├─ obsidian/      Markdown block merge, hash store, conflict sidecars, Agent files
  ├─ ai/            request builder, limits, redaction, endpoint validation, recall fallback
  └─ telemetry/     daily-score heuristic, focus aggregation, sleep/fitness bucketing
```

The core performs no Android I/O directly. File access, clocks, randomness, the credential store, and the network sit behind interfaces, so the conformance fixtures can run on the JVM in CI.

## Platform adapters

| Concern | Android mechanism | Parity requirement / gate |
|---|---|---|
| Journal and media storage | App-private internal storage (for example `filesDir/R0lling/journal_v1.json` and `filesDir/R0lling/Media/<Folder>/`) | 64 MiB journal cap; atomic replace (write temp file, then rename); fail closed on corrupt or unsupported files; 50 MiB free-space reserve via the platform's allocatable-bytes query |
| OS backup of app data | Explicit `dataExtractionRules` / backup rules | The encrypted Vault and credential material must be excluded. Whether the journal and media take part in Android's own device backup is a **user decision**; iOS currently leaves them in OS backups and excludes only the Vault. Either choice must be disclosed |
| Media import | Android Photo Picker for photos/videos; `ACTION_OPEN_DOCUMENT` for files and audio | Stream-copy without loading whole files; MP4/MOV/M4V video only; generated `<UPPERCASE-UUID>.<ext>` names; `originalFilename` display rule from the contract |
| Obsidian vault | `ACTION_OPEN_DOCUMENT_TREE` with a persisted URI permission | `DocumentsContract.createDocument` may rename on collision, so check the returned name and treat a rename as a conflict. Re-read and re-hash immediately before replacing a note. Conflict sidecars use exclusive creation. Never follow provider links outside the tree. Provider atomicity must be validated per provider |
| Backup export/restore | Pick a destination tree and create a `<name>.r0backup/` folder containing `manifest.json` and `Media/`; restore picks a folder tree | Same validation, limits, insert-if-absent, Agent-memory replacement and rollback as iOS |
| Credentials (API key, Hermes token) | AES key held in Android Keystore, wrapping secrets in app-private storage | Never logged or exported; removable from Settings |
| Encrypted Vault | Keystore key plus BiometricPrompt with device-credential fallback | Capability issued after authentication and revoked on stop/lock; 8 MiB document cap; excluded from all backups; no recovery. A biometric-bound key is allowed but must be described accurately |
| Health | Health Connect read permissions for the displayed types only | HRV is RMSSD on Health Connect (see the parity HRV note); no writes; denied or unavailable permission is explained without a repeat-request loop; no interpolation or scores; Fitness uses Europe/Athens buckets like iOS. Verify current Health Connect availability per Android version and the Play health-permission declaration before enabling |
| Speech notes | On-device speech recognition only | iOS is on-device or unavailable; Android must match. If no on-device Greek recognizer is available, show unavailable |
| Text-to-speech (podcast) | System `TextToSpeech` | Greek voice availability is device-dependent; show unavailable when missing |
| OCR for image analysis | On-device OCR engine with Greek script support (to be selected) | Until an engine is chosen and validated, local OCR is unavailable; cloud description still requires an explicit request |
| Meta glasses | Official DAT Android SDK (Maven Central `com.meta.wearable`, developer preview) | Same gates as iOS: registration through Meta AI, explicit permission confirmation, `ready=false` until device evidence. Experimental audio and photo stay unwired |
| Networking | Platform HTTP client with redirects disabled and a streamed 8 MiB response cap | Same limits, retry codes, and cancellation semantics as `AIHTTPClient` |
| Time zones | `java.time` IANA zones | Store IANA identifiers; reject unknown identifiers in the editor |

## UI and styling

- **Navigation:** a four-item bottom bar (Σήμερα, Ημερολόγιο, Fitness, Υγεία) and a plus button that opens the six quick actions in a modal sheet. Back closes the sheet and focus returns to the launcher.
- **Theme:** dark-only, like iOS, with the color values from `Sources/R0lling/UI/Theme.swift` mapped to a Compose theme object. Read the hex values from that file instead of copying the [DESIGN.md](DESIGN.md) table by hand, and keep one token name per Swift token so reviews can diff them.
- **Visual language:** charcoal canvas, flat slate cards with one quiet outline, restrained shadows, separated rings for independent measures, and no neon glows. Reproduce the language, not iPhone pixel positions.
- **Typography:** scalable `sp` text styles throughout. Unlike several iOS screens that still use fixed point sizes, the Android client must not hard-code text sizes.
- **Touch targets:** at least 48dp, the Android guideline (iOS uses 44pt). Icon-only actions need content descriptions.
- **Copy:** Greek strings in `values/strings.xml`, with the same wording as iOS. A missing translation must not fall back to invented copy.

## Accessibility and release gates

1. TalkBack can reach, name, and operate every control on every ported screen. Check font scaling up to the largest system size, display-size changes, and contrast.
2. Cross-client exchange: an iOS-generated bundle restores without loss, and an Android-generated bundle restores on iOS (data-contract acceptance gate).
3. The Obsidian vault opens in Obsidian, re-export is idempotent, and conflict sidecars appear on an external edit, all with the user's real vault provider.
4. Health Connect: permission grant and denial, a no-data state, and HRV labeling on a real device.
5. Release: a signed AAB with user-owned signing keys, a privacy policy and data-safety form describing local storage and AI requests, and the health-permission declaration if Health Connect is shipped.

None of these gates has been attempted.

## CI outline (not implemented)

- An Ubuntu job that builds the Android module and runs the core conformance fixtures on the JVM.
- Optional instrumentation tests on an emulator for SAF and Photo Picker flows. These do not replace device validation.
