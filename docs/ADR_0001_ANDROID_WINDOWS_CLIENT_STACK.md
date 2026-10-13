# ADR 0001 — Android and Windows client stack

- **Status:** Proposed — awaiting the user's decision. Nothing in this ADR is implemented, built, or tested.
- **Date:** 2026-10-13
- **Scope:** the two new clients only. The iOS client stays native SwiftUI and remains the source of truth for v1 behavior ([MULTIPLATFORM_ROADMAP.md](MULTIPLATFORM_ROADMAP.md)).
- **Related:** [CROSS_PLATFORM_DATA_CONTRACT.md](CROSS_PLATFORM_DATA_CONTRACT.md), [CROSS_PLATFORM_FEATURE_PARITY.md](CROSS_PLATFORM_FEATURE_PARITY.md), [ANDROID_CLIENT_DESIGN.md](ANDROID_CLIENT_DESIGN.md), [WINDOWS_CLIENT_DESIGN.md](WINDOWS_CLIENT_DESIGN.md).

## Context

The product target is separate Android and Windows clients next to the existing iOS app. Data stays local on each installation; the only exchange paths are the explicit backup bundle and the Obsidian export. There is no sync service.

`MULTIPLATFORM_ROADMAP.md` recommends Kotlin Multiplatform (KMP) with Compose Multiplatform for both new clients. The user asked for that direction to be evaluated rather than treated as approved. This ADR does that evaluation.

What makes the choice consequential:

1. **Semantic parity is the main risk.** The two new clients must reproduce non-trivial iOS rules exactly:
   - the v1 JSON shapes, dates, and UUID text;
   - restore all-or-nothing and Agent-memory replacement;
   - the Obsidian Markdown, hash, and conflict-sidecar rules;
   - outbound PII redaction with checksum validation;
   - the Hermes cleartext allowlist;
   - AI request and response limits;
   - newest-N context selection and opt-in defaults.

   Every additional implementation of these rules is another place for them to drift. See [CROSS_PLATFORM_FEATURE_PARITY.md](CROSS_PLATFORM_FEATURE_PARITY.md).
2. **Platform integrations differ.**
   - Android needs the Storage Access Framework (vault folder), Health Connect, the official Meta Wearables DAT Android SDK (Maven Central `com.meta.wearable`, developer preview), Keystore and BiometricPrompt.
   - Windows needs folder and file dialogs, a credential store, Windows Hello for the encrypted Vault, keyboard and window layouts, and an honest "unavailable" state for health and glasses.
3. **Accessibility is a release gate.** That means TalkBack on Android, and Narrator plus at least one third-party screen reader on Windows, with keyboard-only operation.
4. **Styling.** The same R0lling token set (`Sources/R0lling/UI/Theme.swift`, [DESIGN.md](DESIGN.md)) has to be re-expressed per platform without claiming iPhone pixel parity.
5. **Cost.** A small team or solo developer already maintains Swift (iOS) and Python (verification). Each extra language adds CI, tooling, and review cost.

## Options considered

### A. Kotlin Multiplatform core + Compose Multiplatform UI (Android + Windows desktop on the JVM)

- **Shared:** one Kotlin implementation of the domain, the codec, and the parity rules (`commonMain`) and of most UI (Compose), with platform adapters in `androidMain` and `desktopMain` (JVM).
- **Android fit:** first-class. Kotlin, Jetpack Compose, Health Connect Jetpack client, SAF, BiometricPrompt and the Meta DAT Android SDK are all native to the toolchain.
- **Windows fit, from the official Compose Multiplatform docs (checked 2026-10-13):**
  - accessibility is "Supported via Java Access Bridge", which is disabled by default, and distributions must add the `jdk.accessibility` module;
  - the docs name JAWS and NVDA for checking output and do not mention Narrator;
  - native distributions are `.exe` and `.msi` only, built on the matching OS (no cross-compilation), with a bundled Java runtime produced by jlink/jpackage (JDK 17+ on the build machine);
  - MSIX and Windows code signing are not covered by the plugin docs.
- **Cost:** one new language (Kotlin) for both clients.

### B. KMP core + Jetpack Compose on Android + native WinUI 3 (C#) on Windows

- Sharing the Kotlin core with C# would need Kotlin/Native (`mingwX64`) behind a C ABI, or a JVM bridge.
- That interop layer is a large surface and has not been evaluated here.
- **Not recommended** unless option A fails its gates and option C is also rejected.

### C. Fully native per platform: Kotlin + Jetpack Compose (Android) and C#/.NET + WinUI 3 (Windows)

- **Shared:** only the contract (the JSON Schema profile, the parity spec, and future conformance fixtures). The parity rules are implemented twice, in Kotlin and C#, on top of the Swift original.
- **Android fit:** same as option A.
- **Windows fit, per the official Windows App SDK README:**
  - WinUI 3 is part of the Windows App SDK and supports Windows 10 1809 (build 17763) and later;
  - MSIX is optional;
  - WinUI's Fluent controls are designed for accessibility.

  This session could not reach `learn.microsoft.com` to confirm Narrator/UI Automation and packaging details. Verify them before deciding.
