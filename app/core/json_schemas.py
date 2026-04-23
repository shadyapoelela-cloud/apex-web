"""
APEX — Pydantic validators for critical JSON columns

Auditor flagged 185 JSON columns accepted without schema validation.
Malformed JSON would be silently stored, then crash at runtime when
consumed. This module provides strict schemas for the highest-impact
JSONs so routes can validate at the boundary.

Usage:
    from app.core.json_schemas import ApprovalThresholds, OperatingHours

    @router.patch("/settings")
    def update_settings(payload: CompanySettingsPatch):
        if payload.approval_thresholds is not None:
            ApprovalThresholds.model_validate(payload.approval_thresholds)
        ...

Extending: add new Pydantic models here (not per-route) so there's a
single source of truth for JSON shapes.
"""
from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator


# ════════════════════════════════════════════════════════════════════
# approval_thresholds (CompanySettings) — multi-level approval rules
# Shape:
#   {
#     "je":  [{"max": 10000, "role": "manager", "level": 1}, ...],
#     "po":  [...],
#     "exp": [...]
#   }
# ════════════════════════════════════════════════════════════════════
VALID_ROLES = ("owner", "admin", "manager", "accountant", "clerk")


class ApprovalRule(BaseModel):
    max: float = Field(..., ge=0, description="Max amount for this tier")
    role: Literal["owner", "admin", "manager", "accountant", "clerk"]
    level: int = Field(..., ge=1, le=10)


class ApprovalThresholds(BaseModel):
    """Per-doc-type approval ladders.

    Each list MUST be sorted by `max` ascending and cover the full
    non-negative range (first tier max=0 is the auto-approve floor;
    last tier should use a very large cap).
    """

    je: list[ApprovalRule] = Field(default_factory=list)
    po: list[ApprovalRule] = Field(default_factory=list)
    exp: list[ApprovalRule] = Field(default_factory=list)

    @field_validator("je", "po", "exp")
    @classmethod
    def _ladder_must_be_sorted(cls, v: list[ApprovalRule]) -> list[ApprovalRule]:
        prev: float = -1.0
        for r in v:
            if r.max < prev:
                raise ValueError(
                    "approval ladder must be sorted by 'max' ascending"
                )
            prev = r.max
        return v


# ════════════════════════════════════════════════════════════════════
# operating_hours (Branch) — day → "HH:MM-HH:MM" (or "closed")
# ════════════════════════════════════════════════════════════════════
_DAY_KEYS = ("sat", "sun", "mon", "tue", "wed", "thu", "fri")


def _valid_hours(v: str) -> str:
    """Accepts 'HH:MM-HH:MM' or 'closed'."""
    if v == "closed":
        return v
    try:
        start, end = v.split("-")
        for part in (start.strip(), end.strip()):
            hh, mm = part.split(":")
            if not (0 <= int(hh) <= 23 and 0 <= int(mm) <= 59):
                raise ValueError
        return v
    except Exception:  # noqa: BLE001
        raise ValueError(
            f"operating hours must be 'HH:MM-HH:MM' or 'closed', got {v!r}"
        )


class OperatingHours(BaseModel):
    """7-day weekly schedule, each value is "HH:MM-HH:MM" or "closed"."""

    sat: Optional[str] = None
    sun: Optional[str] = None
    mon: Optional[str] = None
    tue: Optional[str] = None
    wed: Optional[str] = None
    thu: Optional[str] = None
    fri: Optional[str] = None

    @field_validator("sat", "sun", "mon", "tue", "wed", "thu", "fri")
    @classmethod
    def _validate_hours(cls, v: Optional[str]) -> Optional[str]:
        return None if v is None else _valid_hours(v)


# ════════════════════════════════════════════════════════════════════
# ratios (AnalysisResult) — financial ratio snapshot
# ════════════════════════════════════════════════════════════════════
class FinancialRatios(BaseModel):
    current_ratio: Optional[float] = None
    quick_ratio: Optional[float] = None
    cash_ratio: Optional[float] = None
    debt_to_equity: Optional[float] = None
    debt_to_assets: Optional[float] = None
    gross_margin: Optional[float] = None
    operating_margin: Optional[float] = None
    net_margin: Optional[float] = None
    roa: Optional[float] = None
    roe: Optional[float] = None
    working_capital: Optional[float] = None


# ════════════════════════════════════════════════════════════════════
# applied_rules (ResultExplanation) — rules that fired for a judgment
# ════════════════════════════════════════════════════════════════════
class AppliedRule(BaseModel):
    rule_code: str = Field(..., min_length=1, max_length=64)
    rule_name: str = Field(..., min_length=1, max_length=200)
    severity: Optional[Literal["info", "warning", "error", "critical"]] = None
    citation: Optional[str] = None  # e.g., "IAS 16 §31"


class AppliedRulesList(BaseModel):
    rules: list[AppliedRule] = Field(default_factory=list)


__all__ = [
    "ApprovalRule",
    "ApprovalThresholds",
    "OperatingHours",
    "FinancialRatios",
    "AppliedRule",
    "AppliedRulesList",
]
