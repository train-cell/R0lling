# Cross-platform local data contract

Updated: 2026-10-13 (exact v1 encoding rules added from source at `b29429b6d24051ee2d4f4b52e793f9c5b0748932`)

## Status

This document records the data shape and behavior already present in the Swift source so Android and Windows work can preserve it. It is not a new schema, a sync protocol, or evidence that another client can read/write it. No Android or Windows codec exists yet. Do not change the v1 shape until a separate migration decision and compatibility evidence exist.

Primary sources: `Sources/R0lling/Core/Models.swift`, `Sources/R0lling/Persistence/JSONFileStorageService.swift`, `Sources/R0lling/Persistence/MediaStorageService.swift`, `Sources/R0lling/Persistence/BackupRestoreEngine.swift`, `Sources/R0lling/Obsidian/ObsidianVaultBridge.swift`, `Sources/R0lling/Obsidian/AgentFolderManager.swift`, and `Sources/R0lling/Core/Extensions.swift`.

A machine-readable conservative profile of the JSON shapes is in [`contracts/r0lling-exchange-v1.schema.json`](contracts/r0lling-exchange-v1.schema.json) (JSON Schema 2020-12). It was derived by reading the source; it has not been validated against an app-generated file or by a second implementation. Rules that JSON Schema cannot express are listed below.

## Local journal file

The iOS implementation stores the journal at `Application Support/R0lling/journal_v1.json` and media under `Documents/R0lling/Media/`. Those directories are platform-managed; another client must use its own private application-data location and must not assume the iOS paths exist.

The top-level `StorageContainer` has:

| Key | Type | Rule |
|---|---|---|
| `schemaVersion` | integer | Currently `1`; reject unsupported versions without overwriting the source file. |
| `appVersion` | string | Current writer uses `1.0.0`. |
| `lastUpdated` | ISO-8601 date string | Set on each persisted container write. |
| `entries` | array of `JournalEntry` | Duplicate `id` values are invalid. |

`JournalEntry` fields are `id`, `timestamp`, `timeZoneIdentifier`, optional `title`, `content`, `source`, `tags`, optional `locationName`, `attachments`, `isFavorite`, and `lastModified`. Dates use ISO-8601. Preserve the entry's explicit time-zone identifier; date grouping must not silently substitute the importing device's zone.

`EntrySource` raw values are `manual`, `glasses`, `glasses_clip`, `voice`, `import`, and `ai`. `MediaType` raw values are `photo`, `video`, `clip`, and `audio`.

`MediaAttachment` fields are `id`, `relativePath`, optional `originalFilename`, `mediaType`, `byteSize`, optional `durationSeconds`, `captureTimestamp`, optional `width`, optional `height`, and `hasAudio`. The path is relative to that installation's media root. Never persist an absolute sandbox path or trust an imported relative path before canonical containment checks. Preserve `originalFilename`; it is separate from the generated on-disk leaf name.

## Exact v1 encoding rules (from source)

These rules describe what the iOS v1 writer emits and what its reader accepts. A second client must follow the writer rules so that iOS can read its files, and must accept everything iOS writes.

### JSON text

- UTF-8 JSON. The iOS writer uses `JSONEncoder` with `.prettyPrinted` and `.sortedKeys` for the journal and the backup manifest; formatting is not semantically significant, but sorted keys make byte comparisons and diffs stable. Foundation escapes `/` as `\/`; readers must accept every standard JSON escape, and writers need not escape `/`.
- Optional values are omitted when absent: the iOS writer never writes `null`. Its reader treats a missing optional key as absent and an explicit `null` on an optional key as absent; `null` on a required key is a decoding error.
- Unknown keys are ignored by the iOS reader and are dropped on its next write. A v1 writer therefore must not add keys: any extension needs a schema-version decision first.
- Numbers: `byteSize`, `width`, `height`, `entriesCount`, and `schemaVersion` are integers; `durationSeconds` is a JSON number and may be written without a fractional part (for example `12`).
- Entry order inside `entries` is unspecified: the iOS journal writer serializes an unordered dictionary. Readers must not rely on array order. User-facing order is derived: a selected day is shown oldest-first by `timestamp`; all-entry and search lists are newest-first.

### Dates and time zones

- Every date is written as an ISO-8601 instant in UTC with whole seconds and a literal `Z`, for example `2026-10-13T09:41:07Z` (Foundation `.iso8601`, `ISO8601DateFormatter` internet date-time).
- The iOS v1 decoder does **not** accept fractional seconds. A writer that emits `2026-10-13T09:41:07.250Z` makes iOS reject the whole journal or manifest. Truncate to whole seconds before writing. Because iOS also truncates on write, instants round-trip at one-second precision.
- An entry's calendar day (`dateKey`) is `timestamp` formatted as `yyyy-MM-dd` (Gregorian calendar, POSIX locale) in the zone named by `timeZoneIdentifier`. If the identifier is unknown, iOS falls back to the device zone, but the iOS editor rejects unknown identifiers before save. `timeZoneIdentifier` must be an IANA identifier such as `Europe/Athens`; a Windows client must convert from Windows time-zone IDs before writing and must never store a Windows ID.
- The time shown in Obsidian block headings is `HH:mm` (POSIX locale) in the entry's zone.

