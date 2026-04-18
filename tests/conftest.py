"""
APEX Platform -- Shared pytest fixtures
"""

import os
import pytest

# Set test environment variables BEFORE any app imports
os.environ["DATABASE_URL"] = "sqlite:///test.db"
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
    """Create all tables once for the test session."""
    try:
        from app.phase1.models.platform_models import Base, engine

        Base.metadata.create_all(bind=engine)
    except Exception:
        pass
    yield
    # Cleanup: try to remove test.db after session
    try:
        if os.path.exists("test.db"):
            os.remove("test.db")
    except OSError:
        pass  # File may be locked on Windows


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
