# Cross-platform local data contract

Updated: 2026-10-13

## Status

This document records the data shape and behavior already present in the Swift source so Android and Windows work can preserve it. It is not a new schema, a sync protocol, or evidence that another client can read/write it. No Android or Windows codec exists yet. Do not change the v1 shape until a separate migration decision and compatibility evidence exist.

Primary sources: `Sources/R0lling/Core/Models.swift`, `Sources/R0lling/Persistence/JSONFileStorageService.swift`, `Sources/R0lling/Persistence/BackupRestoreEngine.swift`, and `Sources/R0lling/Obsidian/ObsidianVaultBridge.swift`.

## Local journal file

The iOS implementation stores the journal at `Application Support/R0lling/journal_v1.json`. The directory is platform-managed; another client must use its own private application-data location and must not assume the iOS path exists.

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

## Explicit backup/restore bundle

The existing writer creates a `.r0backup` directory containing `manifest.json` and a `Media/` tree. The manifest has `schemaVersion`, `backupTimestamp`, `appVersion`, `entriesCount`, `entries`, and optional `agentMemory`. It uses ISO-8601 dates and is currently schema version `1`.

Each attachment is copied beneath `Media/<relativePath>` and its manifest `relativePath` remains the path under the app media root. Restore validates path containment, regular-file status, and byte size before use. A restore inserts entries whose IDs are absent; an existing entry with the same ID remains unchanged. Imported attachment paths are mapped into the receiving installation's own media root. A client must not report a partial or successful restore after dropping a referenced attachment.

The bundle is plaintext JSON plus media at the application layer. iOS file protection is OS-specific and does not encrypt the export. This project has no automatic cross-device synchronization contract. Import/export stays user initiated.

## Obsidian exchange

Daily notes use `YYYY/MM/YYYY-MM-DD.md`; exported entries are delimited by their existing `r0lling:id:<UUID>` markers. A content/hash conflict writes a conflict sidecar and preserves the existing note. Obsidian export is an explicit vault integration, not a substitute for the app's journal file or a background synchronization service. Use each platform's own document/vault access and path-safety APIs while preserving the same Markdown and conflict semantics.

## Required compatibility behavior

- Preserve IDs, source/media enum raw values, field meanings, attachment bytes, original filenames, timestamp instants, and entry time zones.
- Accept only supported schema versions; keep source data intact on invalid or unsupported input.
- Validate size and path limits before decoding/copying large imports. Keep path-containment checks platform-specific and fail closed.
- Make import explicit and idempotent by entry ID. Keep current entries unchanged on duplicate IDs, matching iOS restore behavior.
- Preserve the current plain backup privacy disclosure. Do not imply end-to-end encryption or automatic sync.
- Keep platform-only measurements and capabilities optional. A missing HealthKit/Health Connect/DAT source produces an honest unavailable state; it must not create placeholder measurements.

## Compatibility acceptance gate

Before calling the formats cross-platform compatible, generate a privacy-reviewed bundle from the real iOS app and verify that Android and Windows can inspect it, restore it without data loss, preserve attachment bytes and metadata, and export a bundle that iOS can restore. Verify duplicate IDs, unsupported schema versions, malformed dates, oversized inputs, unsafe paths, and interrupted restore behavior on each implementation. No synthetic user entry should be added to the repository as a fixture. The user-owned no-build/no-test restriction remains in force for the current work session.
