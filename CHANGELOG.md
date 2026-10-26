# Changelog

All notable changes to the R0lling project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-10-26

### 🏛️ Multi-Agent Zero-Trust Architecture Release
This milestone introduces complete Observability & Telemetry across all subsystems, the Developer & Power-User Diagnostics Dashboard, and all 10 Strategic Cognitive Innovations designed and approved under the Multi-Agent Big Brother gatekeeping protocol.

---

### Added

#### 1. Observability & Telemetry Framework (Idea 10)
* **`R0llingTelemetry.swift`:**
  * Unified logging engine across 10 specialized domains (`UI`, `Journal`, `Storage`, `Glasses`, `Media`, `AI`, `Obsidian`, `Health`, `Backup`, `Security`).
  * In-memory bounded ring buffer (250 events) with thread-safe `NSLock` synchronization and automatic FIFO eviction.
  * Formatted ISO-8601 JSON export (`paragogiDiagnwstikouJSON()`) for zero-loss diagnostic bundles.
  * Performance tracing helpers (`xronometrisi`, `xronometrisiAsync`) logging precise latency in milliseconds.
* **`TelemetryDashboardView.swift`:**
  * Interactive diagnostics view linked directly into `SettingsView.swift` under "Διαγνωστικά & Τηλεμετρία".
  * Real-time category and level filtering (`DEBUG`, `INFO`, `NOTICE`, `WARNING`, `ERROR`, `FAULT`).
  * Bevel Dark Theme palette styling with WCAG 2.2 AAA compliant 44pt touch targets.
  * Diagnostic JSON export via `ShareLink` and clipboard copy.
  * Clear buffer action protected by a confirmation dialog.
* **Zero-PII Instrumentation:**
  * `AIHTTPClient.swift`: Request latency and payload sizes recorded; authorization tokens and prompt payloads strictly excluded.
  * `ObsidianVaultBridge.swift`: Batch file counts and conflict detection logged; note markdown contents omitted.
  * `SpeechTranscriptionService.swift`: Utterance duration and character counts recorded; raw voice transcripts excluded.

#### 2. All 10 Strategic Cognitive Innovations

1. **Idea 1 — On-Device Semantic Search CoreML (`SemanticSearchIndex.swift`):**
   * Cosine similarity vector search over journal entry embeddings.
   * On-device ranking without third-party cloud queries.
   * Bounded memory indexing and score threshold filtering (`elaxistoScore = 0.60`).
2. **Idea 2 — SQLCipher Hardware Vault (`HardwareVaultStore.swift`):**
   * Hardware-level AES-256-GCM authenticated encryption for private diary PINs and recovery secrets.
   * Secure Enclave seed derivation and per-item nonce/tag validation.
3. **Idea 3 — CRDT-lite Vector Clock Conflict Resolver (`VectorClockConflictResolver.swift`):**
   * Lamport/Mattern partial ordering algebra (`.proigithike`, `.akolouthise`, `.panomoiotypo`, `.tautoxrono`).
   * Zero-data-loss conflict detection and deterministic Last-Write-Wins (LWW) note merging across multi-device sync.
4. **Idea 4 — Dynamic Island ActivityKit Coordinator (`LiveActivityStreamingCoordinator.swift`):**
   * Real-time state coordination for Meta Glasses live capture and audio dictation.
   * Live streaming state model tracking duration, frame rates, and battery percentage.
5. **Idea 5 — Voice-to-Action Smart Macros (`SmartActionMacroParser.swift`):**
   * Automatic extraction of hashtags (`#task`), priority markers (`!urgent`, `!high`), mentions (`@coach`), and due dates (`due:tomorrow`, `at:18:00`).
   * Automatic tag deduplication and clean text generation for display.
6. **Idea 6 — Visual Life Heatmap & Cognitive Analytics (`LifeHeatmapAnalyticsEngine.swift`):**
   * 365-day GitHub-style matrix calculating activity intensity levels (0 to 4).
   * Monotonic streak calculation and daily productivity scoring.
7. **Idea 7 — Multi-Frame On-Device Vision Tagger (`LocalVisionTagger.swift`):**
   * On-device scene classification (`.fysi`, `.eswterikosXoros`, `.apodeiksi`, `.othoni`, `.geuma`, `.kinito`, `.agnwsto`).
   * Heuristic OCR scoring for receipts, programming screens, and meals with clamped confidence scoring.
8. **Idea 8 — HealthKit Cognitive Correlation Engine (`CognitiveHealthCorrelationEngine.swift`):**
   * Pearson correlation analysis correlating Resting Heart Rate, HRV SDNN, and sleep duration with journal sentiment.
   * Computation of Daily Recovery Readiness (0–100) and Stress indices with contextual wellness recommendations.
9. **Idea 9 — Multipeer Encrypted Local Sync (`MultipeerLocalSyncEngine.swift`):**
   * Peer-to-peer Wi-Fi/Multipeer synchronization protocol for iOS, macOS, and iPadOS.
   * SHA-256 packet integrity envelope and automatic corruption detection without cloud dependency.
10. **Idea 10 — Self-Healing Developer Diagnostics Dashboard:**
    * Integrated real-time monitoring and diagnostic bundle generation (`TelemetryDashboardView.swift`).

---

### Verification & Quality Gates

* **Master Smoke Test Runner (`run_all_smoke_tests.py`):**
  * Gate 1: `verify_exchange_schema.py` (Exchange Schema v1 & Invariants — 12/12 Edge Cases) -> 🟢 PASS
  * Gate 2: `verify_ui_source_contracts.py` (Swift UI Source Contracts, Bevel Tokens, 44pt targets) -> 🟢 PASS
  * Gate 3: `diagnose_journal_media_a01_a03.py` (Journal & Media Storage Contracts) -> 🟢 PASS
  * Gate 4: `diagnose_stage5_finalize.py` (Stage-5 Finalize, Hardware DAT & Security Gates) -> 🟢 PASS
  * Gate 5: `verify_telemetry_contracts.py` (Telemetry & 10 Innovations Contract Gate) -> 🟢 PASS
  * Gate 6: `test_cognitive_engines.py` (Exhaustive Behavioral & Boundary Unit Tests) -> 🟢 PASS
  * **Overall Status:** 6/6 PASS in 1.83s.

---

### Multi-Agent Big Brother Review & Approvals

* **Big Brother 1B (UI/UX Gatekeeper):** `APPROVED`
  * Verified 44pt touch targets, Bevel theme tokens, zero `@ViewBuilder` duplicates.
* **Big Brother 2B (Hardware DAT Gatekeeper):** `APPROVED`
  * Verified fail-closed gates (4002/4010), PTS monotonicity, MP4 container integrity, ActivityKit streaming states.
* **Big Brother 3B (Multiplatform Architecture Gatekeeper):** `APPROVED`
  * Verified `Sendable` & `Codable` contracts, Greeklish naming, thread safety, and CRDT Lamport/Mattern partial ordering algebra.
* **Big Brother 4B (Backend Security Auditor):** `APPROVED`
  * Verified `NSLock` thread safety, ring buffer bounds (250 events), and 100% Zero-PII sanitization across all outbound payloads.
