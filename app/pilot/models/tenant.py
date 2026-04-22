"""Tenant model — the top of the ownership hierarchy.

Every other table has `tenant_id` pointing here. This is the SaaS
boundary — one tenant can NEVER see another tenant's data.

Example: "شركة الأزياء الفاخرة" is ONE tenant with 6 entities (branches).
"""

import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Boolean, DateTime, Text, Integer, ForeignKey, JSON, Index
from sqlalchemy.orm import relationship
import enum

# Reuse the same Base as phase1 so all tables end up in the same DB
from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class TenantStatus(str, enum.Enum):
    trial = "trial"            # 30-day trial, limited features
    active = "active"          # paid subscription
    suspended = "suspended"    # payment failed / policy violation
    cancelled = "cancelled"


class TenantTier(str, enum.Enum):
    starter = "starter"        # 1 entity, 5 users, 500 SKUs
    growth = "growth"          # 3 entities, 20 users, 10K SKUs
    enterprise = "enterprise"  # unlimited
    custom = "custom"          # contracted


class Tenant(Base):
    """The customer organization. Root of all data."""
    __tablename__ = "pilot_tenants"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    slug = Column(String(64), unique=True, nullable=False, index=True)  # e.g., "luxury-fashion-sa"
    legal_name_ar = Column(String(255), nullable=False)
    legal_name_en = Column(String(255), nullable=True)
    trade_name = Column(String(255), nullable=True)

    # Commercial registration (primary — usually the main entity's)
    primary_cr_number = Column(String(50), nullable=True)  # 1010234567
    primary_vat_number = Column(String(50), nullable=True)  # 300987654300003
    primary_country = Column(String(2), nullable=False, default="SA")  # ISO-3166

    # Contact
    primary_email = Column(String(255), nullable=False, index=True)
    primary_phone = Column(String(20), nullable=True)
    billing_email = Column(String(255), nullable=True)

    # Status & plan
    status = Column(String(20), nullable=False, default=TenantStatus.trial.value)
    tier = Column(String(20), nullable=False, default=TenantTier.starter.value)
    trial_ends_at = Column(DateTime(timezone=True), nullable=True)
    subscription_started_at = Column(DateTime(timezone=True), nullable=True)
    subscription_renews_at = Column(DateTime(timezone=True), nullable=True)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    # Feature flags as JSON (enables on/off per tenant)
    features = Column(JSON, nullable=False, default=dict)
    # e.g., {"zatca": true, "gosi": true, "wps": false, "uae_ct": true}

    # Relationships (lazy-loaded)
    company_settings = relationship("CompanySettings", back_populates="tenant", uselist=False, cascade="all, delete-orphan")
    entities = relationship("Entity", back_populates="tenant", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_pilot_tenants_country_status", "primary_country", "status"),
    )


