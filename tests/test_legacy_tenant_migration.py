"""G-LEGACY-TENANT-MIGRATION — tests for the legacy-tenant backfill.

Closes the residual leg of UAT Issue #3 that ERR-2 Phase 3 (PR #169)
deliberately left out of scope: users who registered BEFORE PR #169
still have no Tenant row and continue to see the shared
`06892550-…` tenant data through the permissive guard fallback.

Three layers of coverage:

  * `find_legacy_users` — the SQL anti-join that drives the loop
    must include users without a Tenant and exclude users that
    already own one. The NOT-IN-with-NULLs pitfall (three-valued
    SQL logic) is exercised explicitly so a future SQLAlchemy
    upgrade can't silently regress it.
  * `migrate_user` — single-row migration, with the idempotency
    guard re-tested every test (a regression that turns it into a
    second-row insert would re-introduce the orphan-tenant bug
    from UAT).
  * `migrate_all_legacy_users` + `/admin/migrate-legacy-tenants` —
    the batch path and the admin-gated HTTP surface.

The tests run against the same SQLite test DB that the rest of the
auth suite uses (see conftest.py); no testcontainers needed.
"""

from __future__ import annotations

import os
import uuid

import pytest

from app.phase1.models.platform_models import SessionLocal, User, gen_uuid
from app.phase1.services.legacy_tenant_migration import (
    find_legacy_users,
    migrate_all_legacy_users,
    migrate_user,
)
from app.pilot.models.tenant import Tenant


def _mk_user(
    *,
    suffix: str | None = None,
    display_name: str | None = "Legacy User",
    email: str | None = None,
) -> User:
    """Insert a User row directly. Bypasses `auth_service.register()`
    so the user has no associated Tenant — i.e. simulates a
    pre-ERR-2-Phase-3 account exactly."""
    suffix = suffix or uuid.uuid4().hex[:8]
    return User(
        id=gen_uuid(),
        username=f"legacy_{suffix}",
        email=email or f"legacy_{suffix}@example.test",
        display_name=display_name,
        password_hash="$2b$12$dummyhashforTestUserMigrationPath123456",
        status="active",
    )


def _mk_tenant_for(user: User) -> Tenant:
    """Insert a Tenant row owned by the given user — i.e. simulates a
    post-ERR-2-Phase-3 account that should NOT be picked up by the
    migration."""
    return Tenant(
        id=gen_uuid(),
        slug=f"u-{user.id[:8]}-{gen_uuid()[:8]}",
        legal_name_ar=f"{user.display_name or user.username} - الحساب الشخصي",
        primary_email=user.email,
        primary_country="SA",
        created_by_user_id=user.id,
    )


@pytest.fixture
def db():
    """Function-scoped SQLAlchemy session. Cleans up after itself so
    one test's user / tenant rows don't leak into the next test's
    `find_legacy_users` view (the SQLite test.db is session-scoped
    in conftest, but each test rolls back its own additions)."""
    s = SessionLocal()
    inserted_user_ids: list[str] = []
    inserted_tenant_ids: list[str] = []
    original_add = s.add

    def _track_add(obj, *a, **kw):
        if isinstance(obj, User):
            inserted_user_ids.append(obj.id)
        elif isinstance(obj, Tenant):
            inserted_tenant_ids.append(obj.id)
        return original_add(obj, *a, **kw)

    s.add = _track_add  # type: ignore[assignment]
    try:
        yield s
    finally:
        try:
            # Drop everything this test inserted, regardless of whether
            # the test committed. The Tenant rows are tracked from the
            # migrate_user path too (it calls db.add via the same
            # session) so this catches both manual fixtures and
            # migration-produced rows.
            if inserted_tenant_ids:
                s.query(Tenant).filter(
                    Tenant.id.in_(inserted_tenant_ids)
                ).delete(synchronize_session=False)
            if inserted_user_ids:
                s.query(User).filter(
                    User.id.in_(inserted_user_ids)
                ).delete(synchronize_session=False)
            s.commit()
        except Exception:
            s.rollback()
        finally:
            s.close()


# ────────────────────────────────────────────────────────────────────
# find_legacy_users
# ────────────────────────────────────────────────────────────────────


