> Current status (2026-10-09): This document contains historical assertions or design targets. It is not evidence for the current checkout. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) and [FINDINGS_REMEDIATION.md](FINDINGS_REMEDIATION.md). Earlier “100%”, module counts, CI/head references and security/readiness claims are superseded.

# R0lling — Αποφάσεις & Προεπιλογές (Decisions & Defaults Log) v1.0

**Έργο:** `R0lling`  
**Ημερομηνία:** 6 Οκτωβρίου 2026  

---

## 1. Καταγραφή Προεπιλογών Σχεδιασμού (Section 9 Defaults)

| Τομέας | Προεπιλεγμένη Απόφαση | Αιτιολόγηση & Τεχνικό Σκεπτικό |
|---|---|---|
| **Πλατφόρμα** | Εγγενής Swift / SwiftUI εφαρμογή για iOS 17.2+. | Μέγιστη απόδοση hardware, χαμηλή κατανάλωση μπαταρίας, άμεση υποστήριξη του επίσημου Meta DAT SDK. |
| **Γλώσσα & UI** | Ελληνικό περιβάλλον και ελληνική φωνητική αναγνώριση. Υποστήριξη αγγλικών εντολών (`clip this`, `note this`). | Άνετη καθημερινή χρήση στα Ελληνικά, διατηρώντας διεθνείς φωνητικές συντομεύσεις. |
| **Αισθητική** | Dark mode Discord × Twitch (`#16161D` φόντο, `#7742DC` μωβ accents). Επιλογές Light / System. | Σύγχρονη αίσθηση gaming/creator εργαλείου, υψηλή αναγνωσιμότητα timeline. |
| **Buffer Duration** | 10 δευτερόλεπτα προεπιλογή, με επιλογή εναλλαγής σε 5 δευτερόλεπτα. Χωρίς post-roll στην πρώτη έκδοση. | 10s είναι το ιδανικό διάστημα για σύλληψη απρόσμενων γεγονότων χωρίς υπερφόρτωση μνήμης. |
| **Ήχος στα Clips** | Συγχρονισμένος ήχος AAC εφόσον παρέχεται από τη ροή των γυαλιών. Αν όχι, πραγματικό MP4 βίντεο με σαφή ένδειξη. | Αποφυγή σιωπηρών σφαλμάτων και διαφάνεια στον χρήστη. |
| **Φωνητικές Σημειώσεις** | Αποθήκευση του εξαγόμενου κειμένου ως κύρια εγγραφή. Επιλογή αποθήκευσης του αρχικού `.m4a` ήχου. | Εξοικονόμηση χώρου και άμεση ευρετηρίαση/αναζήτηση στο ημερολόγιο. |
| **Κουμπί Fallback** | Ευδιάκριτο κουμπί `Clip` (τουλάχιστον 56pt ύψος) πάντα διαθέσιμο στο UI. | 100% αξιοπιστία όταν ο θόρυβος του περιβάλλοντος εμποδίζει τη φωνητική εντολή. |
| **Κύρια Πηγή Δεδομένων** | Τοπικό Sandbox του R0lling (SQLite / SwiftData). Το Obsidian λειτουργεί ως export mirror. | Αποτροπή αλλοίωσης δεδομένων αν αλλάξει ή μετακινηθεί ο εξωτερικός φάκελος Obsidian. |
| **Διένεξη Obsidian** | Έλεγχος SHA256 hashes. Καμία σιωπηρή διαγραφή εξωτερικών αλλαγών. | Προστασία σημειώσεων που ενδέχεται να συμπλήρωσε ο χρήστης απευθείας στο Obsidian Desktop. |
| **Διπλό AI Interface** | Ρητή επιλογή χρήστη μεταξύ **Hermes (Home PC)** και **Direct API**. | Απόλυτος σεβασμός στην ιδιωτικότητα. Χωρίς αυτόματη/κρυφή διαρροή δεδομένων. |

---

## 2. Meta DAT / Simulation (Lane Clip+Meta — 2026-10-06)

