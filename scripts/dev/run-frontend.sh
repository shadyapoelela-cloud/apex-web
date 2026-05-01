#!/usr/bin/env bash
# APEX local-dev frontend launcher — Mac/Linux equivalent of run-frontend.ps1
# (G-DEV-1, Sprint 8). See run-frontend.ps1 for the full rationale on why
# --dart-define=API_BASE is REQUIRED for local development.

set -euo pipefail

WEB_PORT="${WEB_PORT:-57305}"
API_BASE="${API_BASE:-http://127.0.0.1:8000}"

# 1. Resolve project root + 2. cd into apex_finance.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLUTTER_DIR="$PROJECT_ROOT/apex_finance"

if [ ! -d "$FLUTTER_DIR" ]; then
    echo "[run-frontend] ERROR: apex_finance directory not found at $FLUTTER_DIR" >&2
    exit 1
fi

cd "$FLUTTER_DIR"
echo "[run-frontend] cwd: $FLUTTER_DIR"

# 3. Print + run.
echo "[run-frontend] cmd: flutter run -d chrome --web-port $WEB_PORT --dart-define=API_BASE=$API_BASE"
echo "[run-frontend] open http://127.0.0.1:$WEB_PORT/ once Flutter says 'lib/main.dart on Chrome'."
echo

exec flutter run -d chrome --web-port "$WEB_PORT" "--dart-define=API_BASE=$API_BASE"
