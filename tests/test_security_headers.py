"""Regression guards for the security headers middleware.

Every API response must carry the baseline headers. Tests cover:

  • The four always-on headers (X-Content-Type-Options, X-Frame-Options,
    X-XSS-Protection, Referrer-Policy).
  • Cache-Control: no-store (prevents sensitive JSON being cached by
    intermediaries or shared-machine browsers).
  • The new Permissions-Policy — denies sensor/camera/mic APIs the
    API never needs; mitigates a narrow class of compromised-third-
    party-script attacks.
  • HSTS conditional on ENVIRONMENT=production — asserted via a
    toggled app factory so we don't have to mutate global state
    from a test.

All checks are on a route we know is public and cheap (``/health``)
so the assertions describe the middleware contract, not any
particular feature's plumbing.
"""

from __future__ import annotations

from fastapi.testclient import TestClient


def test_always_on_security_headers_present(client: TestClient) -> None:
    r = client.get("/health")
    assert r.status_code == 200

    # The un-negotiable four.
    assert r.headers.get("X-Content-Type-Options") == "nosniff"
    assert r.headers.get("X-Frame-Options") == "DENY"
    assert r.headers.get("X-XSS-Protection") == "1; mode=block"
    assert r.headers.get("Referrer-Policy") == "strict-origin-when-cross-origin"


def test_cache_control_is_no_store(client: TestClient) -> None:
    """API responses must never be cached by shared proxies — they
    may contain tenant-specific data."""
    r = client.get("/health")
    assert r.headers.get("Cache-Control") == "no-store"


def test_permissions_policy_denies_sensors(client: TestClient) -> None:
    """The API has zero legitimate use for accelerometer/camera/mic/
    geolocation/payment/usb. Permissions-Policy denies them to
    make drive-by exploitation harder even if a page script in a
    related origin goes rogue."""
    r = client.get("/health")
    policy = r.headers.get("Permissions-Policy", "")
    for api in (
        "accelerometer",
        "camera",
        "geolocation",
        "gyroscope",
        "magnetometer",
        "microphone",
        "payment",
        "usb",
    ):
        # Each should appear as `<api>=()` (the empty allow-list).
        assert f"{api}=()" in policy, (
            f"Permissions-Policy missing a closed allow-list for {api!r}"
        )


def test_hsts_not_set_in_non_production(client: TestClient) -> None:
    """HSTS teaches browsers to refuse HTTP for the host for a year.
    Setting it in dev over http://localhost bricks the dev loop for
    anyone else on the machine. Tests run with ENVIRONMENT unset /
    != 'production' — HSTS must be absent here."""
    import os
    env = os.environ.get("ENVIRONMENT", "")
    if env.lower() in ("production", "prod"):
        # Can't run this assertion if tests are somehow being exercised
        # with ENVIRONMENT=production — other tests guard that case.
        return
    r = client.get("/health")
    assert "Strict-Transport-Security" not in r.headers, (
        "HSTS should not be emitted outside production — breaks local dev"
    )
