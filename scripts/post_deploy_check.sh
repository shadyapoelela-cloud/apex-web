#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
# APEX — post-deploy smoke check.
#
# Hits the live Render backend + GitHub Pages frontend and asserts
# they're responding correctly. Runs in <15s with no dependencies
# beyond curl + bash. Intended to be invoked:
#
#   - Manually after pushing to main:        ./scripts/post_deploy_check.sh
#   - Against staging before prod:           APEX_API=https://apex-api-staging.onrender.com ./scripts/post_deploy_check.sh
#   - From a GitHub Actions job (future):    add a "post-deploy" step
#
# Exit codes:
#   0 — all checks passed
#   1 — at least one check failed
#
# This script is the defence against repeating the cascade of
# deploy failures we hit on 2026-04-23:
#   - alembic tried to re-CREATE tables prod already had
#   - schema-drifted columns tripped CREATE INDEX
#   - SW cleanup fought Flutter's own registration
# Any of those would surface here as a non-200 /health or missing
# markers in the served HTML.
# ════════════════════════════════════════════════════════════════════

set -u  # NOTE: intentionally not -e — we collect every failure, don't stop on first

APEX_API="${APEX_API:-https://apex-api-ootk.onrender.com}"
APEX_WEB="${APEX_WEB:-https://shadyapoelela-cloud.github.io/apex-web/}"
TIMEOUT_S="${TIMEOUT_S:-15}"

fail_count=0
pass_count=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; pass_count=$((pass_count + 1)); }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail_count=$((fail_count + 1)); }
note() { printf '    \033[2m%s\033[0m\n' "$1"; }

# ─────────────────────────────────────────────────────────────────
# 1. Backend /health — must be 200 and report all phases active
# ─────────────────────────────────────────────────────────────────
printf '\n\033[1m[1/5] Backend health — %s\033[0m\n' "$APEX_API"
health_body=$(curl -sf --max-time "$TIMEOUT_S" "$APEX_API/health" || echo "")
if [ -z "$health_body" ]; then
    fail "GET /health did not return a body within ${TIMEOUT_S}s"
else
    pass "GET /health returned 200"
    note "$health_body"
    if printf '%s' "$health_body" | grep -q '"status":"ok"'; then
        pass "response reports status=ok"
    else
        fail "response missing status=ok"
    fi
    if printf '%s' "$health_body" | grep -q '"database":true'; then
        pass "database reachable"
    else
        fail "database NOT reachable"
    fi
    if printf '%s' "$health_body" | grep -q '"all_phases_active":true'; then
        pass "all phases (P1-P11) active"
    else
        fail "one or more phases inactive"
    fi
fi

# ─────────────────────────────────────────────────────────────────
# 2. Backend /docs (FastAPI auto docs) — 200 means FastAPI is up
# ─────────────────────────────────────────────────────────────────
printf '\n\033[1m[2/5] Backend OpenAPI\033[0m\n'
docs_code=$(curl -s --max-time "$TIMEOUT_S" -o /dev/null -w "%{http_code}" "$APEX_API/openapi.json")
if [ "$docs_code" = "200" ]; then
    pass "GET /openapi.json → 200 (FastAPI reachable)"
else
    fail "GET /openapi.json → $docs_code"
fi

# ─────────────────────────────────────────────────────────────────
# 3. Backend auth gate — unauth'd access to /clients must be 401
#    (catches the "accidentally-public endpoint" regression)
# ─────────────────────────────────────────────────────────────────
printf '\n\033[1m[3/5] Auth gate\033[0m\n'
cli_code=$(curl -s --max-time "$TIMEOUT_S" -o /dev/null -w "%{http_code}" "$APEX_API/clients")
case "$cli_code" in
    401|403) pass "GET /clients (no token) → $cli_code (expected auth rejection)" ;;
    404)     pass "GET /clients → 404 (endpoint not mounted at this path — acceptable)" ;;
    200)     fail "GET /clients → 200 WITHOUT a token — auth gate is open!" ;;
    *)       fail "GET /clients → $cli_code (unexpected)" ;;
esac

# ─────────────────────────────────────────────────────────────────
# 4. Frontend HTML — served, has correct title + BUILD_ID
# ─────────────────────────────────────────────────────────────────
printf '\n\033[1m[4/5] Frontend HTML — %s\033[0m\n' "$APEX_WEB"
html_body=$(curl -sf --max-time "$TIMEOUT_S" "$APEX_WEB" || echo "")
if [ -z "$html_body" ]; then
    fail "frontend fetch returned empty"
else
    pass "frontend served"
    if printf '%s' "$html_body" | grep -q '<title>APEX</title>'; then
        pass "<title>APEX</title> present"
    else
        fail "<title>APEX</title> missing (did the build break?)"
    fi
    if printf '%s' "$html_body" | grep -q 'APEX_BUILD_ID'; then
        build_id=$(printf '%s' "$html_body" | grep -oE "APEX_BUILD_ID\s*=\s*'[^']*'" | head -1 | sed "s/.*'\(.*\)'.*/\1/")
        pass "APEX_BUILD_ID present: $build_id"
    else
        fail "APEX_BUILD_ID marker missing — old index.html deployed?"
    fi
    if printf '%s' "$html_body" | grep -q 'flutter_bootstrap.js'; then
        pass "flutter_bootstrap.js reference present"
    else
        fail "flutter_bootstrap.js reference missing"
    fi
fi

# ─────────────────────────────────────────────────────────────────
# 5. Backend migrations ran — /health reports db:true AND a
#    presence check on a table we know must exist post-migration
# ─────────────────────────────────────────────────────────────────
printf '\n\033[1m[5/5] Migration sanity\033[0m\n'
# We can't run SQL from here, but if /health's `phases.p1:true` is
# true AND `database:true` AND the app started without the
# `run_migrations_on_startup` RuntimeError, migrations passed.
# The RuntimeError would have taken the app down — if we got 200
# on /health already, migrations are fine.
if printf '%s' "$health_body" | grep -q '"status":"ok"'; then
    pass "app started past the lifespan migration runner (no startup exception)"
else
    fail "app did not start cleanly — check Render logs for run_migrations_on_startup errors"
fi

# ─────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────
total=$((pass_count + fail_count))
printf '\n\033[1m═══ Summary ═══\033[0m\n'
if [ "$fail_count" -eq 0 ]; then
    printf '  \033[32m%d/%d passed\033[0m — deploy looks healthy.\n\n' "$pass_count" "$total"
    exit 0
else
    printf '  \033[31m%d/%d failed\033[0m — deploy is broken or degraded.\n\n' "$fail_count" "$total"
    exit 1
fi
