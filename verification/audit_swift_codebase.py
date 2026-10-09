#!/usr/bin/env python3
"""Heuristic source scan, not a Swift parser/type checker.
Counts declarations and checks selected text/delimiters/theme tokens.
Does not validate imports, runtime behavior or Swift 6 concurrency.
"""

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def audit():
    swift_files = list(ROOT.glob("Sources/**/*.swift")) + list(ROOT.glob("Tests/**/*.swift"))
    print(f"Total Swift files to audit: {len(swift_files)}")
    
    # 1. Bracket balancing & syntax check
    syntax_errors = []
    declared_types = set()
    used_types = set()
    
    for f in swift_files:
        content = f.read_text(encoding="utf-8")
        rel = f.relative_to(ROOT)
        
        # Check balanced braces
        stack = []
        in_string = False
        in_multiline_comment = False
        lines = content.splitlines()
        
        for l_idx, line in enumerate(lines, 1):
            i = 0
            while i < len(line):
                # multi-line comment check
                if not in_string:
                    if not in_multiline_comment and line[i:i+2] == "/*":
                        in_multiline_comment = True
                        i += 2
                        continue
                    elif in_multiline_comment and line[i:i+2] == "*/":
                        in_multiline_comment = False
                        i += 2
                        continue
                    elif in_multiline_comment:
                        i += 1
                        continue
                    elif line[i:i+2] == "//":
                        break
                
                char = line[i]
                if char == '"':
                    # A quote is escaped only when preceded by an odd-length
                    # run of backslashes (e.g. Swift's "\\" separator).
                    backslash_count = 0
                    backslash_index = i - 1
                    while backslash_index >= 0 and line[backslash_index] == "\\":
                        backslash_count += 1
                        backslash_index -= 1
                    if backslash_count % 2 == 0:
                        in_string = not in_string
                elif not in_string and not in_multiline_comment:
                    if char in "{[(":
                        stack.append((char, l_idx, char))
                    elif char in "}])":
                        if not stack:
                            syntax_errors.append(f"{rel}:{l_idx}: Unmatched closing '{char}'")
                        else:
                            last, open_l, _ = stack.pop()
                            expected = {'{': '}', '[': ']', '(': ')'}[last]
                            if char != expected:
                                syntax_errors.append(f"{rel}:{l_idx}: Mismatched '{char}', expected '{expected}' (opened line {open_l})")
                i += 1

        if stack:
            last, open_l, char = stack[-1]
            syntax_errors.append(f"{rel}:{open_l}: Unclosed delimiter '{char}' at EOF")
            
        # Collect type declarations
        for match in re.finditer(r'\b(?:struct|class|enum|actor|protocol)\s+([A-Za-z0-9_]+)', content):
            declared_types.add(match.group(1))

    print(f"Total declared Swift types across codebase: {len(declared_types)}")
    if syntax_errors:
        print(f"Found {len(syntax_errors)} syntax/bracket errors:")
        for err in syntax_errors[:20]:
            print("  ", err)
    else:
        print("  [OK] 100% Balanced delimiters across all Swift files.")

    # 2. Check for missing views specifically in UI files
    missing_type_refs = []
    for f in ROOT.glob("Sources/R0lling/UI/**/*.swift"):
        content = f.read_text(encoding="utf-8")
        rel = f.relative_to(ROOT)
        # Look for TypeName( or TypeName() or TypeName {
        for match in re.finditer(r'\b([A-Z][a-zA-Z0-9]+CardView|[A-Z][a-zA-Z0-9]+Sheet|[A-Z][a-zA-Z0-9]+Banner|[A-Z][a-zA-Z0-9]+Row)\b', content):
            t_name = match.group(1)
            if t_name not in declared_types and not t_name.startswith("NS") and not t_name.startswith("UI"):
                missing_type_refs.append((str(rel), t_name))

    if missing_type_refs:
        print(f"Missing UI view declarations detected ({len(missing_type_refs)}):")
        for file_p, t in set(missing_type_refs):
            print(f"  {file_p} references undeclared type '{t}'")
    else:
        print("  [OK] All UI card/sheet/banner types are declared.")

    return len(syntax_errors) == 0 and len(missing_type_refs) == 0

if __name__ == "__main__":
    success = audit()
    sys.exit(0 if success else 1)
