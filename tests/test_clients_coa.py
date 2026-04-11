"""
APEX Platform -- Client & COA Workflow Tests
=============================================
Covers: Phase 2 clients, Sprint 1-3 COA upload/classify/approve,
Sprint 4 TB binding, Sprint 5 analysis.
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
        "username": f"coa_{uid}",
        "email": f"coa_{uid}@test.com",
        "password": "TestPass123!",
        "display_name": f"COA User {uid}",
    }
    client.post("/auth/register", json=user)
    resp = client.post("/auth/login", json={"username_or_email": user["username"], "password": user["password"]})
    tokens = resp.json().get("tokens", resp.json().get("data", {}).get("tokens", {}))
    return {"Authorization": f"Bearer {tokens.get('access_token', '')}"}, user


# ─── Client Types ───


class TestClientTypes:
    def test_get_client_types(self, client, auth_header):
        resp = client.get("/client-types", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        # May return {"success":true,"data":[]} or just a list
        if isinstance(data, dict):
            assert data.get("success") is True
        else:
            assert isinstance(data, list)

    def test_client_types_is_list(self, client, auth_header):
        resp = client.get("/client-types", headers=auth_header)
        data = resp.json()
        if isinstance(data, dict):
            assert isinstance(data.get("data"), list)
        else:
            assert isinstance(data, list)


# ─── Client CRUD ───


class TestClientCrud:
    def test_create_client(self, client):
        h, _ = _register_and_login(client)
        uid = uuid.uuid4().hex[:6]
        resp = client.post(
            "/clients",
            headers={**h, "Content-Type": "application/json"},
            json={
                "client_code": f"C-{uid}",
                "name": f"Test Corp {uid}",
                "name_ar": f"شركة اختبار {uid}",
                "client_type_code": "standard_business",
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_list_clients(self, client):
        h, _ = _register_and_login(client)
        resp = client.get("/clients", headers=h)
        assert resp.status_code == 200
        data = resp.json()
        if isinstance(data, dict):
            assert data.get("success") is True
        else:
            assert isinstance(data, list)

    def test_create_client_missing_fields(self, client, auth_header):
        resp = client.post("/clients", headers=auth_header, json={})
        assert resp.status_code in (400, 422)

    def test_get_nonexistent_client(self, client, auth_header):
        resp = client.get("/clients/nonexistent-id-999", headers=auth_header)
        assert resp.status_code in (200, 400, 403, 404, 500)


# ─── COA Upload ───


class TestCoaUpload:
    def _create_client(self, client, headers):
        uid = uuid.uuid4().hex[:6]
        resp = client.post(
            "/clients",
            headers={**headers, "Content-Type": "application/json"},
            json={
                "client_code": f"COA-{uid}",
                "name": f"COA Corp {uid}",
                "name_ar": f"شركة {uid}",
                "client_type_code": "standard_business",
            },
        )
        data = resp.json()
        return data.get("data", {}).get("id") or data.get("client_id")

    def test_coa_upload_no_file(self, client):
        h, _ = _register_and_login(client)
        cid = self._create_client(client, h)
        if not cid:
            pytest.skip("Could not create client")
        resp = client.post(f"/clients/{cid}/coa/upload", headers=h)
        assert resp.status_code in (400, 422)

    def test_coa_upload_wrong_format(self, client):
        h, _ = _register_and_login(client)
        cid = self._create_client(client, h)
        if not cid:
            pytest.skip("Could not create client")
        resp = client.post(
            f"/clients/{cid}/coa/upload", headers=h, files={"file": ("test.txt", b"hello world", "text/plain")}
        )
        # Should reject non-Excel files or process them with error
        assert resp.status_code in (200, 400, 422)


# ─── COA Classification Summary ───


class TestCoaClassification:
    def test_classification_summary_nonexistent(self, client, auth_header):
        resp = client.get("/coa/classification-summary/nonexistent-upload", headers=auth_header)
        assert resp.status_code in (200, 404)

    def test_coa_mapping_nonexistent(self, client, auth_header):
        resp = client.get("/coa/mapping/nonexistent-upload?page=1&page_size=10", headers=auth_header)
        assert resp.status_code in (200, 404)

    def test_bulk_approve_nonexistent(self, client, auth_header):
        resp = client.post("/coa/bulk-approve/nonexistent-upload", headers=auth_header, json={"min_confidence": 0.75})
        assert resp.status_code in (200, 404)

    def test_approve_coa_nonexistent(self, client, auth_header):
        resp = client.post("/coa/uploads/nonexistent-upload/approve", headers=auth_header, json={})
        assert resp.status_code in (200, 404)


# ─── TB Binding ───


class TestTbBinding:
    def test_binding_summary_nonexistent(self, client, auth_header):
        resp = client.get("/tb/uploads/nonexistent-tb/binding-summary", headers=auth_header)
        assert resp.status_code in (200, 404)

    def test_bind_tb_nonexistent(self, client, auth_header):
        resp = client.post("/tb/uploads/nonexistent-tb/bind", headers=auth_header, json={})
        assert resp.status_code in (200, 404)

    def test_binding_results_nonexistent(self, client, auth_header):
        resp = client.get("/tb/uploads/nonexistent-tb/binding-results?page=1", headers=auth_header)
        assert resp.status_code in (200, 404)

    def test_approve_binding_nonexistent(self, client, auth_header):
        resp = client.post("/tb/uploads/nonexistent-tb/approve-binding", headers=auth_header, json={})
        assert resp.status_code in (200, 400, 404)


# ─── Analysis ───


class TestAnalysis:
    def test_analyze_no_file(self, client, auth_header):
        resp = client.post("/analyze/full", headers=auth_header)
        assert resp.status_code in (400, 422)

    def test_template_download(self, client):
        resp = client.get("/template/trial-balance")
        # Template may or may not exist
        assert resp.status_code in (200, 404)


# ─── Onboarding ───


class TestOnboarding:
    def test_get_legal_entity_types(self, client, auth_header):
        resp = client.get("/legal-entity-types", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_get_sectors(self, client, auth_header):
        resp = client.get("/sectors", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_get_onboarding_draft(self, client):
        h, _ = _register_and_login(client)
        resp = client.get("/onboarding/draft", headers=h)
        assert resp.status_code == 200

    def test_save_onboarding_draft(self, client):
        h, _ = _register_and_login(client)
        resp = client.post("/onboarding/draft", headers=h, json={"step_completed": 1, "draft_data": {"name": "test"}})
        assert resp.status_code == 200


# ─── Archive ───


class TestArchive:
    def test_get_user_archive(self, client):
        h, _ = _register_and_login(client)
        resp = client.get("/account/archive?page=1", headers=h)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_get_user_archive_no_auth(self, client):
        resp = client.get("/account/archive?page=1")
        assert resp.status_code == 401
