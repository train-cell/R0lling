> Current status (2026-10-13): This is an outstanding acceptance checklist, not evidence that the current checkout passed. Registration/session and camera/frame source exists but is unbuilt; the live camera/media path stays gated. Historical harness results do not cover the latest styling or Apple runtime behavior. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md), [AUDIT_VERIFICATION.md](AUDIT_VERIFICATION.md), and the current [handoff](HANDOFF_R0lling_2026-10-12.md).

# R0lling — Πρωτόκολλο Δοκιμών Συσκευών (DEVICE_TESTS)

**Έργο:** `R0lling`  
**Συσκευές Στόχου:** iPhone 15/16 Pro (iOS 17.2+) & Meta Glasses Gen 2  
**Τελευταία ενημέρωση:** 13 Οκτωβρίου 2026 · DAT 1.0.1 registration/session and camera/frame source are unbuilt; live camera bridge remains gated.

---

## 1. Μητρώο Ελέγχου Φυσικών Συσκευών (Device Check Matrix)

| Έλεγχος | Περιγραφή Δοκιμής | Αναμενόμενο Αποτέλεσμα | Πραγματικό Αποτέλεσμα | Κατάσταση |
|---|---|---|---|---|
| **DEV-01: Apple build + full XCTest** | Σε Mac με Xcode 26.4+ / Swift 6.3+, resolve DAT 1.0.1, build package και iOS host, έπειτα εκτέλεσε το πλήρες XCTest target. | Επιτυχές package build, iOS host build και πλήρες test run. | Δεν εκτελέστηκε για το τρέχον checkout. Το ιστορικό Linux SwiftPM attempt σταμάτησε στην έλλειψη Apple `ImageIO` και δεν αποτελεί αποτέλεσμα για το checkpoint. | ⏳ Εκκρεμεί σε Mac |
| **DEV-02: Offline Journal** | Εγγραφή σημείωσης στο iPhone σε Airplane Mode. Επανεκκίνηση εφαρμογής. | Η σημείωση παραμένει αποθηκευμένη και εμφανίζεται στο `TodayView`. | Isolated Linux harness at the 2026-10-11 baseline: 14 Linux-applicable journal XCTest cases plus 1 legacy protocol compatibility case passed (15/15). Δεν επαληθεύτηκαν iPhone restart, offline app behavior ή iOS Data Protection. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-03: Meta registration + pairing** | Σε Developer Mode με εγκατεστημένο Meta AI app και συμβατό Gen 2, ενεργοποίησε `Σύνδεση Γυαλιών`, ολοκλήρωσε registration/callback και έλεγξε session state. | Επιτυχής registration/session με ακριβή UI state. Μην εμφανίσεις πραγματικό battery value χωρίς πραγματικό source. | Registration/DeviceSession source υπάρχει και χρησιμοποιεί το SDK device name/optional battery, αλλά δεν έχει γίνει Apple build, callback round-trip ή pairing. | ⏳ Εκκρεμεί σε Mac + Gen 2 |
| **DEV-04: Live camera streaming** | Μετά την in-app permission confirmation, ξεκίνα session, περίμενε `.started` και `.streaming`, έλεγξε callback queue/encoder timestamps και κάνε playable clip conversion. | Πραγματικά frames χωρίς σιωπηλή απώλεια· playable clip συμβατό με το buffer/remux contract· per-sample durations positive and consistent with adjacent PTS (last sample uses last observed interval); verified startup, teardown, resolution-change and overflow behavior. | Permission confirmation, publisher bridge, bounded queue, VideoToolbox conversion, and PTS-derived remux timing now have source but are unbuilt and unverified. Synthetic simulation is not live evidence. | ⏳ Εκκρεμεί Apple build + Gen 2 |
| **DEV-05: 10s Clip Trigger** | Πάτημα του κουμπιού `CAPTURE 10s` (`FloatingClipBar`) μετά από επαρκές warm-up· έλεγξε simulation και, ξεχωριστά όταν υπάρχει live feed, πραγματικό clip. | Playable output, σαφές simulation label για placeholder και σωστή captured duration. Το live clip πρέπει να προέρχεται από πραγματικά frames· επιβεβαίωσε ότι sample timing και διάρκεια συμφωνούν με τα captured PTS. | AVFoundation playability/runtime δεν ελέγχθηκαν. DAT camera/frame-to-H.264 source και PTS-derived remux timing υπάρχουν, αλλά το live gate παραμένει κλειστό και δεν υπάρχει Apple/device evidence. | ⏳ Εκκρεμεί σε Mac/Gen 2 |
| **DEV-05b: TZ day filter** | Δημιούργησε εγγραφή σε άλλη TZ (ή mock) και άλλαξε TZ συσκευής. | Εμφανίζεται στη σωστή `dateKey` ημέρα (R3-009). | Source/XCTest checks υπάρχουν· δεν εκτελέστηκαν. | ⏳ Εκκρεμεί σε Mac/iPhone |
| **DEV-05c: Empty AI key** | Σβήσε API key, στείλε chat. | Typed missing-key error πριν από network request. | Source guard υπάρχει· no-network behavior δεν δοκιμάστηκε. | ⏳ Εκκρεμεί σε Mac/iPhone |
| **DEV-06: Voice Wake & Note** | Εκφώνηση «σημείωσε να πάρω τηλέφωνο τη Μαρία». | Note αποθηκεύεται μία φορά από υποστηριζόμενο speech input. | Parser XCTest source υπάρχει· live speech/hardware test δεν έγινε. Hey Meta wake δεν υλοποιείται. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-07: Background / lock lifecycle** | Κατά streaming, βάλε την εφαρμογή background και κλείδωσε τη συσκευή· επέστρεψε foreground και δοκίμασε auto-resume. | Honest paused UI· stop της DAT camera/session στο background/lock· foreground resume με νέα session πριν επανασύνδεση camera· καμία υπόσχεση continuous background capture. | A07 adapter and camera teardown/re-attach now have source; Apple lifecycle and permission-handoff behavior remain unverified. | ⏳ Εκκρεμεί σε iPhone/Gen 2 |
| **DEV-08: Obsidian Vault Link** | Επιλογή φακέλου στο iOS Files και εξαγωγή. | Δημιουργία Markdown/attachment links χωρίς απώλεια υπάρχοντος vault. | XCTest source υπάρχει· Files provider/scoped access δεν δοκιμάστηκαν. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-09: Hermes Connection** | Σύνδεση με ελεγχόμενο endpoint μέσω LAN/VPN. | Επιτυχής απάντηση και σωστό payload/error policy. | Connector source/schema υπάρχουν· δεν έγινε live request. | ⏳ Εκκρεμεί σε endpoint |
| **DEV-10: Observation Game** | Έναρξη αποστολής, λήψη ή εισαγωγή φωτογραφίας, αξιολόγηση. | AI result, fail-closed errors, success-only streak. | Engine/XCTest source υπάρχει· actual provider/device run δεν έγινε. | ⏳ Εκκρεμεί σε Mac/iPhone |
| **DEV-11: B01 Acoustic trigger** | Μόνο σε εγκεκριμένο Developer Mode με πειραματικό camera-PCM capability, αναθεωρημένο microphone disclosure και live stream. Έλεγξε πραγματικά PCM→RMS επίπεδα και trigger behavior· επιβεβαίωσε ότι audio data δεν αποθηκεύεται ως clip media. | Trigger μόνο από πραγματικό sensor sample και υπάρχον threshold/action· καμία synthetic sample ή false “live” label. Η experimental capability δεν προορίζεται για production release. | PCM path, permission flow και sensor calibration δεν υπάρχουν· readiness παραμένει false. | 🚫 Εκκρεμεί implementation / approval / Gen 2 |
| **DEV-12: B02 Head gesture** | Μόνο με Developer Center approval για `MWDATMotion`: έλεγξε orientation mapping σε συσκευή, μεμονωμένο nod, double nod, φυσική κίνηση και cooldown. | Το mapping συμφωνεί με pitch contract και thresholds· δεν ενεργοποιείται από μία sustained κίνηση. Η experimental capability δεν προορίζεται για production release. | Motion module/feed δεν είναι linked ή wired· physical orientation και detector δεν ελέγχθηκαν· readiness παραμένει false. | 🚫 Εκκρεμεί implementation / approval / Gen 2 |
| **DEV-13: Microphone denied** | Στις Ρυθμίσεις iOS απενεργοποίησε το μικρόφωνο για το R0lling· πάτησε υπαγόρευση στο Today. Επανάλαβε με άδεια που δεν έχει ζητηθεί ακόμη. | Με άρνηση: toast «Σφάλμα μικροφώνου: Δεν υπάρχει άδεια μικροφώνου…» και η υπαγόρευση δεν ξεκινά. Χωρίς απόφαση: εμφανίζεται το system prompt. | Μόνο source αλλαγή (2026-10-13)· δεν έγινε build ή έλεγχος σε συσκευή. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-14: Host configuration** | Στο `Apps/R0llingApp` τρέξε `xcodegen generate` και `git status`· κάνε build και άνοιξε το `Info.plist` του παραγόμενου `.app`. | Το checked-in `Info.plist` μένει αμετάβλητο· το built plist περιέχει όλα τα `NS*UsageDescription`, το URL scheme, και `MWDAT > Analytics/CrashReporting > OptOut = true`. | Μόνο source αλλαγή (2026-10-13)· δεν έγινε build ή έλεγχος σε συσκευή. | ⏳ Εκκρεμεί σε Mac |
| **DEV-15: Voice note original audio** | Ενεργοποίησε «Αποθήκευση αρχικού ήχου (.m4a)» στις Ρυθμίσεις, υπαγόρευσε σημείωση και σταμάτησε· επανάλαβε με την επιλογή κλειστή και με εντολή «clip». | Με ενεργή επιλογή η σημείωση έχει ηχητικό συνημμένο που παίζει τη φωνή· κλειστή ή με εντολή clip δεν δημιουργείται ήχος· το κείμενο αποθηκεύεται πάντα. | Μόνο source αλλαγή (2026-10-13)· δεν έγινε build ή έλεγχος σε συσκευή. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-UI-01: Glasses primary control** | In Simulation Mode, start, stop, start again; background/lock to pause and tap to resume; activate VoiceOver and inspect action plus value. | A stopped stream remains connected and restarts; paused session can resume; connecting state prevents duplicate taps; no screen-reader announcement promises real camera data in simulation. | State-level XCTest/probe passed; AppState/SwiftUI/lifecycle interaction not rendered or exercised. | ⏳ Εκκρεμεί σε iPhone |
| **DEV-UI-02: Fitness calendar layout** | Render Fitness at 375pt, 320pt, XXL, and accessibility text sizes; inspect the 44pt day targets, selected-day initial scroll position, horizontal access to both month grids, weekday order, touch precision, and clipping. Compare the 375pt composition with `IMG_0486`. | Each day button has a 44pt cell; the selected date is visible on initial presentation/window refresh; both months remain reachable; selected-day details and chart remain usable. | Source uses 44pt cells at every text size and scrolls the two-month window horizontally on common phone widths. No build, rendered geometry, touch precision, or VoiceOver check has run. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-UI-03: Journal search ordering/accessibility** | In Archive, type a query that returns slowly, then quickly replace it with a different query; inspect and use search/clear with VoiceOver. | Only results for the latest query remain; VoiceOver identifies the search field, clear action, and active-search status in Greek. | Generation-gate probe passes and explicit source labels are present; async storage timing, layout, and VoiceOver still need Simulator/iPhone validation. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-UI-04: Sleep overnight metrics** | Open a sleep report with Health samples and select HR, HRV, RR, and SpO₂. Repeat with missing/denied channels and a HealthKit query failure; inspect chart labels and VoiceOver summary. | Only real measurements inside the primary sleep episode appear; normalized values have the expected units, larger gaps stay visually blank, absent channels show an empty state without interpolation, and a failed stage/vital query is disclosed separately from no samples. | Foundation aggregation tests passed 13/13 at the 2026-10-11 baseline; HealthKit query, layout, touch, and VoiceOver have not run on Apple hardware. | ⏳ Εκκρεμεί σε Mac/iPhone |
| **DEV-UI-05: Simulation camera affordance** | In Simulation Mode, open Observation Game. Inspect glasses camera action, photo picker, and manual confirmation. If a live SDK build is available, change the setting and revisit the screen. | Simulation explains and disables glasses capture; photo/manual alternatives remain usable. Published state follows the Settings change. | Source contract passes; AppState/SwiftUI rendered behavior is not exercised here. Live mode is not implemented in this build. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-UI-06: Bevel rendered comparison** | Σε Apple Simulator/device, αποτύπωσε Today, Health, Fitness, Sleep detail, Share artwork, dock και quick-action panel· σύγκρινε με `IMG_0478`–`IMG_0486` και `IMG_0490`. Έλεγξε narrow widths, Dynamic Type, VoiceOver, clipping και touch targets. | Κρατούνται R0lling content/actions/semantics, οι υπάρχουσες οθόνες προσεγγίζουν τα αντίστοιχα Bevel references και δεν υπάρχουν layout/accessibility regressions. | Δεν έγινε Apple rendering ή σύγκριση. Τα `IMG_0491`–`IMG_0497` δεν είναι Bevel targets. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-UI-07: Watermark export output** | Σε Apple build, εκτέλεσε landscape και portrait fixtures, άνοιξε το exported result και έλεγξε playback/overlay. | Playable output και ορατό watermark και στους δύο προσανατολισμούς· readiness επανεκτιμάται μόνο μετά από αυτή την απόδειξη. | Η Apple-only fixture/render check δεν εκτελέστηκε· readiness παραμένει false. | ⏳ Εκκρεμεί σε Mac/iPhone |
| **DEV-UI-08: Audio attachment control** | Άνοιξε ηχητικό συνημμένο στον media viewer με VoiceOver· πάτησε αναπαραγωγή και παύση. | Το κουμπί ανακοινώνεται «Αναπαραγωγή ήχου» και μετά «Παύση ήχου»· η αναπαραγωγή συμπεριφέρεται όπως πριν. | Μόνο source αλλαγή (2026-10-13)· δεν έγινε build ή VoiceOver έλεγχος. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-UI-09: First launch data** | Με υπάρχουσες σημερινές καταγραφές, τερμάτισε και ξανάνοιξε την εφαρμογή χωρίς να αλλάξεις ημερομηνία. | Οι καταγραφές εμφανίζονται μετά τη φόρτωση· το Assistant έχει έναν χαιρετισμό· οι αλλαγές σε Today/Assistant/Settings αφορούν το ίδιο state. | Μόνο source αλλαγή (2026-10-13)· δεν έγινε build ή έλεγχος σε συσκευή. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-UI-10: Podcast stop** | Στο Assistant πάτησε «🎙️ Podcast», έπειτα «Διακοπή Podcast» κατά την προετοιμασία και κατά την ομιλία· άφησε μια δεύτερη εκφώνηση να τελειώσει. Επανάλαβε με >5 καταγραφές την ημέρα. | Η ομιλία σταματά αμέσως και το κουμπί επανέρχεται· στο φυσικό τέλος επανέρχεται μόνο του· με >5 καταγραφές το toast αναφέρει «5 πιο πρόσφατες από τις N». | Μόνο source αλλαγή (2026-10-13)· δεν έγινε build ή έλεγχος σε συσκευή. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-UI-11: Selected-day summary/export** | Επίλεξε χθεσινή ημέρα στο Today· στο Assistant πάτησε «Σύνοψη ημέρας» και «🎨 Canvas». | Η σύνοψη έχει την ημερομηνία στον τίτλο και, με >5 καταγραφές, τη σημείωση κάλυψης· ο τίτλος του Canvas έχει την επιλεγμένη ημερομηνία. | Μόνο source αλλαγή (2026-10-13)· δεν έγινε build ή έλεγχος σε συσκευή. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-UI-12: Photos name and duration badge** | Εισήγαγε φωτογραφία και βίντεο >60s από Photos· άνοιξε τον media viewer. | Ο τίτλος δείχνει το όνομα αρχείου του Photos (όχι UUID)· το badge διάρκειας δείχνει mm:ss (π.χ. 01:15). | Μόνο source αλλαγή (2026-10-13)· δεν έγινε build ή έλεγχος σε συσκευή. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-UI-13: 5s buffer labels** | Στις Ρυθμίσεις επίλεξε buffer 5 δευτερολέπτων, ξεκίνα ροή προσομοίωσης και πάτησε το κουμπί clip· επανάλαβε με 10s. | Το κουμπί δείχνει «CAPTURE 5s» / «CAPTURE 10s», το viewfinder «/ 5.0s» / «/ 10.0s», και το clip δεν ξεπερνά τη ρύθμιση. | Μόνο source αλλαγή (2026-10-13)· δεν έγινε build ή έλεγχος σε συσκευή. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-UI-14: Clip audio badge and button height** | Κατέγραψε clip σε προσομοίωση· μέτρησε το ύψος του «CAPTURE» και έλεγξε την κάρτα του clip με VoiceOver. | Το κουμπί έχει ύψος τουλάχιστον 56pt· η κάρτα δείχνει «Χωρίς ήχο» και το VoiceOver το ανακοινώνει· εισαγόμενα βίντεο δεν το δείχνουν. | Μόνο source αλλαγή (2026-10-13)· δεν έγινε build ή έλεγχος σε συσκευή. | ⏳ Εκκρεμεί σε Simulator/iPhone |
| **DEV-OB-01: Dataview vault review** | Άνοιξε το query και το placeholder schema από `OBSIDIAN_DATAVIEW.md` σε πραγματικό Obsidian vault με ενεργό Dataview plugin, χωρίς synthetic journal entry. | Query/schema ταιριάζουν στο exported frontmatter και δεν αλλοιώνουν υπάρχοντα vault data. | Υπάρχουν source/docs μόνο· plugin/vault output δεν ελέγχθηκε. | ⏳ Εκκρεμεί σε Obsidian vault |

