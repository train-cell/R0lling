# Cross-platform feature and behavior parity

Updated: 2026-10-13. Source baseline: `b29429b6d24051ee2d4f4b52e793f9c5b0748932`. Design document only: no Android or Windows code exists, and nothing here has been built or tested.

This document lists what the separate Android and Windows clients must preserve from the existing iOS client, and where a platform must show an honest unavailable state instead. It complements the data contract in [CROSS_PLATFORM_DATA_CONTRACT.md](CROSS_PLATFORM_DATA_CONTRACT.md) and the stack evaluation in [ADR_0001_ANDROID_WINDOWS_CLIENT_STACK.md](ADR_0001_ANDROID_WINDOWS_CLIENT_STACK.md). Platform designs are in [ANDROID_CLIENT_DESIGN.md](ANDROID_CLIENT_DESIGN.md) and [WINDOWS_CLIENT_DESIGN.md](WINDOWS_CLIENT_DESIGN.md).

## Ground rules

- **Port, don't extend.** A feature, label, or action appears on Android/Windows only if the iOS client already has it, with the same meaning. Platform conventions (back navigation, window menus, 48dp targets, keyboard focus) are allowed. New product behavior needs a separate user decision.
- **No Bevel-only screens and no invented measurements.** The Bevel references style existing screens only ([DESIGN.md](DESIGN.md)).
- **Honest unavailability.** When a platform has no source for a capability (HealthKit, DAT, Apple Vision, on-device speech for a language), the client shows that it is unavailable. It never shows placeholder values, never simulates success, and never silently drops the feature from a screen whose layout implies it.
- **Readiness gates carry over.** Every iOS `FeatureReadinessRegistry` flag that is `false` stays off on the new clients until the same kind of evidence exists on that platform.
- **Prototype and sample cards are out of the initial scope.** This covers the Studio and strategy prototype cards, the collapsed health sample previews, and the Experimental demo cards. The iOS app labels the prototype and sample cards as previews or examples, does not show the Experimental demo cards at all, and none of them carries user data. Whether to port them is a later product decision.

## Navigation map

The iOS app (`Sources/R0lling/App/R0llingApp.swift`) has eight destinations. Four are in the floating dock: Σήμερα, Ημερολόγιο, Fitness, Υγεία. The other four (Vault, Studio, Βοηθός, Ρυθμίσεις) open from the quick-action panel. The panel has six actions: Vault, Νέα σημείωση, Εισαγωγή αρχείου, Βοηθός, Studio, Ρυθμίσεις.

| iOS element | Android | Windows |
|---|---|---|
| Floating four-item dock | Bottom navigation with the same four destinations, labels, and order | Navigation rail/sidebar listing the same four primary destinations first |
| Plus button → six-action panel (modal, close button, Escape, focus restore) | Same six actions in a modal sheet; system Back closes it; focus returns to the launcher | Same six actions; Escape closes; keyboard focus enters the panel and returns to the launcher |
| Fitness top-right plus (opens the same panel) | Same | Same |
| Today header Share + Settings gear (no profile/avatar) | Same; no profile model is added | Same |

## Feature inventory

Legend:
- **Port**: same behavior over a platform adapter.
- **Adapter + gate**: needs a platform source and its own validation before it is enabled.
- **Unavailable**: show an honest unavailable state.
- **Out of scope**: not part of the initial client.

