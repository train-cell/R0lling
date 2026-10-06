# R0lling — Σχεδιαστικό Σύστημα (Design System: Discord × Twitch) v1.0

**Έργο:** `R0lling`  
**Στυλ:** Discord × Twitch Cyberpunk / Gaming Minimal  
**Ημερομηνία:** 6 Οκτωβρίου 2026  

---

## 1. Χρωματική Παλέτα & Tokens

```css
:root {
  /* Surface Tokens (Dark Mode Default) */
  --bg-primary: #16161D;        /* Πολύ σκούρο ανθρακί με ελαφριά μωβ απόχρωση */
  --bg-surface: #22232D;        /* Κάρτες και panels */
  --bg-elevated: #2C2D39;       /* Modals, Floating action bars, Dropdowns */
  --border-subtle: #373948;     /* Διακριτικά διαχωριστικά */

  /* Text & Contrast */
  --text-primary: #F4F4F8;      /* Καθαρό λευκό / υπόλευκο υψηλής αντίθεσης */
  --text-secondary: #B4B5C5;    /* Απαλό γκρι για ημερομηνίες / metadata */
  --text-muted: #7E8096;        /* Placeholders / disabled states */

  /* Brand Accents (Discord & Twitch Infused) */
  --accent-purple: #7742DC;     /* Βασικό χρώμα κουμπιών & επιλογής (Twitch vibe) */
  --accent-lavender: #A78BFA;   /* Highlights, chips, ενεργά tabs (Discord vibe) */
  --accent-glow: rgba(119, 66, 220, 0.35);

  /* Functional & Status Colors */
  --status-live: #FF4F64;       /* Pulser LIVE indicator για ενεργή ροή κάμερας */
  --status-success: #55D6A4;    /* Επιτυχής αποθήκευση, ολοκληρωμένο clip */
  --status-warning: #FFB347;    /* Χαμηλή μπαταρία, buffer που γεμίζει */
  --status-error: #FF6B7A;      /* Σφάλμα σύνδεσης ή αποτυχία AI */
}
```

---

## 2. Τυπογραφία & Ιεραρχία
- **Γραμματοσειρά:** System Font (`SF Pro Rounded` για τίτλους & ενδείξεις, `SF Pro Text` για σώμα κειμένου).
- **Μεγέθη & Βάρη:**
  - `Title Large`: 28pt, Bold (Κεφαλίδα Ημέρας, π.χ. "Τρίτη, 6 Οκτωβρίου")
  - `Title Medium`: 20pt, SemiBold (Όνομα Ενότητας, "Συνομιλία με Βοηθό")
  - `Body Regular`: 16pt, Regular (Περιεχόμενο σημείωσης / Timeline messages)
  - `Caption`: 13pt, Medium (Ώρα καταγραφής, tags, badges)
  - `Micro Tag`: 11pt, Bold, Monospaced (Buffer countdown, FPS, battery %)

---

## 3. Βασικά Components UI

### 3.1 Timeline Message Card (Discord Style)
- Συγκέντρωση των σημειώσεων της ημέρας σε μορφή ροής συζήτησης.
- Αριστερά: Ώρα και εικονίδιο προέλευσης (π.χ. 🕶️ Γυαλιά, 🎙️ Φωνή, ✍️ Χειροκίνητο, 🤖 AI).
- Δεξιά / Κύριο σώμα: Κείμενο με markdown support, chips ετικετών (tags), και media previews.

### 3.2 Media Thumbnail & Clip Card (Twitch Style)
- Προεπισκόπηση βίντεο/clip με σκοτεινό overlay.
- Επάνω δεξιά: Badge διάρκειας (`10.0s`, `5.0s`).
- Κέντρο: Ημιδιαφανές κουμπί Play (`▶`) με μωβ hover/press glow.
- Κάτω: Badge πηγής ("Meta Glasses Gen 2 • 1080p").

### 3.3 Bottom Action Composer & Floating Clip Bar
- Κάτω μπάρα εισαγωγής σημείωσης (text field + voice dictation button).
- Όταν η ροή της κάμερας είναι ενεργή (`isStreaming == true`):
  Εμφανίζεται υπερυψωμένη φωτεινή μπάρα:
  `[ 🔴 LIVE | Buffer: 10.0s ] — [ ✂️ CLIP THIS (10s) ]`
  με haptic feedback κατά το πάτημα (`UIImpactFeedbackGenerator(.heavy)`).

### 3.4 Προσβασιμότητα (Accessibility & a11y)
- Ελάχιστο touch target: 44pt x 44pt (όλα τα κουμπιά clip είναι τουλάχιστον 52pt).
- Dynamic Type support σε όλο το κείμενο.
- Πλήρης VoiceOver περιγραφή για κάθε κουμπί και ένδειξη κατάστασης.
