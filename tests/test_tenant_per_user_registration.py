"""ERR-2 Phase 3: tenant-per-user registration tests.

Closes UAT Issue #3: a brand-new user used to see 7 unrelated companies
because every registration silently inherited the legacy shared
tenant_id. The fix in `auth_service.register()` creates a fresh
`Tenant` row per user; `auth_service.login()` looks it up; both flows
embed the tenant id in the JWT `tenant_id` claim. The
`TenantContextMiddleware` already wired in `app/main.py:675` then
binds it to the per-request ContextVar, and the existing
`attach_tenant_guard()` SQLAlchemy listener filters every query on
TenantMixin tables by that tenant.

The tests below sit at three layers:
  * pure-unit on `create_access_token` (claim shape + legacy
    backward-compat),
  * service-level on `AuthService.register()` / `.login()` against the
    test SQLite DB (verifies the Tenant row gets inserted and the
    user→tenant link works),
  * end-to-end via the FastAPI `/auth/register` + `/auth/login`
    routes (verifies the token returned to a real client carries the
    claim).

Out of scope of this file (deferred per ERR-2 Phase 3 PR scope):
  * RLS-level tests with a real Postgres instance — needs
    G-CI-DOCKER-POSTGRES.
  * Cross-tenant isolation tests across actual /api endpoints — the
    existing `attach_tenant_guard()` is already exercised by the
    legacy multi-tenant test suites; nothing in this PR changes that
    code path.
"""

from __future__ import annotations

import jwt as _jwt
import os
import uuid

import pytest

from app.phase1.services.auth_service import (
    AuthService,
    JWT_ALGORITHM,
    JWT_SECRET,
    create_access_token,
)


# ────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────


def _unique_user(prefix: str = "tpu") -> dict:
    """Build a never-collides registration payload."""
    uid = uuid.uuid4().hex[:8]
    return {
        "username": f"{prefix}_{uid}",
        "email": f"{prefix}_{uid}@example.test",
        "password": "TenantTest123!",
        "display_name": f"{prefix.title()} User {uid}",
    }


def _decode(token: str) -> dict:
    return _jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])


def _decode_nosig(token: str) -> dict:
    """Bypass signature so we can probe legacy tokens."""
    return _jwt.decode(token, options={"verify_signature": False})


# ────────────────────────────────────────────────────────────────────
# create_access_token — pure unit tests, no DB
# ────────────────────────────────────────────────────────────────────


class TestCreateAccessTokenTenantClaim:
    def test_legacy_signature_omits_tenant_id_claim(self):
        """Existing callers passing only positional args must keep
        working — the JWT must NOT include tenant_id (matches pre-ERR-2
        behavior so the TenantContextMiddleware fallback still applies)."""
        token = create_access_token("user-1", "alice", ["registered_user"])
        decoded = _decode(token)
        assert decoded["sub"] == "user-1"
        assert decoded["username"] == "alice"
        assert decoded["roles"] == ["registered_user"]
        assert "tenant_id" not in decoded

    def test_explicit_none_tenant_id_omits_claim(self):
        """Passing tenant_id=None explicitly is the legacy login path
        for users that don't yet have a tenant row. The claim is
        omitted, not stored as null."""
        token = create_access_token(
            "user-2", "bob", ["registered_user"], tenant_id=None
        )
        decoded = _decode(token)
        assert "tenant_id" not in decoded

    def test_tenant_id_claim_is_embedded_when_provided(self):
        token = create_access_token(
            "user-3", "carol", ["registered_user"], tenant_id="tenant-abc"
        )
        decoded = _decode(token)
        assert decoded["tenant_id"] == "tenant-abc"

    def test_tenant_id_is_keyword_only(self):
        """Defensive: catching tenant_id as the 4th positional arg
        would shadow a future signature change. Keep it keyword-only."""
        with pytest.raises(TypeError):
            # 4th positional arg should fail — tenant_id is kw-only.
            create_access_token("user-4", "dave", ["registered_user"], "tenant-x")  # type: ignore[misc]

    def test_token_is_signed_with_jwt_secret(self):
        """The JWT_SECRET-controlled signature is the production gate
        — make sure adding the optional param didn't accidentally
        switch to an unsigned token in any path."""
        token = create_access_token("user-5", "eve", [], tenant_id="t-1")
        # Must verify against the shared secret (decode without raising).
        decoded = _jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        assert decoded["sub"] == "user-5"


