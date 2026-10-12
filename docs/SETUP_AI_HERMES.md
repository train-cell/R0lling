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

`0.0.0.0` listens on every IPv4 interface. Before starting the gateway, restrict inbound port 8080 in the PC firewall to trusted LAN/VPN clients that need access; do not expose it through a public router port-forward. Use a strong, unique API token.

### 1.2 Ασφαλής Σύνδεση από το iPhone (SEC-004 / SEC-007)

- **Εντός σπιτιού (Wi-Fi):** HTTPS προτιμότερο· cleartext επιτρέπεται μόνο για canonical RFC1918/IPv4 link-local/Tailscale-CGNAT hosts, `localhost`/loopback και `.local` (π.χ. `http://192.168.1.50:8080/v1`). Το `.local` είναι μόνο suffix check: το app δεν ελέγχει ούτε «καρφιτσώνει» τη διεύθυνση που θα επιστρέψει το mDNS/DNS, και η αποδοχή του δεν εγγυάται private προορισμό ([RFC 6762](https://www.rfc-editor.org/rfc/rfc6762.html)). Χρησιμοποίησε plain HTTP μόνο σε δίκτυο που εμπιστεύεσαι· σε μη έμπιστο Wi-Fi χρησιμοποίησε HTTPS ή κρυπτογραφημένο VPN.
- **Default στο app:** `https://127.0.0.1:8080/v1` (loopback HTTPS — χωρίς cleartext LAN default).
- **Εκτός σπιτιού:** Tailscale CGNAT cleartext HTTP επιτρέπεται μόνο για IPv4 διευθύνσεις μέσα στο `100.64.0.0/10` (`100.64.0.0` έως `100.127.255.255`, συμπεριλαμβανομένων των ορίων), π.χ. `http://100.100.0.1:8080/v1`. Οι αμέσως γειτονικές διευθύνσεις `100.63.255.255` και `100.128.0.0` απορρίπτονται. WireGuard μπορεί να χρησιμοποιήσει HTTP μόνο αν η διεύθυνσή του είναι επίσης σε επιτρεπόμενο private/LAN range· διαφορετικά χρησιμοποίησε HTTPS.

**ΠΟΤΕ** μην κάνεις port-forward Hermes στο δημόσιο internet χωρίς TLS.

### 1.3 Ρύθμιση στο R0lling
1. Άνοιξε R0lling → `Ρυθμίσεις` → `Πάροχος Τεχνητής Νοημοσύνης (AI)`.
2. Επίλεξε **`Hermes (Home PC)`**.
3. Εισάγετε URL (HTTPS ή allowlisted HTTP).
4. Εισάγετε Bearer Token → αποθηκεύεται στο **Keychain** (όχι UserDefaults).
5. Μην βάζεις userinfo (`user:password@`) ή query parameters στο Base URL. Το app τα απορρίπτει ώστε tokens/keys να μην καταλήγουν σε URL ή UserDefaults· βάλε το token στο πεδίο Keychain.
6. Πάτα `Αποθήκευση Ρυθμίσεων AI` (fail-closed αν το URL δεν περνάει allowlist ή περιέχει credentials/query).

---

## 2. Επιλογή Β — Άμεσο AI API (Direct Cloud API)

1. Επίλεξε **`Direct AI API`**.
2. **Base URL:** `https://api.openai.com/v1` (υποχρεωτικά **HTTPS**).
   Δεν επιτρέπονται credentials ή query parameters στο Base URL.
3. **Model Name:** `gpt-4o-mini` (ή `gpt-4o` για vision).
4. **API Key:** `sk-...` → Keychain.
5. Άδειο key → typed error **7004** πριν το network (R3-012).

---

## 3. Προστασία Προσωπικών Δεδομένων

- **Context scrubbing:** στο συνηθισμένο chat, όταν ενεργοποιηθεί το journal-context opt-in, το `AppState` δίνει στον router το τοπικά φορτωμένο journal snapshot και ο request builder επιλέγει τις νεότερες 0–5 εγγραφές του, ανεξάρτητα από την ημερομηνία που έχει επιλεγεί στο Today. Η σειρά στο prompt είναι χρονολογική και δεν γίνεται semantic relevance filtering. Η Agent memory έχει ξεχωριστό opt-in και τα κενά markdown headings δεν αποστέλλονται. Τα daily summaries εξακολουθούν να χρησιμοποιούν τις εγγραφές της σημερινής ημέρας· η ανάκληση χρησιμοποιεί τοπική αντιστοίχιση λέξεων-κλειδιών.
- **Vision on-demand:** Η τρέχουσα πραγματική διαδρομή είναι ρητή επιλογή εικόνας από Photos και περνά από JPEG sanitization πριν σταλεί στον ρυθμισμένο provider. Η multi-frame λήψη από rolling buffer και το `capturePhoto` σε πραγματικά γυαλιά παραμένουν μη διαθέσιμα, επειδή το Meta DAT session/frame bridge είναι stub. Το αποτέλεσμα αποθηκεύεται μόνο με ρητή επιλογή και μπορεί να εκφωνηθεί με TTS. Δεν υπάρχει continuous cloud stream.
- **Όριο σώματος αιτήματος:** Direct και Hermes απορρίπτουν το outbound JSON όταν ξεπερνά τα 10 MiB. Ο builder κάνει συντηρητικό preflight σε prompt, context, memory και image frames πριν δημιουργήσει τα message strings/JSON· ο HTTP client ελέγχει ξανά το τελικό body πριν ξεκινήσει URLSession. Η διαδρομή εικόνων περιορίζει επιπλέον τα συνολικά JPEG δεδομένα σε 7 MiB πριν την επέκταση Base64. Τα πολύ μεγάλα αιτήματα χρειάζονται μικρότερο κείμενο ή λιγότερα καρέ.
- **Error scrub (SEC-005):** user-facing μηνύματα = HTTP status μόνο · όχι raw body / tokens.
- **Retry/timeout:** bounded backoff για HTTP 408, 425, 429, 500, 502, 503 και 504 · `Task` cancellation υποστηρίζεται από UI «Άκυρο».

---

## 4. Verification limits

The code contains configurable Direct/Hermes connector paths and stores credentials in Keychain, but a configured source path is not production certification. The full R0lling XCTest suite, Apple build, and live provider request have not run for the current checkout. Focused Linux XCTest harnesses have run selected HTTP body-limit cases and AI request-builder/router cases with Foundation/provider shims; they do not verify Apple redirect behavior or a live provider. A Swift 6 strict-concurrency probe compiled the production Hermes endpoint validator and confirmed rejection of ambiguous numeric HTTP hosts; the local glibc resolver check showed `010.0.0.1` resolves as `8.0.0.1`, despite the old decimal parser reading it as `10.0.0.1`. `verification/ai_privacy_flow_probe.swift` compiled the production router/request-builder sources with narrow shims and verified default-off journal/memory opt-ins, newest-N selection, and location scrubbing/inclusion behavior. These probes do not validate Apple runtime or provider behavior. End-to-end validation still needs a real credential in Keychain and a reachable endpoint; verify TLS/allowlist behavior, cancellation, errors, opt-in context payloads, and image limits against a controlled endpoint before release.

The shared request builder locally redacts common email, mod-97-checksum-valid IBAN (including space- and hyphen-separated forms), Luhn-valid payment-card, US SSN, contextual Greek AFM, and phone patterns from provider-bound prompts, system text, Agent memory, journal content, opted-in locations, and vision prompt text. This is best-effort pattern matching: image pixels are not inspected, names and free-form addresses are not inferred, and complete PII removal is not guaranteed. Ordinary chat sends journal context and Agent memory only when their separate settings are enabled; explicit summary and recall actions send the selected journal entries for those requests. A local Hermes host is a network service, not an on-device model.
