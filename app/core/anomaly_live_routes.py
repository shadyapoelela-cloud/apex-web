"""
APEX — Anomaly Live admin routes
=================================
Trigger scans + inspect rolling buffer state. Hook into cron:
    0 */1 * * *  curl -XPOST -H "X-Admin-Secret: $S" \\
                       https://apex-api.example/admin/anomaly/scan-all
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

from app.core.anomaly_live import (
    buffer_size,
    clear_buffer,
    scan_all_tenants,
    scan_tenant,
)

router = APIRouter(prefix="/admin/anomaly", tags=["admin", "anomaly"])

_ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _verify(x: Optional[str]) -> None:
    import secrets

    if not _ADMIN_SECRET:
        if _IS_PRODUCTION:
            raise HTTPException(500, "ADMIN_SECRET not configured on server")
        return
    if not x or not secrets.compare_digest(x, _ADMIN_SECRET):
        raise HTTPException(403, "Invalid admin secret")


@router.post("/scan")
def scan_one(
    tenant_id: str = Query(..., min_length=1),
    emit_events: bool = Query(True),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    return scan_tenant(tenant_id, emit_events=emit_events)


@router.post("/scan-all")
def scan_all(
    emit_events: bool = Query(True),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Cron entry point — scan every tenant with a non-empty buffer."""
    _verify(x_admin_secret)
    return scan_all_tenants(emit_events=emit_events)


@router.get("/buffer")
def buffer(
    tenant_id: Optional[str] = None,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    return {"success": True, "size": buffer_size(tenant_id), "tenant_id": tenant_id}


@router.post("/clear-buffer")
def clear(
    tenant_id: Optional[str] = None,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    clear_buffer(tenant_id)
    return {"success": True}
