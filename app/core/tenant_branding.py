"""Per-tenant branding / white-label config.

Stores the theme JSON that Flutter's ApexWhiteLabelEditor emits, per
tenant. On login the Flutter app pulls `/api/v1/tenant/branding` and
rebuilds MaterialApp with the tenant's colours, brand text, radius,
etc. A companion `PUT` endpoint writes new config (admin-only).

All rows tenant-scoped via TenantMixin — there's at most one row per
tenant (enforced by app-layer upsert).
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import Boolean, Column, DateTime, Float, String

from app.core.api_versioning import v1_prefix
from app.core.tenant_guard import TenantMixin, current_tenant
from app.phase1.models.platform_models import Base, SessionLocal

logger = logging.getLogger(__name__)


class TenantBranding(Base, TenantMixin):
    """One branding config row per tenant. Upsert semantics — the API
    creates on first write, updates thereafter."""

    __tablename__ = "tenant_branding"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    brand_text = Column(String(120), nullable=False, default="APEX")
    primary_hex = Column(String(9), nullable=False, default="#D4AF37")
    secondary_hex = Column(String(9), nullable=False, default="#2E75B6")
    dark_mode = Column(Boolean, nullable=False, default=True)
    radius_scale = Column(Float, nullable=False, default=1.0)
    type_scale = Column(Float, nullable=False, default=1.0)
    logo_url = Column(String(500), nullable=True)
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )


class BrandingPayload(BaseModel):
    brand_text: str = Field(..., min_length=1, max_length=120)
    primary_hex: str = Field(..., pattern=r"^#[0-9A-Fa-f]{6,8}$")
    secondary_hex: str = Field(..., pattern=r"^#[0-9A-Fa-f]{6,8}$")
    dark_mode: bool = True
    radius_scale: float = Field(1.0, ge=0.5, le=2.5)
    type_scale: float = Field(1.0, ge=0.75, le=1.5)
    logo_url: Optional[str] = Field(None, max_length=500)


router = APIRouter(prefix=v1_prefix("/tenant/branding"), tags=["Tenant Branding"])


def _to_dict(row: TenantBranding) -> dict:
    return {
        "brand_text": row.brand_text,
        "primary_hex": row.primary_hex,
        "secondary_hex": row.secondary_hex,
        "dark_mode": row.dark_mode,
        "radius_scale": row.radius_scale,
        "type_scale": row.type_scale,
        "logo_url": row.logo_url,
        "updated_at": row.updated_at.isoformat(),
    }


@router.get("")
def get_branding():
    """Return the calling tenant's branding, or defaults if never set."""
    tenant = current_tenant()
    db = SessionLocal()
    try:
        row = (
            db.query(TenantBranding)
            .filter(TenantBranding.tenant_id == tenant)
            .first()
        )
        if row is None:
            # Return defaults — the Flutter app can render without waiting
            # for a write.
            return {
                "success": True,
                "data": {
                    "brand_text": "APEX",
                    "primary_hex": "#D4AF37",
                    "secondary_hex": "#2E75B6",
                    "dark_mode": True,
                    "radius_scale": 1.0,
                    "type_scale": 1.0,
                    "logo_url": None,
                    "updated_at": None,
                },
            }
        return {"success": True, "data": _to_dict(row)}
    finally:
        db.close()


@router.put("")
def upsert_branding(payload: BrandingPayload):
    """Admin upsert — writes (or replaces) the tenant's branding row.

    Identity-verification and role-check belong to middleware above this
    endpoint; this handler assumes the caller is allowed to change the
    tenant's own branding.
    """
    tenant = current_tenant()
    if not tenant:
        raise HTTPException(
            status_code=400, detail="tenant context required"
        )
    db = SessionLocal()
    try:
        row = (
            db.query(TenantBranding)
            .filter(TenantBranding.tenant_id == tenant)
            .first()
        )
        if row is None:
            row = TenantBranding(
                id=str(uuid.uuid4()),
                tenant_id=tenant,
                brand_text=payload.brand_text,
                primary_hex=payload.primary_hex,
                secondary_hex=payload.secondary_hex,
                dark_mode=payload.dark_mode,
                radius_scale=payload.radius_scale,
                type_scale=payload.type_scale,
                logo_url=payload.logo_url,
            )
            db.add(row)
        else:
            row.brand_text = payload.brand_text
            row.primary_hex = payload.primary_hex
            row.secondary_hex = payload.secondary_hex
            row.dark_mode = payload.dark_mode
            row.radius_scale = payload.radius_scale
            row.type_scale = payload.type_scale
            row.logo_url = payload.logo_url
            row.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(row)
        return {"success": True, "data": _to_dict(row)}
    finally:
        db.close()
