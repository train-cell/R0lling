import re
import sys
import os

def main():
    log_path = "swift-build.log"
    if not os.path.exists(log_path):
        print("::error::swift-build.log not found.")
        return

    with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
        log = f.read()

    # Find compiler error lines: path/to/File.swift:123:45: error: message
    errors = re.findall(r"(/[^:\n]+):(\d+):(?:\d+:)?\s*error:\s*(.+)", log)
    if errors:
        for fpath, lnum, msg in errors[:40]:
            # Print GitHub Actions error annotation
            print(f"::error file={fpath},line={lnum}::{msg}")
            # Also print to stdout
            print(f"[COMPILER ERROR] {os.path.basename(fpath)}:{lnum} -> {msg}")
    else:
        print("::error::Swift build failed with unparsed error. Tail of log:")
        lines = [l.strip() for l in log.splitlines() if l.strip()]
        for l in lines[-35:]:
            print(f"::error::{l}")

if __name__ == "__main__":
    main()