| Feature (iOS source) | iOS status (see [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md)) | Android | Windows |
|---|---|---|---|
| Journal CRUD, search, favorites, tags, date correction, optional location name (`JSONFileStorageService`, `EntryEditorSheet`, `CalendarView`) | Implemented; Apple runtime unverified | Port | Port |
| Media import, viewer, playback (`MediaStorageService`, `PhotosMediaPicker`, `Components.swift` viewer) | Implemented; Photos/Files runtime unverified | Port (system Photo Picker + document picker) | Port (file dialog); media player component to be selected and validated |
| Today: date picker with read-only history, daily score/focus/cognitive-load rings, composer, time capsule, collapsed productivity tools (`TodayView`) | Implemented; render unverified | Port | Port |
| Today Health preview (HRV, resting HR, sleep) | HealthKit readings | Adapter + gate (Health Connect; see the HRV note below) | Unavailable |
| Share composer: four categories, six cards, PNG save/copy/share (`TodayShareComposerView`) | Implemented; export unverified | Port (Android share sheet, clipboard, save via document picker) | Port (save dialog, clipboard); no system share sheet is assumed |
| Fitness: 30-day workout calendar and cumulative duration trend, Europe/Athens buckets (`FitnessView`, `FitnessActivitySnapshot`) | HealthKit workouts | Adapter + gate (Health Connect exercise sessions) | Unavailable |
| Health Monitor: six readings plus sleep detail with stage timeline and overnight vitals (`SovereignOSComponents`, `SleepReportView`, `HealthKitService`) | HealthKit; no score, no interpolation | Adapter + gate (Health Connect) | Unavailable |
| Box breathing and binaural tones (`BiohackingHubView`, `SovereignOSServices`) | Local tools; device audio unverified | Port; stereo output must be validated | Port; stereo output must be validated |
| Tasks with local paste-text parsing, focus/deep-work history, scratchpad, stopwatch (`ExecutiveUtilityViews`) | Implemented (UserDefaults) | Port (app-private preferences) | Port (app-private settings) |
| Encrypted diary, future letters, decision journal behind device authentication (`EncryptedDiaryStore`, `StrategicVaultHubView`, `DecisionJournalCardView`) | Implemented; device-bound key; excluded from backups | Adapter + gate (Keystore + BiometricPrompt) | Adapter + gate (Windows Hello + OS key protection) |
| Assistant chat via Direct or Hermes, summary, recall with local fallback (`AIRouter`, connectors) | Implemented; live providers unverified | Port (same parity rules) | Port (same parity rules) |
| "What am I seeing" image analysis with local OCR first (`OnDeviceVisionAnalysisPipeline`) | Apple Vision OCR | Adapter + gate (an on-device OCR engine with Greek support must be chosen and validated) | Adapter + gate (same) |
| Meal estimate review with explicit Save (`MealNutritionVisionLogger`) | Heuristic, labeled | Port after OCR gate | Port after OCR gate |
| Observation game with photo and manual paths (`ObservationGameEngine`) | Implemented; glasses capture disabled in simulation | Port (photo/manual); glasses capture unavailable | Port (photo/manual) |
| Daily podcast via text-to-speech (`DailyPodcastGenerator`) | Implemented; device audio unverified | Adapter + gate (system TTS with a Greek voice) | Adapter + gate (system TTS with a Greek voice) |
| Voice notes with on-device speech recognition and command parsing (`SpeechTranscriptionService`, `VoiceCommandParser`) | On-device or unavailable | Adapter + gate (on-device recognizer only, Greek availability required) | Adapter + gate, or unavailable |
| Transcript keyword cues labeled `κείμενο: …` (`TranscriptKeywordTagger`) | Implemented | Port | Port |
| Earcons on clip-save and error events (`EarconFeedbackService`) | OS-routed system sounds | Port (system sounds) | Port (system sounds) |
| Agent memory editing: `Agent/Memory.md`, `Preferences.md`, `Open-loops.md` (`AgentFolderManager`) | Implemented; transaction-safe | Port over the vault adapter | Port over the vault adapter |
| Obsidian link and export, conflict sidecars, Dataview frontmatter (`ObsidianVaultBridge`) | Implemented; Files provider unverified | Port (Storage Access Framework tree) | Port (folder dialog) |
| Obsidian Canvas and Knowledge Graph export (`ObsidianCanvasGenerator`, `AssociativeKnowledgeGraphEngine`) | Wired helpers | Port after the core export | Port after the core export |
| Obsidian folder watcher hint (Experimental, `ready=false`) | Gated | Out of scope until iOS gate closes | Out of scope until iOS gate closes |
| Backup bundle export and restore (`BackupRestoreEngine`) | Implemented | Port (folder bundle via document tree) | Port (folder bundle via folder dialog) |
| Settings: AI provider and credentials, context opt-ins, Obsidian, backup, info (`SettingsView`) | Implemented | Port | Port |
| Settings: glasses simulation and rolling-buffer duration | Simulation only | Out of scope until Android DAT spike | Unavailable (no desktop glasses SDK) |
| Meta glasses and rolling clips (DAT and Buffer modules) | Simulation only; live gated | Adapter + gate (official DAT Android SDK, developer preview) | Unavailable |
| Highlight reel (`HighlightReelMuxer`, registry `ready=true`) | Source-wired AVFoundation composition of existing `clip` attachments into a playable journal video; today those clips come only from the simulation path; Apple runtime unverified | Out of the initial scope; restored `clip` attachments would be valid inputs if a composition adapter is added later | Out of the initial scope (no clip source on desktop) |
| Watermark export (Experimental, registry `ready=false`) | Gated pending Apple render/playability verification | Out of scope | Out of scope |
| Shamir 2-of-3 API, AES helper, zeroization (Core) | API only; no UI | Out of scope | Out of scope |
| Remote mirror, Watch companion, Whisper, proximity, turn-taking, pseudo-vector, hyperlapse, spatial audio, Metal pool | `ready=false` | Out of scope | Out of scope |

