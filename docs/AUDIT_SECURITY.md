# R0lling — Security Audit (Lane: Security)

**Ημερομηνία:** 6 Οκτωβρίου 2026  
**Workspace:** `C:\Users\skyd3\antigarvity\R0lling`  
**Skills:** `security_reviewer` · `security-guardian` · `security_scan`  
**Μέθοδος:** Static code review + targeted grep + Python re-verify R3-004 / R3-012  
**Scope:** Keychain vs UserDefaults · empty API-key guard · Obsidian/media path traversal · Mirror LAN server · WatchConnectivity · simulation flags · secrets in docs/tests · unsafe eval · credential logging  
**P0 code fixes αυτό το pass:** κανένα (δεν υπάρχει ανοιχτό CRITICAL με ασφαλή surgical fix· τα προηγούμενα R3-004/R3-012 παραμένουν κλειστά)

---

## Executive summary

| Κατάσταση | Πλήθος |
|---|---|
| CRITICAL (ανοιχτά) | **0** |
| HIGH (ανοιχτά) | **3** |
| MEDIUM (ανοιχτά) | **4** |
| LOW / INFO | **3** |
| Re-verify CLOSED | **R3-004**, **R3-012** (+ simulation gate R3-003 ως security-adjacent) |

Δεν εντοπίστηκαν hardcoded πραγματικά API keys/tokens. Δεν υπάρχει `eval`/`exec` σε Swift. Το threat model είναι κυρίως **local-first iOS app** (LAN mirror, Keychain, vault FS, WCSession) — όχι Telegram HMAC WebApp.

---

## Re-verify: προηγούμενα findings

### R3-004 — Keychain vs UserDefaults → **CLOSED (επιβεβαιωμένο)**