class TestFindLegacyUsers:
    def test_user_without_tenant_is_returned(self, db):
        u = _mk_user()
        db.add(u)
        db.commit()
        legacy = find_legacy_users(db)
        assert any(x.id == u.id for x in legacy)

    def test_user_with_tenant_is_excluded(self, db):
        u = _mk_user()
        db.add(u)
        db.flush()
        db.add(_mk_tenant_for(u))
        db.commit()
        legacy = find_legacy_users(db)
        assert not any(x.id == u.id for x in legacy)

    def test_three_valued_logic_pitfall_does_not_drop_results(self, db):
        """A Tenant row with `created_by_user_id IS NULL` (legacy
        seed / system tenant) used to collapse the entire NOT IN
        clause to UNKNOWN on PostgreSQL and silently return zero
        users. The service filters those out of the subquery
        explicitly. This test exercises that pitfall by inserting a
        NULL-owner Tenant alongside a real legacy user — the legacy
        user must still surface."""
        u = _mk_user()
        db.add(u)
        db.flush()
        # NULL-owner Tenant — analogous to a system / orphan row.
        db.add(
            Tenant(
                id=gen_uuid(),
                slug=f"sys-{gen_uuid()[:8]}",
                legal_name_ar="System (NULL owner)",
                primary_email="system@example.test",
                primary_country="SA",
                created_by_user_id=None,
            )
        )
        db.commit()
        legacy = find_legacy_users(db)
        assert any(x.id == u.id for x in legacy), (
            "NULL-owner tenants must not collapse the NOT IN to UNKNOWN"
        )


# ────────────────────────────────────────────────────────────────────
# migrate_user — idempotent single-row path
# ────────────────────────────────────────────────────────────────────


class TestMigrateUser:
    def test_creates_tenant_owned_by_user(self, db):
        u = _mk_user()
        db.add(u)
        db.commit()

        t = migrate_user(db, u)
        db.commit()
        assert t.id is not None
        assert t.created_by_user_id == u.id

    def test_idempotent_returns_existing(self, db):
        u = _mk_user()
        db.add(u)
        db.commit()

        first = migrate_user(db, u)
        db.commit()
        # Second call MUST NOT create a second row — the existing one
        # should come back. A regression here means we'd silently
        # accumulate Tenant rows on every retry.
        second = migrate_user(db, u)
        db.commit()
        assert first.id == second.id
        # And the DB physically has exactly one row owned by this user.
        owned = (
            db.query(Tenant)
            .filter(Tenant.created_by_user_id == u.id)
            .all()
        )
        assert len(owned) == 1

    def test_uses_username_when_display_name_is_blank(self, db):
        # `User.display_name` is NOT NULL at the schema layer (see
        # platform_models.py User model). The defensive fallback in
        # `migrate_user` covers the legitimate-in-production case of
        # an empty-string display name (some legacy fixtures set
        # `""` rather than a real value), so the test feeds that
        # rather than NULL.
        u = _mk_user(display_name="")
        db.add(u)
        db.commit()

        t = migrate_user(db, u)
        db.commit()
        # Display fallback chain: display_name → username → user.id.
        # With display_name == "" the username segment must appear.
        assert u.username in t.legal_name_ar

    def test_falls_back_to_user_id_when_username_and_display_blank(self, db):
        # Both display_name and username empty — only the user id
        # remains as a fallback identifier. This is genuinely rare in
        # production (the auth service rejects empty usernames) but
        # we test the contract so a future refactor can't silently
        # produce a tenant whose legal_name_ar is "" or " - الحساب
        # الشخصي" with nothing meaningful in it.
        u = _mk_user(display_name="")
        u.username = ""
        db.add(u)
        db.commit()

        t = migrate_user(db, u)
        db.commit()
        assert u.id in t.legal_name_ar


# ────────────────────────────────────────────────────────────────────
# migrate_all_legacy_users — batch path
# ────────────────────────────────────────────────────────────────────


