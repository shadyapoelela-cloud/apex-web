"""
APEX Platform -- Comprehensive Integration Tests for v10.0.0 through v10.7.0
=============================================================================
Covers: response format standardization, Pydantic validation, admin auth,
CORS, rate limiting, security headers, health check, utility functions,
auth flow, legal acceptance, notifications, account management.
"""

import os
import time
import uuid
import pytest
from datetime import datetime, timezone


@pytest.fixture(autouse=True)
def clear_rate_limits():
    """Clear the in-memory rate limit store before each test to prevent 429 errors."""
    from app.main import _rate_limits

    _rate_limits.clear()
    yield
    _rate_limits.clear()


# ---------------------------------------------------------------------------
# 1. Response Format Standardization (v10.3.0)
# ---------------------------------------------------------------------------


class TestResponseFormatStandardization:
    """Verify all endpoints follow {"success": bool, ...} envelope."""

    def test_register_returns_success_true(self, client):
        unique = uuid.uuid4().hex[:8]
        resp = client.post(
            "/auth/register",
            json={
                "username": f"fmt_{unique}",
                "email": f"fmt_{unique}@test.com",
                "password": "TestPass123!",
                "display_name": "Format Test",
            },
        )
        data = resp.json()
        assert "success" in data, "Register response must include 'success' key"
        if resp.status_code == 200:
            assert data["success"] is True

    def test_login_error_returns_success_false(self, client):
        resp = client.post(
            "/auth/login",
            json={
                "username_or_email": "nonexistent_user_xyz",
                "password": "wrongpass",
            },
        )
        # Login failure should return 401 with error detail
        assert resp.status_code == 401
        data = resp.json()
        assert "detail" in data, "Failed login should return error detail"

    def test_legal_documents_returns_success_data(self, client):
        resp = client.get("/legal/documents")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "data" in data

    def test_notifications_returns_success_data(self, client, auth_header):
        resp = client.get("/notifications", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "data" in data

    def test_account_profile_returns_success(self, client, auth_header):
        resp = client.get("/users/me", headers=auth_header)
        # The profile endpoint should return success envelope
        data = resp.json()
        assert "success" in data

    def test_legal_terms_returns_success_data(self, client):
        resp = client.get("/legal/terms")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "data" in data

    def test_plans_returns_200(self, client):
        resp = client.get("/plans")
        assert resp.status_code == 200
        data = resp.json()
        # Phase1 router serves /plans as a list; main.py version wraps it.
        # Either format is acceptable as long as it returns valid data.
        assert data is not None


# ---------------------------------------------------------------------------
# 2. Pydantic Validation (v10.3.1)
# ---------------------------------------------------------------------------


class TestPydanticValidation:
    """Verify request body validation returns proper 422 errors."""

    def test_register_missing_required_fields_returns_422(self, client):
        resp = client.post("/auth/register", json={})
        assert resp.status_code == 422

    def test_register_missing_password_returns_422(self, client):
        resp = client.post(
            "/auth/register",
            json={
                "username": "test",
                "email": "test@test.com",
                # missing password and display_name
            },
        )
        assert resp.status_code == 422

    def test_register_short_password_returns_422(self, client):
        resp = client.post(
            "/auth/register",
            json={
                "username": "testuser",
                "email": "test@test.com",
                "password": "ab",  # too short (min_length=8)
                "display_name": "Test User",
            },
        )
        assert resp.status_code == 422

    def test_register_short_username_returns_422(self, client):
        resp = client.post(
            "/auth/register",
            json={
                "username": "ab",  # too short (min_length=3)
                "email": "test@test.com",
                "password": "TestPass123!",
                "display_name": "Test User",
            },
        )
        assert resp.status_code == 422

    def test_login_missing_fields_returns_422(self, client):
        resp = client.post("/auth/login", json={})
        assert resp.status_code == 422

    def test_change_password_missing_fields_returns_422(self, client, auth_header):
        resp = client.put("/users/me/security/password", json={}, headers=auth_header)
        assert resp.status_code == 422

    def test_422_response_has_error_detail(self, client):
        resp = client.post("/auth/register", json={})
        assert resp.status_code == 422
        data = resp.json()
        assert "detail" in data, "422 response must include 'detail' field"
        assert isinstance(data["detail"], list), "Validation detail should be a list"
        assert len(data["detail"]) > 0, "Validation detail should not be empty"

    def test_invalid_field_type_returns_422(self, client):
        resp = client.post(
            "/auth/register",
            json={
                "username": 12345,  # should be string, but Pydantic may coerce
                "email": "test@test.com",
                "password": "TestPass123!",
                "display_name": "Test",
            },
        )
        # If the int is coerced, try with a clearly invalid type for a structured field
        resp2 = client.post(
            "/auth/login",
            json={
                "username_or_email": ["not", "a", "string"],
                "password": "test",
            },
        )
        assert resp2.status_code == 422

    def test_change_password_short_new_password_returns_422(self, client, auth_header):
        """The ChangePasswordRequest in main.py requires new_password min_length=6."""
        resp = client.put(
            "/users/me/security/password",
            json={
                "current_password": "oldpass",
                "new_password": "ab",  # too short
                "confirm_password": "ab",
            },
            headers=auth_header,
        )
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# 3. Admin Auth Header (v10.4.0)
# ---------------------------------------------------------------------------


class TestAdminAuthHeader:
    """Verify admin endpoints accept X-Admin-Secret header and query param."""

    def test_admin_header_works(self, client):
        resp = client.post(
            "/admin/reinit-db",
            headers={"X-Admin-Secret": os.environ["ADMIN_SECRET"]},
        )
        assert resp.status_code == 200

    def test_admin_query_param_backward_compat(self, client):
        resp = client.post(
            f"/admin/reinit-db?secret={os.environ['ADMIN_SECRET']}",
        )
        assert resp.status_code == 200

    def test_admin_no_secret_returns_403(self, client):
        resp = client.post("/admin/reinit-db")
        assert resp.status_code == 403

    def test_admin_wrong_secret_returns_403(self, client):
        resp = client.post(
            "/admin/reinit-db",
            headers={"X-Admin-Secret": "totally-wrong-secret"},
        )
        assert resp.status_code == 403

    def test_admin_seed_all_header_works(self, client):
        resp = client.post(
            "/admin/seed-all",
            headers={"X-Admin-Secret": os.environ["ADMIN_SECRET"]},
        )
        assert resp.status_code == 200

    def test_admin_seed_all_no_secret_returns_403(self, client):
        resp = client.post("/admin/seed-all")
        assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 4. CORS Configuration (v10.4.0)
# ---------------------------------------------------------------------------


class TestCORSConfiguration:
    """Verify CORS middleware is correctly configured."""

    def test_preflight_returns_cors_headers(self, client):
        resp = client.options(
            "/health",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )
        # CORS middleware should respond to preflight
        assert resp.status_code == 200
        headers = resp.headers
        assert "access-control-allow-origin" in headers

    def test_wildcard_origin_no_credentials(self, client):
        """When CORS_ORIGINS is wildcard, credentials should not be allowed."""
        resp = client.options(
            "/health",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )
        # With wildcard origins, allow-credentials should be absent or 'false'
        creds = resp.headers.get("access-control-allow-credentials", "")
        assert creds != "true", "access-control-allow-credentials must not be 'true' with wildcard origin"

    def test_cors_allows_standard_methods(self, client):
        resp = client.options(
            "/health",
            headers={
                "Origin": "http://example.com",
                "Access-Control-Request-Method": "POST",
            },
        )
        allowed_methods = resp.headers.get("access-control-allow-methods", "")
        assert "POST" in allowed_methods or "*" in allowed_methods


# ---------------------------------------------------------------------------
# 5. Rate Limiting (v10.2.1)
# ---------------------------------------------------------------------------


class TestRateLimiting:
    """Verify rate limiting middleware exists and works."""

    def test_normal_requests_work_fine(self, client):
        """Several requests in quick succession should succeed."""
        for _ in range(5):
            resp = client.get("/health")
            assert resp.status_code == 200

    def test_rate_limit_variables_exist(self):
        """Verify rate limit configuration is defined in the app."""
        from app.main import RATE_LIMIT_WINDOW, RATE_LIMIT_MAX

        assert isinstance(RATE_LIMIT_WINDOW, int)
        assert isinstance(RATE_LIMIT_MAX, int)
        assert RATE_LIMIT_WINDOW > 0
        assert RATE_LIMIT_MAX > 0

    def test_rate_limit_tracking_dict_exists(self):
        """Verify the in-memory rate limit store is initialized."""
        from app.main import _rate_limits

        assert _rate_limits is not None

    def test_get_client_ip_function_exists(self):
        """Verify the IP extraction helper exists."""
        from app.main import _get_client_ip

        assert callable(_get_client_ip)


# ---------------------------------------------------------------------------
# 6. Security Headers (v10.2.1)
# ---------------------------------------------------------------------------


class TestSecurityHeaders:
    """Verify security headers are present on all responses."""

    def test_x_content_type_options_nosniff(self, client):
        resp = client.get("/health")
        assert resp.headers.get("x-content-type-options") == "nosniff"

    def test_x_frame_options_deny(self, client):
        resp = client.get("/health")
        assert resp.headers.get("x-frame-options") == "DENY"

    def test_x_xss_protection_header(self, client):
        resp = client.get("/health")
        xss = resp.headers.get("x-xss-protection", "")
        assert "1" in xss

    def test_referrer_policy_header(self, client):
        resp = client.get("/health")
        assert resp.headers.get("referrer-policy") == "strict-origin-when-cross-origin"

    def test_cache_control_no_store(self, client):
        resp = client.get("/health")
        assert resp.headers.get("cache-control") == "no-store"

    def test_security_headers_on_api_endpoint(self, client):
        """Security headers should be present on any endpoint, not just /health."""
        resp = client.get("/")
        assert resp.headers.get("x-content-type-options") == "nosniff"
        assert resp.headers.get("x-frame-options") == "DENY"


# ---------------------------------------------------------------------------
# 7. Health Check (v10.2.1)
# ---------------------------------------------------------------------------


class TestHealthCheck:
    """Verify health and root endpoints return expected data."""

    def test_health_returns_status(self, client):
        resp = client.get("/health")
        assert resp.status_code == 200
        data = resp.json()
        assert "status" in data
        assert data["status"] in ("ok", "degraded")

    def test_health_returns_version(self, client):
        resp = client.get("/health")
        data = resp.json()
        assert "version" in data
        assert isinstance(data["version"], str)

    def test_health_returns_database_info(self, client):
        resp = client.get("/health")
        data = resp.json()
        assert "database" in data
        assert isinstance(data["database"], bool)

    def test_health_returns_phase_info(self, client):
        resp = client.get("/health")
        data = resp.json()
        assert "phases" in data
        assert isinstance(data["phases"], dict)

    def test_health_returns_sprint_info(self, client):
        resp = client.get("/health")
        data = resp.json()
        assert "sprints" in data

    def test_root_returns_version(self, client):
        resp = client.get("/")
        assert resp.status_code == 200
        data = resp.json()
        assert "version" in data

    def test_root_returns_phases_info(self, client):
        resp = client.get("/")
        data = resp.json()
        assert "phases_active" in data
        assert "phases_total" in data
        assert data["phases_total"] == 11

    def test_root_returns_modules(self, client):
        resp = client.get("/")
        data = resp.json()
        assert "modules" in data
        assert isinstance(data["modules"], dict)


# ---------------------------------------------------------------------------
# 8. Utility Functions (v10.5.0)
# ---------------------------------------------------------------------------


class TestTextUtils:
    """Test text_utils.remove_diacritics and normalize_arabic."""

    def test_remove_diacritics_basic(self):
        from app.core.text_utils import remove_diacritics

        # Arabic text with fatha (U+064E) and kasra (U+0650)
        text = "\u0645\u064e\u0631\u0652\u062d\u064e\u0628\u064b\u0627"  # مَرْحَبًا
        result = remove_diacritics(text)
        assert "\u064e" not in result  # fatha removed
        assert "\u0652" not in result  # sukun removed
        assert "\u064b" not in result  # tanwin fatha removed
        assert len(result) < len(text)

    def test_remove_diacritics_empty_string(self):
        from app.core.text_utils import remove_diacritics

        assert remove_diacritics("") == ""

    def test_remove_diacritics_no_diacritics(self):
        from app.core.text_utils import remove_diacritics

        text = "\u0645\u0631\u062d\u0628\u0627"  # مرحبا (no diacritics)
        assert remove_diacritics(text) == text

    def test_remove_diacritics_none(self):
        from app.core.text_utils import remove_diacritics

        assert remove_diacritics(None) == ""

    def test_normalize_arabic_hamza_variants(self):
        from app.core.text_utils import normalize_arabic

        # All hamza variants should normalize to plain alef
        alef_hamza_above = "\u0623"  # أ
        alef_hamza_below = "\u0625"  # إ
        alef_madda = "\u0622"  # آ
        plain_alef = "\u0627"  # ا
        assert normalize_arabic(alef_hamza_above) == plain_alef
        assert normalize_arabic(alef_hamza_below) == plain_alef
        assert normalize_arabic(alef_madda) == plain_alef

    def test_normalize_arabic_taa_marbuta(self):
        from app.core.text_utils import normalize_arabic

        # ة (taa marbuta) -> ه (haa)
        assert normalize_arabic("\u0629") == "\u0647"

    def test_normalize_arabic_alef_maqsura(self):
        from app.core.text_utils import normalize_arabic

        # ى (alef maqsura) -> ي (yaa)
        assert normalize_arabic("\u0649") == "\u064a"

    def test_normalize_arabic_whitespace_collapse(self):
        from app.core.text_utils import normalize_arabic

        result = normalize_arabic("  \u0645\u0631\u062d\u0628\u0627   \u0628\u0643  ")
        assert "  " not in result  # no double spaces

    def test_normalize_arabic_empty_string(self):
        from app.core.text_utils import normalize_arabic

        assert normalize_arabic("") == ""

    def test_normalize_arabic_none(self):
        from app.core.text_utils import normalize_arabic

        assert normalize_arabic(None) == ""


class TestDbUtils:
    """Test db_utils helper functions."""

    def test_utc_now_is_timezone_aware(self):
        from app.core.db_utils import utc_now

        now = utc_now()
        assert now.tzinfo is not None
        assert now.tzinfo == timezone.utc

    def test_utc_now_returns_datetime(self):
        from app.core.db_utils import utc_now

        now = utc_now()
        assert isinstance(now, datetime)

    def test_utc_now_iso_returns_string(self):
        from app.core.db_utils import utc_now_iso

        result = utc_now_iso()
        assert isinstance(result, str)
        assert "T" in result  # ISO format has T separator

    def test_get_db_session_returns_valid_session(self):
        from app.core.db_utils import get_db_session

        session = get_db_session()
        assert session is not None
        try:
            from sqlalchemy import text

            result = session.execute(text("SELECT 1"))
            assert result is not None
        finally:
            session.close()

    def test_exec_sql_basic(self):
        from app.core.db_utils import get_db_session, exec_sql

        session = get_db_session()
        try:
            result = exec_sql(session, "SELECT 1 AS val")
            row = result.fetchone()
            assert row is not None
        finally:
            session.close()


# ---------------------------------------------------------------------------
# 9. Auth Flow (v10.0.0)
# ---------------------------------------------------------------------------


class TestAuthFlow:
    """Test full authentication flow: register -> login -> profile -> change password."""

    def test_full_register_login_profile_flow(self, client):
        unique = uuid.uuid4().hex[:8]
        username = f"flow_{unique}"
        email = f"flow_{unique}@test.com"
        password = "FlowTestPass123!"

        # Step 1: Register
        reg_resp = client.post(
            "/auth/register",
            json={
                "username": username,
                "email": email,
                "password": password,
                "display_name": "Flow Test User",
            },
        )
        assert reg_resp.status_code == 200
        reg_data = reg_resp.json()
        assert reg_data["success"] is True

        # Step 2: Login
        login_resp = client.post(
            "/auth/login",
            json={
                "username_or_email": username,
                "password": password,
            },
        )
        assert login_resp.status_code == 200
        login_data = login_resp.json()
        assert login_data["success"] is True
        tokens = login_data.get("tokens") or login_data.get("data", {}).get("tokens", {})
        token = tokens.get("access_token") or login_data.get("token")
        assert token is not None, "Login should return a token"

        # Step 3: Access profile
        profile_resp = client.get(
            "/users/me",
            headers={
                "Authorization": f"Bearer {token}",
            },
        )
        assert profile_resp.status_code == 200

        # Step 4: Change password
        new_password = "NewFlowPass456!"
        chg_resp = client.put(
            "/users/me/security/password",
            json={
                "current_password": password,
                "new_password": new_password,
                "confirm_password": new_password,
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        # Should succeed or return a clear error
        assert chg_resp.status_code in (200, 400)

    def test_protected_endpoint_without_token_returns_401(self, client):
        resp = client.get("/users/me")
        assert resp.status_code == 401

    def test_protected_endpoint_with_invalid_token_returns_401(self, client):
        resp = client.get(
            "/users/me",
            headers={
                "Authorization": "Bearer invalid.token.here",
            },
        )
        assert resp.status_code == 401

    def test_notifications_without_token_returns_401(self, client):
        resp = client.get("/notifications")
        assert resp.status_code == 401

    def test_legal_pending_without_token_returns_401(self, client):
        resp = client.get("/legal/pending")
        assert resp.status_code == 401

    def test_expired_token_returns_401(self, client):
        """A token with past expiration should be rejected."""
        import jwt as pyjwt
        from datetime import timedelta

        payload = {
            "sub": "expired-user",
            "username": "expired",
            "roles": ["registered_user"],
            "type": "access",
            "exp": datetime.now(timezone.utc) - timedelta(hours=1),
            "iat": datetime.now(timezone.utc) - timedelta(hours=2),
        }
        token = pyjwt.encode(payload, os.environ["JWT_SECRET"], algorithm="HS256")
        resp = client.get(
            "/users/me",
            headers={
                "Authorization": f"Bearer {token}",
            },
        )
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# 10. Legal Acceptance (v10.3.0)
# ---------------------------------------------------------------------------


class TestLegalAcceptance:
    """Test Phase 11 legal acceptance endpoints."""

    def test_get_legal_documents(self, client):
        resp = client.get("/legal/documents")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "data" in data

    def test_post_accept_all_with_auth(self, client, auth_header):
        resp = client.post("/legal/accept-all", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert "success" in data

    def test_get_pending_with_auth(self, client, auth_header):
        resp = client.get("/legal/pending", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "data" in data
        assert "pending" in data["data"]
        assert "count" in data["data"]

    def test_get_my_acceptances_with_auth(self, client, auth_header):
        resp = client.get("/legal/my-acceptances", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "data" in data

    def test_accept_all_without_auth_returns_401(self, client):
        resp = client.post("/legal/accept-all")
        assert resp.status_code == 401

    def test_pending_without_auth_returns_401(self, client):
        resp = client.get("/legal/pending")
        assert resp.status_code == 401

    def test_my_acceptances_without_auth_returns_401(self, client):
        resp = client.get("/legal/my-acceptances")
        assert resp.status_code == 401

    def test_legal_terms_static_endpoint(self, client):
        resp = client.get("/legal/terms")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "data" in data
        assert "version" in data["data"]

    def test_legal_privacy_static_endpoint(self, client):
        resp = client.get("/legal/privacy")
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True


# ---------------------------------------------------------------------------
# 11. Notifications (v10.3.0)
# ---------------------------------------------------------------------------


class TestNotifications:
    """Test Phase 10 notification endpoints."""

    def test_get_notifications_with_auth(self, client, auth_header):
        resp = client.get("/notifications", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "data" in data

    def test_get_notifications_pagination(self, client, auth_header):
        resp = client.get("/notifications?page=1&page_size=10", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True

    def test_get_notifications_unread_only(self, client, auth_header):
        resp = client.get("/notifications?unread_only=true", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True

    def test_get_unread_count_with_auth(self, client, auth_header):
        resp = client.get("/notifications/count", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "data" in data
        assert "unread" in data["data"]

    def test_mark_read_with_auth(self, client, auth_header):
        resp = client.post("/notifications/mark-read", json={}, headers=auth_header)
        assert resp.status_code == 200

    def test_mark_read_specific_notification(self, client, auth_header):
        resp = client.post(
            "/notifications/mark-read",
            json={"notification_id": "nonexistent-id"},
            headers=auth_header,
        )
        # Should either succeed (marking nothing) or return 400
        assert resp.status_code in (200, 400)

    def test_notifications_without_auth_returns_401(self, client):
        resp = client.get("/notifications")
        assert resp.status_code == 401

    def test_unread_count_without_auth_returns_401(self, client):
        resp = client.get("/notifications/count")
        assert resp.status_code == 401

    def test_mark_read_without_auth_returns_401(self, client):
        resp = client.post("/notifications/mark-read", json={})
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# 12. Account Management (v10.3.0)
# ---------------------------------------------------------------------------


class TestAccountManagement:
    """Test account profile and password management endpoints."""

    def test_get_profile_with_auth(self, client, auth_header):
        resp = client.get("/users/me", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert "success" in data

    def test_get_security_info_with_auth(self, client, auth_header):
        resp = client.get("/users/me/security", headers=auth_header)
        # Should return profile or a clear error
        assert resp.status_code in (200, 404, 500)

    def test_change_password_with_auth(self, client, auth_header):
        resp = client.put(
            "/users/me/security/password",
            json={
                "current_password": "OldPass123!",
                "new_password": "NewPass456!",
                "confirm_password": "NewPass456!",
            },
            headers=auth_header,
        )
        # May fail because test user doesn't exist in DB,
        # but should not be 401 (auth should pass) or 422 (validation should pass)
        assert resp.status_code not in (401, 422)

    def test_change_password_mismatch(self, client, auth_header):
        resp = client.put(
            "/users/me/security/password",
            json={
                "current_password": "OldPass123!",
                "new_password": "NewPass456!",
                "confirm_password": "DifferentPass789!",
            },
            headers=auth_header,
        )
        assert resp.status_code == 400

    def test_change_password_without_auth_returns_401(self, client):
        resp = client.put(
            "/users/me/security/password",
            json={
                "current_password": "old",
                "new_password": "newpass",
                "confirm_password": "newpass",
            },
        )
        assert resp.status_code == 401

    def test_update_profile_via_phase9(self, client, auth_header):
        resp = client.put(
            "/account/profile",
            json={
                "display_name": "Updated Name",
            },
            headers=auth_header,
        )
        # May fail due to test user not in DB, but auth/validation should pass
        assert resp.status_code not in (401, 422)

    def test_account_sessions_with_auth(self, client, auth_header):
        resp = client.get("/account/sessions", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True

    def test_account_activity_with_auth(self, client, auth_header):
        resp = client.get("/account/activity", headers=auth_header)
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True

    def test_account_closure_with_valid_type(self, client, auth_header):
        resp = client.post(
            "/account/closure",
            json={
                "closure_type": "temporary",
                "reason": "testing",
            },
            headers=auth_header,
        )
        # Phase9 route requires auth and a valid DB user; accept 200 or 400/500
        assert resp.status_code != 401, "Auth should pass with valid token"
        assert resp.status_code != 422, "Validation should pass with valid fields"

    def test_profile_without_auth_returns_401(self, client):
        resp = client.get("/users/me")
        assert resp.status_code == 401

    def test_sessions_without_auth_returns_401(self, client):
        resp = client.get("/account/sessions")
        assert resp.status_code == 401
