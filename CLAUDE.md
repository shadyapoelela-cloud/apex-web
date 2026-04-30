# APEX Financial Platform -- Project Rules

## Architecture

- **Backend**: FastAPI (Python 3.11), modular phase-based architecture (Phases 1-11 + Sprints 1-6)
- **Frontend**: Flutter Web (Dart), Riverpod state management, GoRouter navigation (37 routes)
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

- **~1,784 automated tests** collected across the `tests/` tree (verified
  2026-04-30 via `pytest tests/ --collect-only -q`). The count grew over
  Phases 1-11 and Sprints 1-7; an earlier "204 tests" figure that lived here
  was retired by G-DOCS-1 (Sprint 8). Highlights of long-running suites:
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

## Common Pitfalls

- Phase routers may shadow each other if paths overlap (e.g., `/users/me/security`)
- The classes that used to live in `main.dart` (60+ widgets / models / theme code) were extracted in Sprint 7 into `apex_finance/lib/core/`, `screens/`, `widgets/`. Future refactors should keep `main.dart` minimal and **split per concern**, not pile back into one file. The split history is on branch `sprint-7/g-a1-split-main-dart` (PR merged 2026-04-30) if you need to understand the original coupling.
- The Copilot service uses Claude API with hardcoded fallback responses when API key is missing
- Phase model `init_db()` functions are called at startup via lifespan -- if one fails, others still run
- Social auth (Google/Apple) tokens **are** validated. `app/core/social_auth_verify.py` (Wave 1 PR#2/PR#3) verifies Google id_tokens via `google-auth.verify_oauth2_token()` against Google's JWKs, and Apple identity_tokens via `PyJWT` + `PyJWKClient` against `https://appleid.apple.com/auth/keys` (audience + issuer + signature checks). Production needs `GOOGLE_OAUTH_CLIENT_ID` + `APPLE_CLIENT_ID` env vars; dev mode allows a logged dev-bypass when they're unset so integration tests stay green. Coverage in `tests/test_social_auth.py` + `tests/test_social_auth_verify.py` (26 cases).
- SMS verification uses pluggable backends in `app/core/sms_backend.py`: Unifonic (Saudi +966), Twilio (international), Console (dev/test). OTP storage in `app/core/otp_store.py` with TTL=5min + attempt limit=5 + hash-at-rest. Backend selected via `SMS_BACKEND` env var (default `console` — logs only, never sends). Coverage: `tests/test_sms_otp.py` (10 cases passing).
- Alembic configured with 7 migrations covering **25 of 198 distinct tables**
  (knowledge_brain 14, HR/AP 6, infra 4, ai_usage_log 1; the remaining 3 migrations
  add RLS policies / constraints / dimensions only). Full schema is currently
  managed by `Base.metadata.create_all()` in `app/main.py` `_run_startup()`. Catch-up
  tracked as G-A3.1 (Sprint 8, DBA-reviewed). **Do NOT replace `create_all()` with
  `alembic upgrade head` until G-A3.1 ships** — would deploy production with **173
  missing tables** (`clients`, `analysis_*`, `audit_*`, `archive_*`, `bank_feed_*`,
  and most of the post-Phase-2 schema). Earlier figures in this file said
  "108 tables / 83 uncovered"; both were stale and were corrected by G-DOCS-1.
