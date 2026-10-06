import re
import sys
import os

def main():
    log_path = sys.argv[1] if len(sys.argv) > 1 else "swift-build.log"
    if not os.path.exists(log_path):
        print(f"::error::{log_path} not found.")
        return

    with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
        log = f.read()

    # Find compiler or test failure lines
    errors = re.findall(r"(/[^:\n]+):(\d+):(?:\d+:)?\s*error:\s*(.+)", log)
    test_fails = re.findall(r"Test Case '([^']+)' failed.*", log)
    
    # Find linker errors
    linker_errors = re.findall(r"(?:ld|clang|error):\s*(.+)", log)
    dup_symbols = re.findall(r"(duplicate symbol\s*.+)", log)

    for tf in test_fails:
        print(f"::error::Test failed: {tf}")
        print(f"[TEST FAILED] {tf}")

    for ds in dup_symbols:
        print(f"::error::Linker duplicate symbol: {ds}")
        print(f"[LINKER ERROR] {ds}")

    if errors:
        for fpath, lnum, msg in errors[:40]:
            print(f"::error file={fpath},line={lnum}::{msg}")
            print(f"[COMPILER ERROR] {os.path.basename(fpath)}:{lnum} -> {msg}")

    # Always print tail of log so nothing escapes visibility
    lines = [l.strip() for l in log.splitlines() if l.strip()]
    print(f"::error::--- Tail of {log_path} ---")
    for l in lines[-40:]:
        print(f"::error::{l}")

if __name__ == "__main__":
    main()
