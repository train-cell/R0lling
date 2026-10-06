# R0lling — Local-First Journal & Meta Glasses Hub for iPhone

[![Platform](https://img.shields.io/badge/Platform-iOS%2017.2%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Meta DAT SDK](https://img.shields.io/badge/Meta%20DAT%20SDK-1.0-purple.svg)](https://developers.meta.com/wearables/)
[![Design](https://img.shields.io/badge/Design-Discord%20%C3%97%20Twitch-7742DC.svg)]()

> **R0lling** (με μηδέν αντί για «o»): Προσωπικό, local-first ημερολόγιο και hub για iPhone, συνδεδεμένο με τα **Meta Glasses Gen 2**. Διαθέτει κυλιόμενο προσωρινό buffer 5–10 δευτερολέπτων για αναδρομικό clipping («clip this»), φωνητικές σημειώσεις («note this»), συγχρονισμό Markdown στο Obsidian, και διπλή διασύνδεση AI (Hermes Gateway στο Home PC ή απευθείας OpenAI-compatible API).

---

## 1. Βασικά Χαρακτηριστικά (Core Features)

1. **Daily Journal & Media Timeline:** Καταγραφές ανά ημέρα σε ευανάγνωστη ροή μηνυμάτων τύπου Discord. Υποστήριξη κειμένου, φωτογραφιών, βίντεο, ηχητικών και clips.
2. **5–10s Rolling Buffer & Instant Replay:** Προσωρινός buffer HEVC/H.264 καρέ στη μνήμη RAM (~10-15MB). Με ένα πάτημα του κουμπιού `Clip 10s` ή τη φωνητική εντολή, αποθηκεύεται άμεσα το απόσπασμα των προηγούμενων δευτερολέπτων.
3. **Voice Command Parser:** Αναγνώριση εντολών στα Ελληνικά και Αγγλικά (`clip this`, `κράτα κλιπ`, `note this: ...`, `σημείωσε ...`, `what am I seeing?`).
4. **Obsidian Vault Bridge:** Αυτόματη παραγωγή αρχείων `YYYY/MM/YYYY-MM-DD.md` με σχετικούς συνδέσμους πολυμέσων. Ανίχνευση εξωτερικών αλλαγών μέσω SHA256 hashes χωρίς απώλεια δεδομένων.
5. **Agent Memory Folder:** Διαχείριση των αρχείων `Agent/Memory.md`, `Agent/Preferences.md`, `Agent/Open-loops.md` με πλήρη έλεγχο και έγκριση από τον χρήστη.
6. **Διπλό AI Interface:**
   - **Hermes Agent:** Προσωπικός βοηθός τύπου Jarvis στο οικιακό PC (μέσω LAN / WireGuard / Tailscale VPN).
   - **Direct AI API:** Απευθείας κλήσεις σε OpenAI-compatible endpoints (π.χ. GPT-4o, Gemini Flash) με υποστήριξη Vision.
7. **«What am I seeing?» & Παιχνίδι Παρατήρησης:** Λήψη ενός καρέ από τα γυαλιά κατόπιν αιτήματος και αξιολόγηση από Vision AI (π.χ. αποστολή «Βρες κάτι κόκκινο»).
8. **Offline-First & Sandbox:** Όλα τα δεδομένα ζουν τοπικά στη συσκευή.

---

## 2. Οδηγίες Εγκατάστασης & Build (Mac / Xcode)

### Απαιτήσεις
- **macOS:** Sonoma 14.4+ ή Sequoia 15.0+
- **Xcode:** 16.0+ (με Swift 6 support)
- **Συσκευή δοκιμών:** iPhone με iOS 17.2+
- **Meta Developer Account:** Ενεργοποιημένο Developer Mode στην εφαρμογή Meta View.

### Βήματα
1. **Κλωνοποίηση / Άνοιγμα Project:**
   ```bash
   cd R0lling
   open Package.swift
   # Ή δημιουργία Xcode Project μέσω File -> New -> Project -> iOS App και προσθήκη του R0lling SPM package
   ```
2. **Signing & Team:**
   - Επιλέξτε το App Target στο Xcode.
   - Μεταβείτε στην καρτέλα `Signing & Capabilities`.
   - Επιλέξτε το δικό σας Personal Development Team.
   - Ορίστε μοναδικό Bundle Identifier (π.χ. `com.personal.r0lling`).
3. **Meta DAT SDK:**
   - Προσθέστε το πακέτο SPM: `https://github.com/facebook/meta-wearables-dat-ios.git` (έκδοση `1.0.0+`).
4. **Εκτέλεση:**
   - Επιλέξτε το φυσικό iPhone ή τον iOS Simulator και πατήστε **`Cmd + R`**.
   - Στον Simulator, ενεργοποιήστε το διακόπτη `Simulation Mode` στις Ρυθμίσεις για δοκιμή χωρίς φυσικά γυαλιά.

---

## 3. Δομή Φακέλων Έργου

```text
R0lling/
├── Package.swift
├── Sources/R0lling/
│   ├── App/          # R0llingApp, AppState coordinator
│   ├── Core/         # Domain Models, Extensions, Schema
│   ├── Persistence/  # JSONFileStorageService, MediaStorage, BackupRestore
│   ├── Buffer/       # RollingBufferService, Keyframe alignment, MP4 muxing
│   ├── Glasses/      # MetaGlassesAdapter, Simulation provider
│   ├── Speech/       # VoiceCommandParser, SpeechTranscriptionService
│   ├── Obsidian/     # ObsidianVaultBridge, AgentFolderManager
│   ├── AI/           # AIRouter, DirectAPIConnector, HermesConnector
│   ├── Game/         # ObservationGameEngine, Missions
│   └── UI/           # Theme, Components, Today, Calendar, Assistant, Settings
├── Tests/R0llingTests/
│   ├── JournalStorageTests.swift
│   ├── RollingBufferTests.swift
│   ├── VoiceCommandParserTests.swift
│   ├── ObsidianBridgeTests.swift
│   └── BackupRestoreTests.swift
├── verification/     # Αυτόνομο verification suite για έλεγχο σε Windows/CI
└── docs/             # Τεχνική τεκμηρίωση, αρχιτεκτονική, οδηγοί setup
```

---

## 4. Επαλήθευση & Test Evidence
Στο παρόν Windows workspace, όλα τα υποσυστήματα ελέγχονται αυτόνομα μέσω του `verification/verify_all_subsystems.py`:
```bash
python verification/verify_all_subsystems.py
# Αποτέλεσμα: 100% PASS σε Serialization, Buffer Math, Voice Parser, Markdown & Backup!
```
