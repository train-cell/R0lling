> Current status (2026-10-13): This document records product decisions; it is not runtime evidence. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md), [SETUP_META.md](SETUP_META.md), and [AUDIT_VERIFICATION.md](AUDIT_VERIFICATION.md) for the current checkout. Earlier “100%”, module counts, CI/head references and security/readiness claims are superseded.

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
| **DAT SDK / current usable mode** | The iOS package declares DAT 1.0.1; registration/session, permission-confirmed camera publisher, raw-to-H.264 conversion, and PTS-derived remux timing have source, while simulation remains the only usable glasses mode | Source is not Apple build or device proof. Keep live readiness gated until the existing path is built and verified on a supported device; photo, camera audio, and IMU remain unwired. |
| **Simulation labeling** | Device name περιέχει `SIMULATION — όχι φυσική συσκευή` | Αποφυγή LIVE hardware claims χωρίς Gen 2. |
| **Non-sim χωρίς SDK** | Error `4002` · ποτέ fake `.connected` | R3-003 / plan honesty. |
| **Playable clip χωρίς NAL** | Stage-4 `PlayableClipExporter` placeholder validated with `AVURLAsset.load(.isPlayable)` | A05 software path · real remux requires actual DAT samples and SPS/PPS. |
| **Background capture promise** | `promisesContinuousBackgroundCapture = false` default | Μέχρι εμπειρικό DAT proof στο device. |
| **Acoustic/IMU product** | Simulation-only sample plumbing · `FeatureReadinessRegistry.*.ready = false` | DAT exposes experimental camera PCM audio and `MWDATMotion`; neither is linked/wired in R0lling. Motion needs Developer Center capability approval and production publication is not currently supported. Before DAT audio permission is requested, revise the current voice-notes-only `NSMicrophoneUsageDescription` to disclose glasses camera-audio processing. Implement source mapping, app flow, and verify real callbacks on a device before changing readiness. |
| **DAT implementation guide** | `docs/LANE_CLIP_META.md` | Προαπαιτούνται συμβατό toolchain, πραγματικό bridge/feed και device proof· το guide δεν είναι οδηγία ενεργοποίησης flags. |
| **DAT analytics / crash reporting (2026-10-13)** | `MWDAT > Analytics > OptOut` και `MWDAT > CrashReporting > OptOut` = `true` στο `Apps/R0llingApp/Info.plist` | Το README του DAT 1.0.1 ορίζει ότι και τα δύο είναι ενεργά όταν λείπει το κλειδί· η απενεργοποίηση ευθυγραμμίζεται με την τοπική φύλαξη δεδομένων. Το ίδιο README σημειώνει ότι, με ενεργές τις Meta integrations, η Meta μπορεί να συλλέγει πληροφορίες για την επικοινωνία των συσκευών της με την εφαρμογή· τα δύο κλειδιά είναι ο τεκμηριωμένος τρόπος περιορισμού. Δεν έχει επαληθευτεί σε build· ο χρήστης μπορεί να το αναθεωρήσει. |

---

## 3. AI Dual-Path Software DoD (Lane AI — 2026-10-06)

| Απόφαση | Τιμή | Αιτιολόγηση |
|---|---|---|
| **A10 SW ready** | Adapters + Keychain + SEC-004/007 + empty-key 7004/7104 = **software-complete** (ορισμός DoD, όχι δήλωση επαλήθευσης· XCTest/Apple build και live proof εκκρεμούν, βλ. `GOAL_100_FEATURE_MATRIX.md`) | Live HTTPS/LAN credentials = **DEV** proof, όχι SW blocker. |
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
| **Product surface** | `FeatureReadinessRegistry.*.ready = false`; gated modules stay off | FREEZE μέχρι A05/A10 device. |
| **DoD CLOSED** | Experimental path + flags + README | Δεν μετράει ως πλήρες product feature. |

**Current exception (2026-10-10):** B12's Obsidian watcher is connected as a debounced directory-entry hint for the selected root and nested directories in Settings. It reconciles added/removed folders and same-path directory replacements by identity, skips symlink subtrees, and surfaces reconciliation errors by stopping and marking the watcher unavailable. It does not read vault files, synchronize changes, or reliably detect edits to files inside existing directories. It remains `ready=false` pending Apple runtime/device validation. This narrow status surface supersedes the historical “0 AppState holds” assertion for the watcher only; other Experimental modules remain frozen.

**Orphan placement follow-up (2026-10-13):** B08 ProximityAlertManager, C01 PseudoLexicalVectorSearchEngine, C02 TurnTakingGuard, C05 HyperlapseTripCompressor, and C06 LocalWhisperOfflineService had no product callers and were outside the Experimental folder. They were moved under `Sources/R0lling/Experimental/` with their public type names and `ready=false` flags unchanged. This satisfies the matrix's freeze/orphan placement option; no live feeds, models, or product behavior were added.

---

## 6. AppState God-Object (P1-05 — 2026-10-06)

