#!/usr/bin/env python
# patch_phase1_v8.2.py
# Fix: COA stepper does not advance to stage 7 (Ready for TB) after successful approve.
# Root cause: _submitCoa sets currentStage = 5, but stage 7 = index 6.

import re
import sys
from pathlib import Path

TARGETS = [
    Path(r"C:\apex_app\apex_finance\lib\screens\extracted\coa_screens.dart"),
    Path(r"C:\apex_app\apex_finance\lib\screens\extracted\coa_upload_screen.dart"),
]

PATTERNS = [
    # Match either `_currentStage = 5` or `currentStage = 5` after success
    (re.compile(r"(_?currentStage\s*=\s*)5(\s*;)"), r"\g<1>6\g<2>"),
]

total_changes = 0
for target in TARGETS:
    if not target.exists():
        print(f"SKIP (not found): {target}")
        continue
    src = target.read_text(encoding="utf-8")
    new = src
    file_changes = 0
    for pat, repl in PATTERNS:
        new, n = pat.subn(repl, new)
        file_changes += n
    if file_changes:
        target.write_text(new, encoding="utf-8")
        print(f"PATCHED ({file_changes} changes): {target}")
        total_changes += file_changes
    else:
        print(f"NO MATCH: {target}")

print(f"\nTOTAL CHANGES: {total_changes}")

# Verify
for target in TARGETS:
    if not target.exists():
        continue
    txt = target.read_text(encoding="utf-8")
    if re.search(r"_?currentStage\s*=\s*6\s*;", txt):
        print(f"VERIFIED stage=6 in: {target.name}")
    if re.search(r"_?currentStage\s*=\s*5\s*;", txt):
        print(f"WARNING still has stage=5 in: {target.name}")

sys.exit(0 if total_changes > 0 else 1)
