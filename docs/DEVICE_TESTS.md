# R0lling — Πρωτόκολλο Δοκιμών Συσκευών (DEVICE_TESTS)

**Έργο:** `R0lling`  
**Συσκευές Στόχου:** iPhone 15/16 Pro (iOS 17.2+) & Meta Glasses Gen 2  
**Ημερομηνία:** 6 Οκτωβρίου 2026  

---

## 1. Μητρώο Ελέγχου Φυσικών Συσκευών (Device Check Matrix)

| Έλεγχος | Περιγραφή Δοκιμής | Αναμενόμενο Αποτέλεσμα | Πραγματικό Αποτέλεσμα | Κατάσταση |
|---|---|---|---|---|
| **DEV-01: Xcode Build** | Μεταφορά σε Mac, άνοιγμα `Package.swift`, Build στο Xcode 16+. | `Build Succeeded` χωρίς compilation errors. | Έτοιμο προς εκτέλεση σε Mac. | ⏳ Εκκρεμεί σε Mac |
| **DEV-02: Offline Journal** | Εγγραφή σημείωσης στο iPhone σε Airplane Mode. Επανεκκίνηση εφαρμογής. | Η σημείωση παραμένει αποθηκευμένη και εμφανίζεται στο `TodayView`. | Επαληθεύτηκε σε simulation storage. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-03: Meta Glasses Pairing** | Ενεργοποίηση Bluetooth, πάτημα `Σύνδεση Γυαλιών`. | Σύνδεση με Meta Ray-Ban Gen 2 και ένδειξη μπαταρίας. | Επαληθεύτηκε σε simulation adapter. | ⏳ Εκκρεμεί σε Gen 2 |
| **DEV-04: Live Streaming** | Εκκίνηση ροής κάμερας από τα γυαλιά. | Ροή 1080p @ 30fps, pulsing `LIVE` badge, ένδειξη buffer. | Επαληθεύτηκε με synthetic frames. | ⏳ Εκκρεμεί σε Gen 2 |
| **DEV-05: 10s Clip Trigger** | Πάτημα του κουμπιού `CLIP THIS` μετά από 15s συνεχούς ροής. | Αποθήκευση playable MP4· `AVAsset.isPlayable == true`· simulation = ρητό placeholder label. | Python/static moov contract OK· όχι AVAsset runtime. | ⏳ Εκκρεμεί σε Mac/Gen 2 |
| **DEV-05b: TZ day filter** | Δημιούργησε εγγραφή σε άλλη TZ (ή mock) και άλλαξε TZ συσκευής. | Εμφανίζεται στη σωστή `dateKey` ημέρα (R3-009). | Static + XCTest στον κώδικα. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-05c: Empty AI key** | Σβήσε API key, στείλε chat. | Typed error «Λείπει … key» · χωρίς network 401. | Static guard (R3-012). | ⏳ Εκκρεμεί σε iPhone |
| **DEV-06: Voice Wake & Note** | Εκφώνηση «σημείωσε να πάρω τηλέφωνο τη Μαρία». | Καταχώριση σημείωσης χωρίς διπλότυπα. | Επαληθεύτηκε με test suite. | ⏳ Εκκρεμεί σε Gen 2 |
| **DEV-07: Background Suspension** | Ελαχιστοποίηση της εφαρμογής κατά τη ζωντανή ροή. | Καθαρή ένδειξη `PAUSED`, προστασία μνήμης. | Επαληθεύτηκε στο AppState. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-08: Obsidian Vault Link** | Επιλογή φακέλου στο iOS Files και εξαγωγή. | Δημιουργία `YYYY/MM/YYYY-MM-DD.md` με σχετικά links attachments. | Επαληθεύτηκε με test suite. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-09: Hermes Connection** | Σύνδεση με το Home PC μέσω Wi-Fi ή Tailscale VPN. | Επιτυχής απάντηση του Hermes στο chat και ανάκληση αναμνήσεων. | Επαληθεύτηκε με connector schema. | ⏳ Εκκρεμεί σε Home PC |
| **DEV-10: Observation Game** | Έναρξη αποστολής («Βρες κάτι κόκκινο»), λήψη φωτογραφίας με τα γυαλιά, αξιολόγηση. | Αξιολόγηση από Vision AI, απονομή πόντων. | Επαληθεύτηκε σε game engine. | ⏳ Εκκρεμεί σε Gen 2 |

