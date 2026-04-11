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

- `main.dart` is the monolith (~3500 lines) -- avoid adding more classes to it
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

- **120+ automated tests** in `tests/` directory:
  - `test_integration_v10.py`: 93 comprehensive integration tests
  - `test_auth.py`: Authentication flow tests
  - `test_admin.py`: Admin endpoint tests
  - `test_health.py`: Health check tests
  - `test_utils.py`: Utility function tests
- Run: `pytest tests/ -v`
- CI/CD: GitHub Actions (`.github/workflows/ci.yml`) runs tests on every push
- Coverage: ~14% endpoint coverage (P2-P8 need more tests)

## Common Pitfalls

- Phase routers may shadow each other if paths overlap (e.g., `/users/me/security`)
- `main.dart` has 60+ tightly coupled classes -- splitting requires careful dependency analysis
- The Copilot service uses Claude API with hardcoded fallback responses when API key is missing
- Phase model `init_db()` functions are called at startup via lifespan -- if one fails, others still run
- Social auth (Google/Apple) tokens are NOT validated -- stubs only (production requires real validation)
- SMS verification endpoints are stubs -- always return success
- Alembic is configured but has no migration files yet -- schema created at startup via SQLAlchemy