- **Cost:** two new languages, two UI implementations of the R0lling design, and the highest parity-drift risk.

### D. .NET MAUI for Android + Windows (shared C#)

- **Shared:** one C# core and UI. On Windows, MAUI hosts WinUI.
- **Android fit:** weakest of the options here. The developer-preview Meta DAT Android SDK and Health Connect would need C# bindings over Kotlin/Java libraries. Their availability and maintenance cost were not evaluated in this session.

### E. Flutter for Android + Windows

- **Shared:** one Dart codebase.
- **Android fit:** DAT and Health Connect would go through platform channels or plugins, which adds a third language at the edges.
- Windows accessibility and packaging were not evaluated in this session.
- The roadmap already rules out moving the iOS UI to Flutter. Using it only for the new clients would still add a language without reusing iOS code.

## Evaluation

| Driver | A: KMP + Compose MP | C: Kotlin + WinUI 3 | D: MAUI | E: Flutter |
|---|---|---|---|---|
| Parity rules implemented | Once (Kotlin) | Twice (Kotlin + C#) | Once (C#) | Once (Dart) |
| Android integrations (SAF, Health Connect, DAT, Keystore) | Native | Native | Bindings needed (unverified) | Channels/plugins |
| Windows accessibility | Java Access Bridge; Narrator not documented → **must be proven** | Native Fluent/UIA (verify) | Via WinUI (verify) | Not evaluated |
| Windows packaging | MSI/EXE via jpackage on Windows; MSIX/signing outside plugin | MSIX or own installer | MSIX | Not evaluated |
| Runtime footprint | Bundled JVM runtime | .NET/Windows App SDK runtime | .NET runtime | Flutter engine |
| Styling work | One shared Compose design system + desktop layouts | Compose + XAML (two) | One XAML/MAUI | One Flutter |
| New languages | Kotlin | Kotlin + C# | C# | Dart (+ Kotlin at edges) |

## Recommendation (pending decision)

Adopt **option A** for both new clients, subject to the time-boxed spike gates below. The roadmap proposal is retained but not assumed.

Rationale:
- It implements the parity rules once for both new clients.
- It is native on Android, the platform with the larger integration surface (Health Connect, DAT, SAF).
- It adds only one language.

Its weakest point is Windows accessibility and packaging. That is why the gates come before any client code.

### Spike gates (in order; each needs evidence the user reviews)

1. **Windows accessibility.** Build a minimal packaged MSI with `jdk.accessibility` and run it on a clean Windows 10/11 machine:
   - Narrator and NVDA can reach, name, and operate a list, a text field, a toggle, a dialog, and an icon-only button;
   - keyboard-only navigation works;
   - the same app runs without enabling Java Access Bridge by hand on the user's machine, or the installer enables it reliably.

   If Narrator cannot be supported acceptably, switch the Windows client to **option C**. Keep KMP for Android and treat the C# port as a separate implementation that must pass the shared conformance suite.
2. **Windows distribution.** Confirm that the user accepts MSI/EXE plus code signing outside the Compose plugin, or that a Store/MSIX path exists with acceptable tooling. If neither is acceptable, revisit option C.
3. **Contract conformance.** Have a Kotlin `commonMain` codec:
   - validate a privacy-reviewed, iOS-generated `journal_v1.json` and backup bundle against [`contracts/r0lling-exchange-v1.schema.json`](contracts/r0lling-exchange-v1.schema.json);
   - read both without loss;
   - write a bundle that the real iOS app restores.

   Use no synthetic user data.
4. **Android DAT feasibility.** Do this only if glasses support is in Android scope. Confirm Developer Center registration and a session start on supported hardware with the developer-preview SDK. Until then, Android glasses stay unavailable, exactly as in iOS simulation honesty.

## Consequences

- **If A is accepted:** add a Gradle multi-module project beside the Swift package, for example `clients/kotlin/` with `core`, `android-app`, and `windows-app` modules. The final layout is a separate decision. Add Linux (Android build and `commonTest`) and Windows (desktop packaging) CI jobs. Port the parity rules together with test vectors translated from the existing Swift tests.
- **If C is chosen for Windows:** add a .NET solution, for example `clients/windows/`, and double the parity test vectors. Put the shared conformance fixtures in a language-neutral location so all three implementations run the same cases.
- **In every option:**
  - no automatic sync and no new exchange format;
  - honest unavailable states for HealthKit-only, DAT-only, and Apple-only capabilities;
  - no Bevel-only screens or invented measurements;
  - per-platform accessibility and rendered-UI review before release.

## Not decided here

- The repository layout and module names.
- Whether the prototype/sample cards (Studio and strategy prototypes, collapsed health previews) are ported at all; see the parity document.
- Store accounts, signing identities, and release channels.
- Any change to the v1 data shapes.
