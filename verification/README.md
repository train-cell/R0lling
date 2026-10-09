# Verification boundaries

- `verify_all_subsystems.py`: independent Python examples. No Swift code is imported, compiled or executed.
- `verify_theme_apple_meta_compliance.py`: source/config token and plist-key presence. No UI rendering, permission exercise, or hardware compliance check.
- `audit_swift_codebase.py`: heuristic text/declaration scan. Not a compiler or concurrency checker.
- `diagnose_stage*` / `diagnose_journal_media_a01_a03.py`: archived substring/mirror diagnostics tied to earlier source shapes; retained as historical investigation aids, not current CI gates.
- `.github/workflows/swift-ci.yml`: separate macOS Swift build/tests and iOS host build. These jobs provide the actual build/test results when run for a specific revision.

A successful Python job does not establish Swift runtime behavior, feature coverage, Apple/Meta compliance, or rendered UI fidelity. Current remediation has not been executed through the Apple jobs. See `docs/FINDINGS_REMEDIATION.md`.