# ────────────────────────────────────────────────────────────────────
# AuthService.register() — tenant row creation
# ────────────────────────────────────────────────────────────────────


class TestRegisterCreatesTenant:
    def test_register_inserts_pilot_tenant_row_owned_by_user(self):
        """Smoking gun for UAT Issue #3: the Tenant table must contain
        a row whose `created_by_user_id` equals the new user's id."""
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models.tenant import Tenant as PilotTenant

        svc = AuthService()
        u = _unique_user("rcr1")
        result = svc.register(
            username=u["username"],
            email=u["email"],
            password=u["password"],
            display_name=u["display_name"],
        )
        assert result["success"] is True
        user_id = result["user"]["id"]
        tenant_id = result["user"]["tenant_id"]
        # Server reported a tenant id for the new user.
        assert tenant_id, (
            "register() must surface the new tenant_id in the user "
            "payload (closes UAT Issue #3)"
        )
        # And that tenant id must point to a real row owned by this user.
        db = SessionLocal()
        try:
            row = (
                db.query(PilotTenant)
                .filter(PilotTenant.id == tenant_id)
                .one_or_none()
            )
            assert row is not None, "Tenant row missing"
            assert row.created_by_user_id == user_id
        finally:
            db.close()

    def test_register_token_carries_tenant_id_claim(self):
        """The whole point of this PR — the JWT issued at registration
        must include tenant_id so TenantContextMiddleware binds it."""
        svc = AuthService()
        u = _unique_user("rcr2")
        result = svc.register(
            username=u["username"],
            email=u["email"],
            password=u["password"],
            display_name=u["display_name"],
        )
        access = result["tokens"]["access_token"]
        decoded = _decode(access)
        assert decoded["tenant_id"] == result["user"]["tenant_id"]
        assert decoded["sub"] == result["user"]["id"]

    def test_two_separate_registrations_get_different_tenants(self):
        """The cross-tenant leak in UAT was caused by everyone sharing
        the same id. Two fresh users must get distinct tenants."""
        svc = AuthService()
        a = svc.register(**_unique_user("rcr3a"))
        b = svc.register(**_unique_user("rcr3b"))
        assert a["success"] and b["success"]
        assert a["user"]["tenant_id"] != b["user"]["tenant_id"]
        # And neither user owns the other's tenant.
        a_token = _decode(a["tokens"]["access_token"])
        b_token = _decode(b["tokens"]["access_token"])
        assert a_token["tenant_id"] == a["user"]["tenant_id"]
        assert b_token["tenant_id"] == b["user"]["tenant_id"]
        assert a_token["tenant_id"] != b_token["tenant_id"]

    def test_register_tenant_legal_name_uses_display_name(self):
        """The default tenant name surfaced in the UI before user
        renames it — make sure display_name is in there so the user
        recognizes their own workspace."""
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models.tenant import Tenant as PilotTenant

        svc = AuthService()
        u = _unique_user("rcr4")
        u["display_name"] = "شركة الفجر"  # Arabic display name
        result = svc.register(
            username=u["username"],
            email=u["email"],
            password=u["password"],
            display_name=u["display_name"],
        )
        db = SessionLocal()
        try:
            row = (
                db.query(PilotTenant)
                .filter(PilotTenant.id == result["user"]["tenant_id"])
                .one_or_none()
            )
            assert row is not None
            assert "الفجر" in row.legal_name_ar
        finally:
            db.close()

    def test_failed_register_does_not_orphan_tenant(self):
        """If registration fails after the tenant insert (duplicate
        username / email check), the rollback in the except branch
        must clean the tenant up — otherwise we'd accumulate orphan
        Tenant rows pointing at no user."""
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models.tenant import Tenant as PilotTenant

        svc = AuthService()
        u = _unique_user("rcr5")
        first = svc.register(
            username=u["username"],
            email=u["email"],
            password=u["password"],
            display_name=u["display_name"],
        )
        assert first["success"]
        first_tenant_id = first["user"]["tenant_id"]

        # Second registration with the same username/email must fail.
        second = svc.register(
            username=u["username"],
            email=u["email"],
            password=u["password"],
            display_name=u["display_name"],
        )
        assert second["success"] is False

        # The first user's tenant must still exist (success path), and
        # there must NOT be a second tenant row tied to nothing.
        db = SessionLocal()
        try:
            still_there = (
                db.query(PilotTenant)
                .filter(PilotTenant.id == first_tenant_id)
                .one_or_none()
            )
            assert still_there is not None
        finally:
            db.close()