| Απόφαση | Τιμή | Αιτιολόγηση |
|---|---|---|
| **Windows / no DAT vendor** | Simulation-only path + πλήρες protocol/adapter/remux structure | Το MetaWearablesDAT δεν vendor-άρεται αξιόπιστα σε Windows SPM. |
| **Simulation labeling** | Device name περιέχει `SIMULATION — όχι φυσική συσκευή` | Αποφυγή LIVE hardware claims χωρίς Gen 2. |
| **Non-sim χωρίς SDK** | Error `4002` · ποτέ fake `.connected` | R3-003 / plan honesty. |
| **Playable clip χωρίς NAL** | Stage-4 `PlayableClipExporter` placeholder validated with `AVURLAsset.load(.isPlayable)` | A05 software path · real remux requires actual DAT samples and SPS/PPS. |
| **Background capture promise** | `promisesContinuousBackgroundCapture = false` default | Μέχρι εμπειρικό DAT proof στο device. |
| **Acoustic/IMU product** | Feed API wired · `FeatureReadinessRegistry.*.ready = false` | Flip flag = auto-clip χωρίς νέο wiring. |
| **Mac flip path** | `docs/LANE_CLIP_META.md` | Ακριβή βήματα για DAT SPM + bridge wire. |

---

## 3. AI Dual-Path Software DoD (Lane AI — 2026-10-06)

| Απόφαση | Τιμή | Αιτιολόγηση |
|---|---|---|
| **A10 SW ready** | Adapters + Keychain + SEC-004/007 + empty-key 7004/7104 = **software-complete** | Live HTTPS/LAN credentials = **DEV** proof, όχι SW blocker. |
| **A11/A12 SW ready** | Path + OCR/keyword + fail-closed empty = SW · live vision/AI reply = DEV | Honesty: UI δεν ισχυρίζεται live χωρίς key. |
| **A13 SW ready** | AgentFolderManager + PathAsfaleia + empty templates (CQ-P0-001) | Device Files accept/export = DEV. |
| **No silent failover** | Provider switch manual only | Plan A10 — χωρίς κρυφή εναλλαγή Direct↔Hermes. |

---

## 4. App Target & Permissions (P0-05 / A16 — 2026-10-06)

| Απόφαση | Τιμή | Αιτιολόγηση |
|---|---|---|
| **SPM library ≠ app** | Installable shell στο `Apps/R0llingApp/` (Info.plist + README + XcodeGen yml) | Χωρίς committed `.xcodeproj` (merge thrash). |
| **Privacy strings** | Όλα τα NS*UsageDescription στο `Apps/R0llingApp/Info.plist` | A16 SW scaffolding πριν device deny prompts. |
| **Disk full** | `ELAXISTOS_ELEUTHEROS_XOROS_BYTES` + `AppErrorTaxonomy.diskFull` | Typed error · data safe. |
| **P0-01** | GHA `.github/workflows/swift-ci.yml` = contract · green log = HANDOFF proof | WSL Swift 6.1.3 parses; Linux `swift test` stops at unavailable Apple `ImageIO`; Apple XCTest/build evidence still pending. |

---

## 5. Wave-B Orphans → Experimental/ (P1-04 — 2026-10-06)

| Απόφαση | Τιμή | Αιτιολόγηση |
|---|---|---|
| **Spatial / Metal / Watermark / FileWatcher** | Μετακίνηση σε `Sources/R0lling/Experimental/` | AUDIT P1-04: delete **ή** Experimental — όχι delete (μαθηματικά/schema χρήσιμα μετά device proof). |
| **Product surface** | `FeatureReadinessRegistry.*.ready = false` · **0** AppState holds | FREEZE μέχρι A05/A10 device. |
| **DoD CLOSED** | Experimental path + flags + README | Δεν μετράει ως product feature. |

---

## 6. AppState God-Object (P1-05 — 2026-10-06)

| Απόφαση | Τιμή | Αιτιολόγηση |
|---|---|---|
| **Split Journal/Clip/Assistant/Experimental** | **DEFERRED** μέχρι soft-GO (πράσινο `swift test`) | Μεγάλο refactor · regression risk · Karpathy surgical. |
| **Orphan holds** | **CLOSED** | Spatial/Metal/Watermark/FileWatcher **δεν** κρατιούνται στο AppState · μόνο READY engines + gated acoustic/IMU/mirror. |
| **Gate** | `FeatureReadinessRegistry` | Μοναδική πηγή αλήθειας για wave-B/C UI surface. |
