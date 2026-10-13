# R0lling cross-platform release roadmap

Updated: 2026-10-13

## Confirmed product target

- Keep the existing iOS app native in SwiftUI.
- Add separate Android and Windows desktop clients.
- Keep storage local-first. Do not add automatic cloud/device synchronization.
- Preserve the existing journal, attachment, backup, and Obsidian semantics. Cross-platform exchange must use documented formats and explicit import/export actions.
- The desktop target is assumed to be Windows 10/11, matching the current development host; confirm before packaging work.
- A platform must show an honest unavailable/unsupported state when it lacks a source for a measurement or capability. Do not fabricate health data or claim hardware integration that has not passed its platform gate.

## Current checkout facts

- The only app host is `Apps/R0llingApp`, an XcodeGen iOS target. `Package.swift` declares iOS 17.2 and macOS 14; its Meta Wearables DAT products are conditional on iOS.
- No Android or Windows application project is present. `README.md` explicitly says that Windows cannot build the current Apple-framework app.
- SwiftUI, HealthKit, Vision, PhotosUI, AVFoundation, Security, LocalAuthentication, and Apple picker/file APIs appear in the existing sources. The Swift package is not presently a platform-neutral app core.
- `JournalEntry` and `MediaAttachment` are Codable domain values. `JSONFileStorageService` writes journal schema version 1 with ISO-8601 dates. `BackupRestoreEngine.BackupManifest` also has schema version 1 and includes journal entries, optional Agent memory, and copied media. These are candidate interoperability contracts, not yet validated by a second implementation.
- Obsidian export is an existing explicit integration. Its conflict handling and selected-vault access remain governed by the current iOS behavior and docs.
- The field-level rules and cross-client acceptance gate are recorded in [CROSS_PLATFORM_DATA_CONTRACT.md](CROSS_PLATFORM_DATA_CONTRACT.md); no cross-platform implementation is claimed yet. As of 2026-10-13 it also records the exact v1 encoding rules read from source (whole-second UTC dates, uppercase UUIDs, path grammar, limits, restore and Obsidian semantics), with a machine-readable profile in [`contracts/r0lling-exchange-v1.schema.json`](contracts/r0lling-exchange-v1.schema.json) that has not yet been validated against app-generated files.
- Feature scope, honest-unavailability rules, and behavior parity constants for the new clients are in [CROSS_PLATFORM_FEATURE_PARITY.md](CROSS_PLATFORM_FEATURE_PARITY.md); platform designs are in [ANDROID_CLIENT_DESIGN.md](ANDROID_CLIENT_DESIGN.md) and [WINDOWS_CLIENT_DESIGN.md](WINDOWS_CLIENT_DESIGN.md).

## Recommended implementation shape (proposal under evaluation)

The direction below is a proposal, not an approved technical decision. It is evaluated against native-per-platform, .NET MAUI, and Flutter alternatives in [ADR_0001_ANDROID_WINDOWS_CLIENT_STACK.md](ADR_0001_ANDROID_WINDOWS_CLIENT_STACK.md) (status: Proposed). That ADR keeps this direction as the recommendation only if time-boxed spikes pass: Windows accessibility through Java Access Bridge including Narrator, a Windows distribution path the user accepts, iOS-bundle contract conformance, and Android DAT feasibility if glasses are in scope.

Preserve the existing SwiftUI iOS client and its native integrations. Implement Android and Windows as separate clients over a new portable Kotlin domain/data module, with platform-specific adapters at the edges. Kotlin Multiplatform with Compose targets Android and Windows desktop, allowing those two clients to share domain rules and visual tokens without replacing the existing iOS app.

This recommendation requires porting and then cross-checking the relevant Swift domain behavior; Swift code is not automatically reusable by Kotlin. Keep the existing Swift app as the iOS source of truth until an explicit, separately reviewed migration is requested. Do not move the current UI to Flutter as part of this plan.

The platform split should look like:

```text
iOS SwiftUI client ───── existing Swift domain and native Apple adapters
Android client ───────── Compose UI + shared Kotlin domain + Android adapters
Windows client ───────── Compose Desktop UI + shared Kotlin domain + Windows adapters
                          │
                          └── schema-compatible local journal, media, backup, Obsidian export
```

There is no network sync service in this architecture. Each installation owns its local journal. Existing manual backup/restore and Obsidian export are the exchange paths unless a later product decision changes that contract.

## Platform capability boundaries

| Capability | iOS | Android | Windows desktop |
|---|---|---|---|
| Journal, search, attachments, local backup | Existing implementation; Apple build/runtime still pending | Implement against the same schema and explicit file import/export | Implement against the same schema and desktop file dialogs |
| Obsidian | Existing vault picker/bookmark path; Apple provider validation pending | Separate Android document/vault access adapter | Separate Windows filesystem/vault access adapter |
| Health measurements | Existing optional HealthKit readings; device validation pending | Requires an explicit Health Connect adapter and permission/data-state behavior | No equivalent source is in scope; show honest unavailable state |
| Meta glasses | iOS DAT source exists but remains gated and unverified | Official Android DAT SDK integration is a separate adapter and needs Developer Center/device evidence | No direct glasses adapter planned for desktop |
| AI providers | Existing Direct/Hermes source paths | Port the existing allowlist, redaction, opt-in, cancellation, and request-size contracts before enabling requests | Same contract if AI is exposed on desktop |
| Bevel-inspired styling | Continue screenshot-backed styling of existing R0lling screens | Reapply the design language while following Android layout/accessibility conventions | Reapply the design language for keyboard/window layouts; do not claim pixel parity with iPhone screenshots |

The Meta Wearables Device Access Toolkit has official iOS and Android SDK paths. It does not provide a Windows client SDK, so desktop must not claim direct DAT streaming.

## Delivery phases and acceptance gates

1. **Contract:** freeze the cross-platform JSON/date/path/media rules from the current source; add representative compatibility fixtures only from real app-generated data, with user privacy protected. Specify migration and unsupported-field behavior before a second client writes the schema.
2. **iOS release:** complete documented Swift source gaps; run the supported Apple build/full test suite; review the rendered Bevel-referenced screens, Dynamic Type, accessibility, permissions, HealthKit, media, backup, Obsidian, and DAT gates on Apple hardware.
3. **Android client:** implement the shared domain contract and existing product actions; integrate Android storage/pickers, Health Connect, and DAT as separately gated native adapters. Validate import/export against iOS-generated bundles and exercise permissions on devices.
4. **Windows client:** implement the shared domain contract and existing desktop-appropriate actions; use native file/window behaviors and avoid device-only claims. Validate import/export against both mobile clients.
5. **Release readiness:** add per-platform CI and reproducible release packaging; publish privacy/data-handling, setup, and troubleshooting docs; resolve license/third-party notices; complete accessibility and installed-artifact review on all three platforms.

The final cross-platform 100% gate is independent of the historical iOS/Gen2 matrix. It requires installable releases for iOS, Android, and Windows; documented per-platform capability differences; schema-compatible explicit data exchange; completed platform-specific checks; and rendered UI review. Source presence alone does not close these gates.

## Official platform references

- [Meta Wearables Device Access Toolkit](https://developers.meta.com/wearables/device-access-toolkit/)
- [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/)
- [Kotlin Compose Multiplatform compatibility and supported platforms](https://kotlinlang.org/docs/multiplatform/compose-compatibility-and-versioning.html)
- [Compose Multiplatform native application entry points](https://kotlinlang.org/docs/multiplatform/compose-multiplatform-entry-points.html)
