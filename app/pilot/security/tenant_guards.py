"""Tenant guard helpers for pilot routes.

Pilot models (Entity, JournalEntry, GLPosting, GLAccount, FiscalPeriod,
Tenant, …) do **not** inherit from
:class:`app.core.tenant_mixin.TenantMixin`. They declare ``tenant_id``
as a plain ``Column(String(36))``, which means
:func:`attach_tenant_guard` (the SQLAlchemy ``before_compile`` hook
that auto-injects ``WHERE tenant_id = :current_tenant``) silently
skips their queries. Every pilot route is therefore responsible for
gating tenant access explicitly.

This module is the single source of truth for that gate. It exposes
**three** helpers, one per route shape:

1. :func:`assert_entity_in_tenant` — for routes resolving by
   ``entity_id`` (path or payload).
2. :func:`assert_tenant_matches_user` — for routes shaped
   ``/tenants/{tenant_id}/...`` (the URL contains the tenant id).
3. :func:`assert_resource_in_tenant` — generic helper for routes
   resolving a non-entity resource (PO, PI, JE, Customer, Vendor,
   Product, Branch, …) directly by id.

History
-------
- 2026-05-08, G-TB-REAL-DATA-AUDIT (PR #174) — discovered cross-tenant
  read on the trial-balance endpoint. Fixed in-file with a local
  ``_entity_or_404`` helper.
- 2026-05-08, G-PILOT-REPORTS-TENANT-AUDIT (PR #175) — extracted
  ``assert_entity_in_tenant`` to this module; rolled out to all 32
  pilot routes taking ``entity_id``; switched the response code to
  **404 on cross-tenant** (anti-enumeration) and added structured
  violation logging.
- 2026-05-08, G-PILOT-TENANT-AUDIT-FINAL (this PR) — added the two
  remaining helpers (:func:`assert_tenant_matches_user` and
  :func:`assert_resource_in_tenant`); rolled out across the 37
  ``/tenants/{tid}/...`` routes and 48 ID-based routes; brought the
  pilot surface to full tenant-isolation coverage.
"""

from __future__ import annotations

import logging
from typing import Any, Callable, Mapping, Optional, Type

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.pilot.models.entity import Entity

logger = logging.getLogger(__name__)


# Same response body for "not found" and "exists but cross-tenant" so an
# attacker cannot distinguish the two by reading the response.
_NOT_FOUND_DETAIL = "Entity not found"

# Generic "Resource not found" body used by the helpers that don't deal
# with Entity specifically. Matched-string behaviour matters: a value
# that mentions the model name would leak the resource's existence on
# a cross-tenant probe even with a 404 status. Keep it generic.
_RESOURCE_NOT_FOUND_DETAIL = "Resource not found"


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


def assert_tenant_matches_user(
    tenant_id: str,
    current_user: Optional[Mapping[str, Any]],
) -> str:
    """Assert the URL's ``tenant_id`` matches the JWT's tenant claim.

    Used by routes shaped ``/tenants/{tenant_id}/...`` — the tenant id
    is in the URL, not behind an entity FK. Returns the validated
    ``tenant_id`` on success (so the route can keep using it as a
    query filter), raises :class:`HTTPException(404)` otherwise.

    Anti-enumeration: cross-tenant probes return **404 with the
    generic "Resource not found" body** — same shape a missing tenant
    would produce. The violation is logged server-side via
    :data:`logger` for SOC visibility.

    Examples
    --------
    ::

        @router.get("/tenants/{tenant_id}/products")
        def list_products(
            tenant_id: str,
            db: Session = Depends(get_db),
            current_user: dict = Depends(get_current_user),
        ):
            assert_tenant_matches_user(tenant_id, current_user)
            return db.query(Product).filter(
                Product.tenant_id == tenant_id
            ).all()
    """
    user_tenant = _extract_tenant_id(current_user)
    if not user_tenant or user_tenant != str(tenant_id):
        logger.warning(
            "TENANT_GUARD_VIOLATION user_id=%s user_tenant=%s "
            "requested_tenant=%s",
            (current_user or {}).get("user_id") or (current_user or {}).get("sub"),
            user_tenant,
            tenant_id,
        )
        raise HTTPException(404, _RESOURCE_NOT_FOUND_DETAIL)
    return str(tenant_id)


