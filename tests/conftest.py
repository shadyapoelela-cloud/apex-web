"""
APEX Platform -- Shared pytest fixtures
"""

import os
import pytest

# Set test environment variables BEFORE any app imports.
# setdefault (not =) so the cascade subprocess env injection survives
# — see G-T1.8.2 in 09 § 4 + tests/test_per_directory_coverage.py.
os.environ.setdefault("DATABASE_URL", "sqlite:///test.db")
# 32+ bytes keeps PyJWT's InsecureKeyLengthWarning quiet (PyJWT requires
# SHA-256 HMAC keys to meet the RFC 7518 §3.2 minimum). Deterministic so
# token fixtures below remain stable across test runs.
os.environ["JWT_SECRET"] = "apex-test-jwt-secret-32bytes-min-length"
# Admin secret has no length constraint (arbitrary shared secret).
# Several tests hardcode the "test-admin" string — keep it stable.
os.environ["ADMIN_SECRET"] = "test-admin"

import jwt
from datetime import datetime, timedelta, timezone
from fastapi.testclient import TestClient
from app.main import app


@pytest.fixture(scope="session", autouse=True)
def setup_test_db():
    """Create all tables once per test session on a clean DB.

    Previously this fixture only created tables; it relied on the
    (best-effort) teardown to remove ``test.db``. On Windows the file
    is often locked and the removal silently fails, so subsequent runs
    inherit state. That turned 12 deterministic tests (JE sequence,
    dimensions, ZATCA fiscal-year-isolation, audit chain) into flakes
    that failed iff you'd ever run the suite before — i.e. always in
    CI's second run or local dev.

    Fix: remove ``test.db`` at the START of the session before tables
    are created. If removal fails we fall back to truncating every
    table so at least in-suite ordering is deterministic.
    """
    try:
        if os.path.exists("test.db"):
            try:
                os.remove("test.db")
            except OSError:
                # Windows lock fallback — drop every table's rows instead.
                import sqlite3
                conn = sqlite3.connect("test.db")
                try:
                    tables = conn.execute(
                        "SELECT name FROM sqlite_master WHERE type='table'"
                    ).fetchall()
                    for (name,) in tables:
                        try:
                            conn.execute(f'DELETE FROM "{name}"')
                        except sqlite3.Error:
                            pass
                    conn.commit()
                finally:
                    conn.close()
    except Exception:
        pass  # Never block the suite on pre-clean failure.

    try:
        from app.phase1.models.platform_models import Base, engine

        Base.metadata.create_all(bind=engine)
    except Exception:
        pass
    yield
    # Best-effort teardown (may be locked on Windows — pre-run cleanup
    # above is now the real guarantee).
    try:
        if os.path.exists("test.db"):
            os.remove("test.db")
    except OSError:
        pass


@pytest.fixture()
def client():
    """FastAPI TestClient."""
    with TestClient(app) as c:
        yield c


@pytest.fixture()
def db_session():
    """Create a test database session. Caller must close."""
    from app.phase1.models.platform_models import SessionLocal

    session = SessionLocal()
    yield session
    session.rollback()
    session.close()


@pytest.fixture()
def auth_header():
    """Return a valid JWT Authorization header for testing authenticated endpoints."""
    payload = {
        "sub": "test-user-id-123",
        "username": "testuser",
        "roles": ["registered_user"],
        "type": "access",
        "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        "iat": datetime.now(timezone.utc),
    }
    token = jwt.encode(payload, os.environ["JWT_SECRET"], algorithm="HS256")
    return {"Authorization": f"Bearer {token}"}
