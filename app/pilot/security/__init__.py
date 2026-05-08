"""Tenant-isolation primitives for pilot routes.

Pilot models declare ``tenant_id`` as a plain column instead of
inheriting :class:`TenantMixin`, so the global ``attach_tenant_guard``
silently skips them. Every pilot route is therefore responsible for
enforcing tenant isolation explicitly via one of three helpers:

* :func:`assert_entity_in_tenant` — for routes resolving by
  ``entity_id`` (path or payload).
* :func:`assert_tenant_matches_user` — for routes shaped
  ``/tenants/{tenant_id}/...``.
* :func:`assert_resource_in_tenant` — for routes resolving a
  non-entity resource (PO, PI, JE, Customer, Vendor, Product, …) by id.

See ``docs/PILOT_TENANT_GUARD_PATTERN.md`` for the decision table.

History: G-TB-REAL-DATA-AUDIT (PR #174) discovered the gap;
G-PILOT-REPORTS-TENANT-AUDIT (PR #175) added
:func:`assert_entity_in_tenant`; G-PILOT-TENANT-AUDIT-FINAL (this PR)
added the remaining two helpers and closed the surface.
"""

from app.pilot.security.tenant_guards import (
    assert_entity_in_tenant,
    assert_resource_in_tenant,
    assert_tenant_matches_user,
)

__all__ = [
    "assert_entity_in_tenant",
    "assert_resource_in_tenant",
    "assert_tenant_matches_user",
]
