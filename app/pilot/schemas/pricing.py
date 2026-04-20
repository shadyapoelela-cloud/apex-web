"""Pydantic schemas for price lists."""

from datetime import datetime, date
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


# ──────────────────────────────────────────────────────────────────────────
# PriceListItem
# ──────────────────────────────────────────────────────────────────────────

class PriceListItemCreate(BaseModel):
    variant_id: str
    unit_price: Decimal
    unit_cost: Optional[Decimal] = None
    min_qty: Decimal = Decimal("1")
    promo_discount_pct: Optional[Decimal] = None
    original_price: Optional[Decimal] = None
    promo_starts_at: Optional[datetime] = None
    promo_ends_at: Optional[datetime] = None
    reference_note: Optional[str] = None


class PriceListItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    price_list_id: str
    variant_id: str
    unit_price: Decimal
    unit_cost: Optional[Decimal]
    margin_pct: Optional[Decimal]
    min_qty: Decimal
    promo_discount_pct: Optional[Decimal]
    original_price: Optional[Decimal]
    promo_starts_at: Optional[datetime]
    promo_ends_at: Optional[datetime]
    is_active: bool
    reference_note: Optional[str]


class PriceListItemUpdate(BaseModel):
    unit_price: Optional[Decimal] = None
    unit_cost: Optional[Decimal] = None
    min_qty: Optional[Decimal] = None
    promo_discount_pct: Optional[Decimal] = None
    original_price: Optional[Decimal] = None
    promo_starts_at: Optional[datetime] = None
    promo_ends_at: Optional[datetime] = None
    is_active: Optional[bool] = None
    reference_note: Optional[str] = None


# ──────────────────────────────────────────────────────────────────────────
# PriceList
# ──────────────────────────────────────────────────────────────────────────

class PriceListCreate(BaseModel):
    code: str = Field(..., min_length=3, max_length=50)
    name_ar: str = Field(..., min_length=1, max_length=255)
    name_en: Optional[str] = None
    description_ar: Optional[str] = None

    kind: str = Field("retail", pattern="^(retail|wholesale|promo|contract|staff)$")
    season: str = Field("year_round", pattern="^(spring|summer|fall|winter|ramadan|eid|back_to_school|black_friday|year_round)$")
    currency: str = Field(..., min_length=3, max_length=3)

    scope: str = Field("tenant", pattern="^(tenant|entity|branch|customer_group)$")
    entity_id: Optional[str] = None
    branch_ids: list[str] = Field(default_factory=list)  # when scope=branch
    customer_group_code: Optional[str] = None

    valid_from: date
    valid_to: Optional[date] = None

    priority: int = 100

    is_promo: bool = False
    promo_name_ar: Optional[str] = None
    promo_badge_text_ar: Optional[str] = None
    promo_color_hex: Optional[str] = Field(None, pattern="^#[0-9A-Fa-f]{6}$")

    prices_include_vat: bool = True
    rounding_method: str = Field("nearest_halala", pattern="^(nearest_halala|nearest_riyal|psychological|none)$")

    # Optional inline items — create list + N items in one call
    items: list[PriceListItemCreate] = Field(default_factory=list)


class PriceListRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    code: str
    name_ar: str
    name_en: Optional[str]
    description_ar: Optional[str]
    kind: str
    season: str
    currency: str
    scope: str
    entity_id: Optional[str]
    customer_group_code: Optional[str]
    valid_from: date
    valid_to: Optional[date]
    priority: int
    status: str
    is_active: bool
    is_promo: bool
    promo_name_ar: Optional[str]
    promo_badge_text_ar: Optional[str]
    promo_color_hex: Optional[str]
    prices_include_vat: bool
    rounding_method: str
    approved_by_user_id: Optional[str]
    approved_at: Optional[datetime]


class PriceListDetail(PriceListRead):
    branch_ids: list[str] = Field(default_factory=list)
    item_count: int = 0
    items: list[PriceListItemRead] = Field(default_factory=list)


class PriceListUpdate(BaseModel):
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    description_ar: Optional[str] = None
    kind: Optional[str] = None
    season: Optional[str] = None
    valid_from: Optional[date] = None
    valid_to: Optional[date] = None
    priority: Optional[int] = None
    is_promo: Optional[bool] = None
    promo_name_ar: Optional[str] = None
    promo_badge_text_ar: Optional[str] = None
    promo_color_hex: Optional[str] = None
    prices_include_vat: Optional[bool] = None
    rounding_method: Optional[str] = None


# ──────────────────────────────────────────────────────────────────────────
# Activation / approval
# ──────────────────────────────────────────────────────────────────────────

class PriceListActivate(BaseModel):
    approved_by_user_id: Optional[str] = None


# ──────────────────────────────────────────────────────────────────────────
# Bulk item upsert (CSV import-like)
# ──────────────────────────────────────────────────────────────────────────

class PriceListBulkItems(BaseModel):
    items: list[PriceListItemCreate]
    replace_existing: bool = Field(
        False,
        description="If true, deletes all existing items before inserting. If false, upserts by (variant_id, min_qty)."
    )


# ──────────────────────────────────────────────────────────────────────────
# Price lookup (POS)
# ──────────────────────────────────────────────────────────────────────────

class PriceLookupResponse(BaseModel):
    variant_id: str
    branch_id: Optional[str] = None
    at_time: datetime
    qty: Decimal

    # Resolved price
    unit_price: Decimal
    currency: str
    prices_include_vat: bool
    source: str = Field(..., description="price_list | variant_default | no_price")

    # If source = price_list
    price_list_id: Optional[str] = None
    price_list_code: Optional[str] = None
    price_list_name_ar: Optional[str] = None
    item_id: Optional[str] = None

    # Promo context for UI badge
    is_promo: bool = False
    promo_discount_pct: Optional[Decimal] = None
    original_price: Optional[Decimal] = None
    promo_badge_text_ar: Optional[str] = None
    promo_color_hex: Optional[str] = None
