#!/usr/bin/env bash
# scripts/g-a3-1/install_prereqs.sh
# G-A3.1.1 (Sprint 12+) — Linux / Render-shell operator prereq installer.
#
# Why this script exists:
#   During G-A3.1 Phase 2b (2026-05-03), the operator's Windows machine
#   could not install PostgreSQL CLI — winget downloads from EDB's CDN
#   returned HTTP 403 Forbidden in the operator's region (Saudi Arabia)
#   on two retries. Maintenance window stretched 30 → 90 min.
#
#   psycopg2-binary covers every DB op the runbook needs, comes from
#   PyPI (no CDN regional issues observed), and is already in
#   production's stack. This script ensures Python + psycopg2 are
#   present; psql is reported as INFORMATIONAL only — never
#   auto-installed (a future operator may be in the same region and
#   we don't want to retry the failing path silently).
#
# Usage:
#     bash scripts/g-a3-1/install_prereqs.sh
#
# Exit codes:
#     0 = Python + psycopg2 available (psql may or may not be present).
#     1 = Python missing OR psycopg2 install failed.

set -uo pipefail

# Avoid `set -e` so we can collect all status lines before exiting.

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
cyan()   { printf '\033[36m%s\033[0m\n' "$*"; }

cyan "G-A3.1.1 operator prereq installer (Linux / Render shell)"
cyan "========================================================="
echo

# ── 1. Python ─────────────────────────────────────────────────────
PY=""
if command -v python3 >/dev/null 2>&1; then
    PY="python3"
elif command -v python >/dev/null 2>&1; then
    PY="python"
fi

if [ -n "$PY" ]; then
    python_version="$($PY --version 2>&1)"
    green "[OK] Python ($PY): $python_version"
else
    red "[MISSING] Python (python3 or python)"
    yellow ""
    yellow "Python is required. Install via your distro:"
    yellow "  Debian/Ubuntu: apt install python3 python3-pip"
    yellow "  RHEL/Fedora:   dnf install python3 python3-pip"
    yellow "  Render shell:  Python is pre-installed; this script may be running in a non-standard shell"
    exit 1
fi

# ── 2. psycopg2-binary ────────────────────────────────────────────
psycopg2_ok=0
psycopg2_version=""

if $PY -m pip show psycopg2-binary >/dev/null 2>&1; then
    psycopg2_ok=1
    psycopg2_version="$($PY -m pip show psycopg2-binary 2>/dev/null | awk -F': ' '/^Version:/ {print $2}')"
else
    cyan "[INFO] psycopg2-binary not installed; installing (user scope)..."
    if $PY -m pip install --user psycopg2-binary 2>&1 | sed 's/^/  /'; then
        if $PY -m pip show psycopg2-binary >/dev/null 2>&1; then
            psycopg2_ok=1
            psycopg2_version="$($PY -m pip show psycopg2-binary 2>/dev/null | awk -F': ' '/^Version:/ {print $2}')"
        fi
    fi
fi

# Verify import.
if [ "$psycopg2_ok" -eq 1 ]; then
    if ! $PY -c "import psycopg2; print(psycopg2.__version__)" >/dev/null 2>&1; then
        psycopg2_ok=0
        psycopg2_version="import failed"
    fi
fi

if [ "$psycopg2_ok" -eq 1 ]; then
    green "[OK] psycopg2-binary: $psycopg2_version"
else
    red "[MISSING] psycopg2-binary"
    yellow ""
    yellow "psycopg2-binary install or import failed."
    yellow "Try manually:"
    yellow "  $PY -m pip install --user psycopg2-binary"
    exit 1
fi

# ── 3. psql (INFORMATIONAL ONLY — see header for why) ─────────────
if command -v psql >/dev/null 2>&1; then
    psql_version="$(psql --version 2>&1)"
    green "[OK] psql (optional): $psql_version"
    psql_status="OK"
else
    yellow "[ABSENT] psql (optional)  — psycopg2 covers all DB ops; psql install is intentionally NOT attempted (see header)."
    psql_status="absent (optional)"
fi

# ── Summary ───────────────────────────────────────────────────────
echo
cyan "Summary:"
echo "  Python: OK  |  psycopg2: OK  |  psql: $psql_status"
echo
green "Operator can proceed to scripts/g-a3-1/preflight.py and stamp_head.py."
exit 0