| Πεδίο | Τιμή |
|---|---|
| Severity (ιστορικό) | HIGH |
| Current status | **ΔΙΟΡΘΩΘΗΚΕ — δεν ισχύει πλέον** |
| Evidence | `Sources/R0lling/AI/KeychainSecretStore.swift` — `SecItemAdd` / `kSecClassGenericPassword` / `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| Evidence | `Sources/R0lling/AI/AIRouter.swift` — `retrieveSecret`/`storeSecret` → μόνο `KeychainSecretStore` |
| Evidence | UserDefaults fallback **μόνο** αν `R0LLING_ALLOW_USERDEFAULTS_SECRETS=1` |
| Proof | `diagnose_stage4_fixes.py` + static: `SecItemAdd`∈Keychain, `UserDefaults.standard.set(value`∉AIRouter |
| Residual risk | LOW — αν κάποιο Xcode scheme θέσει το env flag σε device build, secrets πέφτουν σε plaintext defaults |

### R3-012 — Empty API key / Hermes token guard → **CLOSED (επιβεβαιωμένο)**

| Πεδίο | Τιμή |
|---|---|
| Severity (ιστορικό) | MEDIUM |
| Current status | **ΔΙΟΡΘΩΘΗΚΕ — δεν ισχύει πλέον** |
| Evidence | `DirectAPIConnector.swift` L17–25: trim + empty → `NSError` code **7004** πριν network |
| Evidence | `HermesConnector.swift` L15–23: trim + empty → code **7104** πριν network |
| Evidence | Authorization χρησιμοποιεί `trimmedKey` / `trimmedToken` (όχι silent skip header) |
| Evidence | `Task.checkCancellation` πριν το request |
| Proof | `diagnose_stage5_finalize.py` `test_r3_012` patterns |
| Residual | Live credential test σε device εκκρεμεί (όχι security regression) |

### R3-003 — Simulation / fake-connected (security-adjacent) → **CLOSED**

| Πεδίο | Τιμή |
|---|---|
| Evidence | `MetaGlassesAdapter.swift`: χωρίς DAT SDK → `toggleSimulationMode(false)` αγνοείται· `connectDevice` non-sim → error **4002** |
| UI | `SettingsView.swift` αναγκάζει toggle πίσω σε simulation |

---

## Attack surface map

| Surface | Entry | Auth / trust | Notes |
|---|---|---|---|
| Direct AI HTTPS | `URLSession` + Bearer | Keychain secret | Empty-guard OK |
| Hermes LAN/VPN HTTP | `URLSession` + Bearer | Keychain + user URL | Cleartext by default |
| Mirror TCP :8443 + Bonjour | `NWListener` | **Καμία** | Frames όχι ακόμη wired |
| WatchConnectivity | `WCSession` messages | Apple pair trust | Clip/note actions |
| Obsidian vault FS | export / sidecar / attachments | Local sandbox | Path join από `relativePath` |
| Media / Backup restore | JSON `relativePath` | Trust journal/manifest | Path join χωρίς canonicalize |
| Settings UI | `SecureField` → Keychain | User | OK |
| Simulation glasses | synthetic frames | Local | Explicit labels |

---

## Findings (ανοιχτά)

### SEC-001 — Mirror server χωρίς TLS / auth / pairing

| Πεδίο | Τιμή |
|---|---|
| ID | **SEC-001** |
| Severity | **HIGH** (latent **CRITICAL** όταν συνδεθεί frame pipeline από glasses) |
| Sev code | P1 |
| Evidence | `Sources/R0lling/Buffer/RemoteMirrorStreamServer.swift` L48–72, L122–129 |
| Evidence | `NWParameters.tcp` χωρίς TLS· `handleIncomingConnection` δέχεται κάθε client· Bonjour `_r0lling-mirror._tcp` |
| Evidence | `AppState.toggleMirrorStreaming` L405–420 — ξεκινά listener· toast δηλώνει «χωρίς frame pipeline» |
| Impact | Οποιοσδήποτε στο ίδιο LAN μπορεί να συνδεθεί στο Bonjour service. Σήμερα: reconnaissance / idle DoS. Μόλις καλείται `broadcastFrame` από live glasses: **μη εξουσιοδοτημένη μετάδοση κάμερας**. |
| Fix | Document-only αυτό το pass. Προτεινόμενο: (1) shared pairing token / PIN πριν accept, (2) `NWProtocolTLS` ή τοπικό pre-shared key, (3) bind μόνο σε link-local / απαιτεί explicit user confirm, (4) μην κάνεις Bonjour advertise μέχρι auth handshake. |
| Status | **OPEN** |

### SEC-002 — Path traversal μέσω `relativePath` (Media / Backup / Obsidian)

| Πεδίο | Τιμή |
|---|---|
| ID | **SEC-002** |
| Severity | **HIGH** |
| Sev code | P1 |
| Evidence | `MediaStorageService.getMediaFileURL` L57–58: `baseMediaDirectory.appendingPathComponent(relativePath)` χωρίς reject `..` / absolute |
| Evidence | `BackupRestoreEngine.restoreFromBackupBundle` L88–95: αντιγραφή από/προς path από untrusted manifest `attachment.relativePath` |
| Evidence | `ObsidianVaultBridge.exportEntry` L107–114: `attachmentsDir.appendingPathComponent(attachment.relativePath)` |
| Impact | Κακόβουλο `manifest.json` / tampered `journal_v1.json` μπορεί να γράψει/διαβάσει εκτός Media root εντός app container (overwrite journal, Agent markdown, άλλα app files). iOS sandbox περιορίζει έξοδο από container — όχι πλήρες device RCE. |
| Fix | Document-only. Προτεινόμενο helper `asfalhs_relative_media_path(_:base:)` — reject `..`, absolute, null bytes· `resolvingSymlinksInPath` + `standardizedFileURL` + `hasPrefix(base.path + "/")`. Εφαρμογή σε get/delete/restore/export. |
| Status | **OPEN** |

### SEC-003 — WatchConnectivity: μη επικυρωμένα remote actions / unbounded note

| Πεδίο | Τιμή |
|---|---|
| ID | **SEC-003** |
| Severity | **HIGH** (σε compromised/paired Watch ή buggy companion) · πρακτικά **MEDIUM** χωρίς Watch app target |
| Sev code | P1/P2 |
| Evidence | `WatchConnectivityCoordinator.swift` L50–59: `triggerClip` / `saveNote` χωρίς schema version, χωρίς max length στο `text`, χωρίς confirmation |
| Evidence | Docs: δεν υπάρχει Watch app target ακόμη (`GEMINI_AUDIT.md`) |
| Impact | Remote clip trigger ή injection μεγάλου note στο journal από οποιοδήποτε μήνυμα WCSession (trusted channel = paired Apple ID devices). DoS αποθήκευσης / ανεπιθύμητα clips. |
| Fix | Max length (π.χ. 2KB), allowlist actions + `schemaVersion`, optional user confirm για clip από watch. |
| Status | **OPEN** (latent έως Watch target) |

### SEC-004 — Hermes cleartext HTTP + default LAN IP

| Πεδίο | Τιμή |
|---|---|
| ID | **SEC-004** |
| Severity | **MEDIUM** |
| Sev code | P2 |
| Evidence | `Models.swift` L200 default `http://192.168.1.50:8080/v1` |
| Evidence | `SettingsView.swift` L12 ίδιο default· `HermesConnector` στέλνει Bearer πάνω από HTTP |
| Evidence | `docs/SETUP_AI_HERMES.md` — `--host 0.0.0.0` παράδειγμα |
| Impact | Token sniffable στο LAN· gateway bound σε όλες τις interfaces αυξάνει exposure. ATS exception θα απαιτηθεί σε πραγματικό app target (δεν υπάρχει Info.plist στο SPM package). |
| Fix | Προτροπή HTTPS/Tailscale· default URL κενό· docs: bind `127.0.0.1` ή Tailscale IP, όχι `0.0.0.0` χωρίς firewall. |
| Status | **OPEN** |

### SEC-005 — AI error bodies επιστρέφουν raw HTTP response στο UI

| Πεδίο | Τιμή |
|---|---|
| ID | **SEC-005** |
| Severity | **MEDIUM** |
| Sev code | P2 |
| Evidence | `DirectAPIConnector.swift` L80–82: `errorText` από response body μέσα σε `NSLocalizedDescriptionKey` |
| Evidence | `HermesConnector.swift` L73–75 παρόμοια (στη συνέχεια τυλίγεται σε 7103) |
| Impact | Providers μερικές φορές echo-άρουν headers/keys στο error JSON· το κείμενο μπορεί να φανεί σε toast/UI. |
| Fix | Generic user-facing message· log μόνο status code / truncated sanitized body εσωτερικά. |
| Status | **OPEN** |

### SEC-006 — Hermes `catch` καταπίνει typed errors (incl. πιθανό information loss)

| Πεδίο | Τιμή |
|---|---|
| ID | **SEC-006** |
| Severity | **MEDIUM** (reliability / secondary security) |
| Sev code | P2 |
| Evidence | `HermesConnector.swift` L69–93: κάθε error μέσα στο `do` (συμπ. 7102 HTTP reject) ξαναρίχνεται ως **7103** generic |
| Impact | Απόκρυψη auth failure vs network· δυσκολεύει detection brute/misconfig· όχι άμεσο leak credentials. |
| Fix | `catch let e as NSError where e.domain == "R0lling.Hermes"` rethrow· ξεχωριστά `CancellationError`· μόνο transport → 7103. |
| Status | **OPEN** |

### SEC-007 — Settings: Base URL χωρίς scheme/host allowlist

| Πεδίο | Τιμή |
|---|---|
| ID | **SEC-007** |
| Severity | **MEDIUM** |
| Sev code | P2 |
| Evidence | `SettingsView.swift` L85–90 ελεύθερο `TextField` URL· `DirectAPIConnector` L27 `"\(baseURLString)/chat/completions"` |
| Impact | SSRF-like προς εσωτερικά LAN hosts από τη συσκευή του χρήστη (self-SSRF / mistype)· credential στέλνεται στο λανθασμένο host. |
| Fix | Validate `https://` για Direct· για Hermes επιτρέπεται `http://` μόνο σε private ranges + user warning. |
| Status | **OPEN** |

### SEC-008 — Docs placeholders / gateway bind guidance

| Πεδίο | Τιμή |
|---|---|
| ID | **SEC-008** |
| Severity | **LOW** |
| Sev code | P3 |
| Evidence | `docs/SETUP_AI_HERMES.md` — `YOUR_SECRET_HERMES_TOKEN`, `sk-...`, `--host 0.0.0.0` |
| Impact | Όχι πραγματικό secret leak· παράδειγμα `0.0.0.0` ενθαρρύνει υπερ-έκθεση Hermes. |
| Fix | Docs: bind Tailscale/loopback· σαφές «μην commit πραγματικά keys». |
| Status | **OPEN** (docs) |

### SEC-009 — `print` diagnostics (χωρίς secrets σήμερα)

| Πεδίο | Τιμή |
|---|---|
| ID | **SEC-009** |
| Severity | **LOW** |
| Sev code | P3 |
| Evidence | `ObsidianVaultBridge` conflict print· `RemoteMirror` failed print· `MetaGlassesAdapter` sim print· `JSONFileStorageService` load error |
| Impact | Δεν βρέθηκε logging Bearer/apiKey. Κίνδυνος μελλοντικής διαρροής αν προστεθεί debug dump request. |
| Fix | `os.Logger` + ποτέ Authorization/body με secrets. |
| Status | **OPEN** (hygiene) |

### SEC-010 — UserDefaults για non-secret game state (OK)

| Πεδίο | Τιμή |
|---|---|
| ID | **SEC-010** |
| Severity | **INFO** |
| Evidence | `ScavengerHuntStreakManager.swift` — streak data σε UserDefaults |
| Impact | Καμία· δεν είναι credentials. |
| Status | **OK / no action** |

---

## Negative checks (καθαρά)

| Έλεγχος | Αποτέλεσμα |
|---|---|
| Hardcoded `sk-…` / `ghp_` / πραγματικά tokens | **Δεν βρέθηκαν** (μόνο placeholders docs) |
| `eval` / `exec` / `pickle` σε Swift | **Δεν βρέθηκαν** |
| Python `subprocess` | Μόνο `diagnose_stage3` → καλεί stage4 με fixed argv (όχι user shell) |
| Secrets σε Tests | Temp dirs / synthetic data — **OK** |
| Keychain accessibility | `AfterFirstUnlockThisDeviceOnly` — λογικό για background AI· όχι sync σε άλλα devices |

---

## Severity matrix & προτεραιότητα

| Priority | IDs | Ενέργεια |
|---|---|---|
| P0 CRITICAL | — | Καμία ανοιχτή· **δεν** εφαρμόστηκε code fix |
| P1 HIGH | SEC-001, SEC-002, SEC-003 | Mirror auth πριν frame wire· path canonicalize· WCSession schema |
| P2 MEDIUM | SEC-004…007 | Hermes TLS/bind· sanitize errors· URL allowlist |
| P3 LOW | SEC-008, SEC-009 | Docs + logging hygiene |

---

## Proposed surgical patches (όχι εφαρμοσμένα)

1. **Path guard (SEC-002)** — single helper στο `MediaStorageService` + χρήση από Backup/Obsidian.  
2. **Mirror token (SEC-001)** — πρώτο μήνυμα client πρέπει να είναι `AUTH <token>` από Keychain πριν προστεθεί στα `activeConnections`.  
3. **Error scrub (SEC-005)** — μην περνάς raw `String(data: data)` στο `NSLocalizedDescriptionKey`.

---

## Verification commands (επαναλήψιμα)

```text
# R3-004 / R3-012 regression
python verification/diagnose_stage4_fixes.py
python verification/diagnose_stage5_finalize.py

# Secret / eval scan
rg -i "sk-[a-zA-Z0-9]{10,}|ghp_|xoxb-|api_key\s*=\s*['\"][^'\"]+" --glob "*.{swift,md,py,json}"
rg "eval\(|exec\(|pickle" --glob "*.{swift,py}"
rg "UserDefaults.standard\.(set|string)" Sources/R0lling/AI
rg "SecItemAdd|7004|7104" Sources/R0lling/AI
```

---

## Verdict

**Security lane: PASS για P0 credentials (Keychain + empty-key).**  
**FAIL/OPEN για LAN Mirror auth και path traversal hardening** — τεκμηριωμένα ως HIGH, χωρίς CRITICAL live exploit στο τρέχον wiring (mirror χωρίς frames· path χρειάζεται malicious journal/backup).

**Deliverable path:** `docs/AUDIT_SECURITY.md`  
**Git:** χωρίς commit (όπως ζητήθηκε).
