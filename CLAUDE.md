# APEX Financial Platform -- Project Rules

## Architecture

- **Backend**: FastAPI (Python), modular phase-based architecture (Phases 1-11 + Sprints 1-6)
- **Frontend**: Flutter Web (Dart), Riverpod state management, GoRouter navigation
- **Database**: PostgreSQL + SQLAlchemy ORM
- **Auth**: JWT (HS256) via `JWT_SECRET` env var, bcrypt password hashing
- **Deployment**: Render.com free tier (cold-start tolerant)
- **AI**: Anthropic Claude API for Knowledge Brain + Copilot

## Backend Conventions

- Each phase lives in `app/phaseN/` with `models/`, `routes/`, `services/` subdirs
- Sprints live in `app/sprintN/`
- All phase routers are conditionally loaded in `app/main.py` via try/except flags (P1, P2, ... HAS_P7, etc.)
- Never use `from module import *` -- use explicit imports
- Admin endpoints must check `ADMIN_SECRET` env var (never hardcode secrets)
- CORS origins configurable via `CORS_ORIGINS` env var (comma-separated)
- API responses follow `{"success": bool, "data": ...}` or `{"success": bool, "error": str}` pattern
- Don't leak tracebacks to clients -- log with `logging.error()`, return generic HTTPException

## Frontend Conventions

- `main.dart` is the monolith (~3500 lines) -- avoid adding more classes to it
- Key singletons: `AC` (colors/theme), `S` (session/localStorage), `ApiService` (HTTP client)
- API base URL: `const _api` in main.dart
- Arabic RTL is the primary UI language
- All API calls go through `ApiService` which handles token injection and retry logic

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `JWT_SECRET` | JWT signing key | (hardcoded fallback -- must override in prod) |
| `ADMIN_SECRET` | Admin endpoint auth | `apex-admin-2026` |
| `CORS_ORIGINS` | Allowed origins (comma-sep) | `*` (restrict in prod) |
| `DATABASE_URL` | PostgreSQL connection string | SQLite fallback |
| `ANTHROPIC_API_KEY` | Claude AI for Knowledge Brain | (required for AI features) |

## Testing

- No test suite exists yet -- manual testing via Swagger UI at `/docs`
- Frontend tested manually via Flutter web build

## Common Pitfalls

- Phase routers may shadow each other if paths overlap (e.g., `/users/me/security` existed as static in main.py AND real in phase1_routes)
- `main.dart` has 60+ tightly coupled classes -- splitting requires careful dependency analysis
- The Copilot service (`app/copilot/`) is a stub with hardcoded responses and in-memory storage
- Phase model `init_db()` functions must be called at startup or tables won't exist
