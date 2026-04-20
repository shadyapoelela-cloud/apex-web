"""Pydantic schemas for Currency + FxRate."""

from datetime import date, datetime
from typing import Optional
from decimal import Decimal
from pydantic import BaseModel, Field, ConfigDict


class CurrencyCreate(BaseModel):
    code: str = Field(..., min_length=3, max_length=3)
    name_ar: str
    name_en: str
    symbol: Optional[str] = None
    decimal_places: int = Field(2, ge=0, le=4)
    is_active: bool = True
    is_base_currency: bool = False
    sort_order: int = 0
    emoji_flag: Optional[str] = None


class CurrencyRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    code: str
    name_ar: str
    name_en: str
    symbol: Optional[str]
    decimal_places: int
    is_active: bool
    is_base_currency: bool
    sort_order: int
    emoji_flag: Optional[str]


class FxRateCreate(BaseModel):
    from_currency: str = Field(..., min_length=3, max_length=3)
    to_currency: str = Field(..., min_length=3, max_length=3)
    rate: Decimal = Field(..., gt=0)
    rate_type: str = Field("spot", pattern="^(spot|avg_month|closing|historical)$")
    effective_date: date
    source: str = Field("manual")
    source_reference: Optional[str] = None


class FxRateRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    from_currency: str
    to_currency: str
    rate: Decimal
    rate_type: str
    effective_date: date
    source: str
    source_reference: Optional[str]
    created_at: datetime
