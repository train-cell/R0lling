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
