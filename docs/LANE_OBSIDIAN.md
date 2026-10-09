> Current status (2026-10-09): This document contains historical assertions or design targets. It is not evidence for the current checkout. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) and [FINDINGS_REMEDIATION.md](FINDINGS_REMEDIATION.md). Earlier “100%”, module counts, CI/head references and security/readiness claims are superseded.

# R0lling — LANE OBSIDIAN (A08 / A09) — Parallel lane note

```yaml
Lane: Obsidian source path implemented; Apple XCTest/device validation pending
Date: 2026-10-06
Workspace: .
Git_commit: NONE (user forbade)
Scope: A08 export · A09 conflict sidecar · vault bridge · Files picker · Settings UI · PathAsfaleia
AppState: surgical only (re-read under parallel lanes)
```

## DoD (software — όχι device proof)

| ID | Κριτήριο | Κατάσταση |
|---|---|---|
| A08-1 | Idempotent export ×2 (ίδια ημέρα, ίδιο UUID) | ✅ `exportEntry` + markers |
| A08-2 | Batch export όλα τα entries | ✅ `exportBatch` + Settings |
| A08-3 | iOS Files / folder document picker | ✅ `SettingsView.fileImporter(.folder)` |
| A08-4 | Security-scoped bookmark persist | ✅ `VaultBookmarkStore` |
| A08-5 | Media copy στο `Attachments/` με PathAsfaleia | ✅ |
| A09-1 | Hash mismatch → `.r0lling-conflict.md` χωρίς overwrite | ✅ R3-005 |
| A09-2 | Hashes persist across restart | ✅ `R0llingMeta/export-hashes.json` |
| A09-3 | Conflict toast + Settings list | ✅ `teleutaiaObsidianConflicts` |
| SEC | PathAsfaleia σε notes / sidecar / Agent / canvas / KG | ✅ |
| Tests | XCTest source + historical `diagnose_stage5` A08/A09 check | Present; Apple execution unverified |
| Device | Πραγματικό Obsidian vault σε iPhone Files | 🚫 εκκρεμεί Mac/device |

## Αρχεία lane

- `Sources/R0lling/Obsidian/ObsidianVaultBridge.swift` — PathAsfaleia, hash persist, scoped access, import read
- `Sources/R0lling/Obsidian/VaultBookmarkStore.swift` — **ΝΕΟ** bookmark store
- `Sources/R0lling/Obsidian/AgentFolderManager.swift` — PathAsfaleia Agent/*.md
- `Sources/R0lling/UI/SettingsView.swift` — Files picker + conflict UI + vault path
- `Sources/R0lling/App/AppState.swift` — surgical: vault helpers, conflict toast, safe canvas/KG write
- `Tests/R0llingTests/ObsidianBridgeTests.swift` — restart conflict, A08×2, traversal, Agent, bookmark
- `verification/diagnose_stage5_finalize.py` — `test_obsidian_a08_a09_ready`
- `docs/OBSIDIAN_DATA.md` — conflict + hash store note
- `docs/LANE_OBSIDIAN.md` — αυτό το σημείωμα

## Conflict flow (A09)

1. Export γράφει σημείωση + αποθηκεύει SHA256 στο `R0llingMeta/export-hashes.json`.
2. Χρήστης επεξεργάζεται το `.md` στο Obsidian.
3. Επόμενο export: hash ≠ recorded → sidecar `YYYY-MM-DD.r0lling-conflict.md` · πρωτότυπο ανέπαφο.
4. AppState toast + `teleutaiaObsidianConflicts` στο Settings.

## Vault selection (A08)

1. Settings → «Επιλογή Vault (Files / iCloud)» → `fileImporter` folder.
2. `efarmogi_epilogis_obsidian_vault` → bookmark + `setVaultURL(requiresScopedAccess: true)` + Agent sync.
3. Launch: `fortosi_obsidian_vault_apo_bookmark` από `loadInitialData`.
4. «Επαναφορά τοπικού Vault» → Documents default.

## Proof

```text
python verification/diagnose_stage5_finalize.py  # includes A08/A09 suite
# swift test — UNAVAILABLE on Windows (GHA macOS / Mac local)
```

*Η σημείωση lane είναι ιστορική. Το source path υπάρχει, αλλά Apple XCTest/build και δοκιμή πραγματικού vault σε iPhone εκκρεμούν.*
