# R0lling — Εξαρτήσεις & Toolchain (Dependencies & Toolchain) v1.0

**Έργο:** `R0lling`  
**Ημερομηνία:** 6 Οκτωβρίου 2026  

---

## 1. Toolchain & Ελάχιστες Απαιτήσεις

| Εργαλείο / Πλατφόρμα | Ελάχιστη Έκδοση | Προτεινόμενη Έκδοση | Σημειώσεις |
|---|---|---|---|
| **macOS (για Build/Sign)** | macOS 14.4 Sonoma | macOS 15.0+ Sequoia | Απαιτείται για Xcode και Apple Developer Signing. |
| **Xcode** | Xcode 16.0 | Xcode 16.2 / 26.4+ | Swift 6 strict concurrency mode υποστήριξη. |
| **iOS Deployment Target** | iOS 17.2 | iOS 18.0+ | Υποστήριξη SwiftData / Modern AVFoundation APIs. |
| **Swift Toolchain** | Swift 6.0 | Swift 6.0+ | Strict Concurrency checks (`Sendable`). |

---

## 2. Επίσημες Εξαρτήσεις (Dependencies)

### 2.1 Meta Wearables Device Access Toolkit (DAT) SDK
- **URL Αποθετηρίου:** `https://github.com/facebook/meta-wearables-dat-ios.git`
- **Εκδοχή (Tag/Branch):** `1.0.0` (ή νεότερη συμβατή έκδοση)
- **Χρήση:** Σύνδεση με Meta Glasses Gen 2, λήψη compressed video streams και έλεγχος session.
- **Fallbacks:** `MetaGlassesAdapterMock` και ενσωματωμένος προσομοιωτής για δοκιμές σε περιβάλλον χωρίς φυσική συσκευή.

### 2.2 Ενσωματωμένα iOS Frameworks (Zero 3rd-Party Bloat)
Για μέγιστη σταθερότητα, ασφάλεια και απόλυτη ταχύτητα, το R0lling χρησιμοποιεί αποκλειστικά τα επίσημα frameworks της Apple για τις βασικές λειτουργίες του:
- **`AVFoundation`**: Διαχείριση καμερών, συμπίεση H.264/HEVC, εγγραφή MP4 (`AVAssetWriter`), αναπαραγωγή ήχου/βίντεο.
- **`Speech` & `AVFAudio`**: Τοπική μετατροπή ομιλίας σε κείμενο (on-device speech recognition) με υποστήριξη Ελληνικών και Αγγλικών.
- **`SwiftData` / `CoreData` / `SQLite3`**: Τοπική βάση δεδομένων με schema versioning και migrations.
- **`Security` (Keychain)**: Ασφαλής αποθήκευση API keys για το OpenAI και το Hermes token.
- **`UniformTypeIdentifiers` & `UIKit`**: Ασφαλής επιλογή φακέλων Obsidian με security-scoped bookmarks.

---

## 3. Άδειες Χρήστη (Info.plist Permissions)

1. `NSCameraUsageDescription`: "Το R0lling χρησιμοποιεί την κάμερα για λήψη φωτογραφιών, παιχνίδια παρατήρησης και σύνδεση με τα γυαλιά."
2. `NSMicrophoneUsageDescription`: "Το R0lling χρησιμοποιεί το μικρόφωνο για φωνητικές σημειώσεις («note this») και συγχρονισμό ήχου στα clips."
3. `NSSpeechRecognitionUsageDescription`: "Το R0lling μετατρέπει τη φωνή σας σε κείμενο για αυτόματη καταγραφή στο ημερολόγιο."
4. `NSBluetoothAlwaysUsageDescription`: "Το R0lling συνδέεται ασύρματα με τα Meta Glasses Gen 2 μέσω Bluetooth."
5. `NSLocalNetworkUsageDescription`: "Το R0lling συνδέεται με τον τοπικό βοηθό Hermes στο οικιακό σας δίκτυο (Home PC)."
