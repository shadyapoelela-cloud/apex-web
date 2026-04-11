"""
APEX Platform -- Provider & Marketplace Tests
==============================================
Covers: Phase 4 providers, Phase 5 marketplace,
Phase 7 task submissions, Phase 8 subscriptions.
"""

import os
import uuid
import pytest


@pytest.fixture(autouse=True)
def clear_rate_limits():
    from app.main import _rate_limits

    _rate_limits.clear()
    yield
    _rate_limits.clear()


def _register_and_login(client):
    uid = uuid.uuid4().hex[:8]
    user = {
        "username": f"prov_{uid}",
        "email": f"prov_{uid}@test.com",
        "password": "TestPass123!",
        "display_name": f"Provider {uid}",
    }
    client.post("/auth/register", json=user)
    resp = client.post("/auth/login", json={"username_or_email": user["username"], "password": user["password"]})
    tokens = resp.json().get("tokens", resp.json().get("data", {}).get("tokens", {}))
    return {"Authorization": f"Bearer {tokens.get('access_token', '')}"}


# ─── Service Providers (Phase 4) ───


class TestServiceProviders:
    def test_register_provider(self, client):
        h = _register_and_login(client)
        resp = client.post(
            "/service-providers/register",
            headers=h,
            json={"category": "accountant", "bio_ar": "محاسب قانوني", "years_experience": 5, "city": "الرياض"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_register_provider_invalid_category(self, client):
        h = _register_and_login(client)
        resp = client.post("/service-providers/register", headers=h, json={"category": "invalid_category_xyz"})
        data = resp.json()
        # Should fail — either success:false or 400/422
        if resp.status_code == 200:
            assert data.get("success") is False
        else:
            assert resp.status_code in (400, 422)

    def test_register_provider_duplicate(self, client):
        h = _register_and_login(client)
        client.post("/service-providers/register", headers=h, json={"category": "accountant"})
        resp = client.post("/service-providers/register", headers=h, json={"category": "tax_consultant"})
        data = resp.json()
        # Second registration should fail
        if resp.status_code == 200:
            assert data.get("success") is False
        else:
            assert resp.status_code in (400, 409)

    def test_get_my_provider_profile(self, client):
        h = _register_and_login(client)
        client.post("/service-providers/register", headers=h, json={"category": "accountant"})
        resp = client.get("/service-providers/me", headers=h)
        assert resp.status_code == 200

    def test_get_provider_profile_not_registered(self, client):
        h = _register_and_login(client)
        resp = client.get("/service-providers/me", headers=h)
        data = resp.json()
        if resp.status_code == 200:
            assert data.get("success") is False
        else:
            assert resp.status_code in (404, 400)

    def test_list_marketplace_providers(self, client, auth_header):
        resp = client.get("/marketplace/providers", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True
        assert isinstance(data.get("data"), list)

    def test_list_marketplace_providers_by_category(self, client, auth_header):
        resp = client.get("/marketplace/providers?category=accountant", headers=auth_header)
        assert resp.status_code == 200

    def test_verification_queue_no_auth(self, client):
        resp = client.get("/service-providers/verification-queue")
        assert resp.status_code == 401


# ─── Marketplace Requests (Phase 5) ───


class TestMarketplace:
    def test_create_service_request_no_auth(self, client):
        resp = client.post("/marketplace/requests", json={"task_type": "bookkeeping"})
        assert resp.status_code == 401

    def test_list_service_requests(self, client):
        h = _register_and_login(client)
        resp = client.get("/marketplace/requests", headers=h)
        assert resp.status_code == 200

    def test_compliance_check_invalid_provider(self, client, auth_header):
        resp = client.get("/providers/compliance/nonexistent-id", headers=auth_header)
        assert resp.status_code in (200, 404)


# ─── Task Types (Phase 7) ───


class TestTaskTypes:
    def test_get_task_types(self, client, auth_header):
        resp = client.get("/task-types", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_get_task_types_no_auth(self, client):
        resp = client.get("/task-types")
        assert resp.status_code in (200, 401)  # May not require auth


# ─── Subscriptions (Phase 8) ───


class TestSubscriptions:
    def test_get_plans(self, client):
        resp = client.get("/plans")
        assert resp.status_code == 200
        data = resp.json()
        # May return {"success":true,"data":[]} or just a list
        if isinstance(data, dict):
            assert data.get("success") is True
        else:
            assert isinstance(data, list)

    def test_get_my_subscription(self, client):
        h = _register_and_login(client)
        resp = client.get("/subscriptions/me", headers=h)
        assert resp.status_code == 200

    def test_get_entitlements(self, client):
        h = _register_and_login(client)
        resp = client.get("/entitlements/me", headers=h)
        assert resp.status_code == 200

    def test_upgrade_plan_invalid(self, client):
        h = _register_and_login(client)
        resp = client.post("/subscriptions/upgrade", headers=h, json={"plan_id": "nonexistent_plan"})
        # Should fail gracefully
        assert resp.status_code in (200, 400, 404, 422)

    def test_plans_compare(self, client, auth_header):
        resp = client.get("/plans/compare", headers=auth_header)
        assert resp.status_code in (200, 404)


# ─── Service Catalog ───


class TestServiceCatalog:
    def test_get_service_catalog(self, client):
        resp = client.get("/services/catalog")
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_get_service_catalog_by_category(self, client):
        resp = client.get("/services/catalog?category=financial")
        assert resp.status_code == 200

    def test_create_service_case_no_auth(self, client):
        resp = client.post("/services/cases", json={"client_id": "x", "service_code": "y"})
        assert resp.status_code == 401

    def test_create_service_case(self, client):
        h = _register_and_login(client)
        resp = client.post(
            "/services/cases", headers=h, json={"client_id": "test-client", "service_code": "basic_audit"}
        )
        # May fail if client doesn't exist, but should not 500
        assert resp.status_code in (200, 400, 404)

    def test_get_service_cases(self, client):
        h = _register_and_login(client)
        resp = client.get("/services/cases", headers=h)
        assert resp.status_code == 200


# ─── Audit Templates ───


class TestAuditTemplates:
    def test_get_audit_templates(self, client, auth_header):
        resp = client.get("/audit/templates", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True