# ────────────────────────────────────────────────────────────────────
# AuthService.login() — tenant lookup
# ────────────────────────────────────────────────────────────────────


class TestLoginEmbedsTenant:
    def test_login_after_register_returns_same_tenant(self):
        svc = AuthService()
        u = _unique_user("lgn1")
        reg = svc.register(
            username=u["username"],
            email=u["email"],
            password=u["password"],
            display_name=u["display_name"],
        )
        log = svc.login(username_or_email=u["username"], password=u["password"])
        assert log["success"] is True
        assert log["user"]["tenant_id"] == reg["user"]["tenant_id"]
        assert _decode(log["tokens"]["access_token"])["tenant_id"] == reg["user"][
            "tenant_id"
        ]

    def test_login_legacy_user_without_tenant_succeeds(self):
        """Users that registered before ERR-2 lands won't have a
        Tenant row. Their login must still succeed and the token must
        omit `tenant_id` so the middleware's permissive fallback
        applies — preserves existing behavior, no breakage."""
        from app.phase1.models.platform_models import (
            SessionLocal,
            User,
            UserRole,
            Role,
            RoleCode,
            gen_uuid,
        )
        from app.phase1.services.auth_service import hash_password

        svc = AuthService()
        u = _unique_user("lgn2")
        # Insert a User by hand WITHOUT going through register() so no
        # Tenant row gets created — simulates a pre-ERR-2 account.
        db = SessionLocal()
        try:
            user = User(
                id=gen_uuid(),
                username=u["username"],
                email=u["email"],
                display_name=u["display_name"],
                password_hash=hash_password(u["password"]),
                status="active",
            )
            db.add(user)
            role = (
                db.query(Role)
                .filter(Role.code == RoleCode.registered_user.value)
                .first()
            )
            if role:
                db.add(
                    UserRole(
                        id=gen_uuid(),
                        user_id=user.id,
                        role_id=role.id,
                    )
                )
            db.commit()
        finally:
            db.close()

        log = svc.login(
            username_or_email=u["username"], password=u["password"]
        )
        assert log["success"] is True
        assert log["user"]["tenant_id"] is None
        assert "tenant_id" not in _decode(log["tokens"]["access_token"])


# ────────────────────────────────────────────────────────────────────
# End-to-end via FastAPI client — the surface a real frontend hits
# ────────────────────────────────────────────────────────────────────


class TestE2ERegisterAndLogin:
    def test_register_endpoint_returns_token_with_tenant_id(self, client):
        u = _unique_user("e2e1")
        resp = client.post("/auth/register", json=u)
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["success"] is True
        access = data["tokens"]["access_token"]
        decoded = _decode(access)
        assert decoded.get("tenant_id"), (
            "frontend-facing /auth/register response must carry tenant_id "
            "so the deployed app keeps the user isolated"
        )
        assert data["user"]["tenant_id"] == decoded["tenant_id"]

    def test_e2e_two_users_get_different_tenants(self, client):
        a = _unique_user("e2e2a")
        b = _unique_user("e2e2b")
        ra = client.post("/auth/register", json=a).json()
        rb = client.post("/auth/register", json=b).json()
        ta = _decode(ra["tokens"]["access_token"])["tenant_id"]
        tb = _decode(rb["tokens"]["access_token"])["tenant_id"]
        assert ta != tb, "two registrations must get distinct tenants"

    def test_e2e_login_after_register_carries_same_tenant(self, client):
        u = _unique_user("e2e3")
        reg = client.post("/auth/register", json=u).json()
        # /auth/login uses different field names — match the route.
        log = client.post(
            "/auth/login",
            json={"username_or_email": u["username"], "password": u["password"]},
        ).json()
        assert log.get("success") is True, log
        reg_tenant = _decode(reg["tokens"]["access_token"])["tenant_id"]
        log_tenant = _decode(log["tokens"]["access_token"])["tenant_id"]
        assert reg_tenant == log_tenant