---

## 2. Οδηγίες Αναφοράς Σφαλμάτων (Device Bug Report Template)

Αν κατά τις δοκιμές στη φυσική συσκευή εντοπιστεί οποιαδήποτε δυσλειτουργία, χρησιμοποιήστε το πρότυπο `06-GPT-Device-Fixes.md`:

```text
Related acceptance ID / λειτουργία: [π.χ. A05 - Clipping]
Project checkpoint ή build: [v1.0.0-rc1]
Συσκευή / iOS / firmware / Meta SDK: [iPhone 16 Pro, iOS 18.1, Gen 2 FW v3.2, DAT SDK 1.0]
Συγκεκριμένα βήματα αναπαραγωγής: [1. Έναρξη ροής, 2. Πάτημα clip, ...]
Αναμενόμενο αποτέλεσμα: [...]
Πραγματικό αποτέλεσμα: [...]
Σχετικό error/log: [...]
```

---

## 3. Mac / `swift test` checklist (P0-01 — honest blocker)

> **Status:** 🚫 BLOCKED σε Windows host · **χωρίς** fake PASS.  
> Proof artifact: πράσινο GHA log **ή** τοπικό `swift-test.log` → γραμμή στο `docs/HANDOFF.md`.

### 3.1 GitHub Actions (προτιμητέο)

| # | Βήμα | Πού | Done? |
|---|---|---|---|
| 1 | Push/PR στο `main` **ή** Actions → `R0lling CI (Cloud macOS)` → **Run workflow** | GitHub → Actions | ☐ |
| 2 | Job `python-verify` = πράσινο (stage3→5 + verify_all) | Actions run | ☐ |
| 3 | Job `build-and-test` = πράσινο (`swift build` + `swift test --parallel`) | Actions run | ☐ |
| 4 | Κατέβασε artifact `swift-test-log` | Actions → Artifacts | ☐ |
| 5 | Επικόλλησε στο HANDOFF: `GHA run <URL> · swift test PASS · <timestamp>` | `docs/HANDOFF.md` | ☐ |
| 6 | (Optional) `AVAsset.isPlayable` smoke για placeholder clip — DEV-05 | Mac XCTest / device | ☐ |

Workflow file: `.github/workflows/swift-ci.yml`

### 3.2 Τοπικό Mac (εναλλακτικό)

| # | Βήμα | Εντολή / σημείωση | Done? |
|---|---|---|---|
| 1 | Clone + Xcode 16+ | `cd R0lling` | ☐ |
| 2 | Build | `swift build` | ☐ |
| 3 | Tests | `swift test --parallel 2>&1 \| tee swift-test.log` | ☐ |
| 4 | App shell | `Apps/R0llingApp/README.md` (XcodeGen ή manual target) | ☐ |
| 5 | HANDOFF proof | ίδια γραμμή με 3.1 §5 | ☐ |

DAT flip (όχι SW blocker · v1 sim-only): `docs/LANE_CLIP_META.md` §3 + `docs/DECISIONS.md` §2.

---

## 4. Device A-ID checklist (0/16 proven — όχι SW)

Κάθε γραμμή DEV-01…DEV-10 παραπάνω παραμένει ☐ μέχρι **πραγματικό** αποτέλεσμα στη στήλη «Πραγματικό Αποτέλεσμα».  
Μην αλλάξεις σε ✅ χωρίς screenshot/log στο HANDOFF.
