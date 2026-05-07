# APEX Financial Platform -- Project Rules

## Architecture

- **Backend**: FastAPI (Python 3.11), modular phase-based architecture (Phases 1-11 + Sprints 1-6)
- **Frontend**: Flutter Web (Dart), Riverpod state management, GoRouter navigation (~257 GoRoute entries in `router.dart`; ~268 across all `.dart` files. Verify: `grep -c "GoRoute(" apex_finance/lib/core/router.dart`)
- **Database**: PostgreSQL + SQLAlchemy ORM (SQLite fallback for dev)
- **Auth**: JWT (HS256) via `JWT_SECRET` env var, bcrypt password hashing
- **Deployment**: Render.com free tier (cold-start tolerant) + GitHub Pages (frontend)
- **AI**: Anthropic Claude API for Knowledge Brain + Copilot (with fallback responses)
- **Payments**: Stripe + mock backend via `PAYMENT_BACKEND` env var
- **Email**: SMTP / SendGrid / console via `EMAIL_BACKEND` env var
- **Storage**: Local filesystem / S3 via `STORAGE_BACKEND` env var

## Backend Conventions

- Each phase lives in `app/phaseN/` with `models/`, `routes/`, `services/` subdirs
- Sprints live in `app/sprintN/`
- All phase routers are conditionally loaded in `app/main.py` via try/except flags (P1, P2, ... HAS_P7, etc.)
- Never use `from module import *` -- use explicit imports
- **JWT_SECRET**: Single source of truth in `app/core/auth_utils.py` -- all modules import from there
- Admin endpoints must check `ADMIN_SECRET` via `X-Admin-Secret` header (or query param for backward compat)
- CORS origins configurable via `CORS_ORIGINS` env var (comma-separated)
- API responses follow `{"success": bool, "data": ...}` or `{"success": bool, "error": str}` pattern
- Don't leak tracebacks to clients -- log with `logging.error()`, return generic HTTPException
- Startup uses `lifespan` context manager (NOT deprecated `on_event`)
- Environment validation: fail-fast in production if critical vars are missing

## Frontend Conventions

- `apex_finance/lib/main.dart` is now a 21-line bootstrap (G-A1, Sprint 7) — classes live in `core/`, `screens/`, `widgets/`. Do **not** re-collapse them back into `main.dart`.
- Key singletons: `AC` (colors/theme in `core/theme.dart`), `S` (session/localStorage), `ApiService` (HTTP client)
- **API base URL**: Centralized in `core/api_config.dart` -- ALL files import from there (never hardcode URLs)
- Arabic RTL is the primary UI language
- All API calls should go through `ApiService` which handles token injection and retry logic
- **Session-expiry handling (ERR-1, 2026-05-07):** every `ApiResult`-producing helper in `api_service.dart` routes through `_handleResponse`, which detects HTTP 401 and triggers `_SessionExpiryHandler` exactly once: clears `S`, shows a SnackBar via the global `apexScaffoldMessengerKey`, and bumps `apexAuthRefresh` so `appRouter` re-evaluates the auth guard. Direct `_httpClient.{get,post,…}` calls that build their own `ApiResult` must call `_handleResponse(res)` to preserve this contract — do not parse 401s inline.
- **Auth-protected routes:** anything not under `/login`, `/register`, or `/forgot-password*` is gated by `authGuardRedirect` in `core/auth_guard.dart`. The redirect emits `/login?return_to=<encoded path>`; `slide_auth_screen.dart` validates and decodes the param via `resolvePostLoginDestination` (which rejects open-redirect attempts).
- All TextEditingControllers must have `dispose()` in the State class

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `JWT_SECRET` | JWT signing key | (dev fallback -- must override in prod) |
| `ADMIN_SECRET` | Admin endpoint auth | `apex-admin-2026` (must override in prod) |
| `CORS_ORIGINS` | Allowed origins (comma-sep) | `*` (restrict in prod) |
| `DATABASE_URL` | PostgreSQL connection string | SQLite fallback |
| `KB_DATABASE_URL` | Knowledge Brain PostgreSQL | SQLite fallback |
| `ANTHROPIC_API_KEY` | Claude AI for Copilot | (required for AI features) |
| `EMAIL_BACKEND` | Email: `console`, `smtp`, `sendgrid` | `console` |
| `PAYMENT_BACKEND` | Payment: `mock`, `stripe` | `mock` |
| `STORAGE_BACKEND` | Storage: `local`, `s3` | `local` |
| `ENVIRONMENT` | `development` or `production` | `development` |

## Testing