---

## 2. Οδηγίες Αναφοράς Σφαλμάτων (Device Bug Report Template)

Αν κατά τις δοκιμές στη φυσική συσκευή εντοπιστεί οποιαδήποτε δυσλειτουργία, χρησιμοποιήστε το παρακάτω πρότυπο (το εξωτερικό `06-GPT-Device-Fixes.md` δεν βρίσκεται στο repository):

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
> Proof artifact: πράσινο GHA log **ή** τοπικό `swift-test.log` → γραμμή στο τρέχον `docs/HANDOFF_R0lling_2026-10-12.md` και ενημέρωση του `docs/AUDIT_VERIFICATION.md`.

### 3.1 GitHub Actions (προτιμητέο)

| # | Βήμα | Πού | Done? |
|---|---|---|---|
| 1 | Άνοιξε το υπάρχον CI run ή ζήτησε εξουσιοδοτημένο run από GitHub Actions | GitHub → Actions | ☐ |
| 2 | Job `python-verify` = πράσινο (`verify_all_subsystems.py`, `verify_theme_apple_meta_compliance.py`, assistant-context, transcript-cue και UI source-contract guards) | Actions run | ☐ |
| 2b | Job `portable-harnesses` = πράσινο (Linux, container `swift:6.1`: 19 portable XCTest harnesses + focused/source probes) | Actions run | ☐ |
| 3 | Job `build-and-test` = πράσινο (`macos-26`, Xcode 26.4+: `swift build --build-tests` + `swift test`) | Actions run | ☐ |
| 4 | Κατέβασε artifact `swift-build-and-test-logs` (`swift-test.log` + `swift-build.log`) | Actions → Artifacts | ☐ |
| 5 | Επικόλλησε στο HANDOFF: `GHA run <URL> · swift test PASS · <timestamp>` | `docs/HANDOFF_R0lling_2026-10-12.md` | ☐ |
| 6 | Επιβεβαίωσε ότι `package-ios-app` ολοκληρώθηκε· απαιτεί επιτυχία των `build-and-test`, `portable-harnesses` και `python-verify`, και παράγει unsigned IPA artifact | Actions run / Artifacts | ☐ |
| 7 | (Optional) `AVAsset.isPlayable` smoke για placeholder clip — DEV-05 | Mac XCTest / device | ☐ |

