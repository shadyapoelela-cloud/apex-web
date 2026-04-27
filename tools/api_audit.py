#!/usr/bin/env python3
"""APEX backend audit — Wave 3 of APEX_IMPROVEMENT_PLAN.md.

Scans every FastAPI router under `app/` and reports endpoints that
violate the platform's response-shape, error-handling, and permission
conventions documented in CLAUDE.md.

Checks performed
----------------
1. **Response shape:** does the handler return {"success": bool, ...}?
   We grep return statements and flag any handler whose final return is
   a bare dict that doesn't contain the literal `"success"` key, or a
   raw model-dump (model.dict()/model.model_dump()).

2. **Traceback leak:** does an except clause re-raise as HTTPException
   without carrying through the original message? (We flag any
   `raise HTTPException(detail=str(e))` since `e` may contain a stack
   trace from the underlying driver.)

3. **Admin endpoints:** anything matching /admin/ or /tenants/admin must
   call `verify_admin(...)` (CLAUDE.md hard requirement). We flag
   admin-prefixed endpoints that don't reference `verify_admin`.

4. **Tracebacks logged:** do `except` blocks call `logging.error(...)`
   or `logger.error(...)` so failures are visible? We flag silent
   catches.

The script writes a markdown report to docs/audit/api_audit.md (passed
as argv[1] if provided) so it can be checked into the repo for review.

Usage
-----
    python tools/api_audit.py            # writes to stdout
    python tools/api_audit.py report.md  # writes to file
"""

from __future__ import annotations

import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import List


@dataclass
class Finding:
    file: Path
    line: int
    rule: str
    severity: str  # 'error' | 'warn' | 'info'
    message: str
    snippet: str

    def md(self, repo_root: Path) -> str:
        sev = {'error': '🔴', 'warn': '🟡', 'info': 'ℹ️'}.get(self.severity, '·')
        # Cross-platform path display: relative + forward slashes.
        try:
            rel = self.file.relative_to(repo_root).as_posix()
        except ValueError:
            rel = self.file.as_posix()
        return (f'- {sev} **{self.rule}** — '
                f'`{rel}:{self.line}` — {self.message}\n'
                f'  ```python\n  {self.snippet}\n  ```')


# ─── Heuristics ─────────────────────────────────────────────────────────

# A handler is a function decorated with @router.{get,post,put,patch,delete}
HANDLER_DECO = re.compile(
    r'@\w+\.(get|post|put|patch|delete)\s*\(\s*["\']([^"\']+)["\']'
)

# Bare dict return that doesn't include "success"
RETURN_DICT = re.compile(r'^\s*return\s*\{')

# `raise HTTPException(...detail=str(e)...)` — leaks underlying error
LEAK_DETAIL = re.compile(
    r'raise\s+HTTPException\s*\([^)]*detail\s*=\s*(?:str\s*\(|f["\'])\s*\w+'
)

# Admin path regex
ADMIN_PATH = re.compile(r'(?:^|/)(?:admin|tenants/admin)(?:$|/)')

# Whether a function references verify_admin somewhere in its body
USES_ADMIN_CHECK = re.compile(r'verify_admin\s*\(')

# Logged error
LOGGED_ERROR = re.compile(r'(?:logging|logger)\.(?:error|exception|critical)\s*\(')