### Identifiers

- UUIDs are canonical 8-4-4-4-12 hex text. iOS writes **uppercase** (`uuidString`) and reads case-insensitively in JSON. The same uppercase text appears in Obsidian block markers and in generated media file names, so a second client must write uppercase everywhere; a lowercase writer would create a second, non-matching Obsidian block for the same entry.

### Media files

- `relativePath` is exactly `<Folder>/<file>`, where `<Folder>` is `Photos`, `Videos`, `Clips`, or `Audio` for `photo`, `video`, `clip`, or `audio`, respectively. Backup creation and restore require the folder to match `mediaType` and `<file>` to be 1–255 ASCII characters from `[0-9A-Za-z._-]` that does not start with `.`. A journal attachment that violates this cannot be backed up.
- New files are named `<UPPERCASE-UUID>.<ext>`. `<ext>` is the source name's extension lowercased when it is 1–12 characters of `[0-9a-z]`; otherwise `jpg` for photos, `mp4` for videos and clips, and `m4a` for audio.
- `originalFilename` is the last path component of the source name (backslashes treated as `/`), trimmed of surrounding whitespace/newlines and limited to its first 255 Swift characters; an empty, `.`, or `..` result falls back to the generated file name. It is display text only and is never used as a path.
- Observed import semantics, preserve rather than reinterpret: `captureTimestamp` is the import time (not image or video capture metadata); `width`, `height`, and `durationSeconds` are omitted by the current importers; `hasAudio` is `true` only when `mediaType` is `audio`, including for imported videos that contain an audio track. Changing any of these is a product decision, not a port detail.
- Imports require a regular, non-empty source and enough free space for the payload plus a 50 MiB (52,428,800-byte) reserve. Video imports accept MP4, MOV, and M4V only.

### Limits

| Item | Limit | Behavior on violation |
|---|---|---|
| Journal file | 64 MiB (67,108,864 bytes) | Reject before decoding; refuse writes that would exceed it; keep the existing file |
| Backup `manifest.json` | 16 MiB (16,777,216 bytes) | Reject the bundle / refuse to create it |
| Entries per backup | 50,000 | Reject |
| Attachments per entry in a backup | 256 | Reject |
| Attachments per backup | 100,000 | Reject |
| Obsidian daily note read | 16 MiB | Fail closed, keep the note |
| Obsidian hash metadata | 16 MiB | Fail closed |
| Agent Markdown file | 4 MiB each | Fail closed |

### Rules outside JSON Schema

- `entries[].id` values are unique within a journal file and within a manifest.
- A manifest's `entriesCount` equals the length of `entries`.
- `schemaVersion` other than `1` is unsupported; the source file must stay unchanged.

## Explicit backup/restore bundle

The existing writer creates a `.r0backup` directory containing `manifest.json` and a `Media/` tree. The manifest has `schemaVersion`, `backupTimestamp`, `appVersion`, `entriesCount`, `entries`, and optional `agentMemory`. It uses ISO-8601 dates and is currently schema version `1`.

Each attachment is copied beneath `Media/<relativePath>` and its manifest `relativePath` remains the path under the app media root. Restore validates path containment, regular-file status, and byte size before use. A restore inserts entries whose IDs are absent; an existing entry with the same ID remains unchanged. Imported attachment paths are mapped into the receiving installation's own media root. A client must not report a partial or successful restore after dropping a referenced attachment.

The bundle is plaintext JSON plus media at the application layer. iOS file protection is OS-specific and does not encrypt the export. This project has no automatic cross-device synchronization contract. Import/export stays user initiated.

Additional source-derived restore and backup semantics:

