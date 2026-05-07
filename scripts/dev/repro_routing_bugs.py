"""Reproduces the 4 routing bugs discovered in UAT_FORENSIC_FULL_2026-05-06.md.

Run before fix: must print 'Found errors: 4'.
Run after fix: must print 'Found errors: 0'.

The script is intentionally regex-only (no Dart parser) so it can run in CI
without a Flutter toolchain. It catches:

  1. Pins whose route uses the double `/app/erp/app/...` prefix pattern
     (a copy-paste bug observed in BUG-3 + BUG-4 of the audit).
  2. Pins whose chip segment does not appear as an explicit
     `V5Chip(id: '...')` literal in `v5_data.dart`. This is a regex-level
     check, so chips created via the `_chipFromV4(...)` helper (e.g. 'gl')
     also count as "missing" here — that's by design: the audit
     considers a pin route valid only when the chip is explicitly
     declared in the finance/purchasing chip lists.
"""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
data = (REPO / 'apex_finance/lib/core/v5/v5_data.dart').read_text(encoding='utf-8')
shell = (REPO / 'apex_finance/lib/core/v5/apex_v5_service_shell.dart').read_text(encoding='utf-8')

# Collect every chip id written as `V5Chip(id: 'foo')` in v5_data.
chips_global = set(re.findall(r"V5Chip\(\s*id:\s*'([a-z0-9_-]+)'", data))

# Extract pins from the shell as (id, route) pairs.
pin_re = re.compile(r"_Pin\(\s*id:\s*'([^']+)'.*?route:\s*'([^']+)'", re.S)
pins = pin_re.findall(shell)

errors: list[str] = []
for pin_id, route in pins:
    # Detect the double `/app/erp/app/...` prefix bug explicitly so the
    # error message is human-readable.
    if route.startswith('/app/erp/app/'):
        errors.append(f"{pin_id}: double prefix -> {route}")
        continue

    parts = [p for p in route.split('/') if p]
    if len(parts) != 4 or parts[0] != 'app':
        errors.append(f"{pin_id}: wrong shape -> {route}")
        continue

    chip = parts[3]
    if chip not in chips_global:
        errors.append(f"{pin_id}: chip '{chip}' not in v5_data -> {route}")

print(f"Found errors: {len(errors)}")
for err in errors:
    print(f"  - {err}")

# Non-zero exit so CI can gate on it.
raise SystemExit(1 if errors else 0)
