# R0lling Windows client — design

Updated: 2026-10-13. Status: design only. There is no Windows code, project, build, test, installer, or release artifact in this repository. The stack decision is open; see [ADR_0001_ANDROID_WINDOWS_CLIENT_STACK.md](ADR_0001_ANDROID_WINDOWS_CLIENT_STACK.md).

- Under **option A**, this client is Compose Multiplatform on the JVM sharing the Kotlin core with Android.
- Under **option C**, it is C#/.NET with WinUI 3 implementing the same contract and parity rules independently.

Sections note where the options differ. The target is assumed to be Windows 10/11 desktop, matching the current development host; confirm before packaging work. The Windows App SDK README states support down to Windows 10 1809 (build 17763).

Scope and rules come from [CROSS_PLATFORM_FEATURE_PARITY.md](CROSS_PLATFORM_FEATURE_PARITY.md) and [CROSS_PLATFORM_DATA_CONTRACT.md](CROSS_PLATFORM_DATA_CONTRACT.md).

## Product boundary

- A separate, local-first desktop app. It has no account, server, or automatic sync, and it does not use roaming profile folders that a domain could synchronize.
- It contains the journal, media, Assistant (Direct/Hermes), Obsidian export, Agent memory, backup/restore, Today productivity tools, Share composer, Vault, and Settings, with the same Greek copy, actions, and semantics as iOS.
- Health and Fitness have no Windows data source. Those destinations stay in the navigation for parity of structure but show an honest unavailable state. They never show placeholders or sample data. Hiding them instead is an acceptable alternative only if the user decides so.
- There is no desktop Meta glasses SDK, so glasses, clips, highlight reels, and rolling-buffer settings are unavailable.

## Architecture

```text
windows-app
  ├─ ui/         Today, Journal, Fitness (unavailable), Health (unavailable),
  │              Vault, Assistant, Studio (prototypes out of initial scope), Settings
  ├─ adapters/   folder/file dialogs, vault filesystem, credential store,
  │              Windows Hello, media playback, OCR/speech/TTS (gated)
  └─ depends on
core           option A: shared Kotlin core (same as Android)
               option C: C# port of the same modules, validated by the shared fixtures
```

## Platform adapters

| Concern | Windows mechanism | Parity requirement / gate |
|---|---|---|
| Journal and media storage | `%LOCALAPPDATA%\R0lling\journal_v1.json` and `%LOCALAPPDATA%\R0lling\Media\<Folder>\` (local, not roaming) | 64 MiB cap; atomic replace (temp file, then replace or move with replace-existing semantics); fail closed on corrupt or unsupported files; 50 MiB free-space reserve |
| Path safety | Reject reparse points (symbolic links and junctions) inside the media root, the vault, and bundles; canonical containment checks | Equivalent to the iOS no-follow and symlink rejections; Windows path rules (reserved names, case-insensitivity, trailing dots/spaces) must not let two v1 names collide or escape |
| Obsidian vault | Folder picker; direct filesystem access | The Obsidian desktop app may have the same vault open, so re-hash immediately before replace, use exclusive creation for sidecars, and expect sharing violations as failures, never as partial writes |
| Backup export/restore | Folder picker; the bundle is a plain `<name>.r0backup` folder | Same semantics as iOS; transport between devices stays user-owned |
| Credentials | Windows credential protection for API key and Hermes token: DPAPI or Credential Manager for option C; option A needs a native bridge, which is a spike item | Never logged or exported; removable from Settings |
| Encrypted Vault | Windows Hello user-consent verification plus an OS-protected key | Capability after successful verification; revoke on lock, minimize, or navigate-away; 8 MiB document cap; excluded from the R0lling bundle; no recovery. Option A needs a WinRT bridge from the JVM (spike). If Windows Hello is unavailable on a machine, the Vault is unavailable rather than falling back to a weaker invented scheme |
| Media playback | Option C: the platform media player control; option A: no built-in Compose Desktop media player was identified in this review | Photos, video, and audio attachments must open; if a format cannot play, report it (iOS reports playback failures) |
| Speech notes, TTS, OCR | Windows media and OCR APIs are candidates, mainly reachable from option C | Greek support and on-device behavior must be validated; otherwise unavailable |
| Networking | HTTP client with redirects disabled and a streamed 8 MiB response cap | Same AI limits, retries, cancellation, endpoint validation, and redaction as iOS. Hermes on `localhost` is a likely desktop setup and is already allowlisted |
| Time zones | Store IANA identifiers only; the JVM's `ZoneId` already uses them, and .NET must convert Windows IDs to IANA before writing | Never persist a Windows time-zone ID |

## UI and styling

- **Window and navigation:** a resizable window with a sensible minimum size. A navigation rail or sidebar lists Σήμερα, Ημερολόγιο, Fitness, and Υγεία first. A plus button opens the same six quick actions: Escape closes the panel, focus enters the panel and returns to the launcher, and the existing Fitness plus behaves the same way.
- **Keyboard:** every action works from the keyboard, with a visible focus indicator. New global shortcuts are a product decision. The only shortcut carried over from iOS is Escape closing the quick-action panel.
- **Visual language:** the same token values as `Theme.swift` and the same charcoal canvas, flat slate cards, and restrained outlines, with layouts adapted to wide windows. There is no claim of iPhone screenshot parity.
- **Contrast themes:** when Windows contrast themes are active, the UI must stay legible and must not hard-code colors that hide focus or text. The design tokens need a contrast-theme fallback, to be defined during the accessibility gate.
- **Text and copy:** text scales with Windows text-size settings. Greek copy is the same as iOS.

## Accessibility and release gates

1. **Screen readers:** Narrator and at least one of NVDA/JAWS can reach, name, and operate every control on every ported screen, and keyboard-only use is complete. For option A this is the ADR spike gate, because accessibility goes through Java Access Bridge.
2. **Exchange:** the cross-client bundle round trip with iOS and Android passes the data-contract acceptance gate.
3. **Obsidian:** export is checked against a vault that is open in Obsidian desktop at the same time, including idempotent re-export and conflict sidecars.
4. **Packaging:**
   - option A: MSI/EXE built on a Windows runner (cross-compilation is not supported);
   - option C: MSIX or the developer's installer;
   - code signing uses user-owned certificates;
   - the installed artifact is tested on a clean machine.
5. **Privacy:** documentation covers local storage, AI requests, and the plaintext backup bundle.

None of these gates has been attempted.

## CI outline (not implemented)

- A Windows runner job that builds and packages the desktop app and runs the core conformance fixtures.
- Under option A, the fixtures also run in the Linux job shared with Android.
