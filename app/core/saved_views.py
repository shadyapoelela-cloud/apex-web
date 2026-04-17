"""Saved filter views — per-user per-screen filter presets.

User experience:
  • On any list screen (clients / invoices / JEs / ...) users apply
    filters + sort + columns, then hit "Save view" and name it.
  • Next time they open the screen, saved views appear in a dropdown.
  • Views can be shared with their tenant (team view) or kept private.

Storage:
  Table `saved_views` — tenant-scoped via TenantMixin.
  Payload is JSON: filter_state + column_widths + sort.

API:
  GET    /api/v1/saved-views?screen=clients
  POST   /api/v1/saved-views
  PUT    /api/v1/saved-views/{id}
  DELETE /api/v1/saved-views/{id}
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import Boolean, Column, DateTime, JSON, String, UniqueConstraint

from app.core.api_version import v1_prefix
from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base, SessionLocal

logger = logging.getLogger(__name__)


# ── Model ───────────────────────────────────────────────


class SavedView(Base, TenantMixin):
    """A named filter/column preset for a list screen."""

    __tablename__ = "saved_views"
    __table_args__ = (
        UniqueConstraint("tenant_id", "user_id", "screen", "name", name="uq_saved_view_scope"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=True, index=True)
    screen = Column(String(64), nullable=False, index=True)
    name = Column(String(120), nullable=False)
    payload = Column(JSON, nullable=False)
    is_shared = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), nullable=False,
                        default=lambda: datetime.now(timezone.utc))


# ── Schemas ────────────────────────────────────────────


class SavedViewIn(BaseModel):
    screen: str = Field(..., min_length=1, max_length=64)
    name: str = Field(..., min_length=1, max_length=120)
    payload: dict
    is_shared: bool = False


class SavedViewOut(BaseModel):
    id: str
    screen: str
    name: str
    payload: dict
    is_shared: bool
    created_at: datetime


# ── Routes ─────────────────────────────────────────────


router = APIRouter(prefix=v1_prefix("/saved-views"), tags=["Saved Views"])


@router.get("")
def list_saved_views(screen: str, user_id: Optional[str] = None):
    """List saved views for a screen. Returns shared + own private views."""
    db = SessionLocal()
    try:
        q = db.query(SavedView).filter(SavedView.screen == screen)
        rows = q.order_by(SavedView.created_at.desc()).all()
        # Client-side filtering: show shared + rows matching user_id.
        # (In production the `user_id` would come from the JWT, not a query param.)
        filtered = [
            r for r in rows if r.is_shared or r.user_id == user_id or r.user_id is None
        ]
        return {
            "success": True,
            "data": [
                {
                    "id": r.id,
                    "screen": r.screen,
                    "name": r.name,
                    "payload": r.payload,
                    "is_shared": r.is_shared,
                    "created_at": r.created_at.isoformat(),
                }
                for r in filtered
            ],
        }
    finally:
        db.close()


@router.post("", status_code=201)
def create_saved_view(payload: SavedViewIn, user_id: Optional[str] = None):
    db = SessionLocal()
    try:
        # App-layer duplicate guard — SQLite treats NULL as distinct in
        # UNIQUE, so the composite constraint on (tenant_id,user_id,
        # screen,name) misfires when either nullable column is NULL.
        existing = db.query(SavedView).filter(
            SavedView.screen == payload.screen,
            SavedView.name == payload.name,
            SavedView.user_id == user_id,
        ).first()
        if existing is not None:
            raise HTTPException(status_code=409, detail="A view with this name already exists")
        view = SavedView(
            id=str(uuid.uuid4()),
            user_id=user_id,
            screen=payload.screen,
            name=payload.name,
            payload=payload.payload,
            is_shared=payload.is_shared,
        )
        db.add(view)
        try:
            db.commit()
        except Exception:
            db.rollback()
            raise HTTPException(status_code=409, detail="A view with this name already exists")
        db.refresh(view)
        return {
            "success": True,
            "data": {
                "id": view.id,
                "screen": view.screen,
                "name": view.name,
                "payload": view.payload,
                "is_shared": view.is_shared,
                "created_at": view.created_at.isoformat(),
            },
        }
    finally:
        db.close()


@router.put("/{view_id}")
def update_saved_view(view_id: str, payload: SavedViewIn):
    db = SessionLocal()
    try:
        view = db.query(SavedView).filter(SavedView.id == view_id).first()
        if not view:
            raise HTTPException(status_code=404, detail="View not found")
        view.name = payload.name
        view.payload = payload.payload
        view.is_shared = payload.is_shared
        db.commit()
        return {"success": True, "data": {"id": view_id}}
    finally:
        db.close()


@router.delete("/{view_id}")
def delete_saved_view(view_id: str):
    db = SessionLocal()
    try:
        view = db.query(SavedView).filter(SavedView.id == view_id).first()
        if not view:
            raise HTTPException(status_code=404, detail="View not found")
        db.delete(view)
        db.commit()
        return {"success": True, "data": {"id": view_id}}
    finally:
        db.close()
