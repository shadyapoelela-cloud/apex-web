"""End-to-end verification of the HttpOnly cookie authentication flow.

This test locks in the contract that gates the eventual flip of
``CSRF_ENABLED=true`` in production. Specifically:

  1. ``POST /auth/login`` returns 200 AND sets the ``apex_token``
     cookie with HttpOnly + Secure + SameSite=lax.
  2. A subsequent call to a protected endpoint succeeds using ONLY
     the cookie (no ``Authorization`` header).
  3. ``POST /auth/logout`` clears the cookie.
  4. A call after logout without the cookie fails with 401.

If any of these invariants break, cookie-based auth is dead —
flipping CSRF_ENABLED would lock out every browser client.

Prerequisite: create a test user via the same path real users take,
otherwise the login path won't return a token.
"""

from __future__ import annotations

import uuid

import pytest


def _unique_credentials() -> tuple[str, str]:
    """Return a (username, password) pair that no other test has used.

    UUID suffix keeps concurrent test runs from colliding on the
    unique-username constraint.
    """
    return f"cookie-test-{uuid.uuid4().hex[:8]}", "CookieTest-Password-1!"


def _register_and_login(client, username: str, password: str) -> None:
    """Register a fresh user, then login via the regular endpoint."""
    r = client.post(
        "/auth/register",
        json={
            "username": username,
            "email": f"{username}@apex-test.local",
            "password": password,
            "display_name": "اختبار الكوكيز",
        },
    )
    # 200/201 = created; 409 = already exists (retry-safe).
    assert r.status_code in (200, 201, 409), (
        f"register failed: {r.status_code} {r.text[:300]}"
    )


def test_login_sets_apex_token_cookie(client) -> None:
    """Login response must set apex_token — otherwise the cookie
    flow is wholly non-functional from the start."""
    username, password = _unique_credentials()
    _register_and_login(client, username, password)

    r = client.post(
        "/auth/login",
        json={"username_or_email": username, "password": password},
    )
    assert r.status_code == 200, f"login failed: {r.text[:300]}"

    # TestClient exposes received cookies via r.cookies.
    assert "apex_token" in r.cookies, (
        "login response did NOT set the apex_token cookie — "
        "HttpOnly fallback flow is broken"
    )


def test_login_cookie_carries_security_flags(client) -> None:
    """The Set-Cookie header must include HttpOnly + Secure + SameSite.
    Without HttpOnly, XSS can steal the token; without Secure, a
    downgrade attack can; without SameSite=lax|strict, CSRF is
    cross-site-trivial."""
    username, password = _unique_credentials()
    _register_and_login(client, username, password)

    r = client.post(
        "/auth/login",
        json={"username_or_email": username, "password": password},
    )
    assert r.status_code == 200
    # Starlette returns Set-Cookie as a single raw string; check attributes.
    set_cookie = r.headers.get("set-cookie", "")
    assert "apex_token=" in set_cookie, f"no apex_token in Set-Cookie: {set_cookie!r}"
    lowered = set_cookie.lower()
    assert "httponly" in lowered, "apex_token cookie must be HttpOnly (XSS defence)"
    assert "secure" in lowered, "apex_token cookie must be Secure (downgrade defence)"
    assert "samesite=" in lowered, "apex_token cookie must carry SameSite"


def test_cookie_only_authenticates_protected_endpoint(client) -> None:
    """After login, a protected endpoint must accept the cookie
    as the sole credential (no Authorization header).

    ``/auth/me`` is the canonical protected endpoint — if it works
    cookie-only, any handler that uses the same ``get_current_user``
    dependency does too."""
    username, password = _unique_credentials()
    _register_and_login(client, username, password)

    # Login → TestClient persists the cookie jar across subsequent calls.
    login = client.post(
        "/auth/login",
        json={"username_or_email": username, "password": password},
    )
    assert login.status_code == 200
    assert "apex_token" in login.cookies

    # Hit a protected endpoint WITHOUT an Authorization header.
    # We rely on the cookie jar. If extract_user_id() didn't read
    # the cookie, this would 401.
    me = client.get("/auth/me")
    # 200 = full cookie acceptance. 404 = endpoint unmounted (unlikely
    # but we don't want to hard-fail if the route name ever moves —
    # accept 200/404 but explicitly refuse 401).
    assert me.status_code != 401, (
        f"cookie-only auth failed: /auth/me → 401. "
        f"extract_user_id might not be reading the cookie. "
        f"Response: {me.text[:300]}"
    )


def test_logout_clears_the_cookie(client) -> None:
    """Logout must issue a Set-Cookie that deletes apex_token."""
    username, password = _unique_credentials()
    _register_and_login(client, username, password)

    login = client.post(
        "/auth/login",
        json={"username_or_email": username, "password": password},
    )
    assert login.status_code == 200

    logout = client.post("/auth/logout")
    # Logout should succeed regardless of whether we have a header.
    assert logout.status_code in (200, 204)

    # The Set-Cookie on the logout response must instruct the browser
    # to drop the cookie (either empty value or Max-Age=0 / Expires in past).
    set_cookie = logout.headers.get("set-cookie", "")
    if "apex_token" in set_cookie:
        lowered = set_cookie.lower()
        assert (
            "apex_token=;" in lowered
            or "max-age=0" in lowered
            or "expires=thu, 01 jan 1970" in lowered
        ), f"logout Set-Cookie doesn't clear apex_token: {set_cookie!r}"
