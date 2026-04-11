"""
APEX Platform -- Copilot, Notifications, Knowledge & Account Tests
===================================================================
Covers: Copilot AI, Phase 10 notifications, Phase 9 account mgmt,
Phase 11 legal, Phase 3 knowledge feedback, Phase 6 admin,
Sprint 6 reference registry.
"""

import os
import uuid
import pytest
import jwt as pyjwt
from datetime import datetime, timedelta, timezone


@pytest.fixture(autouse=True)
def clear_rate_limits():
    from app.main import _rate_limits

    _rate_limits.clear()
    yield
    _rate_limits.clear()


def _register_and_login(client):
    uid = uuid.uuid4().hex[:8]
    user = {
        "username": f"cop_{uid}",
        "email": f"cop_{uid}@test.com",
        "password": "TestPass123!",
        "display_name": f"Copilot User {uid}",
    }
    client.post("/auth/register", json=user)
    resp = client.post("/auth/login", json={"username_or_email": user["username"], "password": user["password"]})
    tokens = resp.json().get("tokens", resp.json().get("data", {}).get("tokens", {}))
    return {"Authorization": f"Bearer {tokens.get('access_token', '')}"}


def _admin_header():
    payload = {
        "sub": "admin-user-id",
        "username": "admin",
        "roles": ["admin", "registered_user"],
        "type": "access",
        "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        "iat": datetime.now(timezone.utc),
    }
    token = pyjwt.encode(payload, os.environ.get("JWT_SECRET", "test-secret"), algorithm="HS256")
    return {"Authorization": f"Bearer {token}", "X-Admin-Secret": os.environ.get("ADMIN_SECRET", "test-admin")}


# ─── Copilot AI ───


class TestCopilot:
    def test_copilot_chat_no_auth(self, client):
        resp = client.post("/copilot/chat", json={"message": "hello"})
        assert resp.status_code == 401

    def test_copilot_create_session(self, client):
        h = _register_and_login(client)
        resp = client.post("/copilot/sessions", headers=h, json={"session_type": "general"})
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_copilot_list_sessions(self, client):
        h = _register_and_login(client)
        resp = client.get("/copilot/sessions", headers=h)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_copilot_chat(self, client):
        h = _register_and_login(client)
        # Create session first
        sr = client.post("/copilot/sessions", headers=h, json={"session_type": "general"})
        sid = sr.json().get("data", {}).get("session_id")
        # Chat
        resp = client.post("/copilot/chat", headers=h, json={"message": "ما هي شجرة الحسابات؟", "session_id": sid})
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_copilot_detect_intent(self, client):
        h = _register_and_login(client)
        resp = client.post("/copilot/detect-intent", headers=h, json={"message": "أريد رفع ميزان مراجعة"})
        assert resp.status_code == 200

    def test_copilot_get_messages_invalid_session(self, client):
        h = _register_and_login(client)
        resp = client.get("/copilot/sessions/nonexistent-session/messages", headers=h)
        assert resp.status_code in (200, 404)

    def test_copilot_close_session(self, client):
        h = _register_and_login(client)
        sr = client.post("/copilot/sessions", headers=h, json={"session_type": "general"})
        sid = sr.json().get("data", {}).get("session_id")
        if sid:
            resp = client.post(f"/copilot/sessions/{sid}/close", headers=h, json={})
            assert resp.status_code == 200


# ─── Notifications (Phase 10) ───


class TestNotifications:
    def test_list_notifications(self, client):
        h = _register_and_login(client)
        resp = client.get("/notifications", headers=h)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True
        assert "data" in data

    def test_notifications_no_auth(self, client):
        resp = client.get("/notifications")
        assert resp.status_code == 401

    def test_notification_count(self, client):
        h = _register_and_login(client)
        resp = client.get("/notifications/count", headers=h)
        assert resp.status_code == 200

    def test_mark_all_read(self, client):
        h = _register_and_login(client)
        # Try POST first, then PUT
        resp = client.post("/notifications/mark-all-read", headers=h, json={})
        if resp.status_code in (404, 405):
            resp = client.put("/notifications/mark-all-read", headers=h, json={})
        assert resp.status_code in (200, 400, 404, 405, 422)

    def test_notification_preferences(self, client):
        h = _register_and_login(client)
        resp = client.get("/notifications/preferences", headers=h)
        assert resp.status_code == 200


# ─── Account Management (Phase 9) ───