- On iOS the bundle is a directory named `*.r0backup`, declared as `com.personal.r0lling.backup-bundle` conforming to `com.apple.package`; the restore picker also accepts a plain folder. On other platforms it is an ordinary folder; how the user moves it between devices (USB, a user-chosen cloud folder) stays outside the app. A zipped container would be a new transport decision, not part of v1.
- Backup creation sets each attachment's `byteSize` to the actual file size and fails if any referenced file is missing, empty, or not a regular file; it never produces a partial bundle.
- Restore validates the manifest and every attachment of every new entry before installing anything. Any invalid path, missing or non-regular file, zero size, or size mismatch aborts the whole restore without changing the journal.
- Identical bytes already at the requested media path are reused; otherwise a colliding attachment is restored as `<Folder>/<UPPERCASE-UUID>.<ext>` and the restored entry points at that new path. Several references to one bundled file restore to one media file.
- Media are staged and installed before one atomic insert-if-absent journal batch. If a backup contains `agentMemory`, restore then writes it to the current Agent destination (the linked vault, or the app's local `Documents/R0lling/ObsidianVault` default when no vault is linked), **replacing** `Agent/Memory.md`, `Agent/Preferences.md`, and `Agent/Open-loops.md` with the bundle's text; journal entries, by contrast, are insert-if-absent. If that Agent write fails, the newly inserted entries are removed again. A second client must reproduce this replace-vs-insert difference or document a deliberate product change.
- The encrypted private diary, future letters, and decision journal are device-bound, excluded from OS backups, and not part of this bundle. AI settings, Keychain secrets, tasks, focus history, streaks, and other UserDefaults state are also not exchanged.

## Obsidian exchange

Daily notes use `YYYY/MM/YYYY-MM-DD.md`; exported entries are delimited by their existing `r0lling:id:<UUID>` markers. A content/hash conflict writes a conflict sidecar and preserves the existing note. Obsidian export is an explicit vault integration, not a substitute for the app's journal file or a background synchronization service. Use each platform's own document/vault access and path-safety APIs while preserving the same Markdown and conflict semantics.

Exact source-derived Markdown and vault layout:

- The note path uses the entry's `dateKey`: `<yyyy>/<MM>/<yyyy-MM-dd>.md`.
- A new daily note starts with exactly this text, where `D` is the `dateKey`:

  ```text
  ---
  date: D
  type: daily-journal
  app: R0lling
  tags: [journal, rolling]
  ---

  # D
  ```

  followed by a newline. Each exported entry is appended as `\n<!-- r0lling:id:UUID -->\n<block>\n<!-- /r0lling:id:UUID -->\n`; a re-export replaces the text between the two existing markers.
- `<block>` is `### [HH:mm] <title>` followed by a blank line, the raw `content`, and a newline. If `title` is absent or empty, the heading uses the source display name: `Χειροκίνητη`, `Meta Glasses`, `Rolling Clip`, `Φωνητική`, `Εισαγωγή`, or `AI Βοηθός`. Non-empty `tags` add `\n#tag1 #tag2\n`. Each attachment adds `\n![Φωτογραφία](../../Attachments/<relativePath>)\n` for photos, `\n![Κλιπ / Βίντεο](../../Attachments/<relativePath>)\n` for videos and clips, or `\n[Ηχητικό Σημείωμα](../../Attachments/<relativePath>)\n` for audio.
- Attachment bytes are copied to `Attachments/<relativePath>` in the vault; differing bytes at an existing attachment path fail closed.
- `R0llingMeta/export-hashes.json` maps each vault-relative note path to the lowercase hex SHA-256 of the note's exact UTF-8 bytes after the last R0lling write (compact JSON object). A hash mismatch, or a pre-existing block for the same entry in a note with no recorded hash, produces a conflict sidecar instead of an overwrite. A note that is not valid UTF-8 stops the export without writing (error 6005).
- A conflict sidecar sits beside the note as `<name>.r0lling-conflict-<UPPERCASE-UUID>.md`; identical earlier sidecar content is reused.
- Agent memory lives in `Agent/Memory.md`, `Agent/Preferences.md`, and `Agent/Open-loops.md`, with a `.memory-transaction.json` recovery record during a three-file save.
- Two installations exporting into the same vault (for example a vault the user syncs with another tool) is not a supported synchronization mechanism. The shared hash file makes such races fail toward conflict sidecars rather than overwrites, but this has not been exercised.

## Required compatibility behavior

- Preserve IDs, source/media enum raw values, field meanings, attachment bytes, original filenames, timestamp instants, and entry time zones.
- Accept only supported schema versions; keep source data intact on invalid or unsupported input.
- Validate size and path limits before decoding/copying large imports. Keep path-containment checks platform-specific and fail closed.
- Make import explicit and idempotent by entry ID. Keep current entries unchanged on duplicate IDs, matching iOS restore behavior.
- Preserve the current plain backup privacy disclosure. Do not imply end-to-end encryption or automatic sync.
- Keep platform-only measurements and capabilities optional. A missing HealthKit/Health Connect/DAT source produces an honest unavailable state; it must not create placeholder measurements.
- Write dates without fractional seconds, UUIDs in uppercase, IANA zone identifiers, and no keys beyond the v1 set.

## Compatibility acceptance gate

Before calling the formats cross-platform compatible, generate a privacy-reviewed bundle from the real iOS app and verify that Android and Windows can inspect it, restore it without data loss, preserve attachment bytes and metadata, and export a bundle that iOS can restore. Verify duplicate IDs, unsupported schema versions, malformed dates (including fractional seconds), lowercase UUIDs, oversized inputs, unsafe paths, and interrupted restore behavior on each implementation. Validate the iOS-generated `journal_v1.json` and `manifest.json` against the schema profile and record any difference as a contract correction before a second writer ships. No synthetic user entry should be added to the repository as a fixture. The user-owned no-build/no-test restriction remains in force for the current work session.