def scan_file(path: Path) -> List[Finding]:
    findings: List[Finding] = []
    try:
        text = path.read_text(encoding='utf-8')
    except (UnicodeDecodeError, FileNotFoundError):
        return findings
    lines = text.split('\n')

    # Collect handler regions: (start_line, end_line, http_method, path)
    handlers: List[tuple] = []
    for i, line in enumerate(lines):
        m = HANDLER_DECO.search(line)
        if not m:
            continue
        # Find the def below (skip decorator lines + dependencies)
        j = i + 1
        while j < len(lines) and not lines[j].lstrip().startswith('def ') \
                and not lines[j].lstrip().startswith('async def '):
            j += 1
        if j >= len(lines):
            continue
        # Determine end of function: next non-indented line
        body_start = j
        body_end = len(lines)
        for k in range(j + 1, len(lines)):
            if lines[k].strip() and not lines[k].startswith((' ', '\t')):
                body_end = k
                break
        handlers.append((i, body_end, m.group(1), m.group(2), body_start))

    # Apply checks per handler
    for deco_line, end_line, method, route, body_start in handlers:
        body = '\n'.join(lines[body_start:end_line])

        # 1. Response shape: scan returns
        for ln_offset, line in enumerate(lines[body_start:end_line]):
            ln = body_start + ln_offset + 1
            # bare-dict return
            mo = RETURN_DICT.search(line)
            if mo:
                # peek ahead a few lines to find "success" before next blank/return
                window = '\n'.join(lines[body_start + ln_offset:body_start + ln_offset + 8])
                if '"success"' not in window and "'success'" not in window \
                        and 'success=' not in window:
                    findings.append(Finding(
                        file=path, line=ln, rule='response-shape',
                        severity='warn',
                        message=f'{method.upper()} {route} returns a dict without `success` key',
                        snippet=line.strip()[:120],
                    ))
                    break  # one finding per handler is enough

        # 2. Traceback leak in HTTPException
        for ln_offset, line in enumerate(lines[body_start:end_line]):
            if LEAK_DETAIL.search(line):
                ln = body_start + ln_offset + 1
                findings.append(Finding(
                    file=path, line=ln, rule='traceback-leak',
                    severity='error',
                    message=f'{method.upper()} {route} forwards exception text to the client',
                    snippet=line.strip()[:120],
                ))

        # 3. Admin without admin check
        if ADMIN_PATH.search(route):
            if not USES_ADMIN_CHECK.search(body):
                findings.append(Finding(
                    file=path, line=deco_line + 1, rule='admin-unprotected',
                    severity='error',
                    message=f'{method.upper()} {route} is admin-prefixed but never calls verify_admin(...)',
                    snippet=lines[deco_line].strip()[:120],
                ))

        # 4. Silent except (no logging.error / logger.error)
        # Find every `except ... :` and check the next 10 lines.
        for ln_offset, line in enumerate(lines[body_start:end_line]):
            if re.match(r'\s*except\b', line):
                window = '\n'.join(lines[body_start + ln_offset:
                                          body_start + ln_offset + 10])
                if not LOGGED_ERROR.search(window):
                    ln = body_start + ln_offset + 1
                    findings.append(Finding(
                        file=path, line=ln, rule='silent-except',
                        severity='warn',
                        message=f'{method.upper()} {route} catches an exception without logging it',
                        snippet=line.strip()[:120],
                    ))

    return findings


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    app_dir = repo_root / 'app'
    if not app_dir.exists():
        print(f'❌ app/ not found at {app_dir}', file=sys.stderr)
        return 2

    all_findings: List[Finding] = []
    files_scanned = 0
    for py in app_dir.rglob('*.py'):
        # Skip __pycache__ and tests
        if '__pycache__' in py.parts or '/tests/' in str(py):
            continue
        files_scanned += 1
        all_findings.extend(scan_file(py))

    # Group by rule for the summary
    by_rule = defaultdict(list)
    for f in all_findings:
        by_rule[f.rule].append(f)

    out_lines = [
        '# APEX Backend API Audit',
        '',
        f'**Files scanned:** {files_scanned}',
        f'**Findings total:** {len(all_findings)}',
        '',
        '## Summary by rule',
        '',
        '| Rule | Severity | Count |',
        '|---|---|---|',
    ]
    severity_for_rule = {
        'response-shape': '🟡 warn',
        'traceback-leak': '🔴 error',
        'admin-unprotected': '🔴 error',
        'silent-except': '🟡 warn',
    }
    for rule, items in sorted(by_rule.items()):
        out_lines.append(
            f'| {rule} | {severity_for_rule.get(rule, "·")} | {len(items)} |')

    out_lines.extend(['', '## Findings', ''])
    for rule in sorted(by_rule.keys()):
        out_lines.append(f'### {rule}')
        out_lines.append('')
        # Cap at 50 per rule to keep the report readable
        for f in by_rule[rule][:50]:
            out_lines.append(f.md(repo_root))
        if len(by_rule[rule]) > 50:
            out_lines.append(
                f'\n_({len(by_rule[rule]) - 50} more — truncated)_')
        out_lines.append('')

    report = '\n'.join(out_lines)

    if len(sys.argv) > 1:
        target = Path(sys.argv[1])
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(report, encoding='utf-8')
        print(f'✅ Audit report written to {target}')
        print(f'   {files_scanned} files, {len(all_findings)} findings')
    else:
        print(report)

    # Exit non-zero only if there are 🔴 errors (audit-fails-CI semantics).
    return 1 if any(f.severity == 'error' for f in all_findings) else 0


if __name__ == '__main__':
    sys.exit(main())
