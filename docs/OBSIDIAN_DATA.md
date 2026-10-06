# R0lling — Δομή Δεδομένων Obsidian & Αντίγραφα Ασφαλείας (OBSIDIAN_DATA)

**Έργο:** `R0lling`  
**Ημερομηνία:** 6 Οκτωβρίου 2026  

---

## 1. Δομή Φακέλων του Obsidian Vault

```text
R0lling/
├── 2026/
│   ├── 10/
│   │   ├── 2026-10-05.md
│   │   └── 2026-10-06.md
│   └── 11/
├── Agent/
│   ├── Memory.md          # Μακροπρόθεσμες αναμνήσεις και σημειώσεις του AI
│   ├── Preferences.md     # Προτιμήσεις χρήστη (ύφος, γλώσσα, ρυθμίσεις)
│   └── Open-loops.md      # Εκκρεμότητες και ανοιχτά θέματα που παρακολουθεί ο agent
└── Attachments/
    ├── Photos/            # Φωτογραφίες υψηλής ανάλυσης
    ├── Videos/            # Πλήρη βίντεο
    ├── Clips/             # 5-10s rolling clips από τα Meta Glasses
    └── Audio/             # Ηχητικά αρχεία φωνητικών σημειώσεων
```

---

## 2. Μορφή Ημερήσιας Σημείωσης Markdown

Κάθε ημερήσια σημείωση περιέχει σχόλια οριοθέτησης για ασφαλές idempotency:

```markdown
# 2026-10-06

<!-- r0lling:id:C3E25B81-54A7-4632-B831-29E572B7E1B0 -->
### [14:32] Rolling Clip

Rolling Clip (10.0s) από τα Meta Glasses.

#clip #glasses

![Κλιπ / Βίντεο](../../Attachments/Clips/clip_1728214320.mp4)
<!-- /r0lling:id:C3E25B81-54A7-4632-B831-29E572B7E1B0 -->

<!-- r0lling:id:F128A992-62C1-4BD8-842B-1804B32A9951 -->
### [15:10] Φωνητική

Να πω στη Μαρία για το ταξίδι.

#σημαντικό #ταξίδι
<!-- /r0lling:id:F128A992-62C1-4BD8-842B-1804B32A9951 -->
```

---

## 3. Κανόνες Συγχώνευσης & Ανίχνευσης Συγκρούσεων

1. **Κύρια Πηγή (Single Source of Truth):** Η τοπική βάση του R0lling (`Application Support/R0lling/journal_v1.json`) είναι η κύρια αξιόπιστη πηγή των καταγραφών.
2. **Idempotent Export (A08):** Επανεξαγωγή μιας ημέρας ενημερώνει τις υπάρχουσες εγγραφές βάσει του αναγνωριστικού `r0lling:id:UUID` χωρίς να διπλασιάζει γραμμές.
3. **Ανίχνευση Εξωτερικών Αλλαγών (A09):** SHA256 ανά ημερήσιο αρχείο. Hash mismatch → sidecar `YYYY-MM-DD.r0lling-conflict.md` · το πρωτότυπο **δεν** υπεργράφεται.
4. **Hash Persistence:** Τα hashes αποθηκεύονται στο `R0llingMeta/export-hashes.json` μέσα στο vault ώστε το conflict detection να επιβιώνει μετά από restart.
5. **PathAsfaleia (SEC-002):** Όλα τα relative paths (notes, sidecar, Attachments, Agent, canvas/KG) περνούν από `PathAsfaleia.asfalhs_resolved_url`.
6. **Vault Selection:** Default `Documents/R0lling/ObsidianVault` ή εξωτερικός φάκελος μέσω iOS Files picker + security-scoped bookmark (`VaultBookmarkStore`).

---

## 4. Δημιουργία & Επαναφορά Αντιγράφων Ασφαλείας (Backup & Restore)

- **Manifest Format:**
  Το backup περιλαμβάνει το `manifest.json` με `schemaVersion: 1`, όλα τα entities, το `AgentMemory`, και αντίγραφα των φακέλων `Media/`.
- **Deduplication:**
  Κατά την επαναφορά (Restore), ελέγχονται τα IDs των καταχωρίσεων: αν μία καταγραφή υπάρχει ήδη, παραμένει ανέπαφη. Επαναφέρονται μόνο τα νέα δεδομένα, εξασφαλίζοντας μηδενικό κίνδυνο διπλότυπων.
