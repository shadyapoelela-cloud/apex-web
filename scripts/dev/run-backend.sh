#!/usr/bin/env bash
# APEX local-dev backend launcher — Mac/Linux equivalent of run-backend.ps1
# (G-DEV-1, Sprint 8). See run-backend.ps1 for the full rationale; this is
# the same flow with portable shell tooling.

set -euo pipefail

PORT="${PORT:-8000}"
BIND_HOST="${BIND_HOST:-127.0.0.1}"
NO_RELOAD="${NO_RELOAD:-0}"

# 1. Resolve project root from script location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
echo "[run-backend] project root: $PROJECT_ROOT"

# 2. Check whether port is in use. Prefer lsof, fall back to ss.
existing_pid=""
if command -v lsof >/dev/null 2>&1; then
    existing_pid="$(lsof -ti tcp:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
elif command -v ss >/dev/null 2>&1; then
    existing_pid="$(ss -ltnp "sport = :$PORT" 2>/dev/null | awk -F'pid=' 'NR>1 {split($2,a,","); print a[1]}' | head -1)"
fi

if [ -n "$existing_pid" ]; then
    echo "[run-backend] WARNING: port $PORT is already listening (PID $existing_pid)."
    read -r -p "Kill it and continue? [y/N] " resp
    case "$resp" in
        y|Y|yes|YES)
            kill "$existing_pid" || true
            sleep 1
            echo "[run-backend] killed PID $existing_pid."
            ;;
        *)
            echo "[run-backend] aborted. Free port $PORT and re-run."
            exit 1
            ;;
    esac
fi

# 3. Print + run.
cd "$PROJECT_ROOT"

# Pick the right Python launcher. `py` is Windows-specific; on POSIX use python3.
if command -v python3 >/dev/null 2>&1; then
    PY="python3"
else
    PY="python"
fi

reload_flag="--reload"
[ "$NO_RELOAD" = "1" ] && reload_flag=""

echo "[run-backend] cwd: $PROJECT_ROOT"
echo "[run-backend] cmd: $PY -m uvicorn app.main:app --host $BIND_HOST --port $PORT $reload_flag"
echo "[run-backend] (Ctrl+C to stop)"
echo

exec "$PY" -m uvicorn app.main:app --host "$BIND_HOST" --port "$PORT" $reload_flag
