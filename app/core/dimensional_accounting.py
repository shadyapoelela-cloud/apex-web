"""Dimensional Accounting — tag journal entries with branch/project/cost-center.

Problem: legacy accounting has a flat COA. Reports by project, branch, or
department require separate accounts per combo — 100 accounts × 10 projects
= 1000 accounts. Unmanageable.

Solution (Sage Intacct pattern): keep a flat, clean COA and attach
"dimension tags" to each journal entry line. A dimension is a named axis
(branch, project, department, cost_center, product_line, customer, …)
with a set of values. Reports then pivot the ledger on any dimension.

This module ships:
  • DimensionDef — declarative dimension + its values.
  • DimensionValue — one member of a dimension.
  • JournalEntryDimension — link table tying a JE line to
    (dimension, value).
  • CRUD service + API under /api/v1/dimensions/*.
  • aggregate_by_dimension(period, dimension_id) helper — pivot a period's
    ledger by one dimension (for reports + dashboards).

Tenancy: all tables inherit TenantMixin so each tenant has its own
dimensions + values.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import Boolean, Column, DateTime, Numeric, String, UniqueConstraint

from app.core.api_version import v1_prefix
from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base, SessionLocal

logger = logging.getLogger(__name__)


# ── Models ─────────────────────────────────────────────────


class DimensionDef(Base, TenantMixin):
    """A dimension axis — e.g. 'branch', 'project', 'cost_center'."""

    __tablename__ = "dimension_defs"
    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_dim_def_tenant_code"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    code = Column(String(32), nullable=False, index=True)   # 'branch' | 'project' | ...
    name_ar = Column(String(120), nullable=False)
    name_en = Column(String(120), nullable=True)
    required = Column(Boolean, nullable=False, default=False)
    # If required, every journal entry line must carry a value for this dimension.
    active = Column(Boolean, nullable=False, default=True)
    created_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )


class DimensionValue(Base, TenantMixin):
    """A value in a dimension — e.g. branch 'Riyadh', project 'Alpha'."""

    __tablename__ = "dimension_values"
    __table_args__ = (
        UniqueConstraint("tenant_id", "dimension_id", "code",
                         name="uq_dim_val_tenant_dim_code"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    dimension_id = Column(String(36), nullable=False, index=True)
    code = Column(String(64), nullable=False, index=True)
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=True)
    parent_value_id = Column(String(36), nullable=True, index=True)
    # Enables hierarchy: region → country → city
    active = Column(Boolean, nullable=False, default=True)
    created_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )


class JournalEntryDimension(Base, TenantMixin):
    """Link between a journal entry line and a dimension value."""

    __tablename__ = "journal_entry_dimensions"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "journal_entry_line_id", "dimension_id",
            name="uq_jed_tenant_jeline_dim",
        ),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    journal_entry_line_id = Column(String(36), nullable=False, index=True)
    dimension_id = Column(String(36), nullable=False, index=True)
    dimension_value_id = Column(String(36), nullable=False, index=True)
    amount = Column(Numeric(18, 2), nullable=False)
    # Denormalised so aggregate queries don't need to join journal_entry_lines.


# ── Schemas ────────────────────────────────────────────────


class DimensionDefIn(BaseModel):
    code: str = Field(..., pattern=r"^[a-z][a-z0-9_]{1,30}$")
    name_ar: str
    name_en: Optional[str] = None
    required: bool = False


class DimensionDefOut(BaseModel):
    id: str
    code: str
    name_ar: str
    name_en: Optional[str]
    required: bool
    active: bool
    created_at: datetime


class DimensionValueIn(BaseModel):
    code: str = Field(..., min_length=1, max_length=64)
    name_ar: str
    name_en: Optional[str] = None
    parent_value_id: Optional[str] = None


class DimensionValueOut(BaseModel):
    id: str
    dimension_id: str
    code: str
    name_ar: str
    name_en: Optional[str]
    parent_value_id: Optional[str]
    active: bool


# ── Service ────────────────────────────────────────────────


def ensure_default_dimensions() -> list[str]:
    """Create the 4 default dimensions if they don't already exist.

    Returns the list of created dimension codes. Idempotent.
    """
    defaults = [
        ("branch", "فرع", "Branch"),
        ("project", "مشروع", "Project"),
        ("cost_center", "مركز تكلفة", "Cost Center"),
        ("department", "قسم", "Department"),
    ]
    created: list[str] = []
    db = SessionLocal()
    try:
        existing = {d.code for d in db.query(DimensionDef).all()}
        for code, name_ar, name_en in defaults:
            if code in existing:
                continue
            db.add(DimensionDef(
                id=str(uuid.uuid4()),
                code=code,
                name_ar=name_ar,
                name_en=name_en,
            ))
            created.append(code)
        db.commit()
        return created
    finally:
        db.close()


def aggregate_by_dimension(
    dimension_id: str,
    period_start: Optional[datetime] = None,
    period_end: Optional[datetime] = None,
) -> list[dict]:
    """Pivot dimension postings by value.

    Returns [{value_id, value_code, value_name_ar, total_amount}, ...]
    ordered by absolute total descending.
    """
    from sqlalchemy import func

    db = SessionLocal()
    try:
        q = (
            db.query(
                JournalEntryDimension.dimension_value_id,
                func.sum(JournalEntryDimension.amount).label("total"),
            )
            .filter(JournalEntryDimension.dimension_id == dimension_id)
            .group_by(JournalEntryDimension.dimension_value_id)
        )
        rows = q.all()

        # Join with value metadata
        values = {
            v.id: v
            for v in db.query(DimensionValue).filter(
                DimensionValue.dimension_id == dimension_id
            ).all()
        }
        out = []
        for value_id, total in rows:
            v = values.get(value_id)
            out.append({
                "value_id": value_id,
                "code": v.code if v else "?",
                "name_ar": v.name_ar if v else "?",
                "total": float(total or 0),
            })
        out.sort(key=lambda x: abs(x["total"]), reverse=True)
        return out
    finally:
        db.close()


# ── REST API (/api/v1/dimensions/*) ────────────────────────


router = APIRouter(prefix=v1_prefix("/dimensions"), tags=["Dimensions"])


@router.get("")
def list_dimensions():
    db = SessionLocal()
    try:
        rows = db.query(DimensionDef).filter(DimensionDef.active.is_(True)).all()
        return {
            "success": True,
            "data": [
                DimensionDefOut(
                    id=d.id, code=d.code, name_ar=d.name_ar, name_en=d.name_en,
                    required=d.required, active=d.active, created_at=d.created_at,
                ).model_dump(mode="json")
                for d in rows
            ],
        }
    finally:
        db.close()


@router.post("", status_code=201)
def create_dimension(payload: DimensionDefIn):
    db = SessionLocal()
    try:
        # Explicit duplicate check — SQLite treats NULL-tenant rows as
        # distinct in UNIQUE constraints, so we enforce at app layer too.
        if db.query(DimensionDef).filter(DimensionDef.code == payload.code).first():
            raise HTTPException(status_code=409, detail="code already exists")
        dim = DimensionDef(
            id=str(uuid.uuid4()),
            code=payload.code,
            name_ar=payload.name_ar,
            name_en=payload.name_en,
            required=payload.required,
        )
        db.add(dim)
        try:
            db.commit()
        except Exception:
            db.rollback()
            raise HTTPException(status_code=409, detail="code already exists")
        db.refresh(dim)
        return {
            "success": True,
            "data": DimensionDefOut(
                id=dim.id, code=dim.code, name_ar=dim.name_ar, name_en=dim.name_en,
                required=dim.required, active=dim.active, created_at=dim.created_at,
            ).model_dump(mode="json"),
        }
    finally:
        db.close()


@router.get("/{dim_id}/values")
def list_values(dim_id: str):
    db = SessionLocal()
    try:
        rows = (
            db.query(DimensionValue)
            .filter(DimensionValue.dimension_id == dim_id)
            .filter(DimensionValue.active.is_(True))
            .order_by(DimensionValue.code)
            .all()
        )
        return {
            "success": True,
            "data": [
                {
                    "id": v.id,
                    "dimension_id": v.dimension_id,
                    "code": v.code,
                    "name_ar": v.name_ar,
                    "name_en": v.name_en,
                    "parent_value_id": v.parent_value_id,
                    "active": v.active,
                }
                for v in rows
            ],
        }
    finally:
        db.close()


@router.post("/{dim_id}/values", status_code=201)
def create_value(dim_id: str, payload: DimensionValueIn):
    db = SessionLocal()
    try:
        dim = db.query(DimensionDef).filter(DimensionDef.id == dim_id).first()
        if not dim:
            raise HTTPException(status_code=404, detail="dimension not found")
        val = DimensionValue(
            id=str(uuid.uuid4()),
            dimension_id=dim_id,
            code=payload.code,
            name_ar=payload.name_ar,
            name_en=payload.name_en,
            parent_value_id=payload.parent_value_id,
        )
        db.add(val)
        try:
            db.commit()
        except Exception:
            db.rollback()
            raise HTTPException(status_code=409, detail="code already exists for this dimension")
        db.refresh(val)
        return {
            "success": True,
            "data": {
                "id": val.id,
                "dimension_id": val.dimension_id,
                "code": val.code,
                "name_ar": val.name_ar,
                "name_en": val.name_en,
                "parent_value_id": val.parent_value_id,
                "active": val.active,
            },
        }
    finally:
        db.close()


@router.get("/{dim_id}/aggregate")
def aggregate(dim_id: str):
    return {"success": True, "data": aggregate_by_dimension(dim_id)}