**HRV note.** HealthKit's HRV reading is SDNN (`heartRateVariabilitySDNN`). Health Connect exposes RMSSD, a different statistic. An Android client must label RMSSD as RMSSD and must not present it as the iOS value or compare the two. Display scales and gauge bounds must be defined for that metric, not copied.

## Behavior parity rules

The Swift source and its XCTest vectors are normative. A port must reproduce these rules and pass equivalents of the existing Swift test cases, translated as algorithm test vectors. Do not add synthetic journal entries as fixtures.

### AI requests (`AIHTTPClient.swift`, `OpenAIChatRequestBuilder.swift`, `ImageMetadataSanitizer.swift`)

- **Endpoint:** `<base path>/chat/completions` on the validated base URL. The API key or Hermes token lives only in the platform credential store.
- **Timeouts:** 30 s (Direct) and 20 s (Hermes). Up to 2 retries (3 attempts) with backoff of 0.4 s × 2^attempt, only for HTTP 408, 425, 429, 500, 502, 503, and 504. Cancellation stays cancellation on every attempt and is never turned into an error or a fallback success.
- **Redirects:** rejected, so an authenticated body is never replayed to another origin.
- **Request size:** the serialized JSON body is at most 10 MiB (10,485,760 bytes). It is preflighted before message construction and rechecked before sending.
- **Images:** at most 4 frames per request and 7 MiB aggregate JPEG bytes before Base64. Each image source is at most 40 MiB, is downsampled to at most 2,048 px per side, is re-encoded as JPEG at most 8 MiB, and has its metadata removed.
- **Response size:** streamed with an 8 MiB cap, including when `Content-Length` is absent.
- **Errors:** a malformed successful body becomes a typed invalid-response error. An empty key or token returns the typed missing-credential error (7004 Direct / 7104 Hermes) before any network call.
- **Context:** the journal and Agent-memory opt-ins default to OFF. When journal context is on, take the newest N entries by timestamp, where N is the configured limit from 0 to 5 (default 5), regardless of the selected Today date. Present them oldest to newest. A location name is sent only with its own separate opt-in. Explicit summary and recall send the corresponding entries.
- **Recall fallback:** when the provider is unavailable, return deterministic local keyword matches with stable entry IDs and date labels, and propagate cancellation.
- **Provider switching:** manual only. There is no silent failover between Direct and Hermes.

### Endpoint validation (`HermesEndpointAsfaleia.swift`)

