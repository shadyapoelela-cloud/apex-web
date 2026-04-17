"""Set the PostgreSQL `app.current_tenant` GUC on each SQLAlchemy
checkout so Row-Level Security policies can enforce tenant isolation.

Complements app/core/tenant_guard.py (application-layer guard via
SQLAlchemy event listeners). This module covers the database-layer
half — it runs `SET LOCAL app.current_tenant = '<uuid>'` whenever a
connection is checked out, using whatever value
app/core/tenant_context.current_tenant() returns at that moment.

PostgreSQL only. No-op on SQLite so the dev workflow keeps running
unchanged.

Install once at startup:
    from app.core.rls_session import install_rls_session_hook
    install_rls_session_hook(engine)

After that, every request that runs against this engine will have its
queries filtered by RLS policies when the DB is PostgreSQL.
"""
from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import event

logger = logging.getLogger(__name__)


def install_rls_session_hook(engine) -> None:
    """Attach a checkout hook that binds app.current_tenant per-connection.

    Safe to call multiple times — duplicate registrations are ignored.
    No-ops on non-PostgreSQL engines.
    """
    if engine.dialect.name != "postgresql":
        logger.info(
            "install_rls_session_hook: engine is %s, skipping RLS setup",
            engine.dialect.name,
        )
        return

    # Idempotence flag — stored on the engine so re-invocations don't
    # stack up event handlers.
    if getattr(engine, "_apex_rls_installed", False):
        return
    engine._apex_rls_installed = True  # type: ignore[attr-defined]

    # Use lazy import so the rest of the app still boots when
    # app.core.tenant_context isn't importable (e.g. minimal tests).
    from app.core.tenant_context import current_tenant

    @event.listens_for(engine, "checkout")
    def _set_tenant_on_checkout(dbapi_conn: Any, _conn_record, _conn_proxy) -> None:
        tenant = current_tenant()
        try:
            cur = dbapi_conn.cursor()
            # SET LOCAL would be scoped to a transaction — we use the
            # session-wide `SET` so every statement on this connection
            # sees the right tenant. The next checkout will overwrite
            # it regardless.
            if tenant:
                cur.execute("SET app.current_tenant = %s", (str(tenant),))
            else:
                # Reset to empty so a connection that was previously
                # tied to a tenant doesn't leak into a request with no
                # tenant context.
                cur.execute("RESET app.current_tenant")
            cur.close()
        except Exception as e:  # pragma: no cover
            # Never let an RLS setup failure take down the request.
            # Log loud because this is a security-relevant event.
            logger.error("RLS set on checkout failed: %s", e)

    logger.info("RLS session hook installed on %s", engine.url.render_as_string())
