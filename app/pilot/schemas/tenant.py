"""Pydantic schemas for Tenant + CompanySettings."""

from datetime import datetime
from typing import Optional, Any
from pydantic import BaseModel, Field, EmailStr, ConfigDict


class TenantCreate(BaseModel):
    slug: str = Field(..., min_length=3, max_length=64, pattern=r"^[a-z0-9-]+$")
    legal_name_ar: str = Field(..., min_length=2, max_length=255)
    legal_name_en: Optional[str] = Field(None, max_length=255)
    trade_name: Optional[str] = Field(None, max_length=255)
    primary_cr_number: Optional[str] = Field(None, max_length=50)
    primary_vat_number: Optional[str] = Field(None, max_length=50)
    primary_country: str = Field("SA", min_length=2, max_length=2)
    primary_email: EmailStr
    primary_phone: Optional[str] = Field(None, max_length=20)
    tier: str = Field("starter")

    # Optional inline company settings
    base_currency: str = Field("SAR", min_length=3, max_length=3)
    fiscal_year_start_month: int = Field(1, ge=1, le=12)
    default_timezone: str = Field("Asia/Riyadh")


class TenantRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    slug: str
    legal_name_ar: str
    legal_name_en: Optional[str]
    trade_name: Optional[str]
    primary_cr_number: Optional[str]
    primary_vat_number: Optional[str]
    primary_country: str
    primary_email: str
    primary_phone: Optional[str]
    status: str
    tier: str
    trial_ends_at: Optional[datetime]
    features: dict[str, Any] = {}
    created_at: datetime


class TenantUpdate(BaseModel):
    legal_name_ar: Optional[str] = None
    legal_name_en: Optional[str] = None
    trade_name: Optional[str] = None
    primary_cr_number: Optional[str] = None
    primary_vat_number: Optional[str] = None
    primary_phone: Optional[str] = None
    billing_email: Optional[EmailStr] = None
    status: Optional[str] = None
    tier: Optional[str] = None
    features: Optional[dict[str, Any]] = None


class CompanySettingsRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    base_currency: str
    fiscal_year_start_month: int
    fiscal_year_start_day: int
    accounting_method: str
    period_type: str
    default_language: str
    default_calendar: str
    default_timezone: str
    je_prefix: str
    invoice_prefix: str
    bill_prefix: str
    po_prefix: str
    cn_prefix: str
    default_vat_rate: int
    zakat_rate_bp: int
    close_lock_policy: str
    lenient_days: int
    retention_years: int
    audit_log_reads: bool
    audit_log_writes: bool
    ai_enabled: bool
    ai_model: str
    ai_confidence_threshold_bp: int
    approval_thresholds: dict[str, Any]
    extras: dict[str, Any]


class CompanySettingsUpdate(BaseModel):
    base_currency: Optional[str] = None
    fiscal_year_start_month: Optional[int] = Field(None, ge=1, le=12)
    fiscal_year_start_day: Optional[int] = Field(None, ge=1, le=31)
    accounting_method: Optional[str] = None
    default_language: Optional[str] = None
    default_calendar: Optional[str] = None
    default_timezone: Optional[str] = None
    je_prefix: Optional[str] = None
    invoice_prefix: Optional[str] = None
    bill_prefix: Optional[str] = None
    po_prefix: Optional[str] = None
    cn_prefix: Optional[str] = None
    default_vat_rate: Optional[int] = Field(None, ge=0, le=100)
    zakat_rate_bp: Optional[int] = Field(None, ge=0, le=10000)
    close_lock_policy: Optional[str] = None
    ai_enabled: Optional[bool] = None
    ai_model: Optional[str] = None
    ai_confidence_threshold_bp: Optional[int] = Field(None, ge=0, le=10000)
    approval_thresholds: Optional[dict[str, Any]] = None
    extras: Optional[dict[str, Any]] = None
