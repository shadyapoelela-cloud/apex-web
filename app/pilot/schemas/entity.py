"""Pydantic schemas for Entity + Branch."""

from datetime import datetime
from typing import Optional, Any
from pydantic import BaseModel, Field, EmailStr, ConfigDict


class EntityCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=20)
    name_ar: str = Field(..., min_length=2, max_length=255)
    name_en: Optional[str] = None
    type: str = Field("branch")
    country: str = Field(..., min_length=2, max_length=2)
    cr_number: Optional[str] = None
    vat_number: Optional[str] = None
    local_tax_id: Optional[str] = None
    functional_currency: str = Field(..., min_length=3, max_length=3)
    reporting_currency_override: Optional[str] = None
    fiscal_year_start_month: Optional[int] = Field(None, ge=1, le=12)
    address_line1: Optional[str] = None
    city: Optional[str] = None
    region: Optional[str] = None
    postal_code: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[EmailStr] = None
    icon_emoji: Optional[str] = None
    parent_entity_id: Optional[str] = None


class EntityRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    parent_entity_id: Optional[str]
    code: str
    name_ar: str
    name_en: Optional[str]
    type: str
    status: str
    country: str
    cr_number: Optional[str]
    vat_number: Optional[str]
    local_tax_id: Optional[str]
    functional_currency: str
    reporting_currency_override: Optional[str]
    fiscal_year_start_month: Optional[int]
    city: Optional[str]
    region: Optional[str]
    phone: Optional[str]
    email: Optional[str]
    zatca_csid_id: Optional[str]
    zatca_onboarding_status: Optional[str]
    # G-ENTITY-SELLER-INFO (2026-05-11): seller identity surfaced for
    # ZATCA Phase-1 QR rendering on POS receipts and sales-invoice
    # details. All three are nullable so legacy entities still load
    # (frontend uses placeholders when null).
    seller_vat_number: Optional[str] = None
    seller_name_ar: Optional[str] = None
    seller_address_ar: Optional[str] = None
    icon_emoji: Optional[str]
    sort_order: int
    created_at: datetime


class EntityUpdate(BaseModel):
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    status: Optional[str] = None
    cr_number: Optional[str] = None
    vat_number: Optional[str] = None
    local_tax_id: Optional[str] = None
    functional_currency: Optional[str] = None
    fiscal_year_start_month: Optional[int] = Field(None, ge=1, le=12)
    address_line1: Optional[str] = None
    city: Optional[str] = None
    region: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[EmailStr] = None
    zatca_csid_id: Optional[str] = None
    zatca_onboarding_status: Optional[str] = None
    # G-ENTITY-SELLER-INFO (2026-05-11): PATCHable seller identity.
    seller_vat_number: Optional[str] = None
    seller_name_ar: Optional[str] = None
    seller_address_ar: Optional[str] = None
    icon_emoji: Optional[str] = None
    sort_order: Optional[int] = None
    extras: Optional[dict[str, Any]] = None


class BranchCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=30)
    name_ar: str = Field(..., min_length=2, max_length=255)
    name_en: Optional[str] = None
    short_name: Optional[str] = None
    type: str = Field("retail_store")
    city: str = Field(..., min_length=2, max_length=100)
    district: Optional[str] = None
    address_line1: Optional[str] = None
    address_line2: Optional[str] = None
    postal_code: Optional[str] = None
    latitude: Optional[str] = None
    longitude: Optional[str] = None
    area_sqm: Optional[int] = None
    capacity_skus: Optional[int] = None
    operating_hours: dict[str, Any] = Field(default_factory=dict)
    phone: Optional[str] = None
    whatsapp: Optional[str] = None
    email: Optional[EmailStr] = None
    manager_user_id: Optional[str] = None
    default_cost_center_id: Optional[str] = None
    default_profit_center_id: Optional[str] = None
    pos_station_count: int = Field(1, ge=0, le=100)
    allowed_payment_methods: list[str] = Field(default_factory=list)
    accepts_returns: bool = True
    accepts_exchange: bool = True
    supports_delivery: bool = False
    supports_pickup: bool = True
    sort_order: int = 0


class BranchRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    entity_id: str
    code: str
    name_ar: str
    name_en: Optional[str]
    short_name: Optional[str]
    type: str
    status: str
    country: str
    city: str
    district: Optional[str]
    address_line1: Optional[str]
    postal_code: Optional[str]
    area_sqm: Optional[int]
    phone: Optional[str]
    whatsapp: Optional[str]
    email: Optional[str]
    manager_user_id: Optional[str]
    pos_station_count: int
    allowed_payment_methods: list[str]
    accepts_returns: bool
    supports_delivery: bool
    supports_pickup: bool
    opened_at: Optional[datetime]
    sort_order: int
    operating_hours: dict[str, Any] = {}
    created_at: datetime


class BranchUpdate(BaseModel):
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    short_name: Optional[str] = None
    type: Optional[str] = None
    status: Optional[str] = None
    city: Optional[str] = None
    district: Optional[str] = None
    address_line1: Optional[str] = None
    phone: Optional[str] = None
    whatsapp: Optional[str] = None
    email: Optional[EmailStr] = None
    manager_user_id: Optional[str] = None
    pos_station_count: Optional[int] = None
    allowed_payment_methods: Optional[list[str]] = None
    accepts_returns: Optional[bool] = None
    supports_delivery: Optional[bool] = None
    operating_hours: Optional[dict[str, Any]] = None
    sort_order: Optional[int] = None
    extras: Optional[dict[str, Any]] = None
