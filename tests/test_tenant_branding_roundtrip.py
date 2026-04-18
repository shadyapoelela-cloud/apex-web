"""Integration tests for tenant_branding backend.

Verifies the round-trip the Flutter ApexWhiteLabelConnected widget
makes against /api/v1/tenant/branding:
  • GET returns defaults when no row exists
  • PUT stores an admin-supplied config when tenant context is set
  • Subsequent GET returns the stored config
  • Bad hex codes get a 422 from the Pydantic validator
"""

from __future__ import annotations

import uuid


def _tenant_headers(tid: str) -> dict:
    """Use the X-Tenant-Id header that the TenantContextMiddleware reads."""
    return {"X-Tenant-Id": tid}


def test_get_returns_defaults_for_fresh_tenant(client):
    tid = f"t-{uuid.uuid4().hex[:8]}"
    resp = client.get("/api/v1/tenant/branding", headers=_tenant_headers(tid))
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["brand_text"] == "APEX"
    assert data["primary_hex"].upper() == "#D4AF37"
    assert data["dark_mode"] is True


def test_put_with_tenant_stores_and_get_reads_back(client):
    tid = f"t-{uuid.uuid4().hex[:8]}"
    payload = {
        "brand_text": "Red & Co",
        "primary_hex": "#E11D48",
        "secondary_hex": "#0EA5E9",
        "dark_mode": False,
        "radius_scale": 1.2,
        "type_scale": 0.95,
        "logo_url": "https://example.com/logo.png",
    }
    put = client.put(
        "/api/v1/tenant/branding", json=payload, headers=_tenant_headers(tid)
    )
    assert put.status_code == 200, put.text
    put_data = put.json()["data"]
    assert put_data["brand_text"] == "Red & Co"
    assert put_data["primary_hex"] == "#E11D48"

    # Read back in same tenant — should see what we just wrote.
    g = client.get("/api/v1/tenant/branding", headers=_tenant_headers(tid))
    assert g.status_code == 200
    d = g.json()["data"]
    assert d["brand_text"] == "Red & Co"
    assert d["primary_hex"] == "#E11D48"
    assert d["dark_mode"] is False
    assert abs(d["radius_scale"] - 1.2) < 1e-6


def test_put_rejects_bad_hex_with_422(client):
    tid = f"t-{uuid.uuid4().hex[:8]}"
    bad = {
        "brand_text": "X",
        "primary_hex": "not-a-colour",
        "secondary_hex": "#00FF00",
        "dark_mode": True,
        "radius_scale": 1.0,
        "type_scale": 1.0,
    }
    resp = client.put(
        "/api/v1/tenant/branding", json=bad, headers=_tenant_headers(tid)
    )
    assert resp.status_code == 422


def test_put_is_upsert_not_duplicate_insert(client):
    """Second PUT updates the existing row — no duplicate key error."""
    tid = f"t-{uuid.uuid4().hex[:8]}"
    base = {
        "brand_text": "First",
        "primary_hex": "#111111",
        "secondary_hex": "#222222",
        "dark_mode": True,
        "radius_scale": 1.0,
        "type_scale": 1.0,
    }
    r1 = client.put(
        "/api/v1/tenant/branding", json=base, headers=_tenant_headers(tid)
    )
    assert r1.status_code == 200

    updated = dict(base, brand_text="Second", primary_hex="#333333")
    r2 = client.put(
        "/api/v1/tenant/branding", json=updated, headers=_tenant_headers(tid)
    )
    assert r2.status_code == 200
    assert r2.json()["data"]["brand_text"] == "Second"

    g = client.get("/api/v1/tenant/branding", headers=_tenant_headers(tid))
    assert g.json()["data"]["brand_text"] == "Second"


def test_each_tenant_sees_only_its_own_branding(client):
    """Two tenants save different brandings — each sees its own."""
    t1 = f"t-{uuid.uuid4().hex[:8]}"
    t2 = f"t-{uuid.uuid4().hex[:8]}"
    p1 = {
        "brand_text": "Tenant One",
        "primary_hex": "#111111",
        "secondary_hex": "#222222",
        "dark_mode": True,
        "radius_scale": 1.0,
        "type_scale": 1.0,
    }
    p2 = dict(p1, brand_text="Tenant Two", primary_hex="#AAAAAA")
    client.put("/api/v1/tenant/branding", json=p1, headers=_tenant_headers(t1))
    client.put("/api/v1/tenant/branding", json=p2, headers=_tenant_headers(t2))

    g1 = client.get("/api/v1/tenant/branding", headers=_tenant_headers(t1))
    g2 = client.get("/api/v1/tenant/branding", headers=_tenant_headers(t2))
    assert g1.json()["data"]["brand_text"] == "Tenant One"
    assert g2.json()["data"]["brand_text"] == "Tenant Two"
