"""Entity (Legal Company) + Branch (Physical Location) models.

Hierarchy:
  Tenant (مجموعة الشركات)
    └── Entity (شركة قانونية مستقلة — عادة واحدة لكل دولة)
          └── Branch (موقع مادي — فرع في مدينة/حي)
                └── Warehouse / POS / ...

For the clothing customer:
  - 6 Entities (one per country: SA, QA, AE, KW, BH, EG)
  - Each Entity has 1..N Branches (cities or neighborhoods within cities)
  - Each Entity has its own GL, VAT, fiscal year, currency
  - Branches share the Entity's GL (same legal company = same books)

Consolidation happens at Tenant level across the 6 Entities.
"""

import enum
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, JSON, UniqueConstraint, Index
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class EntityType(str, enum.Enum):
    holding = "holding"            # شركة قابضة
    subsidiary = "subsidiary"      # شركة تابعة
    branch = "branch"              # فرع
    joint_venture = "joint_venture"  # مشروع مشترك
    associate = "associate"        # شركة زميلة


class EntityStatus(str, enum.Enum):
    active = "active"
    dormant = "dormant"            # مسجّلة لكن غير نشطة
    closing = "closing"            # قيد الإقفال النهائي
    closed = "closed"


class Entity(Base):
    """A legal entity — subsidiary, branch, or JV — within a Tenant."""
    __tablename__ = "pilot_entities"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    parent_entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="SET NULL"), nullable=True)

    # Identification
    code = Column(String(20), nullable=False)  # SA-RYD, AE-DXB, KW-KWT, ...
    name_ar = Column(String(255), nullable=False)
    name_en = Column(String(255), nullable=True)

    # Classification
    type = Column(String(30), nullable=False, default=EntityType.branch.value)
    status = Column(String(20), nullable=False, default=EntityStatus.active.value)

    # Legal
    country = Column(String(2), nullable=False)  # SA, AE, QA, KW, BH, EG
    cr_number = Column(String(50), nullable=True)
    vat_number = Column(String(50), nullable=True)
    local_tax_id = Column(String(50), nullable=True)  # UAE TRN, Egypt Tax Card, ...

    # Financial
    functional_currency = Column(String(3), nullable=False)  # SAR, AED, QAR, KWD, BHD, EGP
    reporting_currency_override = Column(String(3), nullable=True)  # optional override of tenant base
    fiscal_year_start_month = Column(Integer, nullable=True)  # inherits from tenant if null

    # Location (for branches)
    address_line1 = Column(String(255), nullable=True)
    address_line2 = Column(String(255), nullable=True)
    city = Column(String(100), nullable=True)
    region = Column(String(100), nullable=True)  # Riyadh Region, Makkah Region, ...
    postal_code = Column(String(20), nullable=True)
    phone = Column(String(30), nullable=True)
    email = Column(String(255), nullable=True)

    # ZATCA specific (Saudi entities)
    zatca_csid_id = Column(String(64), nullable=True)  # Cryptographic Stamp Identifier
    zatca_csid_expires_at = Column(DateTime(timezone=True), nullable=True)
    zatca_onboarding_status = Column(String(30), nullable=True)  # pending | onboarded | failed | expired

    # G-ENTITY-SELLER-INFO (2026-05-11): real seller identification
    # rendered into Phase-1 ZATCA QR codes (POS receipts + sales
    # invoice details). Pre-fix the frontend used hardcoded placeholders
    # ('APEX', '300000000000003') so any ZATCA scanner saw the wrong
    # company info. These columns persist per-entity legal identity:
    #   * seller_vat_number — 15-digit ZATCA VAT registration (no
    #     validation enforced beyond optional string; UI is responsible
    #     for masking + format).
    #   * seller_name_ar — Arabic legal name shown on the receipt
    #     (falls back to `name_ar` if null on the frontend).
    #   * seller_address_ar — optional, for Phase 2 readiness when
    #     ZATCA requires address on the simplified-tax invoice.
    # Nullable so existing entities upgrade cleanly (SQLAlchemy
    # create_all auto-adds the columns; no alembic migration needed).
    seller_vat_number = Column(String(20), nullable=True)
    seller_name_ar = Column(String(255), nullable=True)
    seller_address_ar = Column(String(512), nullable=True)

    # Display / sorting
    sort_order = Column(Integer, nullable=False, default=0)
    icon_emoji = Column(String(10), nullable=True)  # 🇸🇦 🇦🇪 ...

    # Extras
    extras = Column(JSON, nullable=False, default=dict)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)
    is_deleted = Column(Boolean, nullable=False, default=False)
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    tenant = relationship("Tenant", back_populates="entities")
    parent = relationship("Entity", remote_side=[id], backref="children")

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_entity_tenant_code"),
        Index("ix_pilot_entities_tenant_country", "tenant_id", "country"),
        Index("ix_pilot_entities_tenant_status", "tenant_id", "status"),
    )


