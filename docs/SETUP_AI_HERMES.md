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
- **Εκτός σπιτιού:** Tailscale/WireGuard (`http://100.x.y.z:8080/v1` allowlisted) ή HTTPS.

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

- **Context scrubbing:** μόνο σχετικές journal entries + πραγματική Agent memory (άδεια headings δεν στέλνονται).
- **Vision on-demand:** multi-frame από rolling buffer όταν υπάρχει· αλλιώς ένα `capturePhoto` (protocol/sim). Όχι continuous cloud stream.
- **Error scrub (SEC-005):** user-facing μηνύματα = HTTP status μόνο · όχι raw body / tokens.
- **Retry/timeout:** transient 408/429/5xx με bounded backoff · `Task` cancelation υποστηρίζεται από UI «Άκυρο».

---

## 4. Live tokens (residual)

Για end-to-end A10–A12 proof χρειάζονται πραγματικά credentials στο Keychain + reachable Hermes ή Direct endpoint. Ο κώδικας είναι production-ready χωρίς live tokens.