- Base URLs are trimmed. They must be non-empty, at most 512 characters, and have no user, password, or query component. A fragment is rejected when the endpoint is built.
- **Direct:** `https` only.
- **Hermes:** any `https` host. `http` is allowed only for `localhost`, `127.0.0.1`, `::1`, hosts ending in `.local`, or canonical dotted-decimal IPv4 in 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, or 100.64.0.0/10. Each octet must be decimal digits without a leading zero (except `0` itself), so `010.0.0.1` and other alternate numeric forms are rejected. Other hostnames are refused for cleartext. `.local` is a syntax allowance only: the resolved address is neither checked nor pinned.
- **Defaults:** Direct `https://api.openai.com/v1` with model `gpt-4o-mini`; Hermes `https://127.0.0.1:8080/v1`.

### Outbound PII redaction (`OutboundPIIRedactor.swift`)

Before serialization, all provider-bound text is redacted: prompt, system text, Agent memory, journal content, and an opted-in location. Redaction covers:

- email addresses;
- IBANs that pass the mod-97 check, including space- and hyphen-separated forms;
- payment-card numbers that pass the Luhn check;
- US SSNs;
- contextual Greek AFM;
- phone-number patterns.

Values that fail their checksum are preserved. Image bytes are not inspected. This is best-effort pattern matching and must be described that way. The port must reproduce the source patterns and pass the existing redaction test vectors in `OpenAIChatRequestBuilderTests.swift` and `AIHTTPClientTests.swift`.

### Journal and day semantics

- An entry belongs to the calendar day of its own `timeZoneIdentifier` (see the data contract). A selected day lists entries oldest-first. Search is a case-insensitive substring match over content, title, and tags, with an exact tag filter and an optional source filter, newest-first.
- Edits, favorites, date corrections, and attachment appends merge against the current stored row and reject IDs that no longer exist. A stale screen must not resurrect a deleted entry.
- Corrupt, oversized, or unsupported journal files fail closed and are never overwritten.

### Today indicators

- **Daily score:** a productivity heuristic from today's journal-entry count and focus seconds (including an active session). It is absent (em dash) when both are zero and never uses health data. Its label must keep saying it is an estimate from entries and focus time.
- **Focus sessions:** daily totals count only the overlap of each session with the local calendar day. An active deadline survives relaunch using wall-clock time. Undecodable stored state is preserved, and the user must confirm before it is discarded.

### Assistant helpers

- Meal estimates are labeled heuristic and are written only after explicit confirmation. The review shows every persisted quantity.
- Observation-game manual confirmation is labeled non-AI. Synthetic or simulated images are never AI-evaluated. The streak advances only on success.
- Voice-command parsing (Greek and English): note prefixes take precedence over action keywords. An incidental "clip" inside a dictated note does not trigger capture. Final dictation survives deduplication.
- Transcript cues are visibly labeled `κείμενο: …` and never claim acoustic or emotional inference.

### Private Vault

- Store operations require a capability issued only after successful device authentication and revoked on lock, deactivation, or leaving the screen. Plaintext view state is cleared at the same time.
- **Limits:** ciphertext document at most 8 MiB, with the existing count and size caps.
- **Future letters:** payloads stay redacted until the device wall clock reaches the unlock date. The UI must not describe this as trusted time.
- **Decisions:** the outcome review is due 90 days after the decision.
- **Device binding:** the key is device-bound. The vault is excluded from OS backup and from the R0lling backup bundle, and there is no device-loss recovery. A platform that can bind the key to biometric authentication may do so, but it must not claim Secure Enclave–equivalent protection without evidence.

## Conformance plan

1. Translate the existing Swift XCTest vectors into a language-neutral fixture format. Cover:
   - the redaction, endpoint, IPv4, and request-size cases;
   - context selection;
   - day grouping, Fitness bucketing, and sleep-episode aggregation;
   - backup path grammar;
   - Obsidian Markdown merge and conflict rules.
2. Run those fixtures against the Swift implementation first, to prove that the fixtures match current behavior. Then run them against each new client.
3. Add the cross-client bundle round trip from the data contract's acceptance gate, using a privacy-reviewed bundle generated by the real iOS app.

None of these steps has been performed. Building and running them is outside the current no-build/no-test session.
