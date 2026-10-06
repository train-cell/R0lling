# R0lling — Πίνακας Δυνατοτήτων (Capability Matrix) v1.0

**Έργο:** `R0lling`  
**Συσκευές:** Meta Glasses Gen 2 & iPhone  
**Ημερομηνία:** 6 Οκτωβρίου 2026  
**Επίσημο SDK:** Meta Wearables Device Access Toolkit (DAT) iOS SDK 1.0  

---

## 1. Κατάσταση Δυνατοτήτων Meta Glasses Gen 2 (Hardware & SDK)

| Δυνατότητα | Κατάσταση SDK 1.0 | Απαιτεί Physical Device / Account | Συμπεριφορά στο R0lling | Εναλλακτική (Fallback) |
|---|---|---|---|---|
| **Camera Live Stream (Foreground)** | Επίσημα υποστηριζόμενο (HEVC/H.264) | Ναι (Meta Dev Account + Gen 2) | Πλήρης λήψη καρέ και τροφοδότηση Rolling Buffer. | Simulation Stream Generator (Test Frames). |
| **High-Res Photo Capture** | Επίσημα υποστηριζόμενο | Ναι (Gen 2 paired) | Λήψη πλήρους ανάλυσης snapshot από τα γυαλιά. | iPhone Camera / Photo Picker. |
| **Microphone Audio Stream** | Επίσημα υποστηριζόμενο | Ναι (Bluetooth HFP/LE Audio) | Συγχρονισμός ήχου στο buffer με τα βίντεο frames. | iPhone Built-in Microphone. |
| **Rolling Buffer 5-10s** | Εφαρμογή R0lling (Local) | Όχι (Επεξεργασία στο iPhone) | Ring-buffer + keyframe snap· export playable MP4 via AVAssetWriter (simulation = placeholder με moov). | Πλήρως λειτουργικό σε Simulation (ρητό placeholder label). |
| **«Hey Meta, clip this» (Voice Wake)** | Experimental / Restricted | Ναι (Meta AI Voice Invocation) | Ανίχνευση μέσω SDK voice hooks όταν είναι διαθέσιμα. | Μεγάλο κουμπί `Clip 10s` / `Clip 5s` στο UI + iOS Dictation. |
| **«Hey Meta, note this» (Voice Wake)** | Experimental / Restricted | Ναι (Meta AI Voice Invocation) | Ανίχνευση φράσης έναρξης υπαγόρευσης. | Κουμπί μικροφώνου (iOS Speech Framework) στο Composer. |
| **Stream in Background (App Minimized)** | Περιορισμένο / Beta | Ναι | Το sample κλείνει το session κατά το backgrounding. Αν το SDK 1.0 επιτρέπει compressed stream, διατηρείται· αλλιώς pause με σαφή ένδειξη. | Καθαρή ένδειξη στο UI: «Ροή ανεστάλη στο background». |
| **Stream with Locked Screen** | Μη υποστηριζόμενο από iOS Sandbox | Ναι | Αναστολή ροής για προστασία απορρήτου και μπαταρίας. | Αυτόματη επαναφορά κατά το ξεκλείδωμα. |
| **On-device AI Vision** | Μη διαθέσιμο στα Gen 2 | Ναι | Αποστολή ενός (1) επιλεγμένου καρέ στο συνδεδεμένο AI. | Local / Cloud Vision API (GPT-4o, Gemini Flash). |

---

## 2. Κατάσταση Αποθήκευσης & Εξωτερικών Υπηρεσιών

| Σύστημα | Κατάσταση | Απαιτήσεις | Συμπεριφορά στο R0lling |
|---|---|---|---|
| **Τοπική Βάση (Local DB)** | R3-001 ISO8601 + R3-009 TZ day filter στον κώδικα · device XCTest εκκρεμεί | Τοπικό Sandbox iPhone | Offline-first JSON journal· day buckets via entry.dateKey + display TZ. |
| **Rolling Clip Export** | Playable placeholder MP4 (AVAssetWriter + moov) · πραγματικό DAT NAL remux εκκρεμεί | iPhone · Gen 2 για πραγματικό stream | Simulation: playable placeholder + `isSimulationPlaceholder`. |
| **Obsidian Vault Export** | Κώδικας OK (R3-005 conflict sidecar) · Files picker εκκρεμεί | iOS Files picker | Idempotent markers· hash mismatch → `.r0lling-conflict.md` χωρίς overwrite. |
| **Hermes Gateway (Home PC)** | Connectors υπάρχουν · live endpoint εκκρεμεί | PC σε LAN/VPN + token | OpenAI-compatible HTTP· χωρίς silent failover. |
| **Direct AI API** | Connectors + Keychain (R3-004) · empty-key guard (R3-012) στον κώδικα | API Key στο Keychain | HTTPS· άδειο key → typed error 7004 πριν network. |
| **Meta DAT Pairing** | Simulation-only χωρίς SDK (R3-003) | MetaWearablesDAT SPM + Gen 2 | Non-sim χωρίς SDK → error 4002 (όχι ψευδής σύνδεση). |
| **Observation Game** | Κώδικας υπάρχει · vision live εκκρεμεί | Κάμερα + Vision AI | Manual fallback αν λείπει το AI. |

---

## Stage 4–5 note (2026-10-06)

Μην βασίζεσαι σε παλιές δηλώσεις «100% Υλοποιημένο» για hardware paths. Βλέπε `IMPLEMENTATION_STATUS.md` και `FIX_LOG.md`.  
Gemini super-features: earcons / Time Capsule / Watch hooks = partial wiring· acoustic + head-nod **disabled** until mic/IMU feed (CQ-P0-007)· όχι Gen 2 proof.

## 3. Lifecycle Πολιτική (State Transitions)

```text
Foreground Active:
  - Ροή Κάμερας: ΕΝΕΡΓΗ (αν τα γυαλιά είναι συνδεδεμένα)
  - Rolling Buffer: Γεμίζει κυκλικά (μέχρι 10s)
  - UI Ένδειξη: "LIVE" (κόκκινο pulsing badge)
  - Clip Button: Ενεργό με ένδειξη πραγματικής διάρκειας (π.χ. "10s", "4.2s")

Background Entering:
  - Ενημέρωση Buffer: Ασφαλής δέσμευση τελευταίου snapshot
  - Έλεγχος SDK session: Αν το session κλείσει από το λειτουργικό, κατάσταση -> Paused
  - UI Ένδειξη: "PAUSED / INACTIVE"

Screen Locked:
  - Ασφαλής διακοπή buffering, μηδενισμός κατανάλωσης ενέργειας
  - Καμία ψευδής ένδειξη ότι καταγράφει στα κρυφά
```
