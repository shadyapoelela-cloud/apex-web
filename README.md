# APEX Financial Platform

A comprehensive bilingual (Arabic/English) financial management platform built for enterprise accounting, HR, payroll, and business intelligence.

## Architecture

| Layer | Technology |
|-------|-----------|
| **Backend** | FastAPI (Python 3.11), modular phase-based architecture |
| **Frontend** | Flutter Web (Dart), Riverpod state management, GoRouter |
| **Database** | PostgreSQL + SQLAlchemy ORM |
| **Auth** | JWT (HS256) + bcrypt password hashing |
| **AI** | Anthropic Claude API (Knowledge Brain + Copilot) |
| **Deployment** | Render.com |

The backend is organized into phases (1-11) and sprints (1-6), each in its own `app/phaseN/` or `app/sprintN/` directory with `models/`, `routes/`, and `services/` subdirectories.

## Quick Start

### Prerequisites

- Python 3.11+
- PostgreSQL (or SQLite for local dev)
- Flutter SDK (for frontend)

### Backend Setup

```bash
# Clone the repository
git clone https://github.com/your-org/apex-app.git
cd apex-app

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Copy environment config
cp .env.example .env
# Edit .env with your values

# Run the server
uvicorn app.main:app --reload --port 8000
```

### Frontend Setup

```bash
cd apex_finance
flutter pub get
flutter run -d chrome
```

> **First-time local setup?** See [`LOCAL_DEV_RUNBOOK.md`](LOCAL_DEV_RUNBOOK.md) — covers the
> `--dart-define=API_BASE=http://127.0.0.1:8000` flag (REQUIRED to point Flutter at
> your local backend instead of the production Render URL baked into
> `apex_finance/lib/core/api_config.dart`), test-user creation, port conflicts,
> the `127.0.0.1` vs `localhost` IPv6 trap, and the Python 3.14 `pandas` caveat.
> The plain `flutter run -d chrome` above will silently talk to **production** —
> use the runbook (or the `scripts/dev/` wrappers) for any real local work.

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `DATABASE_URL` | PostgreSQL connection string | SQLite fallback |
| `KB_DATABASE_URL` | Knowledge Brain database | Uses `DATABASE_URL` |
| `JWT_SECRET` | JWT signing key | Must override in prod |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Token lifetime | `60` |
| `REFRESH_TOKEN_EXPIRE_DAYS` | Refresh token lifetime | `30` |
| `ADMIN_SECRET` | Admin endpoint authentication | Must override in prod |
| `CORS_ORIGINS` | Allowed origins (comma-separated) | `*` |
| `ANTHROPIC_API_KEY` | Claude AI for Knowledge Brain | Required for AI features |
| `OPENAI_API_KEY` | OpenAI integration | Optional |

See `.env.example` for a complete template.

## API Documentation

Once the server is running, interactive API docs are available at:

- **Swagger UI**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **ReDoc**: [http://localhost:8000/redoc](http://localhost:8000/redoc)
- **Health Check**: [http://localhost:8000/health](http://localhost:8000/health)

## Running Tests

```bash
# Install test dependencies
pip install pytest httpx pytest-asyncio

# Run all tests
pytest tests/ -v

# Run a specific test file
pytest tests/test_core.py -v
```

## Deployment

The platform is configured for deployment on [Render.com](https://render.com):

- `render.yaml` defines the web service and PostgreSQL database
- Health checks hit `/health` to verify the service is running
- CI/CD via GitHub Actions (`.github/workflows/ci.yml`) runs tests on push and triggers deploy on merge to `main`

### Docker

```bash
docker build -t apex-api .
docker run -p 8000:8000 --env-file .env apex-api
```

The Dockerfile runs as a non-root user (`apex`) and includes a health check.

## Version History

| Version | Highlights |
|---------|-----------|
| **v11.6** | Float → Numeric(18,2) for all financial fields; VAT/currency on Client; journal entry sequence; audit trail; tiered rate limiting; prod-mandatory secrets; ZATCA readiness |
| **v11.5** | 11 Phases + 7 Sprints feature-complete; Copilot + KB streaming |
| **v10.7** | Security hardening, Docker non-root user, CI deploy pipeline |
| **v10.6** | Infrastructure: Dockerfile, render.yaml, CI workflow, .env.example |
| **v10.5** | Test suite foundation, comprehensive test_core.py |
| **v10.4** | Copilot AI service with persistent database storage |
| **v10.3** | Startup reliability, eliminate bare except blocks |
| **v10.2** | Architecture cleanup, remove `import *`, CORS config, proper logging |
| **v10.1** | Knowledge Brain AI integration |
| **v10.0** | Platform consolidation, phase-based architecture |
| **v9.x** | Legacy versions (DB persistence, import cleanup, startup fixes) |

## Project Structure

```
apex-app/
  app/
    main.py          # FastAPI entry point, router registration
    core.py          # Database engine, shared utilities
    phase1/          # User management, authentication
    phase2/          # Onboarding, service catalog, archives
    phase3/          # Advanced financial modules
    ...
    copilot/         # AI Copilot service
    knowledge_brain/ # AI Knowledge Brain
  apex_finance/      # Flutter frontend
  tests/             # Test suite
  .github/workflows/ # CI/CD pipeline
```

## License

Proprietary. All rights reserved.