class BranchType(str, enum.Enum):
    retail_store = "retail_store"        # متجر تجزئة
    wholesale = "wholesale"              # جملة
    warehouse_only = "warehouse_only"    # مستودع فقط (بدون بيع)
    head_office = "head_office"          # المقر الرئيسي
    showroom = "showroom"                # معرض
    popup = "popup"                      # مؤقت / موسمي
    online = "online"                    # متجر إلكتروني (افتراضي)
    office = "office"                    # مكتب إداري


class BranchStatus(str, enum.Enum):
    active = "active"
    opening_soon = "opening_soon"        # قيد الافتتاح
    closed_temp = "closed_temp"          # مُغلق مؤقتاً (صيانة/إجازة)
    closed_permanent = "closed_permanent"


class Branch(Base):
    """A physical or virtual location within an Entity.

    - Branch belongs to exactly ONE Entity (the legal company).
    - Entity = separate legal books / GL / taxes.
    - Branches share their Entity's GL (same double-entry books).
    - Warehouse/POS/Stock belong to a Branch (not Entity directly).
    """
    __tablename__ = "pilot_branches"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)

    # Identification
    code = Column(String(30), nullable=False)  # RYD-KFH-01, DXB-DUBAI-MALL, ...
    name_ar = Column(String(255), nullable=False)  # "فرع الرياض — طريق الملك فهد"
    name_en = Column(String(255), nullable=True)
    short_name = Column(String(50), nullable=True)  # displayed in tight UIs

    # Classification
    type = Column(String(30), nullable=False, default=BranchType.retail_store.value)
    status = Column(String(20), nullable=False, default=BranchStatus.active.value)

    # Location
    country = Column(String(2), nullable=False)  # inherited from entity by default
    city = Column(String(100), nullable=False)  # "الرياض", "دبي", ...
    district = Column(String(100), nullable=True)  # "العليا", "التحلية", ...
    address_line1 = Column(String(255), nullable=True)
    address_line2 = Column(String(255), nullable=True)
    postal_code = Column(String(20), nullable=True)
    latitude = Column(String(20), nullable=True)  # for delivery / map pin
    longitude = Column(String(20), nullable=True)

    # Physical attributes
    area_sqm = Column(Integer, nullable=True)  # مساحة بالمتر المربع
    capacity_skus = Column(Integer, nullable=True)  # سعة تقديرية
    shelf_count = Column(Integer, nullable=True)

    # Operating hours (stored as JSON for flexibility)
    # Example: {"sat": "10:00-23:00", "fri": "16:00-23:00", "fri_lunch": "12:00-13:30"}
    operating_hours = Column(JSON, nullable=False, default=dict)

    # Contact
    manager_user_id = Column(String(36), nullable=True)  # branch manager
    phone = Column(String(30), nullable=True)
    whatsapp = Column(String(30), nullable=True)
    email = Column(String(255), nullable=True)

    # Financial dimension defaults
    default_cost_center_id = Column(String(36), nullable=True)  # auto-apply on POS txns
    default_profit_center_id = Column(String(36), nullable=True)

    # Commercial flags
    accepts_returns = Column(Boolean, nullable=False, default=True)
    accepts_exchange = Column(Boolean, nullable=False, default=True)
    supports_delivery = Column(Boolean, nullable=False, default=False)
    supports_pickup = Column(Boolean, nullable=False, default=True)

    # POS configuration
    pos_station_count = Column(Integer, nullable=False, default=1)  # عدد نقاط البيع
    allowed_payment_methods = Column(JSON, nullable=False, default=list)
    # Example for SA: ["cash", "mada", "visa", "mastercard", "stc_pay", "apple_pay"]
    # Example for UAE: ["cash", "visa", "mastercard", "amex", "apple_pay"]

    # Opening date (for aging / analysis)
    opened_at = Column(DateTime(timezone=True), nullable=True)

    # Display
    sort_order = Column(Integer, nullable=False, default=0)

    # Extras
    extras = Column(JSON, nullable=False, default=dict)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)
    is_deleted = Column(Boolean, nullable=False, default=False)
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    entity = relationship("Entity", backref="branches")

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_branch_tenant_code"),
        Index("ix_pilot_branches_tenant_entity", "tenant_id", "entity_id"),
        Index("ix_pilot_branches_entity_city", "entity_id", "city"),
        Index("ix_pilot_branches_status", "status"),
    )