| Απόφαση | Τιμή | Αιτιολόγηση |
|---|---|---|
| **Split Journal/Clip/Assistant/Experimental** | **DEFERRED** μέχρι soft-GO (πράσινο `swift test`) | Μεγάλο refactor · regression risk · Karpathy surgical. |
| **Orphan holds** | **CLOSED** | Spatial/Metal/Watermark δεν κρατιούνται στο AppState. Ο FileWatcher κρατιέται μόνο για status hint στο Settings· παραμένει `ready=false` και δεν κάνει import/sync. |
| **Gate** | `FeatureReadinessRegistry` | Πηγή αλήθειας για product actions· ένα `ready=false` feature μπορεί να έχει μόνο ρητό diagnostic/status surface. |

---

## 7. Cross-platform clients (2026-10-13)

| Απόφαση | Τιμή | Αιτιολόγηση |
|---|---|---|
| **iOS client** | Παραμένει native SwiftUI και πηγή αλήθειας για τη v1 συμπεριφορά | Επιβεβαιωμένη κατεύθυνση χρήστη· βλ. `MULTIPLATFORM_ROADMAP.md`. |
| **Android / Windows stack** | **Εκκρεμεί απόφαση χρήστη.** Το KMP/Compose είναι πρόταση υπό αξιολόγηση στο `ADR_0001_ANDROID_WINDOWS_CLIENT_STACK.md` (status: Proposed), με spike gates για Windows accessibility (Narrator μέσω Java Access Bridge), διανομή Windows, contract conformance και Android DAT | Ο χρήστης ζήτησε αξιολόγηση, όχι προεγκεκριμένη επιλογή. |
| **Ανταλλαγή δεδομένων** | Μόνο ρητό backup bundle και Obsidian export· κανένα αυτόματο sync· v1 shapes αμετάβλητα | `CROSS_PLATFORM_DATA_CONTRACT.md` και `contracts/r0lling-exchange-v1.schema.json`. |
| **Prototype/sample cards** | Εκτός αρχικού scope των νέων clients μέχρι ρητή απόφαση | Δεν φέρουν δεδομένα χρήστη· στο iOS οι prototype/sample κάρτες είναι σημασμένες ως προεπισκοπήσεις, ενώ οι Experimental demo cards δεν εμφανίζονται καθόλου. |

**Σημείωση συνέπειας (2026-10-13):** Η γραμμή «Αισθητική» της §1 αναφέρει επιλογές Light / System, αλλά ο τρέχων κώδικας εφαρμόζει `.preferredColorScheme(.dark)` στη ρίζα της εφαρμογής (`Sources/R0lling/App/R0llingApp.swift`) και δεν υπάρχει ρύθμιση θέματος. Οι επιλογές Light/System δεν είναι υλοποιημένες· οποιαδήποτε υλοποίηση απαιτεί ρητή απόφαση και light-mode tokens. Επίσης στην §1:
- **Χρώματα:** τα `#16161D` / `#7742DC` έχουν αντικατασταθεί από τα tokens του [DESIGN.md](DESIGN.md) (`bgPrimary` `#1F2023`, `accentPurple` `#7068E8`).
- **Αποθήκευση δεδομένων:** η κύρια αποθήκευση είναι το JSON v1 `journal_v1.json` ([CROSS_PLATFORM_DATA_CONTRACT.md](CROSS_PLATFORM_DATA_CONTRACT.md)), όχι SQLite/SwiftData.
- **Αρχικό `.m4a`:** η επιλογή αποθήκευσης του αρχικού ήχου στις φωνητικές σημειώσεις δεν υλοποιείται· το `m4a` υπάρχει μόνο ως τύπος εισαγωγής ήχου.
- **«100% αξιοπιστία»:** η φράση για το κουμπί `Clip` είναι στόχος σχεδιασμού, όχι μετρημένο αποτέλεσμα.
- **Ύψος κουμπιού `Clip`:** το κουμπί «CAPTURE 10s» του `FloatingClipBar` (`Sources/R0lling/UI/Components.swift`) έχει κείμενο `subheadline` με 14pt κάθετο padding, δηλαδή περίπου 48pt ύψος (υπολογισμός από τον κώδικα, όχι μέτρηση σε render), και εμφανίζεται μόνο όσο υπάρχει ενεργή ροή στη σημερινή ημέρα. Το ελάχιστο 56pt της §1 δεν επιβάλλεται ρητά· η αλλαγή μεγέθους είναι οπτική απόφαση που εκκρεμεί για τον χρήστη. Από 2026-10-13 το κείμενο του κουμπιού και του viewfinder ακολουθεί τη ρύθμιση buffer (5s/10s).
- **Ήχος AAC στα clips:** δεν υλοποιείται. Και οι δύο διαδρομές εξαγωγής γράφουν MP4 μόνο με βίντεο και δηλώνουν `hasAudio: false` (`RollingBufferService.triggerClip`)· τα audio samples του buffer δεν γίνονται mux. Η «σαφής ένδειξη» για clip χωρίς ήχο δεν εμφανίζεται ακόμη στο UI.