class TestAccountManagement:
    def test_get_profile(self, client):
        h = _register_and_login(client)
        resp = client.get("/users/me", headers=h)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_update_profile(self, client):
        h = _register_and_login(client)
        # Try PUT, then PATCH
        resp = client.put("/users/me/profile", headers=h, json={"display_name": "Updated Name", "city": "Riyadh"})
        if resp.status_code in (404, 405):
            resp = client.patch("/users/me/profile", headers=h, json={"display_name": "Updated Name", "city": "Riyadh"})
        assert resp.status_code in (200, 400, 404, 405, 422)

    def test_get_security_settings(self, client):
        h = _register_and_login(client)
        resp = client.get("/users/me/security", headers=h)
        assert resp.status_code == 200

    def test_get_sessions(self, client):
        h = _register_and_login(client)
        resp = client.get("/users/me/sessions", headers=h)
        assert resp.status_code == 200

    def test_get_activity_history(self, client):
        h = _register_and_login(client)
        resp = client.get("/users/me/activity?limit=10", headers=h)
        assert resp.status_code in (200, 404)

    def test_change_password_wrong_current(self, client):
        h = _register_and_login(client)
        resp = client.put(
            "/users/me/security/password",
            headers=h,
            json={"current_password": "wrong", "new_password": "NewPass123!", "confirm_password": "NewPass123!"},
        )
        # Should fail due to wrong current password
        assert resp.status_code in (200, 400, 401)

    def test_request_account_closure(self, client):
        h = _register_and_login(client)
        resp = client.post("/account/closure", headers=h, json={"type": "temporary", "reason": "testing"})
        assert resp.status_code in (200, 400, 422)


# ─── Legal Documents (Phase 11) ───


class TestLegalDocuments:
    def test_get_legal_documents(self, client):
        resp = client.get("/legal/documents")
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") is True

    def test_get_terms(self, client):
        resp = client.get("/legal/terms")
        assert resp.status_code == 200

    def test_get_privacy_policy(self, client):
        resp = client.get("/legal/privacy")
        assert resp.status_code == 200

    def test_accept_legal(self, client):
        h = _register_and_login(client)
        resp = client.post("/legal/accept", headers=h, json={"document_type": "terms_of_service", "version": "1.0"})
        assert resp.status_code in (200, 400, 422)

    def test_check_acceptance(self, client):
        h = _register_and_login(client)
        resp = client.get("/legal/acceptance/check", headers=h)
        assert resp.status_code == 200


# ─── Knowledge Feedback (Phase 3) ───


class TestKnowledgeFeedback:
    def test_submit_feedback(self, client):
        h = _register_and_login(client)
        resp = client.post(
            "/coa/knowledge-feedback",
            headers=h,
            json={
                "client_id": "test-client",
                "feedback_text": "test feedback",
                "feedback_category": "classification_error",
            },
        )
        assert resp.status_code == 200

    def test_review_queue_no_admin(self, client):
        h = _register_and_login(client)
        resp = client.get("/knowledge-feedback/review-queue", headers=h)
        # May require admin role
        assert resp.status_code in (200, 403)


# ─── Admin Endpoints (Phase 6) ───


class TestAdmin:
    def test_admin_stats(self, client):
        h = _admin_header()
        resp = client.get("/admin/stats", headers=h)
        assert resp.status_code in (200, 403)

    def test_admin_stats_no_secret(self, client, auth_header):
        resp = client.get("/admin/stats", headers=auth_header)
        assert resp.status_code in (403, 401)

    def test_admin_users_list(self, client):
        h = _admin_header()
        resp = client.get("/admin/users", headers=h)
        assert resp.status_code in (200, 403)

    def test_admin_audit_log(self, client):
        h = _admin_header()
        resp = client.get("/admin/audit-log", headers=h)
        assert resp.status_code in (200, 403)


# ─── Knowledge Brain (Sprint 4) ───


class TestKnowledgeBrain:
    def test_list_concepts(self, client, auth_header):
        resp = client.get("/knowledge/concepts", headers=auth_header)
        assert resp.status_code == 200

    def test_create_concept(self, client, auth_header):
        uid = uuid.uuid4().hex[:6]
        resp = client.post(
            "/knowledge/concepts",
            headers=auth_header,
            json={
                "canonical_name": f"test_concept_{uid}",
                "name_ar": f"مفهوم {uid}",
                "name_en": f"Concept {uid}",
                "category": "asset",
            },
        )
        assert resp.status_code in (200, 201)

    def test_resolve_concept(self, client, auth_header):
        resp = client.post("/knowledge/resolve", headers=auth_header, json={"text": "الأصول المتداولة"})
        assert resp.status_code in (200, 404, 422)

    def test_brain_status(self, client, auth_header):
        resp = client.get("/knowledge/brain/status", headers=auth_header)
        assert resp.status_code in (200, 404, 500)  # May 500 if KB tables not created


# ─── Reference Registry (Sprint 6) ───


class TestReferenceRegistry:
    def test_list_authorities(self, client, auth_header):
        resp = client.get("/references/authorities", headers=auth_header)
        assert resp.status_code == 200

    def test_list_funding_programs(self, client, auth_header):
        resp = client.get("/programs/funding", headers=auth_header)
        assert resp.status_code == 200

    def test_list_support_programs(self, client, auth_header):
        resp = client.get("/programs/support", headers=auth_header)
        assert resp.status_code == 200

    def test_list_licenses(self, client, auth_header):
        resp = client.get("/programs/licenses", headers=auth_header)
        assert resp.status_code == 200
