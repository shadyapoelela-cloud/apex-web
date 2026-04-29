"""
APEX — Cash Flow Forecast HTTP routes.
=======================================
Public + admin endpoints for the algorithmic cash-flow forecast service
(see app/core/cashflow_forecast.py).

Endpoints:
    GET /api/v1/forecast/cashflow?tenant_id=...&entity_id=...&weeks=4&history_weeks=12
        Authenticated end-user endpoint. Returns the forecast for the
        caller's tenant (tenant_id derived from the JWT in production;
        accepted as a query param here for simplicity in v1).

    POST /admin/forecast/cashflow {tenant_id, entity_id, weeks, history_weeks, starting_balance}
        Admin variant — supports starting_balance override and any tenant.

Both share the same JSON response shape.
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.cashflow_forecast import forecast_cashflow, is_available

router = APIRouter(tags=["forecast"])

_ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _verify_admin(x_admin_secret: Optional[str]) -> None:
    import secrets

    if not _ADMIN_SECRET:
        if _IS_PRODUCTION:
            raise HTTPException(500, "ADMIN_SECRET not configured on server")
        return
    if not x_admin_secret or not secrets.compare_digest(x_admin_secret, _ADMIN_SECRET):
        raise HTTPException(403, "Invalid admin secret")


@router.get("/api/v1/forecast/cashflow")
def public_cashflow_forecast(
    tenant_id: str = Query(..., min_length=1),
    entity_id: Optional[str] = Query(None),
    weeks: int = Query(4, ge=1, le=52),
    history_weeks: int = Query(12, ge=4, le=104),
):
    """Cash-flow forecast for the authenticated user's tenant.

    Production note: tenant_id should be derived from the JWT in
    `tenant_context`, not accepted from the client. This v1 endpoint
    keeps the API surface minimal; tighten before going live.
    """
    if not is_available():
        raise HTTPException(503, "Forecast service unavailable: GL models not loaded")
    return forecast_cashflow(
        tenant_id=tenant_id,
        entity_id=entity_id,
        weeks=weeks,
        history_weeks=history_weeks,
    )


class AdminForecastRequest(BaseModel):
    tenant_id: str = Field(..., min_length=1)
    entity_id: Optional[str] = None
    weeks: int = Field(4, ge=1, le=52)
    history_weeks: int = Field(12, ge=4, le=104)
    starting_balance: float = 0.0


@router.post("/admin/forecast/cashflow")
def admin_cashflow_forecast(
    payload: AdminForecastRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Admin variant — supports starting_balance + arbitrary tenant_id."""
    _verify_admin(x_admin_secret)
    if not is_available():
        raise HTTPException(503, "Forecast service unavailable: GL models not loaded")
    return forecast_cashflow(
        tenant_id=payload.tenant_id,
        entity_id=payload.entity_id,
        weeks=payload.weeks,
        history_weeks=payload.history_weeks,
        starting_balance=payload.starting_balance,
    )
