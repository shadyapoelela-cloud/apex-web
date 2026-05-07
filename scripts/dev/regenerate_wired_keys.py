"""Regenerate `apex_finance/lib/core/v5/v5_wired_keys.dart` from the
keys present in `apex_finance/lib/core/v5/v5_wired_screens.dart`.

This is a pure data-extraction step — the keys file is a thin lookup
used by the routing validator and tests so they can know which chips
are wired without importing the giant screen-widget graph (which pulls
`dart:html` and breaks `flutter test`).

Run after every edit to `v5_wired_screens.dart`. The keys file should
be committed alongside the wiring change.
"""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SRC = REPO / 'apex_finance/lib/core/v5/v5_wired_screens.dart'
DST = REPO / 'apex_finance/lib/core/v5/v5_wired_keys.dart'

src = SRC.read_text(encoding='utf-8')
keys = re.findall(r"^\s*'([a-z0-9_/-]+)':\s*\(ctx\)", src, re.M)

if len(keys) != len(set(keys)):
    dupes = [k for k in set(keys) if keys.count(k) > 1]
    raise SystemExit(f'duplicate keys in v5_wired_screens.dart: {dupes}')

header = """/// Auto-derived set of all chip path keys present in
/// [v5WiredScreens] (apex_finance/lib/core/v5/v5_wired_screens.dart).
///
/// Lives in a separate file so the routing validator and unit tests
/// can know which chips are wired without importing the giant screen
/// graph in [v5_wired_screens.dart] (~200 screen widget imports — many
/// of which transitively pull in package:web, breaking flutter test).
///
/// **Discipline:** any add/remove in [v5WiredScreens] must be mirrored
/// here. Regenerate via `python scripts/dev/regenerate_wired_keys.py`.
library;

const Set<String> v5WiredKeys = <String>{
"""

body = '\n'.join(f"  '{k}'," for k in keys)
footer = '\n};\n'

DST.write_text(header + body + footer, encoding='utf-8', newline='\n')
print(f'wrote {len(keys)} keys to {DST.relative_to(REPO)}')
