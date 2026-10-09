> Current status (2026-10-09): This document contains historical assertions or design targets. It is not evidence for the current checkout. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) and [FINDINGS_REMEDIATION.md](FINDINGS_REMEDIATION.md). Earlier “100%”, module counts, CI/head references and security/readiness claims are superseded.

# R0lling — Πρωτόκολλο Δοκιμών Συσκευών (DEVICE_TESTS)

**Έργο:** `R0lling`  
**Συσκευές Στόχου:** iPhone 15/16 Pro (iOS 17.2+) & Meta Glasses Gen 2  
**Τελευταία ενημέρωση:** 9 Οκτωβρίου 2026

---

## 1. Μητρώο Ελέγχου Φυσικών Συσκευών (Device Check Matrix)

| Έλεγχος | Περιγραφή Δοκιμής | Αναμενόμενο Αποτέλεσμα | Πραγματικό Αποτέλεσμα | Κατάσταση |
|---|---|---|---|---|
| **DEV-01: Xcode Build** | Μεταφορά του τρέχοντος checkout σε Mac, build package και app host. | Επιτυχές Swift package test και iOS host build. | Δεν εκτελέστηκε. WSL Swift 6.1 parse πέρασε· SwiftPM build σταμάτησε σε έλλειψη Apple `ImageIO`. | ⏳ Εκκρεμεί σε Mac |
| **DEV-02: Offline Journal** | Εγγραφή σημείωσης στο iPhone σε Airplane Mode. Επανεκκίνηση εφαρμογής. | Η σημείωση παραμένει αποθηκευμένη και εμφανίζεται στο `TodayView`. | Source path και XCTest υπάρχουν· δεν εκτελέστηκαν σε αυτή την εργασία. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-03: Meta Glasses Pairing** | Ενεργοποίηση Bluetooth, πάτημα `Σύνδεση Γυαλιών`. | Pairing και πραγματική ένδειξη συσκευής/battery. | Live DAT bridge είναι stub· η εφαρμογή μένει σε simulation. Δεν έγινε pairing. | 🚫 Blocked: DAT implementation + Gen 2 |
| **DEV-04: Live Streaming** | Εκκίνηση ροής κάμερας από τα γυαλιά. | Πραγματικά frames με timestamp και σωστή κατάσταση streaming. | Δεν υπάρχει live DAT frame path. Synthetic simulation δεν είναι live test. | 🚫 Blocked: DAT implementation + Gen 2 |
| **DEV-05: 10s Clip Trigger** | Πάτημα του κουμπιού `CLIP THIS` μετά από επαρκές warm-up. | Playable output, honest simulation label, correct captured duration. | XCTest source υπάρχει· AVFoundation playability/runtime δεν ελέγχθηκαν. | ⏳ Εκκρεμεί σε Mac/Gen 2 |
| **DEV-05b: TZ day filter** | Δημιούργησε εγγραφή σε άλλη TZ (ή mock) και άλλαξε TZ συσκευής. | Εμφανίζεται στη σωστή `dateKey` ημέρα (R3-009). | Source/XCTest checks υπάρχουν· δεν εκτελέστηκαν. | ⏳ Εκκρεμεί σε Mac/iPhone |
| **DEV-05c: Empty AI key** | Σβήσε API key, στείλε chat. | Typed missing-key error πριν από network request. | Source guard υπάρχει· no-network behavior δεν δοκιμάστηκε. | ⏳ Εκκρεμεί σε Mac/iPhone |
| **DEV-06: Voice Wake & Note** | Εκφώνηση «σημείωσε να πάρω τηλέφωνο τη Μαρία». | Note αποθηκεύεται μία φορά από υποστηριζόμενο speech input. | Parser XCTest source υπάρχει· live speech/hardware test δεν έγινε. Hey Meta wake δεν υλοποιείται. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-07: Background Suspension** | Ελαχιστοποίηση της εφαρμογής κατά ενεργή ροή. | Honest paused state και καθαρή lifecycle policy. | Source logic υπάρχει· iPhone lifecycle/session behavior δεν ελέγχθηκε. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-08: Obsidian Vault Link** | Επιλογή φακέλου στο iOS Files και εξαγωγή. | Δημιουργία Markdown/attachment links χωρίς απώλεια υπάρχοντος vault. | XCTest source υπάρχει· Files provider/scoped access δεν δοκιμάστηκαν. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-09: Hermes Connection** | Σύνδεση με ελεγχόμενο endpoint μέσω LAN/VPN. | Επιτυχής απάντηση και σωστό payload/error policy. | Connector source/schema υπάρχουν· δεν έγινε live request. | ⏳ Εκκρεμεί σε endpoint |
| **DEV-10: Observation Game** | Έναρξη αποστολής, λήψη ή εισαγωγή φωτογραφίας, αξιολόγηση. | AI result, fail-closed errors, success-only streak. | Engine/XCTest source υπάρχει· actual provider/device run δεν έγινε. | ⏳ Εκκρεμεί σε Mac/iPhone |

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

> **Status:** 🚫 Εκκρεμεί Apple build/test. WSL Swift parse περνά, αλλά Linux SwiftPM build σταματά επειδή δεν παρέχεται Apple `ImageIO`. Δεν υπάρχει fake PASS.
> Proof artifact: πράσινο GHA log **ή** τοπικό `swift-test.log` → γραμμή στο `docs/HANDOFF.md`.

### 3.1 GitHub Actions (προτιμητέο)

| # | Βήμα | Πού | Done? |
|---|---|---|---|
| 1 | Άνοιξε το υπάρχον CI run ή ζήτησε εξουσιοδοτημένο run από GitHub Actions | GitHub → Actions | ☐ |
| 2 | Job `python-verify` = πράσινο (`verify_all_subsystems.py` + `verify_theme_apple_meta_compliance.py`) | Actions run | ☐ |
| 3 | Job `build-and-test` = πράσινο (`swift build` + `swift test --parallel`) | Actions run | ☐ |
| 4 | Κατέβασε artifact `swift-build-and-test-logs` (`swift-test.log` + `swift-build.log`) | Actions → Artifacts | ☐ |
| 5 | Επικόλλησε στο HANDOFF: `GHA run <URL> · swift test PASS · <timestamp>` | `docs/HANDOFF.md` | ☐ |
| 6 | (Optional) `AVAsset.isPlayable` smoke για placeholder clip — DEV-05 | Mac XCTest / device | ☐ |

Workflow file: `.github/workflows/swift-ci.yml`. The archived diagnose-stage scripts are not part of the current `python-verify` job.

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