def assert_resource_in_tenant(
    db: Session,
    model: Type[Any],
    resource_id: str,
    current_user: Optional[Mapping[str, Any]],
    *,
    tenant_field: str = "tenant_id",
    tenant_resolver: Optional[Callable[[Session, Any], Optional[str]]] = None,
    soft_delete_field: Optional[str] = "is_deleted",
) -> Any:
    """Resolve a non-entity pilot resource (PO, PI, JE, Customer, …) by id,
    asserting it belongs to the caller's tenant.

    Generic helper for routes that hit a resource directly by primary
    key (no ``entity_id`` in the URL). The default behaviour reads the
    ``tenant_id`` column off the loaded row — which works for ~95 % of
    pilot tables, since almost all of them carry ``tenant_id`` as a
    plain column. For the few tables that don't (e.g.,
    :class:`ProductAttributeValue`, which scopes via
    ``attribute_id → ProductAttribute.tenant_id``), pass a
    ``tenant_resolver`` callback.

    Parameters
    ----------
    db
        Active SQLAlchemy session.
    model
        SQLAlchemy model class to resolve against (``PurchaseOrder``,
        ``SalesInvoice``, ``Customer``, …).
    resource_id
        The candidate primary-key value from the URL.
    current_user
        Result of ``Depends(get_current_user)``.
    tenant_field
        Name of the column holding the tenant id on this model.
        Defaults to ``"tenant_id"``. Set to ``None`` (and pass
        ``tenant_resolver``) for models that scope via FK chain.
    tenant_resolver
        Optional callable taking ``(db, resource)`` and returning the
        resolved tenant id. Used for models that don't carry
        ``tenant_id`` directly. The example case is
        ``ProductAttributeValue``, where the resolver follows
        ``value.attribute_id → ProductAttribute.tenant_id``.
    soft_delete_field
        Name of the column tracking soft deletion (``is_deleted`` by
        default). Pass ``None`` for models that don't soft-delete.

    Anti-enumeration: cross-tenant probes return **404 with
    "Resource not found"** — same body as a genuinely missing id, so
    the response code carries no existence signal.

    Examples
    --------
    Standard usage::

        @router.get("/purchase-orders/{po_id}")
        def get_po(
            po_id: str,
            db: Session = Depends(get_db),
            current_user: dict = Depends(get_current_user),
        ):
            po = assert_resource_in_tenant(
                db, PurchaseOrder, po_id, current_user
            )
            return po

    With a custom resolver (model has no ``tenant_id``)::

        def _attr_value_tenant(db, value):
            attr = db.get(ProductAttribute, value.attribute_id)
            return attr.tenant_id if attr else None

        @router.post("/attributes/{attribute_id}/values")
        def create_value(
            attribute_id: str,
            db: Session = Depends(get_db),
            current_user: dict = Depends(get_current_user),
        ):
            assert_resource_in_tenant(
                db, ProductAttribute, attribute_id, current_user
            )
            ...
    """
    resource = db.get(model, resource_id)
    if resource is None:
        raise HTTPException(404, _RESOURCE_NOT_FOUND_DETAIL)

    if soft_delete_field is not None:
        flag = getattr(resource, soft_delete_field, None)
        if flag is True:
            raise HTTPException(404, _RESOURCE_NOT_FOUND_DETAIL)

    if tenant_resolver is not None:
        resource_tenant: Optional[str] = tenant_resolver(db, resource)
    else:
        raw = getattr(resource, tenant_field, None)
        resource_tenant = str(raw) if raw is not None else None

    if resource_tenant is None:
        # Defensive: a row whose tenant we can't resolve is treated as
        # not-found rather than allowed-by-default.
        raise HTTPException(404, _RESOURCE_NOT_FOUND_DETAIL)

    user_tenant = _extract_tenant_id(current_user)
    if not user_tenant or resource_tenant != user_tenant:
        logger.warning(
            "TENANT_GUARD_VIOLATION user_id=%s user_tenant=%s "
            "model=%s resource_id=%s resource_tenant=%s",
            (current_user or {}).get("user_id") or (current_user or {}).get("sub"),
            user_tenant,
            model.__name__,
            resource_id,
            resource_tenant,
        )
        raise HTTPException(404, _RESOURCE_NOT_FOUND_DETAIL)

    return resource