> Ιστορικό (2026-10-13): τα hosted runs στα `b614db9` (38173016590) και `b29429b` (38415047820) απέτυχαν πριν από το `swift build`. Η διόρθωση workflow/guards/manifests είναι uncommitted και δεν έχει εκτελεστεί· βλ. [AUDIT_VERIFICATION.md](AUDIT_VERIFICATION.md).

Workflow file: `.github/workflows/swift-ci.yml`. The archived diagnose-stage scripts are not part of the current `python-verify` job.

### 3.2 Τοπικό Mac (εναλλακτικό)

| # | Βήμα | Εντολή / σημείωση | Done? |
|---|---|---|---|
| 1 | Clone + Xcode 26.4+ / Swift 6.3+ για DAT package | `cd R0lling` | ☐ |
| 2 | Build | `swift build` | ☐ |
| 3 | Tests | `swift test --parallel 2>&1 \| tee swift-test.log` | ☐ |
| 4 | App shell | `Apps/R0llingApp/README.md` (XcodeGen ή manual target) | ☐ |
| 5 | HANDOFF proof | ίδια γραμμή με 3.1 §5 | ☐ |

DAT flip (όχι SW blocker · v1 sim-only): `docs/LANE_CLIP_META.md` §3 + `docs/DECISIONS.md` §2.

---

## 4. Device A-ID checklist (0/16 proven — όχι SW)

Κάθε γραμμή DEV-* (DEV-01…DEV-15, DEV-UI-01…DEV-UI-14, DEV-OB-01) παραπάνω παραμένει ☐ μέχρι **πραγματικό** αποτέλεσμα στη στήλη «Πραγματικό Αποτέλεσμα».

Μην αλλάξεις σε ✅ χωρίς screenshot/log στο HANDOFF.