- **2,330 automated tests** collected across **134 test files** in the
  `tests/` tree (verified 2026-05-04 by G-DOCS-2 via
  `py -m pytest tests/ --collect-only -q | tail -3`). The count grew over
  Phases 1-11 and Sprints 1-13; the original "204 tests" figure was
  retired by G-DOCS-1 (Sprint 8) and the intermediate "~1,784" figure
  was retired by G-DOCS-2 (Sprint 14). When this number drifts again
  re-measure with the same command and update both this line and
  `APEX_BLUEPRINT/00_MASTER_INDEX.md`. Highlights of long-running suites:
  - `test_integration_v10.py`: 93 integration tests (response format, CORS, security, auth, legal, account)
  - `test_clients_coa.py`: 26 tests (clients, COA upload/classify/approve, TB binding, onboarding, archive)
  - `test_providers_marketplace.py`: 25 tests (providers, marketplace, subscriptions, service catalog, audit)
  - `test_copilot_notifications.py`: 33 tests (copilot AI, notifications, admin, legal docs, knowledge brain)
  - `test_auth.py`: 6 auth flow tests
  - `test_admin.py`: 4 admin endpoint tests
  - `test_health.py`: 3 health check tests
  - `test_social_auth*.py`: 26 tests (Wave 1 OAuth verification)
  - `test_sms_otp.py`: 10 tests (Wave SMS + OTP store)
  - `test_zatca_*.py`: ZATCA submission, retry queue, CSID encryption (~80 tests)
  - `test_utils.py` + `test_core.py`: 14 utility/sanity tests
- Run: `pytest tests/ -v` or `pytest tests/ --cov=app --cov-report=term-missing`
- CI/CD: GitHub Actions (`.github/workflows/ci.yml`) — lint (Black, Ruff, Bandit) + tests + coverage + deploy
- Config: `pyproject.toml` for Black (120 chars), Ruff, pytest, coverage settings

### V5 Routing Validation (HOTFIX-Routing, Sprint 16)

Every PR runs two layers of routing checks:

1. **CI lint job** runs `python scripts/dev/repro_routing_bugs.py` —
   regex-only guard for `/app/erp/app/erp/...` double-prefix bugs and
   pins pointing at chip ids that aren't declared as
   `V5Chip(id: 'foo')` literals in `v5_data.dart`. Fast, no Flutter
   needed.
2. **CI flutter-routing job** runs
   `flutter test apex_finance/test/v5_routing_test.dart` —
   stricter runtime check (knows main-module scope, so a chip that
   exists in the wrong main module is flagged). Also enforces a
   ratchet on the count of unreachable chips: the number is allowed
   to decrease as chips get wired but never grow.

When wiring a previously-broken chip, the test will pass and the
baseline implicitly decreases. To formally tighten the baseline, lower
the `allowedUnreachable` (or `allowedBrokenPins`) constant in
`test/v5_routing_test.dart` (acts as a ratchet).

Audit history: `UAT_FORENSIC_FULL_2026-05-06.md`
Validator: `apex_finance/lib/core/v5/v5_routing_validator.dart`

## Local Development

- Full runbook: **`LOCAL_DEV_RUNBOOK.md`** (G-DEV-1, Sprint 8). Covers the `--dart-define=API_BASE` flag (REQUIRED — `api_config.dart` defaults to the Render production URL), test-user creation, the 127.0.0.1-vs-localhost / IPv6-fallback trap, port conflicts, and the Python 3.14 pandas caveat.
- One-shot start: `scripts/dev/run-backend.ps1` then `scripts/dev/run-frontend.ps1` (Windows) or the `.sh` equivalents (Mac/Linux). Both wrappers print the underlying `uvicorn` / `flutter run` command before executing — read once, learn the shape, drop the wrapper if you prefer.
- **Do not edit `apex_finance/lib/core/api_config.dart` to "fix" local dev** — production CI bakes the default at build time. Use `--dart-define` instead.

## Deployment

### Backend → Render
The `deploy` job in `.github/workflows/ci.yml` triggers a Render deploy
hook on every push to `main` (after `lint` and `test` pass). No manual
step.

### Frontend → GitHub Pages auto-deploy (G-WEB-BUILD-1, Sprint 16)
Every push to `main` runs the `pages-deploy` CI job, which:
1. Builds Flutter web with `API_BASE=https://apex-api-ootk.onrender.com`
2. Smoke-tests the bundle (`main.dart.js` ≥ 1 MB, recently-wired chip
   keys present in the JS — guards against tree-shake regressions)
3. Force-pushes the build output to the **`gh-pages`** branch via
   `peaceiris/actions-gh-pages@v4`. main is never written to.

`apex-web/` in `main` is now a frozen catch-up snapshot only; normal
deploys live in `gh-pages` and are reproducible from CI. To see the
bundle history use `git log gh-pages` (force-orphan keeps it 1-commit).

