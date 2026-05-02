# APEX — Local Development Runbook

> **Audience:** anyone who just cloned `apex-web` and wants to see the
> Flutter UI talk to a local backend, end-to-end. ~10 minutes from clean
> clone to logged-in `/app`.
>
> **Why this file exists (G-DEV-1):** the existing `README.md` Quick Start
> ends at `flutter run -d chrome`, which silently inherits the production
> Render URL baked into `apex_finance/lib/core/api_config.dart` as the
> `API_BASE` default. Without `--dart-define=API_BASE=http://127.0.0.1:8000`,
> the local Flutter app talks to live production — symptoms include
> "Failed to fetch", CORS errors, or accidentally hitting prod data with
> dev tokens. This runbook is the antidote.

---

## 1. Architecture (text diagram)

```
┌─────────────────────────┐     fetch /api/...        ┌────────────────────────┐
│  Browser :57305         │ ────────────────────────▶ │  uvicorn :8000         │
│  (Flutter web build)    │                           │  app.main:app          │
│                         │ ◀──────────────────────── │  + SQLite (dev fallback)
└─────────────────────────┘     JSON response          └────────────────────────┘
   built with                                          imports phaseN/, sprintN/,
   --dart-define=API_BASE=                             pilot/, copilot/, zatca/...
   http://127.0.0.1:8000
```

The frontend is **always** built with the production `API_BASE` baked in
unless you override at run time. Production CI relies on that default
(see `.github/workflows/ci.yml` and the `flutter build web` step), so the
correct local-dev fix is the override flag, **not** editing
`api_config.dart` (which would break production deploys — gap closure
documented in 09 § 11 G-DEV-1).

---

## 2. One-shot quick start

### Windows (PowerShell)

```powershell
# Terminal 1: backend
.\scripts\dev\run-backend.ps1

# Terminal 2 (after backend prints "Application startup complete"):
.\scripts\dev\run-frontend.ps1
```

### macOS / Linux (bash)

```bash
# Terminal 1:
./scripts/dev/run-backend.sh

# Terminal 2:
./scripts/dev/run-frontend.sh
```

The scripts print the exact command they're about to run before they run
it — read the output once, learn the underlying commands, then you can
skip the wrapper if you prefer.

When Flutter says `lib/main.dart on Chrome`, open
<http://127.0.0.1:57305/> manually if Chrome didn't auto-open.

---

## 3. Test users

Out of a fresh database, no users exist. Create one via the public
register endpoint:

```bash
curl -X POST http://127.0.0.1:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "shady2",
    "email": "shady2@test.local",
    "password": "Aa@123456",
    "full_name": "Shady Test"
  }'
```

The response includes `access_token`. Log in via the Flutter UI with
`shady2` / `Aa@123456`. The Sprint 7 G-S1 bcrypt rehash logic will quietly
upgrade the stored hash on next login — no action needed.

For richer fixtures (sample customers, COA, invoices), the existing
`scripts/seed_clothing_customer.py` and `scripts/interactive_customer_setup.py`
seeders work against the local backend out of the box.

---

## 4. Troubleshooting

### "Failed to fetch" in the Flutter UI

Almost always one of:
1. **uvicorn isn't running.** Check terminal 1; if it died, the runbook's
   step 2 also dies. Re-run `run-backend.ps1`/`.sh`.
2. **You forgot `--dart-define=API_BASE=...`.** Stop Flutter (`q`),
   re-run via the wrapper, OR run by hand:
   `flutter run -d chrome --web-port 57305 --dart-define=API_BASE=http://127.0.0.1:8000`
3. **Backend bound to a different host.** See § 4.4 below.

### Login fails with "CORS preflight error"

**Symptom:** Browser console shows:

```
Access to fetch at 'http://127.0.0.1:8000/auth/login' has been blocked
by CORS policy: Response to preflight request doesn't pass access
control check: The value of the 'Access-Control-Allow-Origin' header
in the response must not be the wildcard '*' when the request's
credentials mode is 'include'.
```

**Cause:** Backend's default CORS allows all origins (`*`), which is
incompatible with the frontend sending `credentials: 'include'` for
HttpOnly cookies. The two are mutually exclusive per CORS spec.

**Fix:** `scripts/dev/run-backend.{ps1,sh}` now auto-sets `CORS_ORIGINS`
to a localhost-allowlist (G-DEV-1.1). If running uvicorn manually, set
the env var:

```powershell
# PowerShell
$env:CORS_ORIGINS = "http://localhost:57305,http://127.0.0.1:57305"
py -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

```bash
# Bash
export CORS_ORIGINS="http://localhost:57305,http://127.0.0.1:57305"
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

