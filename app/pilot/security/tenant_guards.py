"""Tenant guard helpers for pilot routes.

Pilot models (Entity, JournalEntry, GLPosting, GLAccount, FiscalPeriod,
Tenant, …) do **not** inherit from
:class:`app.core.tenant_mixin.TenantMixin`. They declare ``tenant_id``
as a plain ``Column(String(36))``, which means
:func:`attach_tenant_guard` (the SQLAlchemy ``before_compile`` hook
that auto-injects ``WHERE tenant_id = :current_tenant``) silently
skips their queries. Every pilot route resolving an entity by id is
therefore responsible for gating tenant access explicitly.

This module provides the single source of truth for that gate.

History
-------
- 2026-05-08, G-TB-REAL-DATA-AUDIT (PR #174) — discovered cross-tenant
  read on the trial-balance endpoint. Fixed in-file with a local
  ``_entity_or_404`` helper.
- 2026-05-08, G-PILOT-REPORTS-TENANT-AUDIT (this PR) — extracted to
  this module; rolled out to all 32 pilot routes that take
  ``entity_id``; switched the response code to **404 on cross-tenant**
  (anti-enumeration) and added structured violation logging.
"""

from __future__ import annotations

import logging
from typing import Any, Mapping, Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.pilot.models.entity import Entity

logger = logging.getLogger(__name__)


# Same response body for "not found" and "exists but cross-tenant" so an
# attacker cannot distinguish the two by reading the response.
_NOT_FOUND_DETAIL = "Entity not found"


def _extract_tenant_id(current_user: Optional[Mapping[str, Any]]) -> Optional[str]:
    """Pull the tenant id out of the ``current_user`` dependency.

    Production tokens (post-PR #169 / ERR-2 Phase 3) carry both
    ``tenant_id`` and ``tid``; older tokens may carry only one. Returns
    ``None`` if neither is present — caller decides what to do with
    that.
    """
    if not current_user:
        return None
    raw = current_user.get("tenant_id") or current_user.get("tid")
    return str(raw) if raw else None


def assert_entity_in_tenant(
    db: Session,
    entity_id: str,
    current_user: Optional[Mapping[str, Any]],
) -> Entity:
    """Resolve a pilot entity, asserting it belongs to the caller's tenant.

    The single source of truth for tenant-isolation enforcement on
    pilot routes. Returns the loaded :class:`Entity` on success, raises
    :class:`HTTPException` otherwise.

    Anti-enumeration design choice
    ------------------------------
    Cross-tenant probes return **404 with the same body** as a genuinely
    missing id. Returning 403 in that case would leak existence — an
    attacker could iterate UUIDs and read "403 → exists" vs "404 →
    doesn't exist". Status code 404 + identical body keeps both cases
    indistinguishable to the client. The violation is recorded server-
    side via :data:`logger` with structured fields so SOC dashboards
    can still detect probing.

    Parameters
    ----------
    db
        Active SQLAlchemy session.
    entity_id
        The candidate entity UUID (from the URL path or request body).
    current_user
        The dict returned by ``Depends(get_current_user)``. Pass
        ``None`` only from internal callers that genuinely lack a JWT
        context — every public route should pass the dependency value.

    Raises
    ------
    HTTPException(404)
        Either the entity does not exist, or it belongs to a different
        tenant, or ``current_user`` carries no ``tenant_id`` claim.
        The detail body is identical in all three cases.

    Examples
    --------
    Standard route usage::

        @router.get("/entities/{entity_id}/reports/balance-sheet")
        def balance_sheet(
            entity_id: str,
            db: Session = Depends(get_db),
            current_user: dict = Depends(get_current_user),
        ):
            assert_entity_in_tenant(db, entity_id, current_user)
            ...

    Payload-shaped routes (entity_id from request body)::

        @router.post("/purchase-orders")
        def create_po(
            payload: PoCreate,
            db: Session = Depends(get_db),
            current_user: dict = Depends(get_current_user),
        ):
            entity = assert_entity_in_tenant(db, payload.entity_id, current_user)
            ...
    """
    e = (
        db.query(Entity)
        .filter(Entity.id == entity_id, Entity.is_deleted == False)  # noqa: E712
        .first()
    )
    if e is None:
        raise HTTPException(404, _NOT_FOUND_DETAIL)

    user_tenant = _extract_tenant_id(current_user)
    if not user_tenant or str(e.tenant_id) != user_tenant:
        # Structured log — SOC + audit pipelines key on the prefix.
        # Do NOT echo back the existence signal in the response.
        logger.warning(
            "TENANT_GUARD_VIOLATION user_id=%s user_tenant=%s "
            "requested_entity=%s entity_tenant=%s",
            (current_user or {}).get("user_id") or (current_user or {}).get("sub"),
            user_tenant,
            entity_id,
            e.tenant_id,
        )
        raise HTTPException(404, _NOT_FOUND_DETAIL)

    return e
