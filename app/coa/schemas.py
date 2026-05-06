"""Pydantic v2 DTOs for the Chart of Accounts API.

Kept separate from `models.py` so the wire format is decoupled from
the SQLAlchemy ORM (lets us evolve either independently).
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator

from app.coa.models import AccountClass, NormalBalance


# ── Read DTOs ─────────────────────────────────────────────


class AccountOut(BaseModel):
    id: str
    entity_id: str
    account_code: str
    parent_id: Optional[str] = None
    level: int
    full_path: str
    name_ar: str
    name_en: Optional[str] = None
    account_class: str
    account_type: str
    normal_balance: str
    is_active: bool
    is_system: bool
    is_postable: bool
    is_reconcilable: bool
    requires_cost_center: bool
    requires_project: bool
    requires_partner: bool
    default_tax_rate: Optional[str] = None
    standard_ref: Optional[str] = None
    currency_code: Optional[str] = None
    tags: list[str] = Field(default_factory=list)
    custom_fields: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str] = None


class AccountTreeNode(AccountOut):
    """Same shape as AccountOut but with children attached."""

    children: list["AccountTreeNode"] = Field(default_factory=list)


# Pydantic v2 forward-reference resolution
AccountTreeNode.model_rebuild()


class TemplateSummaryOut(BaseModel):
    id: str
    code: str
    name_ar: str
    name_en: Optional[str] = None
    description_ar: Optional[str] = None
    description_en: Optional[str] = None
    standard: str
    industry: Optional[str] = None
    account_count: int
    is_official: bool
    created_at: datetime


class TemplateDetailOut(TemplateSummaryOut):
    accounts: list[dict[str, Any]] = Field(default_factory=list)


class ChangeLogEntryOut(BaseModel):
    id: str
    account_id: Optional[str] = None
    action: str
    diff: dict[str, Any]
    user_id: Optional[str] = None
    timestamp: datetime
    reason: Optional[str] = None


class UsageReportOut(BaseModel):
    account_id: str
    journal_lines: int = 0
    last_used_at: Optional[datetime] = None
    is_used_in_drafts: bool = False
    can_delete: bool = True
    deletion_blockers: list[str] = Field(default_factory=list)


# ── Write DTOs ────────────────────────────────────────────


class AccountCreateIn(BaseModel):
    entity_id: str = Field(..., min_length=1, max_length=36)
    account_code: str = Field(..., min_length=1, max_length=40)
    parent_id: Optional[str] = None
    name_ar: str = Field(..., min_length=1, max_length=200)
    name_en: Optional[str] = Field(default=None, max_length=200)
    account_class: str
    account_type: str = Field(..., min_length=1, max_length=40)
    normal_balance: str
    is_active: bool = True
    is_system: bool = False
    is_postable: bool = True
    is_reconcilable: bool = False
    requires_cost_center: bool = False
    requires_project: bool = False
    requires_partner: bool = False
    default_tax_rate: Optional[str] = Field(default=None, max_length=20)
    standard_ref: Optional[str] = Field(default=None, max_length=40)
    currency_code: Optional[str] = Field(default=None, min_length=3, max_length=3)
    tags: list[str] = Field(default_factory=list)
    custom_fields: dict[str, Any] = Field(default_factory=dict)

    @field_validator("account_class")
    @classmethod
    def _valid_class(cls, v: str) -> str:
        if v not in AccountClass.ALL:
            raise ValueError(f"invalid account_class: {v}")
        return v

    @field_validator("normal_balance")
    @classmethod
    def _valid_normal_balance(cls, v: str) -> str:
        if v not in NormalBalance.ALL:
            raise ValueError(f"invalid normal_balance: {v}")
        return v


class AccountUpdateIn(BaseModel):
    """Partial update — every field optional."""

    account_code: Optional[str] = Field(default=None, min_length=1, max_length=40)
    parent_id: Optional[str] = None
    name_ar: Optional[str] = Field(default=None, min_length=1, max_length=200)
    name_en: Optional[str] = Field(default=None, max_length=200)
    account_class: Optional[str] = None
    account_type: Optional[str] = Field(default=None, max_length=40)
    normal_balance: Optional[str] = None
    is_active: Optional[bool] = None
    is_postable: Optional[bool] = None
    is_reconcilable: Optional[bool] = None
    requires_cost_center: Optional[bool] = None
    requires_project: Optional[bool] = None
    requires_partner: Optional[bool] = None
    default_tax_rate: Optional[str] = Field(default=None, max_length=20)
    standard_ref: Optional[str] = Field(default=None, max_length=40)
    currency_code: Optional[str] = Field(default=None, min_length=3, max_length=3)
    tags: Optional[list[str]] = None
    custom_fields: Optional[dict[str, Any]] = None
    reason: Optional[str] = Field(default=None, max_length=400)

    @field_validator("account_class")
    @classmethod
    def _valid_class(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        if v not in AccountClass.ALL:
            raise ValueError(f"invalid account_class: {v}")
        return v

    @field_validator("normal_balance")
    @classmethod
    def _valid_normal_balance(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        if v not in NormalBalance.ALL:
            raise ValueError(f"invalid normal_balance: {v}")
        return v


class MergeIn(BaseModel):
    source_id: str
    target_id: str
    reason: Optional[str] = Field(default=None, max_length=400)


class ImportTemplateIn(BaseModel):
    entity_id: str
    overwrite: bool = False


class DeactivateIn(BaseModel):
    reason: Optional[str] = Field(default=None, max_length=400)


__all__ = [
    "AccountOut",
    "AccountTreeNode",
    "TemplateSummaryOut",
    "TemplateDetailOut",
    "ChangeLogEntryOut",
    "UsageReportOut",
    "AccountCreateIn",
    "AccountUpdateIn",
    "MergeIn",
    "ImportTemplateIn",
    "DeactivateIn",
]
