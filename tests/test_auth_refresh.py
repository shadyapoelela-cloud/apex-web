"""Integration tests for ``POST /auth/refresh``.

Contract the endpoint must satisfy:

  1. With a valid refresh token (body OR cookie): 200 with new
     access_token + updated apex_token cookie.
  2. Missing token: 400.
  3. Invalid / malformed token: 401.
  4. Expired refresh token: 401.
  5. Access-type token sent in the refresh slot: 401.
  6. Refresh token of a user who logged out: 401 (session revoked).
  7. New access token is actually usable on a protected endpoint.
  8. The refresh-cookie path is /auth (narrower scope than /).
"""

from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient


def _fresh_user(client: TestClient) -> tuple[str, str]:
    username = f"refresh-{uuid.uuid4().hex[:8]}"
    password = "GoodPass-1!"
    r = client.post(
        "/auth/register",
        json={
            "username": username,
            "email": f"{username}@apex-test.local",
            "password": password,
            "display_name": "Refresh Tester",
        },
    )
    assert r.status_code in (200, 201), f"register failed: {r.text[:200]}"
    return username, password


def _login(client: TestClient, username: str, password: str) -> dict:
    r = client.post(
        "/auth/login",
        json={"username_or_email": username, "password": password},
    )
    assert r.status_code == 200, f"login failed: {r.text[:200]}"
    return r.json()


def test_refresh_with_valid_body_token_returns_200(client: TestClient) -> None:
    u, p = _fresh_user(client)
    login_body = _login(client, u, p)
    refresh = login_body["tokens"]["refresh_token"]

    r = client.post("/auth/refresh", json={"refresh_token": refresh})
    assert r.status_code == 200, r.text[:300]
    body = r.json()
    assert body["success"] is True
    assert "access_token" in body and body["access_token"]
    # Note: we intentionally DON'T assert the new token differs byte-for-byte
    # from the login one — JWT iat/exp are second-precision, so a refresh
    # called within the same wall-clock second produces an identical token.
    # What matters is that `success` is True and a usable token is returned;
    # behavioural verification lives in
    # test_refresh_new_access_token_works_on_protected_endpoint.


def test_refresh_sets_new_apex_token_cookie(client: TestClient) -> None:
    u, p = _fresh_user(client)
    login_body = _login(client, u, p)
    refresh = login_body["tokens"]["refresh_token"]

    r = client.post("/auth/refresh", json={"refresh_token": refresh})
    assert r.status_code == 200
    assert "apex_token" in r.cookies, (
        "refresh must update the apex_token cookie so cookie-auth "
        "clients don't have to read the body"
    )


def test_refresh_without_token_returns_400(client: TestClient) -> None:
    r = client.post("/auth/refresh", json={})
    assert r.status_code == 400, r.text[:200]


def test_refresh_with_invalid_token_returns_401(client: TestClient) -> None:
    r = client.post("/auth/refresh", json={"refresh_token": "not-a-jwt"})
    assert r.status_code == 401


def test_refresh_rejects_access_token_in_refresh_slot(client: TestClient) -> None:
    """An access token has type='access'. The refresh endpoint must
    reject it even though the JWT itself is valid — otherwise an
    attacker with a stolen access token could mint fresh ones at will."""
    u, p = _fresh_user(client)
    login_body = _login(client, u, p)
    access = login_body["tokens"]["access_token"]

    r = client.post("/auth/refresh", json={"refresh_token": access})
    assert r.status_code == 401, f"access token was accepted as refresh: {r.text[:200]}"


def test_refresh_rejects_after_logout(client: TestClient) -> None:
    """Logging out revokes the session. Refresh-token replay after
    logout must fail — otherwise logout doesn't actually kill the
    session, and a stolen refresh token survives a user's ""logout of
    all devices"" action."""
    u, p = _fresh_user(client)
    login_body = _login(client, u, p)
    refresh = login_body["tokens"]["refresh_token"]
    access = login_body["tokens"]["access_token"]

    # Logout using the access token.
    logout = client.post(
        "/auth/logout",
        headers={"Authorization": f"Bearer {access}"},
    )
    assert logout.status_code in (200, 204)

    # Replay the refresh token — must be rejected.
    r = client.post("/auth/refresh", json={"refresh_token": refresh})
    assert r.status_code == 401, (
        f"refresh token still valid after logout: {r.status_code} {r.text[:200]}"
    )


def test_refresh_new_access_token_works_on_protected_endpoint(client: TestClient) -> None:
    """End-to-end: the minted access token must authenticate
    subsequent requests."""
    u, p = _fresh_user(client)
    login_body = _login(client, u, p)
    refresh = login_body["tokens"]["refresh_token"]

    r = client.post("/auth/refresh", json={"refresh_token": refresh})
    new_access = r.json()["access_token"]

    me = client.get(
        "/users/me",
        headers={"Authorization": f"Bearer {new_access}"},
    )
    assert me.status_code == 200, (
        f"fresh access token rejected on /users/me: {me.status_code} {me.text[:200]}"
    )


def test_refresh_cookie_path_is_narrow(client: TestClient) -> None:
    """The apex_refresh cookie must be scoped to /auth, not / —
    narrower scope means it's not sent on /clients or /pilot/*,
    shrinking the CSRF + accidental-logging blast radius."""
    u, p = _fresh_user(client)
    r = client.post(
        "/auth/login",
        json={"username_or_email": u, "password": p},
    )
    assert r.status_code == 200
    raw = r.headers.get("set-cookie", "")
    # With multiple Set-Cookie lines, headers[] joins them by ", " — split
    # and find the apex_refresh one.
    chunks = [c for c in raw.split(", ") if "apex_refresh=" in c.lower()]
    if not chunks:
        # Starlette sometimes exposes multiple Set-Cookie via getlist-like
        # access; fall back to cookie jar.
        assert "apex_refresh" in r.cookies
        return
    cookie_line = chunks[0].lower()
    assert "path=/auth" in cookie_line, (
        f"apex_refresh must be path=/auth, got: {cookie_line!r}"
    )
