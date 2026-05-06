"""APEX Dashboard module — customizable per-user dashboards with RBAC.

Public surface:
    from app.dashboard.models import DashboardWidget, DashboardLayout, DashboardDataCache
    from app.dashboard.router import router

The router is mounted by app/main.py under /api/v1/dashboard/* via the
HAS_DASHBOARD try/except guard pattern (see app/main.py for the
canonical wiring spot).

Cross-references:
    - app/core/saved_views.py — persistence pattern this module follows.
    - app/core/cache.py — TTL-cached widget payloads (`dashboard:*`).
    - app/core/event_bus.py — feeds SSE stream + cache invalidation.
    - app/core/custom_roles.py — 4 new permissions registered:
        read:dashboard, customize:dashboard, manage:dashboard_role,
        lock:dashboard.
    - app/pilot/models/rbac.py — scope mixin used by layout records.

See app/dashboard/README.md for architecture overview.
"""

from __future__ import annotations
