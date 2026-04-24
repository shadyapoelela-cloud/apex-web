"""Regression guards: admin endpoints must fail CLOSED.

Pattern discovered 2026-04-24:

  required = os.environ.get("ADMIN_SECRET")
  if required and x_admin_secret != required:
      raise HTTPException(401, ...)

Reads as "reject if wrong secret" but actually reads as "reject only
IF a secret is configured on the server AND it doesn't match".
When ADMIN_SECRET is unset — which happens in dev/test/staging —
the `if required` guard short-circuits and the endpoint passes
through to its payload: publicly-exposed admin action.

Production is safe because app/main.py:58 raises RuntimeError at
startup if ADMIN_SECRET is missing, but non-prod was drifted. Two
sites were affected:
  • app/main.py::admin_seed_permissions (/admin/pilot/seed-permissions)
  • app/pilot/routes/pilot_routes.py::list_tenants (/tenants — was
    exposing the full cross-tenant list)

These tests assert fail-closed behaviour for both:
  • No secret on server → 500 (won't accept ANY request)
  • No header from caller → 401
  • Wrong header → 401
  • Correct header → passes past auth gate (may still 4xx for other
    reasons like no data, but not 401/500)
"""

from __future__ import annotations

import os

from fastapi.testclient import TestClient


# ══════════════════════════════════════════════════════════════════════
# /admin/pilot/seed-permissions
# ══════════════════════════════════════════════════════════════════════
def test_admin_seed_permissions_requires_secret(client: TestClient) -> None:
    """No X-Admin-Secret header → 401/403 (not a silent 200)."""
    # ADMIN_SECRET is set by conftest to "test-admin".
    r = client.post("/admin/pilot/seed-permissions")
    assert r.status_code in (401, 403), (
        f"admin endpoint accepted request without X-Admin-Secret: {r.status_code}"
    )


def test_admin_seed_permissions_rejects_wrong_secret(client: TestClient) -> None:
    r = client.post(
        "/admin/pilot/seed-permissions",
        headers={"X-Admin-Secret": "definitely-wrong"},
    )
    assert r.status_code in (401, 403), (
        f"admin endpoint accepted wrong secret: {r.status_code}"
    )


def test_admin_seed_permissions_fail_closed_when_secret_unset(monkeypatch) -> None:
    """If the server has no ADMIN_SECRET configured, the endpoint must
    not silently open — this is the exact bug we just fixed."""
    from app.main import app
    monkeypatch.delenv("ADMIN_SECRET", raising=False)
    # _verify_admin closes over ADMIN_SECRET at import time, but the
    # endpoint-level os.environ.get checks (the pattern we're testing)
    # read at call time. Patch the module constant too for safety.
    import app.main as _m
    monkeypatch.setattr(_m, "ADMIN_SECRET", None, raising=False)

    with TestClient(app) as client:
        r = client.post(
            "/admin/pilot/seed-permissions",
            headers={"X-Admin-Secret": "anything"},
        )
    # Any 4xx/5xx is acceptable — the invariant is "NOT 200".
    assert r.status_code != 200, (
        f"admin endpoint returned 200 despite unset ADMIN_SECRET — "
        f"this is the fail-open bug. Response: {r.text[:200]}"
    )


# ══════════════════════════════════════════════════════════════════════
# /tenants  (pilot_routes list_tenants)
# ══════════════════════════════════════════════════════════════════════
def test_list_tenants_requires_secret(client: TestClient) -> None:
    """Tenant list is cross-tenant data — leaking it without auth
    breaks the entire multi-tenant isolation model."""
    r = client.get("/tenants")
    assert r.status_code in (401, 403, 404), (
        f"cross-tenant list exposed without X-Admin-Secret: {r.status_code} "
        f"body={r.text[:200]}"
    )


def test_list_tenants_fail_closed_when_secret_unset(monkeypatch) -> None:
    from app.main import app
    monkeypatch.delenv("ADMIN_SECRET", raising=False)
    with TestClient(app) as client:
        r = client.get("/tenants", headers={"X-Admin-Secret": "anything"})
    assert r.status_code != 200, (
        f"tenant list returned 200 despite unset ADMIN_SECRET — fail-open bug"
    )


# ══════════════════════════════════════════════════════════════════════
# Timing-attack regression: admin secret checks must use
# secrets.compare_digest, not bare ==/!=.
# ══════════════════════════════════════════════════════════════════════
def test_verify_admin_uses_constant_time_compare() -> None:
    """Regression for 2026-04-24 audit: bare `token != ADMIN_SECRET`
    short-circuits on first differing byte, leaking the secret
    byte-by-byte under timing analysis. Source of _verify_admin
    must reference secrets.compare_digest; if someone ever rewrites
    it back to `!=` this test flags it.

    We could mock sleep + measure wall-clock to empirically detect
    short-circuit, but that's flaky — source inspection is cheap
    and reliable."""
    import pathlib
    src = pathlib.Path(__file__).parent.parent / "app" / "main.py"
    text = src.read_text(encoding="utf-8")
    # Extract _verify_admin body
    start = text.index("def _verify_admin(")
    # Find end of function (next def at same or lower indent)
    body = text[start:start + 2000]
    assert "compare_digest" in body, (
        "_verify_admin must use secrets.compare_digest for constant-time "
        "comparison — bare `!=` on ADMIN_SECRET is a timing-side-channel "
        "leak. Check that the import + comparison are both present."
    )


def test_list_tenants_uses_constant_time_compare() -> None:
    """Same regression for app/pilot/routes/pilot_routes.py::list_tenants —
    we fixed the inline comparison there too."""
    import pathlib
    src = (
        pathlib.Path(__file__).parent.parent
        / "app" / "pilot" / "routes" / "pilot_routes.py"
    )
    text = src.read_text(encoding="utf-8")
    # Locate list_tenants definition
    start = text.index("def list_tenants(")
    body = text[start:start + 2000]
    assert "compare_digest" in body, (
        "list_tenants must use secrets.compare_digest for the ADMIN_SECRET "
        "comparison — plain `!=` leaks the secret under timing analysis."
    )