**Verify:** uvicorn startup logs should NOT show:
`WARNING root — CORS allows all origins — set CORS_ORIGINS env var`.

The wrapper script prints `CORS_ORIGINS auto-set for local dev: ...`
on startup so you can confirm at a glance.

### "Port already in use" / "address already in use"

The wrapper scripts detect this on Windows and offer to kill the
existing process. On Mac/Linux they use `lsof`/`ss` to find the PID
and prompt the same way. If you'd rather kill manually:

```powershell
# Windows
Get-NetTCPConnection -LocalPort 8000 -State Listen | Stop-Process -Id { $_.OwningProcess } -Force

# bash
lsof -ti tcp:8000 -sTCP:LISTEN | xargs kill -9
```

### `ModuleNotFoundError: No module named 'app'`

You ran uvicorn from the wrong directory. The backend must be launched
from the **project root** (the directory with `pyproject.toml`), not from
inside `app/`. The wrapper script handles this automatically; if you're
running by hand, `cd` to the project root first.

### `127.0.0.1` vs `localhost` — why this matters

We deliberately use `127.0.0.1` everywhere (`API_BASE`, the uvicorn
bind, `app/main.py`'s lifespan log line):

- **DNS resolution:** `127.0.0.1` is a literal IPv4 address — zero DNS
  lookup. `localhost` goes through the resolver.
- **IPv6 fallback (this is the sharp edge):** on Windows 11 and recent
  macOS, `localhost` often resolves to `::1` (IPv6) before `127.0.0.1`.
  Uvicorn's default bind on `127.0.0.1` is **IPv4-only**, so a browser
  request to `http://localhost:8000/...` that hits `::1` first will
  silently fall through to a connection-refused, surfaced in the Flutter
  app as "Failed to fetch" with no useful error.
- **Consistency with logs:** when uvicorn starts it prints
  `Uvicorn running on http://127.0.0.1:8000`. If your dev tooling uses
  `localhost`, your CORS errors and your logs will show two different
  hostnames, and you'll spend an hour reading the wrong stack trace.

If for some reason you must use `localhost`, start uvicorn with
`--host 0.0.0.0` so it binds to every interface (including `::1`). This
is **not recommended** for dev — it exposes the server to your LAN — but
it works.

### `pandas` build failure on Python 3.14

If you `pip install -r requirements.txt` on a Python-3.14 system, the
`pandas` wheel may fall through to a source build and fail. The backend
runs **without pandas** for everything except a few legacy report
endpoints. Two workarounds:

1. **Skip pandas** (recommended for fast onboarding):
   ```bash
   pip install -r requirements.txt --no-deps  # then install needed deps individually
   # or comment pandas out of requirements.txt for local-only use
   ```
   The 1700+ tests in `tests/` pass without pandas. `pytest tests/ -k "not pandas"`
   if anything complains.

2. **Pin Python 3.11/3.12** via `pyenv` / `py -3.11`. Production runs on
   3.11 (see `runtime.txt`).

The wrapper `run-backend.ps1` invokes `py -m uvicorn ...`; on Windows
`py` defaults to the highest installed Python. Override with
`$env:PY_VERSION="-3.11"; py $env:PY_VERSION -m uvicorn ...` if needed.

---

## 5. What the scripts do NOT do

To stay honest about scope:

- **They do not run migrations.** `Base.metadata.create_all()` in
  `app/main.py` `_run_startup()` builds the schema on first boot. The
  alembic catch-up (gap **G-A3.1**) is deferred until the 173-table
  drift is closed under DBA review.
- **They do not seed data.** Use `scripts/seed_clothing_customer.py`
  or the `/auth/register` endpoint above.
- **They do not configure HTTPS.** Local dev is plain HTTP on
  `127.0.0.1`. Production uses Render's TLS termination.
- **They do not pin Flutter or Python versions.** Use the project's
  `pubspec.yaml` and `runtime.txt` as source of truth.

---

## 6. Where to file new troubleshooting entries

If you hit a new failure mode worth documenting, append a new sub-heading
to § 4 and reference it from the relevant gap entry in
`APEX_BLUEPRINT/09_GAPS_AND_REWORK_PLAN.md`. Keep the matrix terse — a
half-sentence symptom + the one-line fix beats a paragraph of theory.

> Verify-First reminder (`APEX_BLUEPRINT/10_CLAUDE_CODE_INSTRUCTIONS.md` § 0):
> grep the cited file before drafting a fix. This runbook itself is part of
> the truth surface — when it lags, the trap returns.
