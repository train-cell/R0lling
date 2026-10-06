# R0lling — Οδηγός Εγκατάστασης Meta Glasses Gen 2 (SETUP_META)

**Έργο:** `R0lling`  
**Συσκευές:** Meta Ray-Ban Glasses Gen 2 + iPhone  
**SDK:** Meta Wearables Device Access Toolkit (DAT) iOS SDK 1.0  
**Ημερομηνία:** 6 Οκτωβρίου 2026  

---

## 1. Προετοιμασία Λογαριασμού & Developer Mode

1. **Εγγραφή στο Meta Wearables Developer Center:**
   - Επισκεφθείτε το [developers.meta.com/wearables](https://developers.meta.com/wearables/).
   - Συνδεθείτε με τον Meta λογαριασμό που είναι συζευγμένος με τα γυαλιά σας στην εφαρμογή **Meta View**.
   - Δημιουργήστε ένα νέο App Project με όνομα `R0lling`.
   - Σημειώστε το `App ID` και το `Client Token`.
2. **Ενεργοποίηση Developer Mode στην Εφαρμογή Meta View:**
   - Ανοίξτε το **Meta View** στο iPhone.
   - Μεταβείτε στις `Ρυθμίσεις (Settings)` -> `Συσκευές (Devices)` -> `Πληροφορίες (About)`.
   - Πατήστε επανειλημμένα (7 φορές) πάνω στον αριθμό έκδοσης (Build Number) μέχρι να εμφανιστεί το μήνυμα `Developer Mode Enabled`.
   - Ενεργοποιήστε την επιλογή `Wireless Camera Streaming & Debugging`.

---

## 2. Άδειες & Bluetooth Pairing

1. **Εγκατάσταση R0lling στο iPhone:**
   - Κατά την πρώτη εκκίνηση, αποδεχθείτε τα αιτήματα αδειών:
     - `Bluetooth`: Απαιτείται για τον εντοπισμό και έλεγχο των γυαλιών.
     - `Local Network`: Για σύνδεση με το Home PC.
     - `Microphone`: Για φωνητικές εντολές και ήχο στα clips.
2. **Σύνδεση μέσα από το R0lling:**
   - Μεταβείτε στην καρτέλα `Ρυθμίσεις` ή πατήστε το εικονίδιο γυαλιών στην κεφαλίδα της οθόνης `Σήμερα`.
   - Πατήστε **`Σύνδεση Γυαλιών`**.
   - Η κατάσταση θα μεταβεί από `Searching` σε `Connected: Meta Ray-Ban Gen 2 (XX% Μπαταρία)`.

---

## 3. Δοκιμή Ζωντανής Ροής & Rolling Buffer

1. **Εκκίνηση Ροής:**
   - Πατήστε το badge των γυαλιών. Η κατάσταση γίνεται **`STREAMING (30 FPS)`** και ανάβει η κόκκινη ένδειξη **`LIVE`**.
   - Εμφανίζεται η μπάρα `Buffer: X.Xs διαθέσιμα`.
2. **Δοκιμή «Clip This»:**
   - Αφήστε τη ροή να τρέξει για τουλάχιστον 5–10 δευτερόλεπτα.
   - Πατήστε το κουμπί **`CLIP THIS (10s)`** ή πείτε «κράτα κλιπ» / «clip this».
   - Ακούγεται διακριτικό haptic feedback και εμφανίζεται μήνυμα επιτυχίας.
   - Στο timeline της ημέρας εμφανίζεται άμεσα το νέο clip με δυνατότητα άμεσης αναπαραγωγής!

---

## 4. Lifecycle Πολιτική & Περιορισμοί Background

- **Foreground (Εφαρμογή ανοιχτή):** Πλήρης ροή βίντεο 1080p @ 30fps, συνεχής ανανέωση του 10s ring buffer.
- **Background (Ελαχιστοποίηση εφαρμογής):** Το επίσημο Meta CameraAccess sample αναστέλλει τη συνεδρία ροής κατά την είσοδο στο background για προστασία της μπαταρίας. Το R0lling αποθηκεύει με ασφάλεια τα δείγματα μέχρι εκείνο το σημείο και θέτει την ένδειξη σε `PAUSED`.
- **Lock Screen (Κλειδωμένη οθόνη):** Η ροή διακόπτεται πλήρως. Μετά το ξεκλείδωμα, επανασυνδέεται αυτόματα εντός 1 δευτερολέπτου.
- **Simulation Fallback:** Σε περιβάλλον ανάπτυξης χωρίς τα φυσικά γυαλιά, ενεργοποιήστε το διακόπτη `Simulation Mode` στις Ρυθμίσεις για να παράγονται τεχνητά καρέ 30fps και να ελέγξετε όλη τη ροή clipping χωρίς hardware. Η ένδειξη συσκευής περιέχει ρητά `SIMULATION — όχι φυσική συσκευή`.

---

## 5. Mac → 100% Gen 2 path

Οδηγός flip από simulation σε πραγματικό DAT device: **[`docs/LANE_CLIP_META.md`](LANE_CLIP_META.md)** (SPM uncomment, `MetaDATStreamBridge` wire, A05 remux, A06/A07 matrix, acoustic/IMU flag flip).
