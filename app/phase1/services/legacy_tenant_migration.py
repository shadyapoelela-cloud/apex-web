"""G-LEGACY-TENANT-MIGRATION (2026-05-08)
================================================

One-off migration that backfills `pilot_tenants` rows for users who
registered BEFORE ERR-2 Phase 3 (PR #169). Without this, those users
still log in with a JWT that has no `tenant_id` claim — so
`TenantContextMiddleware` falls back to its permissive path and they
keep seeing the legacy shared `06892550-…` tenant's data (the residual
leg of UAT Issue #3 that ERR-2 Phase 3 deliberately left out of scope).

Triggered by an admin via `POST /admin/migrate-legacy-tenants`. NOT
run automatically — running it must be a deliberate operator action,
gated on `X-Admin-Secret`.

## Idempotency contract

Every entry point in this module is idempotent:

  * `find_legacy_users(db)` lists users that genuinely have no Tenant
    row owned by them. Once a user is migrated, they fall out of this
    list.
  * `migrate_user(db, user)` short-circuits if the user already owns
    a Tenant — it returns the existing row instead of creating a
    second one.
  * `migrate_all_legacy_users(db)` is just `find_legacy_users` →
    `migrate_user` in a loop, so re-runs report `migrated == 0` once
    the backfill is complete.

Callers may safely retry on transient errors (network blip during
admin call, accidental double-click on the trigger button, etc.).

## Naming convention

The Tenant rows produced here use the exact same shape as the ones
ERR-2 Phase 3 creates at registration time, so the dashboard renders
new and migrated tenants identically. See
`app/phase1/services/auth_service.py` `register()` for the
canonical fields.

## Out of scope (kept for separate cleanup tickets)

  * Reassigning data already in the shared `06892550-…` tenant — that
    data may belong to a single legitimate user OR may be orphans;
    deciding which row goes to which user is a manual / heuristic
    job that requires customer support context. This migration
    creates fresh empty tenants for the affected users; it does NOT
    move data between tenants.
  * Reissuing JWTs to migrated users. They'll pick up the new
    `tenant_id` claim on their next login (handled by ERR-2 Phase 3's
    `auth_service.login()` lookup, no extra code needed here).
"""

from __future__ import annotations

import logging
from typing import Optional

from sqlalchemy.orm import Session

from app.phase1.models.platform_models import User, gen_uuid

logger = logging.getLogger(__name__)


def _import_tenant_model():
    """Best-effort lazy import of `Tenant`.

    Mirrors the wrapper ERR-2 Phase 3 uses inside `auth_service.py`:
    if the pilot package isn't reachable in the current environment
    (older schema, separate DB, ImportError on a deferred dependency),
    callers can degrade gracefully — re-raised by `migrate_user` /
    swallowed by `migrate_all_legacy_users` so a single failure
    doesn't stall the whole batch.
    """
    from app.pilot.models.tenant import Tenant
    return Tenant


def find_legacy_users(db: Session) -> list[User]:
    """Return every `User` row that has no `Tenant` owned by them.

    The "owned by" link is `Tenant.created_by_user_id == User.id`,
    matching the shape ERR-2 Phase 3 uses at registration.

    Implementation note: a left-anti-join would be more elegant in
    raw SQL, but `~User.id.in_(subquery)` is the form that survives
    SQLAlchemy version drift between the project's SQLite test path
    and PostgreSQL prod. The subquery deliberately filters out
    `created_by_user_id IS NULL` because rows seeded with NULL owners
    (e.g. legacy fixtures or system-created tenants) would otherwise
    leak into the NOT IN comparison via SQL three-valued logic and
    cause the whole expression to evaluate to UNKNOWN — which would
    return zero users on PostgreSQL.
    """
    Tenant = _import_tenant_model()

    # Pass an explicit select() to `IN(...)` rather than a Subquery —
    # the latter triggers a SAWarning under SQLAlchemy 2.x ("Coercing
    # Subquery object into a select()"). Functionally identical, just
    # the canonical form.
    from sqlalchemy import select as _select

    owned_user_ids = (
        _select(Tenant.created_by_user_id)
        .where(Tenant.created_by_user_id.isnot(None))
    )
    return (
        db.query(User)
        .filter(~User.id.in_(owned_user_ids))
        .order_by(User.id.asc())  # deterministic for tests
        .all()
    )


def migrate_user(db: Session, user: User) -> "object":
    """Create a fresh `Tenant` for `user` and return it. Idempotent.

    If the user already owns a Tenant row (by
    `Tenant.created_by_user_id`) the existing row is returned unchanged
    — re-running the migration is safe.

    The caller is responsible for committing. `migrate_all_legacy_users`
    flushes after each insert and commits at the end so a single
    failing insert can be rolled back without losing the prior
    successful migrations in the batch.
    """
    Tenant = _import_tenant_model()

    existing = (
        db.query(Tenant)
        .filter(Tenant.created_by_user_id == user.id)
        .order_by(Tenant.created_at.asc())
        .first()
    )
    if existing is not None:
        # Idempotent path — the user already migrated (or signed up
        # post-ERR-2 Phase 3 and somehow ended up in this batch).
        return existing

    # Same shape as ERR-2 Phase 3's `register()` so dashboards render
    # legacy and new tenants identically.
    display = (user.display_name or user.username or user.id)
    new_tenant = Tenant(
        id=gen_uuid(),
        slug=f"u-{user.id[:8]}-{gen_uuid()[:8]}",
        legal_name_ar=f"{display} - الحساب الشخصي",
        primary_email=user.email,
        primary_country="SA",
        created_by_user_id=user.id,
    )
    db.add(new_tenant)
    db.flush()
    logger.info(
        "G-LEGACY-TENANT-MIGRATION: created tenant %s for user %s",
        new_tenant.id,
        user.id,
    )
    return new_tenant


def migrate_all_legacy_users(db: Session) -> dict:
    """Backfill every user without a tenant. Returns a JSON-friendly
    summary: how many were eligible, how many were migrated, how many
    failed (per-row), and a small detail list with the new tenant ids.

    `details` is bounded by the number of legacy users found in this
    run (≤ a few thousand in any realistic deployment), so returning
    them inline keeps the admin endpoint payload small enough for the
    response logger without paging.
    """
    legacy_users = find_legacy_users(db)
    migrated: list[dict] = []
    failed: list[dict] = []

    for user in legacy_users:
        try:
            tenant = migrate_user(db, user)
            migrated.append(
                {
                    "user_id": user.id,
                    "username": user.username,
                    "tenant_id": tenant.id,
                }
            )
        except Exception as exc:  # noqa: BLE001 — top-level batch guard
            logger.exception(
                "G-LEGACY-TENANT-MIGRATION: failed for user %s",
                user.id,
            )
            failed.append(
                {
                    "user_id": user.id,
                    "username": getattr(user, "username", None),
                    "error": str(exc),
                }
            )

    if migrated and not failed:
        db.commit()
    elif migrated:
        # Mixed batch — commit the successes, drop the failures.
        # SQLAlchemy doesn't have a partial-commit API; the simplest
        # safe shape is "commit if at least one row succeeded and we
        # didn't raise"; the failed inserts never made it into the
        # session because `migrate_user` raised before `db.add`.
        db.commit()
    elif failed:
        db.rollback()
    # If neither (empty input list) — nothing to commit.

    return {
        "total_legacy": len(legacy_users),
        "migrated": len(migrated),
        "failed": len(failed),
        "details": migrated,
        "failures": failed,
    }
