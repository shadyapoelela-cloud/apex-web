"""
APEX Platform -- Authentication tests
"""

import uuid
import pytest


def _unique_user():
    """Generate unique user data for each test."""
    uid = uuid.uuid4().hex[:8]
    return {
        "username": f"testuser_{uid}",
        "email": f"test_{uid}@example.com",
        "password": "TestPass123",
        "display_name": f"Test User {uid}",
    }


def test_register_valid(client):
    user = _unique_user()
    response = client.post("/auth/register", json=user)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True


def test_register_duplicate_username(client):
    user = _unique_user()
    # First registration should succeed
    resp1 = client.post("/auth/register", json=user)
    assert resp1.status_code == 200
    # Second registration with same data should fail
    resp2 = client.post("/auth/register", json=user)
    assert resp2.status_code == 400


def test_login_valid_credentials(client):
    user = _unique_user()
    client.post("/auth/register", json=user)
    login_data = {
        "username_or_email": user["username"],
        "password": user["password"],
    }
    response = client.post("/auth/login", json=login_data)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    # Token may be at data["tokens"]["access_token"] or data["access_token"]
    tokens = data.get("tokens", data.get("data", {}).get("tokens", {}))
    assert "access_token" in tokens


def test_login_invalid_credentials(client):
    login_data = {
        "username_or_email": "nonexistent_user_xyz",
        "password": "WrongPass999",
    }
    response = client.post("/auth/login", json=login_data)
    assert response.status_code == 401


def test_protected_endpoint_without_token(client):
    response = client.get("/users/me")
    assert response.status_code == 401