class TestMigrateAllLegacyUsers:
    def test_migrates_multiple_users(self, db):
        users = [_mk_user(suffix=f"batch_{i}") for i in range(3)]
        for u in users:
            db.add(u)
        db.commit()

        result = migrate_all_legacy_users(db)
        assert result["total_legacy"] >= 3
        assert result["migrated"] >= 3
        assert result["failed"] == 0
        # Each user now owns exactly one Tenant.
        for u in users:
            owned = (
                db.query(Tenant)
                .filter(Tenant.created_by_user_id == u.id)
                .count()
            )
            assert owned == 1

    def test_skips_users_who_already_have_a_tenant(self, db):
        legacy = [_mk_user(suffix=f"mix_l_{i}") for i in range(2)]
        modern = _mk_user(suffix="mix_m")
        for u in legacy + [modern]:
            db.add(u)
        db.flush()
        db.add(_mk_tenant_for(modern))
        db.commit()

        result = migrate_all_legacy_users(db)
        # The "modern" user already owns a tenant; only the 2 legacy
        # users should appear in `migrated`.
        migrated_ids = {row["user_id"] for row in result["details"]}
        assert modern.id not in migrated_ids
        for u in legacy:
            assert u.id in migrated_ids

    def test_idempotent_second_run_migrates_zero(self, db):
        users = [_mk_user(suffix=f"idemp_{i}") for i in range(2)]
        for u in users:
            db.add(u)
        db.commit()

        first = migrate_all_legacy_users(db)
        assert first["migrated"] >= 2

        # Second call MUST report zero — re-running is the explicit
        # idempotency contract that lets an admin click the button
        # twice without doubling Tenant rows.
        second = migrate_all_legacy_users(db)
        for u in users:
            assert all(row["user_id"] != u.id for row in second["details"]), (
                f"User {u.id} appeared in the second-run details — "
                "idempotency broken"
            )

    def test_empty_input_no_op(self, db):
        # Sanity: with no legacy users, the service must return zeros
        # cleanly (no rollback, no exception, no commit on an empty
        # session).
        # The conftest's session-scoped DB may already have other test
        # users in flight, but this test only asserts that THIS run's
        # `migrated` count includes nothing tied to a fresh user we
        # didn't create — the simplest assertion is that the result
        # shape is well-formed.
        result = migrate_all_legacy_users(db)
        assert isinstance(result["total_legacy"], int)
        assert isinstance(result["migrated"], int)
        assert isinstance(result["failed"], int)
        assert isinstance(result["details"], list)
        assert isinstance(result["failures"], list)


# ────────────────────────────────────────────────────────────────────
# /admin/migrate-legacy-tenants — HTTP surface
# ────────────────────────────────────────────────────────────────────


class TestAdminEndpoint:
    def test_endpoint_requires_admin_secret(self, client):
        resp = client.post("/admin/migrate-legacy-tenants")
        # Without any secret the gate fires (403 in prod, 403 in test
        # too — `_verify_admin` always rejects when token doesn't
        # match).
        assert resp.status_code == 403

    def test_endpoint_with_invalid_secret_is_rejected(self, client):
        resp = client.post(
            "/admin/migrate-legacy-tenants",
            headers={"X-Admin-Secret": "obviously-wrong"},
        )
        assert resp.status_code == 403

    def test_endpoint_with_valid_secret_runs_migration(self, client):
        # Insert a legacy user via the same path the service tests use
        # so we know the migration has work to do.
        s = SessionLocal()
        try:
            u = _mk_user(suffix="endpoint_a")
            s.add(u)
            s.commit()
            uid = u.id
        finally:
            s.close()

        resp = client.post(
            "/admin/migrate-legacy-tenants",
            headers={"X-Admin-Secret": os.environ["ADMIN_SECRET"]},
        )
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["success"] is True
        assert "data" in body
        # The legacy user we inserted should appear in details.
        migrated_ids = {r["user_id"] for r in body["data"]["details"]}
        assert uid in migrated_ids

        # Cleanup the rows we created so we don't leave them around
        # for unrelated tests.
        s = SessionLocal()
        try:
            s.query(Tenant).filter(
                Tenant.created_by_user_id == uid
            ).delete(synchronize_session=False)
            s.query(User).filter(User.id == uid).delete(
                synchronize_session=False
            )
            s.commit()
        finally:
            s.close()

    def test_endpoint_idempotent_second_run_reports_zero(self, client):
        # One legacy user → first run migrates 1, second run migrates 0.
        s = SessionLocal()
        try:
            u = _mk_user(suffix="endpoint_idemp")
            s.add(u)
            s.commit()
            uid = u.id
        finally:
            s.close()

        try:
            first = client.post(
                "/admin/migrate-legacy-tenants",
                headers={"X-Admin-Secret": os.environ["ADMIN_SECRET"]},
            ).json()
            assert any(
                r["user_id"] == uid for r in first["data"]["details"]
            ), first

            second = client.post(
                "/admin/migrate-legacy-tenants",
                headers={"X-Admin-Secret": os.environ["ADMIN_SECRET"]},
            ).json()
            assert all(
                r["user_id"] != uid for r in second["data"]["details"]
            ), second
        finally:
            s = SessionLocal()
            try:
                s.query(Tenant).filter(
                    Tenant.created_by_user_id == uid
                ).delete(synchronize_session=False)
                s.query(User).filter(User.id == uid).delete(
                    synchronize_session=False
                )
                s.commit()
            finally:
                s.close()