Manual rebuild (emergency only — e.g. CI is down and a fix must ship):
```bash
cd apex_finance
flutter build web --release --no-tree-shake-icons \
  --base-href "/apex-web/" \
  --dart-define=API_BASE=https://apex-api-ootk.onrender.com
# Then push the output to gh-pages directly:
cd ..
git push origin --force build/web:gh-pages   # one-off override
```

`--no-tree-shake-icons` is required until a separate cleanup ticket
fixes the source's non-const `IconData` usage. CI mirrors this flag.

## Common Pitfalls

- Phase routers may shadow each other if paths overlap (e.g., `/users/me/security`)
- The classes that used to live in `main.dart` (60+ widgets / models / theme code) were extracted in Sprint 7 into `apex_finance/lib/core/`, `screens/`, `widgets/`. Future refactors should keep `main.dart` minimal and **split per concern**, not pile back into one file. The split history is on branch `sprint-7/g-a1-split-main-dart` (PR merged 2026-04-30) if you need to understand the original coupling.
- The Copilot service uses Claude API with hardcoded fallback responses when API key is missing
- Phase model `init_db()` functions are called at startup via lifespan -- if one fails, others still run
- Social auth (Google/Apple) tokens **are** validated. `app/core/social_auth_verify.py` (Wave 1 PR#2/PR#3) verifies Google id_tokens via `google-auth.verify_oauth2_token()` against Google's JWKs, and Apple identity_tokens via `PyJWT` + `PyJWKClient` against `https://appleid.apple.com/auth/keys` (audience + issuer + signature checks). Production needs `GOOGLE_OAUTH_CLIENT_ID` + `APPLE_CLIENT_ID` env vars; dev mode allows a logged dev-bypass when they're unset so integration tests stay green. Coverage in `tests/test_social_auth.py` + `tests/test_social_auth_verify.py` (26 cases).
- SMS verification uses pluggable backends in `app/core/sms_backend.py`: Unifonic (Saudi +966), Twilio (international), Console (dev/test). OTP storage in `app/core/otp_store.py` with TTL=5min + attempt limit=5 + hash-at-rest. Backend selected via `SMS_BACKEND` env var (default `console` — logs only, never sends). Coverage: `tests/test_sms_otp.py` (10 cases passing).
- **Migration management (post-Sprint 12, G-A3.1 closed 2026-05-03):**
  - Schema changes are managed via **alembic**. Run
    `alembic revision --autogenerate -m "..."` to generate a new
    migration; alembic + `create_all()` coexist on production but
    **alembic is authoritative**.
  - **Render production env:** `RUN_MIGRATIONS_ON_STARTUP=true`
    (default; flipped from `false` on 2026-05-03 after G-A3.1 Phase 2b
    stamped production at head `g1e2b4c9f3d8`).
  - **Local dev:** `app/main.py` `_run_startup()` calls
    `run_migrations_on_startup()` which honors the env var. Default
    in dev is to skip alembic (no-op without `RUN_MIGRATIONS_ON_STARTUP=true`);
    set the var to `true` to test migration paths locally.
  - **Autogenerate is safe:** `alembic/env.py:_MODEL_MODULES` was
    expanded 20 → 37 entries in Phase 2a (PR #135) so
    `target_metadata = PhaseBase.metadata` reflects every model
    registered anywhere in the codebase. The verification gate at
    Phase 2a merge required ZERO `op.create_table` AND ZERO
    `op.drop_table` against a fresh `create_all`-built local DB — that
    bar holds. Future `alembic revision --autogenerate` produces
    clean diffs; spurious DROPs against `pilot_*` / `knowledge_*` /
    `copilot_*` are no longer possible.
  - **Historical context (resolved):** alembic originally covered only
    25 of 198 tables (12%). The 173 untracked tables (`clients`,
    `analysis_*`, `audit_*`, `archive_*`, `bank_feed_*`, most of
    post-Phase-2 schema) worked via `create_all()` but were invisible
    to alembic autogenerate. G-A3.1's resolution path was
    "stamp + expand `_MODEL_MODULES`", not a full catch-up migration —
    the catch-up migration approach was empirically proven dangerous
    in Phase 1 (104 spurious `op.drop_table` proposed). The historical
    drift is now closed; alembic sees the same tables `create_all`
    builds.
  - **Knowledge Brain runs on a separate database** (`KB_DATABASE_URL`)
    with its own `Base` (`app.knowledge_brain.models.db_models.Base`).
    Alembic targets only `PhaseBase.metadata`. KB schema is still
    managed by `create_all()` against the KB engine — this is by
    design, not a gap.
  - See `APEX_BLUEPRINT/09 § 2 G-A3.1` (full closure history with
    Sprint 11 incident, workaround retirement, and the psycopg2
    execution divergence) and `§ 12 G-PROC-4` (workaround discipline
    pattern, registry now empty).
