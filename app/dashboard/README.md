# `app.dashboard` — Customizable Dashboard

Per-user, per-role, per-tenant dashboards with permission-based widget
filtering and SSE-driven live updates.

## Architecture

```
                            ┌──────────────────────┐
                            │   FastAPI router     │  /api/v1/dashboard/*
                            │   (router.py)        │
                            └──────────┬───────────┘
                                       │
                                       ▼
   permissions ───────►  ┌──────────────────────┐
                         │   service.py         │  filter, fallback chain,
                         │                      │  resolver dispatch
                         └──────┬────────┬──────┘
                                │        │
                ┌───────────────┘        └────────────────┐
                ▼                                          ▼
        ┌────────────────┐                       ┌────────────────┐
        │   models.py    │                       │  events.py     │
        │  (3 ORM tables)│                       │  hub + listeners
        └────────┬───────┘                       └────────┬───────┘
                 │                                        │
                 ▼                                        ▼
        ┌────────────────┐                       ┌────────────────┐
        │  PostgreSQL    │                       │  app.core      │
        │  (alembic)     │                       │  event_bus     │
        └────────────────┘                       └────────────────┘
```

### Files

| file              | role                                             |
| ----------------- | ------------------------------------------------ |
| `models.py`       | 3 SQLAlchemy tables: widgets / layouts / cache.  |
| `schemas.py`      | Pydantic v2 request/response models.             |
| `service.py`      | Permission filter, layout fallback, resolver dispatch, batch executor, cache mirroring. |
| `router.py`       | 10 endpoints + SSE stream.                        |
| `seeds.py`        | 12 system widgets + 5 role layouts + system fallback. |
| `events.py`       | event_bus listener + SSE pub/sub hub.            |
| `resolvers.py`    | Per-widget data sources (wired in Phase 2 work). |

### Tables

| table                  | scope            | notes                                |
| ---------------------- | ---------------- | ------------------------------------ |
| `dashboard_widgets`    | system + tenant  | catalog; required_perms is JSON.      |
| `dashboard_layouts`    | user/role/tenant/system | unique on (tenant_id, scope, owner_id, name). |
| `dashboard_data_cache` | global           | snapshots for SSE replay; expiry index. |

## Permissions (added to `app.core.custom_roles`)

| perm                       | scope     | who                               |
| -------------------------- | --------- | --------------------------------- |
| `read:dashboard`           | platform  | every authed user (auto)          |
| `customize:dashboard`      | platform  | end-user can save own layout      |
| `manage:dashboard_role`    | admin     | tenant admin sets role defaults   |
| `lock:dashboard`           | admin     | freeze a layout from edits        |

## Layout fallback chain

When `GET /layout` runs, the service resolves the user's effective
layout in this order:

1. **`scope=user`** — owner_id matches user_id.
2. **`scope=role`** — owner_id matches the user's primary role.
3. **`scope=tenant`** — tenant_id matches caller's tenant.
4. **`scope=system`** — last resort; the platform-wide default.

`save_user_layout` writes scope=user. `save_role_layout` writes
scope=role and respects `lock:dashboard`.

## Endpoints

| method | path                                | required perm           |
| ------ | ----------------------------------- | ----------------------- |
| GET    | /widgets                            | `read:dashboard`        |
| GET    | /layout                             | `read:dashboard`        |
| PUT    | /layout                             | `customize:dashboard`   |
| POST   | /layout/reset                       | `customize:dashboard`   |
| GET    | /role-layouts                       | `manage:dashboard_role` |
| PUT    | /role-layouts/{role_id}             | `manage:dashboard_role` |
| POST   | /role-layouts/{role_id}/lock        | `lock:dashboard`        |
| POST   | /data/batch                         | `read:dashboard` (filtered per widget) |
| GET    | /data/{widget_code}                 | per widget perms        |
| GET    | /stream                             | `read:dashboard` (SSE)  |

All return the canonical envelope:

```json
{ "success": true, "data": ... }
```

## Adding a new widget

1. **Catalog** — append a dict to `seeds.SYSTEM_WIDGETS` with code,
   labels, type, data_source, required_perms, refresh_secs.
2. **Resolver** — register a function in `resolvers.py`:

   ```python
   from app.dashboard.service import register_resolver

   def _my_widget(ctx: dict) -> dict:
       return {"value": 42}

   register_resolver("my.widget", _my_widget)
   ```

3. **Migration** — none needed unless you add new columns.
4. **Tests** — add a row in `tests/test_dashboard_api.py::test_widget_catalog`.

## Cache invalidation

`events.py::EVENT_INVALIDATIONS` maps event_bus events to widget codes.
When `invoice.posted` fires, `kpi.cash_balance`, `kpi.ar_outstanding`,
`chart.revenue_30d`, and `list.recent_invoices` all get dropped from
the cache and an SSE `invalidate` record is pushed to connected clients.

To add a new mapping, edit the dict — no code changes elsewhere needed.

## SSE protocol

```
GET /api/v1/dashboard/stream
Accept: text/event-stream

event: hello
data: {"ok": true, "ts": "..."}

event: ping
data: {"ts": "..."}                         # every 25s

event: invalidate
data: {"event": "invoice.posted", "widget_codes": [...], ...}

event: update
data: {"widget_code": "kpi.cash_balance", "payload": {...}}
```

The frontend `dashboardStream()` listener routes by `widget_code` and
re-renders only that widget — no full-dashboard re-render.

## Cross-references

- `app/core/saved_views.py` — same persistence shape (UNIQUE on tenant +
  scope + owner + name; JSON payload).
- `app/core/cache.py` — TTL cache; this module reuses it via `tenant_key`.
- `app/core/event_bus.py` — invalidation source.
- `app/core/custom_roles.py` — 4 new permissions registered there.
- `apex_finance/lib/core/apex_dashboard_builder.dart` — drag/drop frontend.

## Status

| phase | what                                      | done |
| ----- | ----------------------------------------- | ---- |
| 0     | Scaffold module + README                  | ✅   |
| 1     | Models + permissions + alembic migration  | ✅   |
| 2     | Seeds + service layer + resolvers         | ✅   |
| 3     | API endpoints + SSE + tests               | ✅   |
| 4     | Frontend (api_service + customizable screen + renderers) | partial |
| 5     | Permission hardening + 15 tests           | ✅   |
| 6     | Coverage 85% + perf + docs + PR           | partial |
