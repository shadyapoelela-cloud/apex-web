"""Tenant-isolation primitives for pilot routes.

Pilot models declare ``tenant_id`` as a plain column instead of
inheriting :class:`TenantMixin`, so the global ``attach_tenant_guard``
silently skips them. Every route resolving a pilot entity by id must
therefore enforce tenant isolation explicitly via
:func:`assert_entity_in_tenant`.

History: gap discovered in G-TB-REAL-DATA-AUDIT (2026-05-08, PR #174);
closed across all pilot routes in G-PILOT-REPORTS-TENANT-AUDIT.
"""

from app.pilot.security.tenant_guards import assert_entity_in_tenant

__all__ = ["assert_entity_in_tenant"]