class CompanySettings(Base):
    """Tenant-wide configuration. One row per tenant (1:1)."""
    __tablename__ = "pilot_company_settings"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)

    # Financial configuration
    base_currency = Column(String(3), nullable=False, default="SAR")  # ISO-4217
    fiscal_year_start_month = Column(Integer, nullable=False, default=1)  # 1=Jan, 4=Apr, 7=Jul
    fiscal_year_start_day = Column(Integer, nullable=False, default=1)
    accounting_method = Column(String(20), nullable=False, default="accrual")  # accrual | cash
    period_type = Column(String(20), nullable=False, default="monthly")  # monthly | 4-4-5

    # Localization
    default_language = Column(String(5), nullable=False, default="ar-SA")
    default_calendar = Column(String(20), nullable=False, default="gregorian")  # gregorian | hijri
    default_timezone = Column(String(64), nullable=False, default="Asia/Riyadh")

    # Numbering — prefixes for document types
    je_prefix = Column(String(20), nullable=False, default="JE")
    invoice_prefix = Column(String(20), nullable=False, default="INV")
    bill_prefix = Column(String(20), nullable=False, default="VB")
    po_prefix = Column(String(20), nullable=False, default="PO")
    cn_prefix = Column(String(20), nullable=False, default="CN")

    # Tax defaults
    default_vat_rate = Column(Integer, nullable=False, default=15)  # basis points / 100 = 15%
    zakat_rate_bp = Column(Integer, nullable=False, default=250)  # 2.50% = 250 bp

    # Close policy
    close_lock_policy = Column(String(20), nullable=False, default="hard")  # hard | soft | lenient
    lenient_days = Column(Integer, nullable=False, default=0)

    # Document retention (ZATCA requires 7 years)
    retention_years = Column(Integer, nullable=False, default=7)

    # Audit trail policy
    audit_log_reads = Column(Boolean, nullable=False, default=False)
    audit_log_writes = Column(Boolean, nullable=False, default=True)
    audit_log_failures = Column(Boolean, nullable=False, default=True)

    # AI configuration
    ai_enabled = Column(Boolean, nullable=False, default=True)
    ai_model = Column(String(100), nullable=False, default="claude-opus-4-7")
    ai_confidence_threshold_bp = Column(Integer, nullable=False, default=8500)  # 85.00%

    # Approval thresholds (stored as JSON for flexibility)
    approval_thresholds = Column(JSON, nullable=False, default=lambda: {
        "je": [
            {"max": 50000, "role": "accountant", "level": 1},
            {"max": 500000, "role": "accounting_manager", "level": 2},
            {"max": 5000000, "role": "cfo", "level": 3},
            {"max": None, "role": "board", "level": 4, "dual_approval": True},
        ],
        "po": [
            {"max": 25000, "role": "department_manager", "level": 1},
            {"max": 250000, "role": "operations_manager", "level": 2},
            {"max": None, "role": "ceo", "level": 3},
        ],
    })

    # Branding — شكل المستندات والفواتير
    logo_url = Column(String(500), nullable=True)  # URL أو data: URI (base64)
    logo_position = Column(String(20), nullable=False, default="right")  # right|left|center
    brand_primary_color = Column(String(7), nullable=False, default="#D4AF37")  # hex
    brand_secondary_color = Column(String(7), nullable=False, default="#0A1628")
    invoice_header_html = Column(String(2000), nullable=True)  # HTML/نص للعرض في رأس الفاتورة
    invoice_footer_html = Column(String(2000), nullable=True)  # HTML/نص للعرض في ذيل الفاتورة
    invoice_terms_ar = Column(String(2000), nullable=True)  # الشروط والأحكام بالعربية
    invoice_terms_en = Column(String(2000), nullable=True)  # الشروط بالإنجليزية
    signature_url = Column(String(500), nullable=True)  # توقيع رقمي (صورة)
    show_vat_breakdown = Column(Boolean, nullable=False, default=True)
    show_qr_on_invoice = Column(Boolean, nullable=False, default=True)

    # Extra settings as JSON for future expansion
    extras = Column(JSON, nullable=False, default=dict)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    tenant = relationship("Tenant", back_populates="company_settings")


class SettingsChangeLog(Base):
    """سجل التغييرات على إعدادات الشركة — لتتبّع من غيّر ماذا ومتى.

    يميّز APEX عن QBO/Xero/SAP: كل تغيير يُسجّل بـ diff قابل للقراءة,
    مع إمكانية الاستعادة (rollback) لأي تعديل.
    """
    __tablename__ = "pilot_settings_change_log"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)

    # Category (fiscal / currency / tax / approvals / numbering / security / audit / ai / backup / regional / branding / tenant)
    category = Column(String(32), nullable=False, index=True)

    # List of {field, old_value, new_value} — JSON
    changes = Column(JSON, nullable=False, default=list)

    # Who + when
    changed_by_user_id = Column(String(36), nullable=True, index=True)
    changed_by_name = Column(String(100), nullable=True)
    changed_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, index=True)

    # Optional comment / rollback reference
    note = Column(Text, nullable=True)
    rolled_back_from_id = Column(String(36), nullable=True)

    __table_args__ = (
        Index("ix_pilot_settings_log_tenant_cat_time", "tenant_id", "category", "changed_at"),
    )
