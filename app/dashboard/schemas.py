"""Pydantic v2 schemas for the dashboard API.

Kept separate from models.py so the FastAPI surface is decoupled from
the SQLAlchemy ORM (lets us evolve the wire format without migrations
and vice-versa).
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator

from app.dashboard.models import LayoutScope, WidgetType


# ── Catalog ────────────────────────────────────────────────


class WidgetOut(BaseModel):
    """A widget catalog entry as returned by GET /widgets."""

    code: str
    title_ar: str
    title_en: str
    description_ar: Optional[str] = None
    description_en: Optional[str] = None
    category: str
    widget_type: str
    data_source: Optional[str] = None
    default_span: int
    min_span: int
    max_span: int
    required_perms: list[str] = Field(default_factory=list)
    config_schema: Optional[dict[str, Any]] = None
    refresh_secs: int
    is_system: bool


# ── Layout ─────────────────────────────────────────────────


class LayoutBlock(BaseModel):
    """One placed widget inside a layout's `blocks` array."""

    id: str = Field(..., min_length=1, max_length=64)
    widget_code: str = Field(..., min_length=1, max_length=120)
    span: int = Field(default=4, ge=1, le=12)
    x: int = Field(default=0, ge=0, le=11)
    y: int = Field(default=0, ge=0)
    config: dict[str, Any] = Field(default_factory=dict)


class LayoutOut(BaseModel):
    id: str
    scope: str
    owner_id: Optional[str] = None
    name: str
    blocks: list[LayoutBlock]
    is_default: bool
    is_locked: bool
    version: int
    updated_at: datetime


class LayoutSaveIn(BaseModel):
    """Body of PUT /layout — saves the calling user's own layout."""

    name: str = Field(default="default", min_length=1, max_length=120)
    blocks: list[LayoutBlock]

    @field_validator("blocks")
    @classmethod
    def _no_dup_block_ids(cls, v: list[LayoutBlock]) -> list[LayoutBlock]:
        seen: set[str] = set()
        for b in v:
            if b.id in seen:
                raise ValueError(f"duplicate block id: {b.id}")
            seen.add(b.id)
        return v


class RoleLayoutSaveIn(LayoutSaveIn):
    """Body of PUT /role-layouts/{role_id} — admin assigns a role default."""

    is_default: bool = True


class LockToggleIn(BaseModel):
    is_locked: bool = True


# ── Data ───────────────────────────────────────────────────


class BatchDataRequest(BaseModel):
    entity_id: Optional[str] = None
    as_of_date: Optional[str] = None  # ISO date or NULL=now
    widgets: list[str] = Field(..., min_length=1, max_length=40)


class BatchDataResponse(BaseModel):
    computed_at: datetime
    data: dict[str, Any]
    errors: dict[str, str] = Field(default_factory=dict)


# ── Helpers ────────────────────────────────────────────────


def validate_widget_type(t: str) -> str:
    if t not in WidgetType.ALL:
        raise ValueError(f"invalid widget_type: {t}")
    return t


def validate_scope(s: str) -> str:
    if s not in LayoutScope.ALL:
        raise ValueError(f"invalid scope: {s}")
    return s


__all__ = [
    "WidgetOut",
    "LayoutBlock",
    "LayoutOut",
    "LayoutSaveIn",
    "RoleLayoutSaveIn",
    "LockToggleIn",
    "BatchDataRequest",
    "BatchDataResponse",
    "validate_widget_type",
    "validate_scope",
]
