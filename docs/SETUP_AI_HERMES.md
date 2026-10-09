> Current status (2026-10-09): This document contains historical assertions or design targets. It is not evidence for the current checkout. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) and [FINDINGS_REMEDIATION.md](FINDINGS_REMEDIATION.md). Earlier “100%”, module counts, CI/head references and security/readiness claims are superseded.

# R0lling — Οδηγός Ρύθμισης AI & Hermes Agent (SETUP_AI_HERMES)

**Έργο:** `R0lling`  
**Επιλογές AI:** Hermes Agent (Home PC) & Direct AI API (Cloud)  
**Ημερομηνία:** 6 Οκτωβρίου 2026  
**Security:** SEC-004 HTTPS preference · SEC-007 URL allowlist · R3-004 Keychain · R3-012 empty-key

---

## 1. Επιλογή Α — Hermes Agent στο Home PC (Jarvis Mode)

Ο **Hermes Agent** εκτελείται στον προσωπικό υπολογιστή του σπιτιού και λειτουργεί ως ιδιωτικός βοηθός.

### 1.1 Εκκίνηση Gateway στον Υπολογιστή (PC)
```bash
# Εγκατάσταση και εκκίνηση Hermes API Gateway
hermes gateway start --host 0.0.0.0 --port 8080 --api-key "YOUR_SECRET_HERMES_TOKEN"
```

### 1.2 Ασφαλής Σύνδεση από το iPhone (SEC-004 / SEC-007)

- **Εντός σπιτιού (Wi-Fi):** HTTPS προτιμότερο· cleartext μόνο σε RFC1918 (π.χ. `http://192.168.1.50:8080/v1`).
- **Default στο app:** `https://127.0.0.1:8080/v1` (loopback HTTPS — χωρίς cleartext LAN default).
- **Εκτός σπιτιού:** Tailscale CGNAT cleartext HTTP επιτρέπεται μόνο για IPv4 διευθύνσεις μέσα στο `100.64.0.0/10` (`100.64.0.0` έως `100.127.255.255`, συμπεριλαμβανομένων των ορίων), π.χ. `http://100.100.0.1:8080/v1`. Οι αμέσως γειτονικές διευθύνσεις `100.63.255.255` και `100.128.0.0` απορρίπτονται. WireGuard μπορεί να χρησιμοποιήσει HTTP μόνο αν η διεύθυνσή του είναι επίσης σε επιτρεπόμενο private/LAN range· διαφορετικά χρησιμοποίησε HTTPS.

**ΠΟΤΕ** μην κάνεις port-forward Hermes στο δημόσιο internet χωρίς TLS.

### 1.3 Ρύθμιση στο R0lling
1. Άνοιξε R0lling → `Ρυθμίσεις` → `Πάροχος Τεχνητής Νοημοσύνης (AI)`.
2. Επίλεξε **`Hermes (Home PC)`**.
3. Εισάγετε URL (HTTPS ή allowlisted HTTP).
4. Εισάγετε Bearer Token → αποθηκεύεται στο **Keychain** (όχι UserDefaults).
5. Πάτα `Αποθήκευση Ρυθμίσεων AI` (fail-closed αν το URL δεν περνάει allowlist).

---

## 2. Επιλογή Β — Άμεσο AI API (Direct Cloud API)

1. Επίλεξε **`Direct AI API`**.
2. **Base URL:** `https://api.openai.com/v1` (υποχρεωτικά **HTTPS**).
3. **Model Name:** `gpt-4o-mini` (ή `gpt-4o` για vision).
4. **API Key:** `sk-...` → Keychain.
5. Άδειο key → typed error **7004** πριν το network (R3-012).

---

## 3. Προστασία Προσωπικών Δεδομένων

- **Context scrubbing:** στο συνηθισμένο chat αποστέλλονται έως πέντε πιο πρόσφατες εγγραφές της σημερινής ημέρας μόνο όταν είναι ενεργό το αντίστοιχο journal-context setting· δεν γίνεται semantic relevance filtering στο chat. Η ξεχωριστή λειτουργία ανάκλησης χρησιμοποιεί τοπική αντιστοίχιση λέξεων-κλειδιών. Η πραγματική Agent memory έχει δικό της opt-in setting και τα κενά markdown headings δεν αποστέλλονται.
- **Vision on-demand:** Η τρέχουσα πραγματική διαδρομή είναι ρητή επιλογή εικόνας από Photos και περνά από JPEG sanitization πριν σταλεί στον ρυθμισμένο provider. Η multi-frame λήψη από rolling buffer και το `capturePhoto` σε πραγματικά γυαλιά παραμένουν μη διαθέσιμα, επειδή το Meta DAT session/frame bridge είναι stub. Το αποτέλεσμα αποθηκεύεται μόνο με ρητή επιλογή και μπορεί να εκφωνηθεί με TTS. Δεν υπάρχει continuous cloud stream.
- **Error scrub (SEC-005):** user-facing μηνύματα = HTTP status μόνο · όχι raw body / tokens.
- **Retry/timeout:** bounded backoff για HTTP 408, 425, 429, 500, 502, 503 και 504 · `Task` cancellation υποστηρίζεται από UI «Άκυρο».

---

## 4. Verification limits

The code contains configurable Direct/Hermes connector paths and stores credentials in Keychain, but a configured source path is not production certification. No Swift XCTest, Apple build, or live provider request has been run for the current checkout. End-to-end validation needs a real credential in Keychain and a reachable endpoint; verify TLS/allowlist behavior, cancellation, errors, opt-in context payloads, and image limits against a controlled endpoint before release.

The app does not perform automatic text PII redaction. Ordinary chat sends journal context and Agent memory only when their separate settings are enabled; explicit summary and recall actions send the selected journal entries for those requests. User-entered prompts may still contain personal data. A local Hermes host is a network service, not an on-device model.
